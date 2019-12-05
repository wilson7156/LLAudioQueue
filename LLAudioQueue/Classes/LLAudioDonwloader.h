//
//  LLAudioDonwloader.h
//  FBSnapshotTestCase
//
//  Created by wilson on 2019/12/4.
//

#import <Foundation/Foundation.h>

#define MAX_FAILURE_TIME 10


NS_ASSUME_NONNULL_BEGIN

@class LLAudioDonwloader;
@protocol LLAudioDownloaderDelegate <NSObject>

@optional

- (void)audioDownloaderReceiveRespone:(LLAudioDonwloader *)audioDownloader;

/// 收到数据回调，会多次回调
/// @param audioDownloader 当前下载对象
/// @param data 下载到的数据
- (void)audioDownloader:(LLAudioDonwloader *)audioDownloader didReceiveData:(NSData *)data;

/// 当前下载结束回调
/// @param audioDownloader 当前下载对象
/// @param data 所有下载的数据
/// @param error 错误，如果不为nil,则下载成功，否则下载失败
- (void)audioDownloader:(LLAudioDonwloader *)audioDownloader didCompletionWithData:(NSData *)data error:(NSError *_Nullable)error;
@end

/// 音频下载
@interface LLAudioDonwloader : NSObject

- (instancetype)initWithURL:(NSURL *)url;

@property (nonatomic,strong,readonly) NSURL *url;

@property (nonatomic,assign) id<LLAudioDownloaderDelegate> delegate;

/// 文件大小
@property (nonatomic,assign,readonly) long long fileSize;

/// 是否下载失败
@property (nonatomic,assign,readonly) BOOL downloadFailure;

@property (nonatomic,assign,readonly) BOOL cacheFile;

//设置下载进度
- (void)download;
- (void)seekTime:(CGFloat)progress;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
