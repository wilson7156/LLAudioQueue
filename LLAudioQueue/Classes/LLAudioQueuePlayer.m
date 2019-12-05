//
//  LLAudioQueuePlayer.m
//  LLAudioQueue
//
//  Created by wilson on 2019/11/28.
//

#import "LLAudioQueuePlayer.h"
#import "LLAudioQueueBuffer.h"
#import "LLAudioQueue.h"

@interface LLAudioQueuePlayer ()<LLAudioQueueBufferDelegagte,LLAudioQueueDelegate> {
    
    BOOL _havePlay;
}

@property (nonatomic,strong) NSError *error;
@property (nonatomic,strong) LLAudioQueueBufferThread *bufferThread;
@property (nonatomic,strong) LLAudioQueue *audioQueue;
@end

@implementation LLAudioQueuePlayer

- (instancetype)initWithAudioStreamBasicDescription:(AudioStreamBasicDescription)format error:(NSError *__autoreleasing  _Nullable *)error {
    
    self = [super init];
    if (self) {
        self->_format = format;
        if (error) {
            self.error = *error;
        }
        
        self.audioQueue = [[LLAudioQueue alloc] initWithFormat:format error:error];
        self.audioQueue.delegate = self;
    }
    return self;
}

#pragma mark - Public Method
- (void)playDatas:(NSArray *)audioDatas {
    
    if (!self.bufferThread) {
    
        self.bufferThread = [[LLAudioQueueBufferThread alloc] initWithBufferCount:2 audioQueue:self.audioQueue.audioQueue];
        self.bufferThread.delegate = self;
        [self.bufferThread start];
    }
    [self.bufferThread appendData:audioDatas];
    self->_havePlay = YES;
}

- (long long)lastPlayDataSize {
    return self.bufferThread.lastEnqueueDataSize;
}

- (void)start {
    
    self->_playStatus = LLAudioQueuePlayStatusPlaying;
    [self.audioQueue start];
}

- (void)pause {
    
    self->_playStatus = LLAudioQueuePlayStatusPause;
    [self.audioQueue pause];
}

- (void)stop {
    
    self->_playStatus = LLAudioQueuePlayStatusStop;
    [self.audioQueue stopInImmediate:YES];
    [self.bufferThread cancel];
    self.bufferThread = nil;
}

- (void)setVolume:(CGFloat)volume {
    _volume = volume;
    self.audioQueue.volume = volume;
}

- (float)progress {
    return self.audioQueue.progress;
}

#pragma mark - Private Method
- (void)callStatusDelegate {
    if ([self.delegate respondsToSelector:@selector(audioQueuePlayer:audioStatusChanged:)]) {
        [self.delegate audioQueuePlayer:self audioStatusChanged:self->_playStatus];
    }
}


#pragma mark - LLAudioQueueBufferDelegagte
- (void)canPlayWithBufferThread:(LLAudioQueueBufferThread *)bufferThread {
    
    if (self->_playStatus == LLAudioQueuePlayStatusPlaying ||
        self->_playStatus == LLAudioQueuePlayerStatusPending) {
        
        [self.audioQueue start];
        if ([self.delegate respondsToSelector:@selector(audioDataDidEnqueueBuffer:)]) {
            [self.delegate audioDataDidEnqueueBuffer:self];
        }
        self->_playStatus = LLAudioQueuePlayStatusPlaying;
        [self callStatusDelegate];
    }
}

- (void)didPlayFinishWithBufferThread:(LLAudioQueueBufferThread *)bufferThread {
    
    if (!self.finishData) {
        
        if (self->_havePlay) {
            [self pause];
            self->_playStatus = LLAudioQueuePlayerStatusPending;
            self->_havePlay = NO;
            [self callStatusDelegate];
        }
        return;
    }
    if (self.playStatus != LLAudioQueuePlayStatusStop) {
        self->_playStatus = LLAudioQueuePlayStatusStop;
        [self callStatusDelegate];
    }
}

#pragma mark - LLAudioQueueDelegate
- (void)audioQueue:(LLAudioQueue *)audioQueue didFinishBuffer:(AudioQueueBufferRef)buffer {
    [self.bufferThread enqueueBuffer:buffer];
}

- (void)dealloc
{
    [self.bufferThread cancel];
    self.bufferThread = nil;
}
@end
