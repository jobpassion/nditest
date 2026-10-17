
#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NDISender : NSObject

- (instancetype)initWithName:(NSString *)name clockAudio:(BOOL)clockAudio;

// BGRA (kCVPixelFormatType_32BGRA) frame
- (void)sendBGRAFrame:(CVPixelBufferRef)pixelBuffer
                width:(int)width
               height:(int)height
           timecodeNS:(int64_t)tcNS;

// AVAudioPCMBuffer (float32, non-interleaved). If not float32 planar, it will be rejected.
- (void)sendPCMBuffer:(AVAudioPCMBuffer *)buffer
           sampleRate:(int)sampleRate
           timecodeNS:(int64_t)tcNS;

- (void)destroy;

@end

NS_ASSUME_NONNULL_END
