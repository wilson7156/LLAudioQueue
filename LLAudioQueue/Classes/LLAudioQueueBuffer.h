//
//  LLAudioQueueBuffer.h
//  LLAudioQueue
//
//  Created by wilson on 2019/11/28.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "LLAudioData.h"

#define BUFFER_SIZE 100000

NS_ASSUME_NONNULL_BEGIN

// AudioQueueBufferRef 缓存对象
@interface LLAudioQueueBuffer : NSObject
@property (nonatomic,assign) AudioQueueBufferRef buffer;
@property (nonatomic,assign) BOOL isUse;
@end

@class LLAudioQueueBufferThread;
@protocol LLAudioQueueBufferDelegagte <NSObject>

@optional

/// buffer已添加队列完成后回调，该方法会多次调用
/// @param bufferThread bufferThread
- (void)canPlayWithBufferThread:(LLAudioQueueBufferThread *)bufferThread;

/// 数据已经播放完
/// @param bufferThread  bufferThread
- (void)didPlayFinishWithBufferThread:(LLAudioQueueBufferThread *)bufferThread;
@end

@interface LLAudioQueueBufferThread : NSThread

- (instancetype)initWithBufferCount:(NSUInteger)bufferCount
                         audioQueue:(AudioQueueRef)audioQueue;

@property (nonatomic,readonly,assign) AudioQueueRef audioQueue;
@property (nonatomic,readonly) NSUInteger bufferCount;

@property (nonatomic,weak) id <LLAudioQueueBufferDelegagte> delegate;

/// 是否已经播放完成
@property (nonatomic,readonly) BOOL hasPlayBuffer;

/// 最后插入缓存数据的长度
@property (nonatomic,assign) long long lastEnqueueDataSize;

/// 添加音频数据到缓存
/// @param audioDatas 音频数据
- (void)appendData:(NSArray<LLAudioData *> *)audioDatas;

/// 播放完 buffer数据后回调重入缓存
/// @param bufferRef 缓存buffer
- (void)enqueueBuffer:(AudioQueueBufferRef)bufferRef;
- (void)enqueue;

/// 关闭buffer
- (void)destroyBuffers;
@end

NS_ASSUME_NONNULL_END
