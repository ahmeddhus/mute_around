//! C API over libDF used by the Mute Around engine (`native/engine/src/mute_df.h`).
//!
//! Every function catches panics, so no unwinding ever crosses into C.
//! Rust allocations on the engine's processing thread come from a
//! preallocated pool (see `rt_alloc`), never from the system heap.

mod rt_alloc;

use std::ffi::{c_char, CStr};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::PathBuf;
use std::sync::Once;

use df::tract::{DfParams, DfTract, RuntimeParams};
use ndarray::{ArrayView2, ArrayViewMut2};

#[global_allocator]
static ALLOCATOR: rt_alloc::RtAlloc = rt_alloc::RtAlloc;

/// Size of each model's real-time pool. DFN3-ll's per-frame working set is a
/// few MiB; power-of-two size classes can double that.
const RT_POOL_BYTES: usize = 32 << 20;

/// Opaque DeepFilterNet state. Field order matters: the model (whose blocks
/// may live in the pool) is dropped before the pool.
pub struct MdfState {
    model: DfTract,
    pool: Box<rt_alloc::Pool>,
}

static SILENCE_PANICS: Once = Once::new();

fn copy_error(msg: &str, buf: *mut c_char, cap: usize) {
    if buf.is_null() || cap == 0 {
        return;
    }
    let bytes = msg.as_bytes();
    let n = bytes.len().min(cap - 1);
    // SAFETY: the caller guarantees `buf` holds `cap` bytes.
    unsafe {
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), buf.cast::<u8>(), n);
        *buf.add(n) = 0;
    }
}

/// Loads a model. `model_path` NULL uses the embedded DFN3 low-latency model.
/// Returns NULL on failure and writes the reason into `err` (`err_cap` bytes).
///
/// # Safety
/// `model_path` must be NULL or a valid NUL-terminated string; `err` must be
/// NULL or point to `err_cap` writable bytes.
#[no_mangle]
pub unsafe extern "C" fn mdf_create(
    model_path: *const c_char,
    atten_lim_db: f32,
    err: *mut c_char,
    err_cap: usize,
) -> *mut MdfState {
    // A panic would otherwise print to stderr; the engine reports errors itself.
    SILENCE_PANICS.call_once(|| std::panic::set_hook(Box::new(|_| {})));

    let path = if model_path.is_null() {
        None
    } else {
        match CStr::from_ptr(model_path).to_str() {
            Ok(p) => Some(PathBuf::from(p)),
            Err(_) => {
                copy_error("model path is not valid UTF-8", err, err_cap);
                return std::ptr::null_mut();
            }
        }
    };

    let result = catch_unwind(move || -> Result<MdfState, String> {
        let params = match path {
            Some(p) => DfParams::new(p).map_err(|e| format!("{e:#}"))?,
            None => DfParams::default(),
        };
        let runtime = RuntimeParams::default_with_ch(1).with_atten_lim(atten_lim_db);
        let model = DfTract::new(params, &runtime).map_err(|e| format!("{e:#}"))?;
        let pool = rt_alloc::Pool::create(RT_POOL_BYTES)
            .ok_or_else(|| "could not reserve the real-time memory pool".to_string())?;
        Ok(MdfState { model, pool })
    });

    match result {
        Ok(Ok(state)) => Box::into_raw(Box::new(state)),
        Ok(Err(msg)) => {
            copy_error(&msg, err, err_cap);
            std::ptr::null_mut()
        }
        Err(_) => {
            copy_error("model loading panicked", err, err_cap);
            std::ptr::null_mut()
        }
    }
}

/// Hop size in samples (480 = 10 ms at 48 kHz for DFN3).
///
/// # Safety
/// `st` must come from `mdf_create`.
#[no_mangle]
pub unsafe extern "C" fn mdf_frame_length(st: *const MdfState) -> usize {
    st.as_ref().map_or(0, |s| s.model.hop_size)
}

/// Denoises one hop of `mdf_frame_length` samples from `input` into `output`.
/// Returns the local SNR in dB, or NaN on error (then `output` is untouched).
///
/// # Safety
/// `st` must come from `mdf_create`; both buffers must hold a full hop.
#[no_mangle]
pub unsafe extern "C" fn mdf_process_frame(
    st: *mut MdfState,
    input: *const f32,
    output: *mut f32,
) -> f32 {
    let Some(state) = st.as_mut() else { return f32::NAN };
    if input.is_null() || output.is_null() {
        return f32::NAN;
    }
    let hop = state.model.hop_size;
    let result = catch_unwind(AssertUnwindSafe(|| {
        let input = ArrayView2::from_shape_ptr((1, hop), input);
        let output = ArrayViewMut2::from_shape_ptr((1, hop), output);
        state.model.process(input, output)
    }));
    match result {
        Ok(Ok(lsnr)) => lsnr,
        _ => f32::NAN,
    }
}

/// Sets the maximum noise attenuation in dB.
///
/// # Safety
/// `st` must come from `mdf_create`.
#[no_mangle]
pub unsafe extern "C" fn mdf_set_atten_lim(st: *mut MdfState, lim_db: f32) {
    if let Some(state) = st.as_mut() {
        let _ = catch_unwind(AssertUnwindSafe(|| state.model.set_atten_lim(lim_db)));
    }
}

/// Makes the calling thread allocate from `st`'s pool until `mdf_rt_leave`.
/// Call on the processing thread before the first `mdf_process_frame`.
///
/// # Safety
/// `st` must come from `mdf_create` and outlive the entered period.
#[no_mangle]
pub unsafe extern "C" fn mdf_rt_enter(st: *const MdfState) {
    if let Some(state) = st.as_ref() {
        rt_alloc::enter(&state.pool);
    }
}

/// Returns the calling thread to the system allocator.
#[no_mangle]
pub extern "C" fn mdf_rt_leave() {
    rt_alloc::leave();
}

/// Allocations on an entered thread that had to fall back to the system heap
/// (pool exhausted or unusual alignment). Should stay 0.
#[no_mangle]
pub extern "C" fn mdf_rt_fallbacks() -> usize {
    rt_alloc::fallbacks()
}

/// Frees a state. Safe on NULL. Call only after every thread entered on it
/// has called `mdf_rt_leave`.
///
/// # Safety
/// `st` must be NULL or come from `mdf_create`, and not be used afterwards.
#[no_mangle]
pub unsafe extern "C" fn mdf_free(st: *mut MdfState) {
    if !st.is_null() {
        let MdfState { model, pool } = *Box::from_raw(st);
        drop(model);
        rt_alloc::Pool::release(pool);
    }
}
