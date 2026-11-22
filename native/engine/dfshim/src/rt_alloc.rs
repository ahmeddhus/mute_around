//! Real-time-safe allocator for the processing thread.
//!
//! libDF/tract allocate small tensors on every frame (~800 per 10 ms hop).
//! The audio-thread rules forbid system-heap allocation on real-time threads, so
//! this global allocator serves a thread that called [`enter`] from a pool
//! that was allocated and touched up front:
//!
//! - Power-of-two size classes (16 B … 16 MB), one free list per class: O(1)
//!   allocate and free, no system calls, no locks, no page faults.
//! - Blocks freed by another thread (e.g. when the model is dropped on the
//!   control thread) go onto a per-class lock-free stack (push-only Treiber
//!   stack); the owning thread takes the whole stack with one atomic swap.
//! - When a request doesn't fit (pool exhausted, alignment > 4 KiB) it falls
//!   back to the system heap and bumps [`fallbacks`], which the engine's
//!   zero-allocation test checks.
//!
//! - A pool counts its outstanding blocks. Some live in thread-locals (tract
//!   scratch buffers) and are only freed when their thread exits, possibly
//!   after the model is gone, so [`Pool::release`] frees the region only when
//!   nothing is outstanding and otherwise keeps it registered (a bounded,
//!   one-off leak rather than a use-after-free).
//!
//! Threads that never call [`enter`] use the system allocator unchanged.

use std::alloc::{GlobalAlloc, Layout, System};
use std::cell::Cell;
use std::ptr::{self, null_mut};
use std::sync::atomic::{AtomicPtr, AtomicUsize, Ordering};

const MIN_SHIFT: u32 = 4; // 16 bytes: room for a free-list link
const MAX_SHIFT: u32 = 24; // 16 MiB
const NUM_CLASSES: usize = (MAX_SHIFT - MIN_SHIFT + 1) as usize;
const MAX_BLOCK_ALIGN: usize = 4096;
const MAX_POOLS: usize = 8;

struct FreeNode {
    next: *mut FreeNode,
}

/// A fixed region carved into size-class blocks. `bump` and `local` are only
/// touched by the thread the pool is entered on; `remote` by anyone.
pub struct Pool {
    base: *mut u8,
    size: usize,
    bump: Cell<usize>,
    local: [Cell<*mut FreeNode>; NUM_CLASSES],
    remote: [AtomicPtr<FreeNode>; NUM_CLASSES],
    outstanding: AtomicUsize,
}

// SAFETY: owner-only fields are only used from the entered thread (see
// `enter`); cross-thread access goes through `remote`, which is atomic.
unsafe impl Sync for Pool {}
unsafe impl Send for Pool {}

static POOLS: [AtomicPtr<Pool>; MAX_POOLS] = [const { AtomicPtr::new(null_mut()) }; MAX_POOLS];
static FALLBACKS: AtomicUsize = AtomicUsize::new(0);

thread_local! {
    static CURRENT: Cell<*const Pool> = const { Cell::new(ptr::null()) };
}

fn class_of(layout: Layout) -> Option<usize> {
    if layout.align() > MAX_BLOCK_ALIGN {
        return None;
    }
    let need = layout.size().max(layout.align()).max(1);
    let shift = usize::BITS - (need - 1).leading_zeros();
    let shift = shift.max(MIN_SHIFT);
    if shift > MAX_SHIFT {
        return None;
    }
    Some((shift - MIN_SHIFT) as usize)
}

impl Pool {
    /// Allocates and touches a pool of `size` bytes and registers it.
    /// Returns `None` if the system can't provide it or too many pools exist.
    pub fn create(size: usize) -> Option<Box<Pool>> {
        let layout = Layout::from_size_align(size, MAX_BLOCK_ALIGN).ok()?;
        // SAFETY: non-zero size, valid alignment.
        let base = unsafe { System.alloc(layout) };
        if base.is_null() {
            return None;
        }
        // Touch every page now so the real-time thread never page-faults.
        unsafe { ptr::write_bytes(base, 0, size) };
        let pool = Box::new(Pool {
            base,
            size,
            bump: Cell::new(0),
            local: [const { Cell::new(null_mut()) }; NUM_CLASSES],
            remote: [const { AtomicPtr::new(null_mut()) }; NUM_CLASSES],
            outstanding: AtomicUsize::new(0),
        });
        let raw = &*pool as *const Pool as *mut Pool;
        for slot in &POOLS {
            if slot
                .compare_exchange(null_mut(), raw, Ordering::AcqRel, Ordering::Relaxed)
                .is_ok()
            {
                return Some(pool);
            }
        }
        unsafe { System.dealloc(base, layout) };
        None
    }

    fn contains(&self, p: *mut u8) -> bool {
        let addr = p as usize;
        let base = self.base as usize;
        addr >= base && addr < base + self.size
    }

    /// Frees the pool, or keeps it alive and registered if blocks are still
    /// outstanding (see the module docs).
    pub fn release(pool: Box<Pool>) {
        if pool.outstanding.load(Ordering::Acquire) == 0 {
            drop(pool);
        } else {
            Box::leak(pool);
        }
    }

    /// Owner thread only.
    unsafe fn alloc(&self, class: usize) -> *mut u8 {
        let p = self.alloc_block(class);
        if !p.is_null() {
            self.outstanding.fetch_add(1, Ordering::Relaxed);
        }
        p
    }

    unsafe fn alloc_block(&self, class: usize) -> *mut u8 {
        let head = self.local[class].get();
        if !head.is_null() {
            self.local[class].set((*head).next);
            return head.cast();
        }
        let stolen = self.remote[class].swap(null_mut(), Ordering::Acquire);
        if !stolen.is_null() {
            self.local[class].set((*stolen).next);
            return stolen.cast();
        }
        let block = 1usize << (class as u32 + MIN_SHIFT);
        let align = block.min(MAX_BLOCK_ALIGN);
        let start = (self.bump.get() + align - 1) & !(align - 1);
        if start + block > self.size {
            return null_mut();
        }
        self.bump.set(start + block);
        self.base.add(start)
    }

    /// Owner thread only.
    unsafe fn free_local(&self, p: *mut u8, class: usize) {
        let node = p.cast::<FreeNode>();
        (*node).next = self.local[class].get();
        self.local[class].set(node);
        self.outstanding.fetch_sub(1, Ordering::Release);
    }

    /// Any thread.
    unsafe fn free_remote(&self, p: *mut u8, class: usize) {
        let node = p.cast::<FreeNode>();
        let mut head = self.remote[class].load(Ordering::Relaxed);
        loop {
            (*node).next = head;
            match self.remote[class].compare_exchange_weak(
                head,
                node,
                Ordering::Release,
                Ordering::Relaxed,
            ) {
                Ok(_) => {
                    self.outstanding.fetch_sub(1, Ordering::Release);
                    return;
                }
                Err(h) => head = h,
            }
        }
    }
}

impl Drop for Pool {
    fn drop(&mut self) {
        let me = self as *mut Pool;
        for slot in &POOLS {
            let _ = slot.compare_exchange(me, null_mut(), Ordering::AcqRel, Ordering::Relaxed);
        }
        // SAFETY: same layout as in `create`.
        unsafe {
            System.dealloc(self.base, Layout::from_size_align_unchecked(self.size, MAX_BLOCK_ALIGN))
        };
    }
}

/// Routes this thread's Rust allocations to `pool` until [`leave`].
/// Only one thread may be entered on a pool at a time.
pub fn enter(pool: &Pool) {
    CURRENT.with(|c| c.set(pool as *const Pool));
}

/// Returns this thread to the system allocator.
pub fn leave() {
    CURRENT.with(|c| c.set(ptr::null()));
}

/// Number of allocations on an entered thread that had to use the system heap.
pub fn fallbacks() -> usize {
    FALLBACKS.load(Ordering::Relaxed)
}

fn owning_pool(p: *mut u8) -> Option<&'static Pool> {
    for slot in &POOLS {
        let q = slot.load(Ordering::Acquire);
        // SAFETY: registered pools stay alive until they unregister in Drop.
        if !q.is_null() && unsafe { (*q).contains(p) } {
            return Some(unsafe { &*q });
        }
    }
    None
}

pub struct RtAlloc;

unsafe impl GlobalAlloc for RtAlloc {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let pool = CURRENT.with(Cell::get);
        if !pool.is_null() {
            if let Some(class) = class_of(layout) {
                let p = (*pool).alloc(class);
                if !p.is_null() {
                    return p;
                }
            }
            FALLBACKS.fetch_add(1, Ordering::Relaxed);
        }
        System.alloc(layout)
    }

    unsafe fn dealloc(&self, p: *mut u8, layout: Layout) {
        let current = CURRENT.with(Cell::get);
        if !current.is_null() && (*current).contains(p) {
            // Blocks in a pool always came from `class_of(layout)`.
            (*current).free_local(p, class_of(layout).unwrap_unchecked());
            return;
        }
        if let Some(pool) = owning_pool(p) {
            pool.free_remote(p, class_of(layout).unwrap_unchecked());
            return;
        }
        System.dealloc(p, layout)
    }

    unsafe fn realloc(&self, p: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
        let new_layout = Layout::from_size_align_unchecked(new_size, layout.align());
        let in_pool = {
            let current = CURRENT.with(Cell::get);
            (!current.is_null() && (*current).contains(p)) || owning_pool(p).is_some()
        };
        // A pool block already big enough for the new size can stay put.
        if in_pool && class_of(layout) == class_of(new_layout) {
            return p;
        }
        if !in_pool && CURRENT.with(Cell::get).is_null() {
            return System.realloc(p, layout, new_size);
        }
        let q = self.alloc(new_layout);
        if !q.is_null() {
            ptr::copy_nonoverlapping(p, q, layout.size().min(new_size));
            self.dealloc(p, layout);
        }
        q
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classes() {
        assert_eq!(class_of(Layout::from_size_align(1, 1).unwrap()), Some(0));
        assert_eq!(class_of(Layout::from_size_align(16, 8).unwrap()), Some(0));
        assert_eq!(class_of(Layout::from_size_align(17, 8).unwrap()), Some(1));
        assert_eq!(class_of(Layout::from_size_align(8, 64).unwrap()), Some(2));
        assert_eq!(class_of(Layout::from_size_align(1 << 24, 8).unwrap()), Some(20));
        assert_eq!(class_of(Layout::from_size_align((1 << 24) + 1, 8).unwrap()), None);
        assert_eq!(class_of(Layout::from_size_align(8, 8192).unwrap()), None);
    }
}
