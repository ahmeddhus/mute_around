# DeepFilterNet model

The engine uses the **DeepFilterNet 3 low-latency model** (no lookahead,
≈ 20 ms STFT window).

It isn't copied here. The model file is
`third_party/deepfilternet/models/DeepFilterNet3_ll_onnx.tar.gz` in the
DeepFilterNet submodule (tag v0.5.6). The Rust shim (`../dfshim`) builds
libDF with the `default-model-ll` feature, which **embeds** that tarball in
the library, so `me_engine_create(NULL, …)` needs no model file at runtime.
To try another model, pass the path of a DFN `.tar.gz` to
`me_engine_create`.

License: the model weights, like the code, are dual-licensed MIT /
Apache-2.0 (DeepFilterNet README, "License" section). See `LICENSE-MIT` and
`LICENSE-APACHE` next to this file.
