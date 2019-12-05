//
//  LLAudioQueuePlayer.h
//  LLAudioQueue
//
//  Created by wilson on 2019/11/28.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "LLAudioData.h"

NS_ASSUME_NONNULL_BEGIN

//播放状态
typedef NS_ENUM(NSInteger,LLAudioQueuePlayStatus) {
    
    //等待播放,初始化只用一次
    LLAudioQueuePlayStatusWaitting,
    
    //暂停中，待填充数据
    LLAudioQueuePlayerStatusPending,
    
    //播放中
    LLAudioQueuePlayStatusPlaying,
    
    //暂停播放
    LLAudioQueuePlayStatusPause,
    
    //停止播放
    LLAudioQueuePlayStatusStop,
};

@class LLAudioQueuePlayer;
@protocol LLAudioQueuePlayerDelegate <NSObject>

@optional
- (void)audioQueuePlayer:(LLAudioQueuePlayer *)audioQueuePlayer audioStatusChanged:(LLAudioQueuePlayStatus)status;

- (void)audioDataDidEnqueueBuffer:(LLAudioQueuePlayer *)audioQueuePlayer;

@end

/// AudioQueue播放器
@interface LLAudioQueuePlayer : NSObject

/// 音频格式初始化AudioQueuePlayer
/// @param format 音频格式
/// @param error 错误
- (instancetype)initWithAudioStreamBasicDescription:(AudioStreamBasicDescription)format error:(NSError **)error;

/// 音频格式
@property (nonatomic,readonly) AudioStreamBasicDescription format;

@property (nonatomic,weak) id <LLAudioQueuePlayerDelegate> delegate;

@property (nonatomic,assign) NSInteger bufferSize;
@property (nonatomic,assign) SInt64 fileSize;

/// 当前播放状态
@property (nonatomic,readonly) LLAudioQueuePlayStatus playStatus;

/// 音量大小 0 - 1
@property (nonatomic,assign) CGFloat volume;

///  是否已经填充所有数据
@property (nonatomic,assign) BOOL finishData;

@property (nonatomic,assign) float progress;

/// 最后会被播放音频数据的长度
@property (nonatomic,assign,readonly) long long lastPlayDataSize;

/// 播放数据
/// @param audioDatas 音频数据对象数组
- (void)playDatas:(NSArray *)audioDatas;

/// 开始播放
- (void)start;

/// 暂停播放
- (void)pause;

/// 停止播放
- (void)stop;

@end




NS_ASSUME_NONNULL_END
