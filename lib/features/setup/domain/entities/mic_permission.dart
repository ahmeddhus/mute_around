/// Whether the app may use the microphone.
///
/// macOS reports it through `AVCaptureDevice`. Windows has no query API, so
/// it stays [notDetermined] until the engine fails to open the microphone
/// with "access denied", which makes it [denied].
enum MicPermission { granted, denied, notDetermined }
