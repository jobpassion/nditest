
#import "NDISender.h"
#import <os/lock.h>

extern "C" {
  #include "Processing.NDI.Lib.h"
}

@interface NDISender () {
    NDIlib_send_instance_t _sender;
    os_unfair_lock _lock;
}
@end

@implementation NDISender

- (instancetype)initWithName:(NSString *)name clockAudio:(BOOL)clockAudio {
    self = [super init];
    if (!self) return nil;

    if (!NDIlib_initialize()) {
        NSLog(@"NDIlib_initialize failed");
        return nil;
    }

    NDIlib_send_create_t create_desc = {0};
    create_desc.p_ndi_name = name.UTF8String;
    create_desc.clock_audio = clockAudio ? true : false;
    create_desc.clock_video = true;

    _sender = NDIlib_send_create(&create_desc);
    if (!_sender) {
        NSLog(@"NDIlib_send_create failed");
        return nil;
    }

    _lock = OS_UNFAIR_LOCK_INIT;
    return self;
}

- (void)sendBGRAFrame:(CVPixelBufferRef)pixelBuffer
                width:(int)width
               height:(int)height
           timecodeNS:(int64_t)tcNS {
    if (!_sender || !pixelBuffer) return;

    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    void *base = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t stride = CVPixelBufferGetBytesPerRow(pixelBuffer);

    NDIlib_video_frame_v2_t frame = {0};
    frame.xres = width;
    frame.yres = height;
    frame.line_stride_in_bytes = (int)stride;
    frame.FourCC = NDIlib_FourCC_video_type_BGRX; // Treat BGRA as BGRX
    frame.frame_rate_N = 30000;
    frame.frame_rate_D = 1001;
    frame.picture_aspect_ratio = (float)width / (float)height;
    frame.frame_format_type = NDIlib_frame_format_type_progressive;
    frame.timecode = (int64_t)tcNS; // NDI expects 100ns units; SDK will scale if given ns.
    frame.p_data = (uint8_t *)base;

    os_unfair_lock_lock(&_lock);
    NDIlib_send_send_video_v2(_sender, &frame);
    os_unfair_lock_unlock(&_lock);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

- (void)sendPCMBuffer:(AVAudioPCMBuffer *)buffer
           sampleRate:(int)sampleRate
           timecodeNS:(int64_t)tcNS {
    if (!_sender || !buffer) return;

    AVAudioFormat *fmt = buffer.format;
    if (fmt.commonFormat != AVAudioCommonFormat.pcmFormatFloat32 || fmt.isInterleaved) {
        NSLog(@"NDISender expects float32 planar audio");
        return;
    }
    const int channels = (int)fmt.channelCount;
    const int frames = (int)buffer.frameLength;
    if (channels <= 0 || frames <= 0) return;

    float * const *planes = buffer.floatChannelData;
    if (!planes) return;

    NDIlib_audio_frame_v3_t audio = {0};
    audio.sample_rate = sampleRate;
    audio.no_channels = channels;
    audio.no_samples = frames;
    audio.channel_stride_in_bytes = (int)buffer.stride * (int)sizeof(float);
    audio.timecode = (int64_t)tcNS;
    audio.p_data = (float * const *)planes;

    os_unfair_lock_lock(&_lock);
    NDIlib_send_send_audio_v3(_sender, &audio);
    os_unfair_lock_unlock(&_lock);
}

- (void)destroy {
    if (_sender) {
        NDIlib_send_destroy(_sender);
        _sender = nullptr;
    }
    NDIlib_destroy();
}

- (void)dealloc {
    [self destroy];
}

@end
