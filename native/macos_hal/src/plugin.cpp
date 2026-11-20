// Mute Around virtual microphone: a Core Audio Audio Server plug-in (libASPL).
//
// Publishes one device, "Mute Around" (UID com.mutearound.virtualmic), with
// an output stream the app plays processed audio into and an input stream
// meeting apps record from. Output is looped back
// to input through a ring indexed by device sample time, so:
//   - any number of clients can read the same audio at the same time;
//   - samples are only returned for the exact time they were written, so
//     when nothing is writing (app closed) every reader gets silence;
//   - added latency is about one IO cycle.
//
// Real-time rules: the IO callbacks only index preallocated arrays; no
// allocation, locks, logging or system calls.
#include <aspl/Driver.hpp>

#include <CoreAudio/AudioServerPlugIn.h>

#include <cstdint>
#include <memory>
#include <vector>

namespace {

constexpr UInt32 kSampleRate = 48000;
constexpr UInt32 kChannels = 1;
// ~340 ms of history: far more than any IO buffer, so writes never lap reads.
constexpr int64_t kRingFrames = 1 << 14;
constexpr int64_t kRingMask = kRingFrames - 1;

constexpr const char* kDeviceName = "Mute Around";
constexpr const char* kDeviceUID = "com.mutearound.virtualmic";
constexpr const char* kModelUID = "com.mutearound.virtualmic.model";

AudioStreamBasicDescription FloatMonoFormat() {
    AudioStreamBasicDescription f = {};
    f.mSampleRate = kSampleRate;
    f.mFormatID = kAudioFormatLinearPCM;
    f.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian |
                     kAudioFormatFlagIsPacked;
    f.mBitsPerChannel = 32;
    f.mChannelsPerFrame = kChannels;
    f.mBytesPerFrame = sizeof(float) * kChannels;
    f.mFramesPerPacket = 1;
    f.mBytesPerPacket = f.mBytesPerFrame;
    return f;
}

// Loops the mixed output back to every client's input.
class LoopbackHandler : public aspl::ControlRequestHandler, public aspl::IORequestHandler {
   public:
    LoopbackHandler() : samples_(kRingFrames, 0.0f), times_(kRingFrames, -1) {}

    void OnWriteMixedOutput(const std::shared_ptr<aspl::Stream>& stream, Float64 zeroTimestamp,
                            Float64 timestamp, const void* bytes, UInt32 bytesCount) override {
        (void)stream;
        (void)zeroTimestamp;
        const auto* in = static_cast<const float*>(bytes);
        const auto frames = static_cast<int64_t>(bytesCount / sizeof(float));
        const auto start = static_cast<int64_t>(timestamp);
        for (int64_t i = 0; i < frames; i++) {
            const int64_t t = start + i;
            samples_[t & kRingMask] = in[i];
            times_[t & kRingMask] = t;
        }
    }

    void OnReadClientInput(const std::shared_ptr<aspl::Client>& client,
                           const std::shared_ptr<aspl::Stream>& stream, Float64 zeroTimestamp,
                           Float64 timestamp, void* bytes, UInt32 bytesCount) override {
        (void)client;
        (void)stream;
        (void)zeroTimestamp;
        auto* out = static_cast<float*>(bytes);
        const auto frames = static_cast<int64_t>(bytesCount / sizeof(float));
        const auto start = static_cast<int64_t>(timestamp);
        for (int64_t i = 0; i < frames; i++) {
            const int64_t t = start + i;
            out[i] = times_[t & kRingMask] == t ? samples_[t & kRingMask] : 0.0f;
        }
    }

   private:
    // Only touched from the device's IO thread.
    std::vector<float> samples_;
    std::vector<int64_t> times_;
};

// The output side must never become the system's default output, or system
// sounds would leak into meetings. The input side may be the default input.
class MuteAroundDevice : public aspl::Device {
   public:
    using aspl::Device::Device;

    OSStatus GetPropertyData(AudioObjectID objectID, pid_t clientPID,
                             const AudioObjectPropertyAddress* address, UInt32 qualifierDataSize,
                             const void* qualifierData, UInt32 inDataSize, UInt32* outDataSize,
                             void* outData) const override {
        if (address->mSelector == kAudioDevicePropertyDeviceCanBeDefaultDevice &&
            address->mScope == kAudioObjectPropertyScopeOutput) {
            if (inDataSize < sizeof(UInt32)) return kAudioHardwareBadPropertySizeError;
            *static_cast<UInt32*>(outData) = 0;
            *outDataSize = sizeof(UInt32);
            return kAudioHardwareNoError;
        }
        return aspl::Device::GetPropertyData(objectID, clientPID, address, qualifierDataSize,
                                             qualifierData, inDataSize, outDataSize, outData);
    }
};

std::shared_ptr<aspl::Driver> CreateDriver() {
    // No tracing: coreaudiod would otherwise log every property access.
    auto tracer = std::make_shared<aspl::Tracer>(aspl::Tracer::Mode::Noop);
    auto context = std::make_shared<aspl::Context>(tracer);

    aspl::DeviceParameters params;
    params.Name = kDeviceName;
    params.Manufacturer = kDeviceName;
    params.DeviceUID = kDeviceUID;
    params.ModelUID = kModelUID;
    params.SampleRate = kSampleRate;
    params.ChannelCount = kChannels;
    params.CanBeDefault = true;
    params.CanBeDefaultForSystemSounds = false;

    auto device = std::make_shared<MuteAroundDevice>(context, params);

    aspl::StreamParameters input;
    input.Direction = aspl::Direction::Input;
    input.Format = FloatMonoFormat();
    device->AddStreamAsync(input);

    aspl::StreamParameters output;
    output.Direction = aspl::Direction::Output;
    output.Format = FloatMonoFormat();
    device->AddStreamAsync(output);

    auto handler = std::make_shared<LoopbackHandler>();
    device->SetControlHandler(handler);
    device->SetIOHandler(handler);

    auto plugin = std::make_shared<aspl::Plugin>(context);
    plugin->AddDevice(device);
    return std::make_shared<aspl::Driver>(context, plugin);
}

}  // namespace

// Factory function named in Info.plist (CFPlugInFactories).
extern "C" void* MuteAroundEntryPoint(CFAllocatorRef allocator, CFUUIDRef typeUUID) {
    (void)allocator;
    if (!CFEqual(typeUUID, kAudioServerPlugInTypeUUID)) return nullptr;
    static std::shared_ptr<aspl::Driver> driver = CreateDriver();
    return driver->GetReference();
}
