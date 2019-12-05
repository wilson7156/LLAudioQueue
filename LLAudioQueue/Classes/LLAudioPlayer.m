//
//  LLAudioPlayer.m
//  LLAudioQueue
//
//  Created by wilson on 2019/11/29.
//

#import "LLAudioPlayer.h"

#import "LLAudioFileStream.h"
#import "LLAudioQueuePlayer.h"
#import "LLAudioDonwloader.h"

@interface LLAudioPlayer ()<LLAudioFileStreamDelegate,LLAudioQueuePlayerDelegate,LLAudioDownloaderDelegate> {
    
    BOOL _seek;
    BOOL _isTimerRusume;
    dispatch_source_t _timer;
    CGFloat _seekProgress;
    BOOL _enterBackground;
    
    LLAudioPlayerDownloadStatus _downloadStatus;
    
}

@property (nonatomic,strong) NSError *error;

//解析数据对象
@property (nonatomic,strong) LLAudioFileStream *audioFileStream;

//音频数据播放对象
@property (nonatomic,strong) LLAudioQueuePlayer *audioQueuePlayer;

//代理
@property (nonatomic,assign) id<LLAudioPlayerDelegate> delegate;

//音频下载对象
@property (nonatomic,strong) LLAudioDonwloader *downloader;

@property (nonatomic,strong) NSArray *urls;
@property (nonatomic,assign) NSInteger index;

@end

@implementation LLAudioPlayer

- (instancetype)initWithURL:(NSURL *)url error:(NSError *__autoreleasing  _Nullable * _Nullable)error delegate:(nonnull id<LLAudioPlayerDelegate>)delegate {
    
    if (!url) {
        return nil;
    }
    return [self initWithURLs:@[url] error:error delegate:delegate];
}

- (instancetype)initWithURLs:(NSArray<NSURL *> *)urls error:(NSError *__autoreleasing  _Nullable * _Nullable)error delegate:(nonnull id<LLAudioPlayerDelegate>)delegate {
    
    self = [super init];
    if (self) {
        
        if (error) {
            self.error = *error;
        }
        
        self.delegate = delegate;
        self.urls = urls;
        if (self.urls.count > 1) {
            self.autoPlayNext = YES;
        }
        
        self->_status = LLAudioPlayerStatusStop;
        if (urls) {
            [self playWithURL:urls.firstObject];
            self->_index = 0;
        }
        
        //监听App前台后台状态
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForegroundNotification) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackgroundNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

#pragma mark - Public Method
- (void)play {
    
    if (self.status == LLAudioPlayerStatusStop) {
        [self playWithURL:self.currentUrl];
        
    }
    [self _play];
    [self callStatusDelegate];
}

- (void)_play {
    
    if (self.audioQueuePlayer) {
        [self.audioQueuePlayer start];
    }
    self->_status = LLAudioPlayerStatusPlaying;
}

- (void)pause {
    
    if (self.audioQueuePlayer) {
        [self.audioQueuePlayer pause];
    }

    [self pauseTimer];
    self->_status = LLAudioPlayerStatusPause;
    [self callStatusDelegate];
}

- (void)stop {
    
    [self _stop];
    if (!self->_seek) {
        [self destroyTimer];
    }
    self->_seekProgress = 0;
    self->_status = LLAudioPlayerStatusStop;
    [self callStatusDelegate];
}

- (void)_stop {
    
    if (self.audioQueuePlayer) {
        [self.audioQueuePlayer stop];
    }
}

- (void)replaceAudioURL:(NSURL *)url {
    
    if (!url) {
        return;
    }

    [self stop];
    [self playWithURL:url];
    [self _play];
}

- (void)seekTimeToProgress:(CGFloat)progress {
    
    self->_seekProgress = progress;
    [self _seekTimeToProgress:progress];
}

- (void)_seekTimeToProgress:(CGFloat)progress {
    
    if (progress >= 1 || progress < 0) {
        return;
    }

    self->_seek = YES;
    [self _stop];
    if (self.currentUrl.isFileURL) {

        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:self.currentUrl error:nil];

        CGFloat offset = [fileHandle availableData].length * progress;
        [fileHandle seekToFileOffset:offset];
        NSData *data = [fileHandle readDataToEndOfFile];
        [self.audioFileStream parseData:data];

        if (progress >= 1) {
            [self audioQueuePlayer:self.audioQueuePlayer audioStatusChanged:LLAudioQueuePlayStatusStop];
        }
    }else {

        [self pauseTimer];
        [self.downloader seekTime:progress];
    }
}

- (void)setVolume:(CGFloat)volume {
    
    if (volume > 1) {
        return;
    }
    _volume = volume;
    self.audioQueuePlayer.volume = volume;
}

- (void)playNext {
    [self stop];
    [self _playNext];
}

#pragma mark - Private Method
- (void)playWithURL:(NSURL *)url {
    
    [self destroyTimer];
    self->_currentUrl = url;
    self->_seek = NO;
    self->_seekProgress = 0;

    //创建音频解析器
    [self createAudioFileStream];

    //s本地播放
    if (url.isFileURL) {

        //检查本地文件是否存在
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (!data) {

            NSString *errorString = [NSString stringWithFormat:@"audio url \"%@\" is not exist",url.absoluteString];
            self.error = [NSError errorWithDomain:errorString code:-100 userInfo:nil];
            return;
        }
        self.audioFileStream.fileSize = data.length;
        [self.audioFileStream parseData:data];
        
        //创建时长定时器
        [self createTimer];
    }else {

        //远程文件播放
        [self createDownloader];
    }
}

//创建音频解析器
- (void)createAudioFileStream {
    
    if (!self.audioFileStream) {
        
        NSError *error = nil;
        
        NSString *fileExtension = self.currentUrl.pathExtension;
        self.audioFileStream = [[LLAudioFileStream alloc] initWithFileType:[self hintForFileExtension:fileExtension] error:&error];
        self.error = error;
        self.audioFileStream.delegate = self;
    }
    [self.audioFileStream reset];
}

//重置AudioQueuePlayer
- (void)resetAudioQueuePlayer {
    
    [self.audioQueuePlayer stop];
    self.audioQueuePlayer = nil;
}

- (AudioFileTypeID)hintForFileExtension:(NSString *)fileExtension
{
    AudioFileTypeID fileTypeHint = kAudioFileAAC_ADTSType;
    if ([fileExtension isEqual:@"mp3"])
    {
        fileTypeHint = kAudioFileMP3Type;
    }
    else if ([fileExtension isEqual:@"wav"])
    {
        fileTypeHint = kAudioFileWAVEType;
    }
    else if ([fileExtension isEqual:@"aifc"])
    {
        fileTypeHint = kAudioFileAIFCType;
    }
    else if ([fileExtension isEqual:@"aiff"])
    {
        fileTypeHint = kAudioFileAIFFType;
    }
    else if ([fileExtension isEqual:@"m4a"])
    {
        fileTypeHint = kAudioFileM4AType;
    }
    else if ([fileExtension isEqual:@"mp4"])
    {
        fileTypeHint = kAudioFileMPEG4Type;
    }
    else if ([fileExtension isEqual:@"caf"])
    {
        fileTypeHint = kAudioFileCAFType;
    }
    else if ([fileExtension isEqual:@"aac"])
    {
        fileTypeHint = kAudioFileAAC_ADTSType;
    }
    return fileTypeHint;
}

//创建AudioQueuePlayer
- (void)createAudioQueuePlayerWithDesc:(AudioStreamBasicDescription)desc {
    
    if (!self.audioQueuePlayer) {
        NSError *error = nil;
        self.audioQueuePlayer = [[LLAudioQueuePlayer alloc] initWithAudioStreamBasicDescription:desc error:&error];
        self.audioQueuePlayer.delegate = self;
        self.error = error;
    }
    if (self.status == LLAudioPlayerStatusPlaying) {
        [self.audioQueuePlayer start];
    }
}


//播放下一首
- (void)_playNext {
    
    if (self.urls.count >= 1) {
        
        if (self.mode == LLAudioPlayerModeNormal) {
            
            //顺序播放
            self->_index++;
        }else if (self.mode == LLAudioPlayerModeListRoop) {
            
            //列表循环
            if (self.index == self.urls.count -1) {
                self.index = 0;
            }
        }else if (self.mode == LLAudioPlayerModeRandom) {
            
            //随机播放
            NSInteger index = arc4random() % self.urls.count;
            self.index = index;
        }
            
        if (self->_index < self.urls.count) {
            [self playWithURL:self.urls[self->_index]];
            [self play];
        }
    }
}

- (void)createTimer {
    
    if (!self->_timer) {
        
        self->_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
        dispatch_source_set_timer(self->_timer, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), 1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(self->_timer, ^{
            
            CGFloat seekTime = 0;
            if (self->_seekProgress > 0 && self->_seekProgress < 1) {
                
                seekTime = self.audioFileStream.duration * self->_seekProgress;
            }
            self->_progress.totalUnitCount = self.audioFileStream.duration;
            self->_progress.completedUnitCount = roundl(self.audioQueuePlayer.progress + seekTime);
            
            if (self->_progress.completedUnitCount > self.audioFileStream.duration) {
                [self destroyTimer];
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
               
                if ([self.delegate respondsToSelector:@selector(audioPlayer:didPlayProgress:)]) {
                    [self.delegate audioPlayer:self didPlayProgress:self->_progress];
                }
            });
        });
        self->_progress = [NSProgress new];
    }
}

#pragma mark - Timer
- (void)resumeTimer {
    if (self->_timer && !self->_isTimerRusume) {
        dispatch_resume(self->_timer);
        self->_isTimerRusume = YES;
    }
}

- (void)pauseTimer {
    
    if (self->_timer && !self->_isTimerRusume) {
        dispatch_suspend(self->_timer);
        self->_isTimerRusume = NO;
    }
}

- (void)destroyTimer {
    
    if (self->_timer && self->_isTimerRusume) {
        dispatch_source_cancel(self->_timer);
        self->_timer = nil;
        self->_isTimerRusume = NO;
        self->_progress = nil;
    }
}

#pragma mark - Downloader
- (void)createDownloader {
    
    self.downloader = [[LLAudioDonwloader alloc] initWithURL:self.currentUrl];
    self.downloader.delegate = self;
    [self.downloader download];
    
    if (!self.downloader.cacheFile) {
        self->_downloadStatus = LLAudioPlayerDownloadStatusPending;
    }
}

- (void)cancelDownloader {
    
    if (self.downloader) {
        [self.downloader cancel];
        self.downloader = nil;
    }
}

- (void)callStatusDelegate {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(audioPlayer:didChangeStatus:)]) {
            [self.delegate audioPlayer:self didChangeStatus:self->_status];
        }
    });
}

#pragma mark - ApplcationNotification
- (void)appWillEnterForegroundNotification {
    if (!self.playInBackground) {
        [self pause];
        self->_enterBackground = YES;
    }
}

- (void)appDidEnterBackgroundNotification {
    if (!self.playInBackground) {
        [self pause];
        self->_enterBackground = YES;
    }
}

#pragma mark - LLAudioFileStreamDelegate
- (void)didReadyToProductPacketWithAudioFileStream:(LLAudioFileStream *)audioFileStream {
    
    self.audioQueuePlayer.finishData = NO;
    [self createAudioQueuePlayerWithDesc:audioFileStream.format];
}

- (void)audioFileStream:(LLAudioFileStream *)audioFileStream didParseDatas:(NSArray *)audioDatas {

    [self.audioQueuePlayer playDatas:audioDatas];
    [self createTimer];
    [self resumeTimer];
    
    if (self.status == LLAudioPlayerStatusPlaying) {
        [self _play];
    }
    
    //如果是本地文件流，则设置数据已经结束
    if (self.currentUrl.isFileURL) {
        
        self.audioQueuePlayer.finishData = YES;
        if (!self->_seek) {
            [self callStatusDelegate];
        }
    }
    self->_duration = audioFileStream.duration;
}

- (void)audioFileStream:(LLAudioFileStream *)audioFileStream didParseFailure:(NSError *)error {
    self.error = error;
}

#pragma mark - LLAudioQueuePlayerDelegate
- (void)audioQueuePlayer:(LLAudioQueuePlayer *)audioQueuePlayer audioStatusChanged:(LLAudioQueuePlayStatus)status {
    
    if (status == LLAudioQueuePlayStatusStop) {
        
        //音频数据播放结束会回调
        //如果是设置播放进度则不做处理
        if (self->_seek) {
            return;
        }
        
        //做延时处理
        NSInteger afterTime = self.progress.totalUnitCount - self.progress.completedUnitCount;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(afterTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            self->_seekProgress = 0;
            [self destroyTimer];
            [self cancelDownloader];
            [self stop];
            self->_status = LLAudioPlayerStatusStop;
            if (self.mode == LLAudioPlayerModeRoop) {
                
                [self playWithURL:self.currentUrl];
                [self _play];
            }else if (self.urls.count > 1) {
                
                if (!self.autoPlayNext) {
                    return;
                }
                [self _playNext];
            }
        });
    }else if (status == LLAudioQueuePlayerStatusPending) {
        
        if (!self.audioQueuePlayer.finishData) {
            
            if (!self.currentUrl.fileURL) {
                
                if (self->_downloadStatus != LLAudioPlayerDownloadStatusCompleted) {
                    self->_downloadStatus = LLAudioPlayerDownloadStatusPending;
                    if ([self.delegate respondsToSelector:@selector(audioPlayer:didDownloadingStatus:)]) {
                        [self.delegate audioPlayer:self didDownloadingStatus:self->_downloadStatus];
                    }
                }
                return;
            }
        }
    }else if (status == LLAudioQueuePlayStatusPlaying) {
        
        if (self->_downloadStatus == LLAudioPlayerDownloadStatusPending) {
            
            self->_downloadStatus = LLAudioPlayerDownloadStatusNormal;
            if ([self.delegate respondsToSelector:@selector(audioPlayer:didDownloadingStatus:)]) {
                [self.delegate audioPlayer:self didDownloadingStatus:self->_downloadStatus];
            }
        }
    }
}

- (void)audioDataDidEnqueueBuffer:(LLAudioQueuePlayer *)audioQueuePlayer {
    self->_seek = NO;
}

#pragma mark - LLAudioDownloaderDelegate
- (void)audioDownloaderReceiveRespone:(LLAudioDonwloader *)audioDownloader {
    [self createTimer];
    [self resumeTimer];
}

- (void)audioDownloader:(LLAudioDonwloader *)audioDownloader didReceiveData:(NSData *)data {
    
    if (data) {
        self.audioFileStream.fileSize = audioDownloader.fileSize;
        [self.audioFileStream parseData:data];
    }
    
    if (self.status == LLAudioPlayerStatusPlaying) {
        [self resumeTimer];
        [self _play];
    }
}

- (void)audioDownloader:(LLAudioDonwloader *)audioDownloader didCompletionWithData:(NSData *)data error:(NSError *)error {
    
    if ([audioDownloader.url isEqual:self.currentUrl]) {
        self.audioQueuePlayer.finishData = YES;
    }
    
    if (!error) {
        
        if (self->_downloadStatus != LLAudioPlayerDownloadStatusCompleted && !audioDownloader.cacheFile) {
            self->_downloadStatus = LLAudioPlayerDownloadStatusCompleted;
            if ([self.delegate respondsToSelector:@selector(audioPlayer:didDownloadingStatus:)]) {
                [self.delegate audioPlayer:self didDownloadingStatus:self->_downloadStatus];
            }
        }
    }else {
        
        [self stop];
        self->_status = LLAudioPlayerStatusError;
        if ([self.delegate respondsToSelector:@selector(audioPlayer:didChangeStatus:)]) {
            [self.delegate audioPlayer:self didChangeStatus:self->_status];
        }
    }
}

@end
