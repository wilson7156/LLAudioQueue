//
//  LLAudioQueue.m
//  FBSnapshotTestCase
//
//  Created by wilson on 2019/12/4.
//

#import "LLAudioQueue.h"

@interface LLAudioQueue ()

@property (nonatomic,strong) NSError *error;

@end

@implementation LLAudioQueue

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format error:(NSError *__autoreleasing  _Nullable * _Nullable)error {
    
    self = [super init];
    if (self) {
        
        if (error) {
            self.error = *error;
        }
        self->_format = format;
        [self createAudioQueue];
    }
    return self;
}

- (void)start {
    
    if (!self->_audioQueue) {
        return;
    }
    OSStatus status = AudioQueueStart(self->_audioQueue, 0);
    if (status != noErr) {
        [self generatorError:@"AudioQueueStart failure" code:status];
    }
}

- (void)pause {
    
    if (!self->_audioQueue) {
        return;
    }
    OSStatus status = AudioQueuePause(self->_audioQueue);
    if (status != noErr) {
        [self generatorError:@"AudioQueueStart failure" code:status];
    }
}

- (void)stopInImmediate:(BOOL)inImmediate {
    
    if (!self->_audioQueue) {
        return;
    }
    OSStatus status = AudioQueueFlush(self->_audioQueue);
    if (status != noErr) {
        [self generatorError:@"AudioQueueStart failure" code:status];
        return;
    }
    status = AudioQueueStop(self->_audioQueue, inImmediate);
    if (status != noErr) {
        [self generatorError:@"AudioQueueStart failure" code:status];
    }
}

- (float)progress {
    
    AudioTimeStamp timeStamp;
    OSStatus status = AudioQueueGetCurrentTime(self->_audioQueue, NULL, &timeStamp, NULL);
    if (status != noErr) {
        return 0;
    }
    
    return timeStamp.mSampleTime / self.format.mSampleRate;
}

- (void)setVolume:(CGFloat)volume {
    _volume = volume;
    
    if (self->_audioQueue) {
        AudioQueueSetParameter(self->_audioQueue, kAudioQueueParam_Volume, volume);
    }
}

- (void)createAudioQueue {
    
    OSStatus status = AudioQueueNewOutput(&self->_format, LLAudioQueueOutputCallback, (__bridge void * _Nullable)(self), NULL, NULL, 0, &(self->_audioQueue));
    if (status != noErr) {
        AudioQueueDispose(self->_audioQueue, YES);
        [self generatorError:@"AudioQueueNewOutput error" code:status];
        return;
    }
    
    status = AudioQueueAddPropertyListener(self->_audioQueue, kAudioQueueProperty_IsRunning, LLAudioQueueOutputPropertyCallback, (__bridge void * _Nullable)(self));
    if (status != noErr) {
        [self generatorError:@"AudioQueueAddPropertyListener kAudioQueueProperty_IsRunning error" code:status];
    }
}

- (void)generatorError:(NSString *)errorString code:(UInt32)code {
    
    if (code != 0) {
        NSError *error = [NSError errorWithDomain:errorString code:code userInfo:nil];
        self.error = error;
    }
}

#pragma mark - Callback
static void LLAudioQueueOutputCallback(
                                       void * __nullable       inUserData,
                                       AudioQueueRef           inAQ,
                                       AudioQueueBufferRef     inBuffer) {
    
    LLAudioQueue *audioQueuePlay = (__bridge LLAudioQueue *)(inUserData);
    [audioQueuePlay handleAudioQueueOutputWithBuffer:inBuffer];
}

static void LLAudioQueueOutputPropertyCallback(
                                               void * __nullable       inUserData,
                                               AudioQueueRef           inAQ,
                                               AudioQueuePropertyID    inID) {
    
    LLAudioQueue *audioPlayer = (__bridge LLAudioQueue *)(inUserData);
    [audioPlayer hanleAudioQueueProperty:inID];
    
}

#pragma mark - Callback Method
- (void)handleAudioQueueOutputWithBuffer:(AudioQueueBufferRef)buffer {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(audioQueue:didFinishBuffer:)]) {
            [self.delegate audioQueue:self didFinishBuffer:buffer];
        }
    });
}

- (void)hanleAudioQueueProperty:(AudioQueuePropertyID)propertyId {
    
    UInt32 running = 0;
    UInt32 runningSize = sizeof(running);
    AudioQueueGetProperty(self->_audioQueue, kAudioQueueProperty_IsRunning, &runningSize, &running);
    self->_running = running;
}

- (void)dealloc
{
    if (self->_audioQueue) {
        AudioQueueDispose(self->_audioQueue, NO);
    }
}

@end
