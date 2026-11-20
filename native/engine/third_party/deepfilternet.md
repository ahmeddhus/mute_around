# DeepFilterNet (libDF)

- Source: https://github.com/Rikorose/DeepFilterNet, git submodule at
  `native/engine/third_party/deepfilternet`, pinned to tag **v0.5.6**.
- License: MIT / Apache-2.0 (code and model weights).
- Crate used: `deep_filter` (`libDF/`), linked through our shim
  `native/engine/dfshim` with features **`tract`** and
  **`default-model-ll`** (default features off).
- We don't use the `capi` feature: its `df_create` can't take a NULL path,
  always embeds the standard (lookahead) model, and panics on errors. The
  shim exposes `mdf_*` (see `native/engine/src/mute_df.h`) instead, and adds
  the real-time pool allocator (`dfshim/src/rt_alloc.rs`).
- Model: `models/DeepFilterNet3_ll_onnx.tar.gz`, embedded at build time.
- Dependency pins: `dfshim/Cargo.lock` starts from upstream's lockfile. Only
  `time` 0.3.x was bumped, because the old version doesn't compile on Rust ≥ 1.80.
