//
//  LLAudioPlayer.h
//  LLAudioQueue
//
//  Created by wilson on 2019/11/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//播放状态
typedef NS_ENUM(NSInteger,LLAudioPlayerStatus) {
    
    //播放中
    LLAudioPlayerStatusPlaying,
    
    //暂停中
    LLAudioPlayerStatusPause,
    
    //已经停止
    LLAudioPlayerStatusStop,
    
    //播放错误
    LLAudioPlayerStatusError,
    
};

//播放模式
typedef NS_ENUM(NSInteger,LLAudioPlayerMode) {
    
    //正常播放,如果是列表则列表顺序播放,列表播放完最后一曲则会停止
    LLAudioPlayerModeNormal,
    
    //单曲循环
    LLAudioPlayerModeRoop,
    
    //列表循环,如果是列表则列表顺序播放
    LLAudioPlayerModeListRoop,
    
    //随机播放，列表才有笑
    LLAudioPlayerModeRandom,
};

typedef NS_ENUM(NSInteger,LLAudioPlayerDownloadStatus) {
    
    //正常播放
    LLAudioPlayerDownloadStatusNormal,
    
    //等待下载
    LLAudioPlayerDownloadStatusPending,
    
    //下载完成
    LLAudioPlayerDownloadStatusCompleted,
};

@class LLAudioPlayer;
@protocol LLAudioPlayerDelegate <NSObject>

@optional
/// 播放状态
/// @param audioPlayer 播放器对象
/// @param status 播放状态
- (void)audioPlayer:(LLAudioPlayer *)audioPlayer didChangeStatus:(LLAudioPlayerStatus)status;

/// 播放进度
/// @param audioPlayer 播放器对象
/// @param progress 播放进度
- (void)audioPlayer:(LLAudioPlayer *)audioPlayer didPlayProgress:(NSProgress *)progress;

/// 下载状态，只有远程链接才会回调
/// @param audioPlayer 播放器对象
/// @param status 下载状态
- (void)audioPlayer:(LLAudioPlayer *)audioPlayer didDownloadingStatus:(LLAudioPlayerDownloadStatus)status;
@end

/*
    音频播放器，使用AudioFileStream+AudioQueue方式播放，可以支持本地文件,远程文件
 */
@interface LLAudioPlayer : NSObject

/// 根据url初始化播放器对象
/// @param url 音频链接
/// @param error 错误
/// @param delegate 代理
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error delegate:(id<LLAudioPlayerDelegate>)delegate;

/// 根据url数组初始化播放器对象
/// @param urls 音频链接数组
/// @param error 错误
/// @param delegate 代理
- (instancetype)initWithURLs:(NSArray<NSURL *> *)urls error:(NSError **)error delegate:(id<LLAudioPlayerDelegate>)delegate;

/// 当前播放音频
@property (nonatomic,readonly) NSURL *currentUrl;

/// 循环播放,默认为 NO
@property (nonatomic,assign) BOOL roopPlay;

/// 是否自动播放下一首,如果是列表则默认是YES，否则是NO
@property (nonatomic,assign) BOOL autoPlayNext;

/// 播放模式
@property (nonatomic,assign) LLAudioPlayerMode mode;

/// 音量大小 0 - 1
@property (nonatomic,assign) CGFloat volume;

/// 播放状态
@property (nonatomic,assign,readonly) LLAudioPlayerStatus status;

/// 当前播放进度
@property (nonatomic,strong,readonly) NSProgress *progress;

/// 时长，以秒计算
@property (nonatomic,assign,readonly) NSInteger duration;

/// 是否在后台播放，NO:如果进入后台会暂停，Yes,正常播放
@property (nonatomic,assign) BOOL playInBackground;

/// 切换音频
/// @param url 音频url
- (void)replaceAudioURL:(NSURL *)url;

/// 播放
- (void)play;

/// 暂停
- (void)pause;

/// 停止
- (void)stop;

/// 设置播放进度
/// @param progress 进度 0 - 1
- (void)seekTimeToProgress:(CGFloat)progress;

/// 播放下一首 
- (void)playNext;
@end

NS_ASSUME_NONNULL_END
