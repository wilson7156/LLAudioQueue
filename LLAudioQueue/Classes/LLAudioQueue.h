//
//  LLAudioQueue.h
//  FBSnapshotTestCase
//
//  Created by wilson on 2019/12/4.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class LLAudioQueue;
@protocol LLAudioQueueDelegate <NSObject>

@optional
- (void)audioQueue:(LLAudioQueue *)audioQueue didFinishBuffer:(AudioQueueBufferRef)buffer;

@end

/// 负责管理AudioQueue播放
@interface LLAudioQueue : NSObject

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format error:(NSError **)error;

@property (nonatomic,assign) id<LLAudioQueueDelegate> delegate;
@property (nonatomic,readonly) AudioStreamBasicDescription format;
@property (nonatomic,readonly) AudioQueueRef audioQueue;
@property (nonatomic,assign) CGFloat volume;
@property (nonatomic,assign,readonly,getter=isRunning) BOOL running;

/// 当前播放进度
@property (nonatomic,readonly) float progress;

- (void)start;
- (void)pause;
- (void)stopInImmediate:(BOOL)inImmediate;

@end

NS_ASSUME_NONNULL_END
