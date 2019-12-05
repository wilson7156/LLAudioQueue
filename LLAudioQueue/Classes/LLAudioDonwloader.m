//
//  LLAudioDonwloader.m
//  FBSnapshotTestCase
//
//  Created by wilson on 2019/12/4.
//

#import "LLAudioDonwloader.h"



@interface LLAudioDonwloader ()<NSURLSessionDataDelegate> {
    
    long long _offset;
    BOOL _isDownload;
    NSInteger _downloadFailureTime;
    NSInteger _cahceLength;
}

@property (nonatomic,strong) NSURLSessionDataTask *dataTask;
@property (nonatomic,strong) NSURLSession *session;

@property (nonatomic,strong) NSMutableData *data;
@property (nonatomic,strong) NSMutableData *cacheData;

@end

@implementation LLAudioDonwloader

- (instancetype)initWithURL:(NSURL *)url {
    
    self = [super init];
    if (self) {
        
        self->_url = url;
        
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue new]];
        self.data = [NSMutableData new];
        self.cacheData = [NSMutableData new];
        
        _cahceLength = 100 * 1024;
        
    }
    return self;
}

- (void)download {
    
    NSString *cacheFilePath = [self checkIsStoreDisk];
    if (cacheFilePath) {
        self->_cacheFile = YES;
        [self fetchCacheData];
        return;
    }
    [self creteDataTaskWithOffset:0];
}

- (void)seekTime:(CGFloat)progress {
    
    //清除缓存
    [self.data replaceBytesInRange:NSMakeRange(0, self.data.length) withBytes:NULL length:0];
    
    //取消上次下载
    if (self.dataTask) {
        [self.dataTask cancel];
        self.dataTask = nil;
    }
    
    self->_offset = self.fileSize * progress;
    if ([self checkIsStoreDisk]) {
        [self fetchCacheData];
        return;
    }
    [self cancel];
    [self creteDataTaskWithOffset:self->_offset];
}

- (void)cancel {
    
    if (self.dataTask) {
        [self.dataTask cancel];
        self.dataTask = nil;
    }
}

- (void)creteDataTaskWithOffset:(long long)offset {
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    if (offset > 0) {
        
        NSString *range = [NSString stringWithFormat:@"bytes=%lld-%lld",offset,self.fileSize];
        [request setValue:range forHTTPHeaderField:@"Range"];
    }
    self.dataTask = [self.session dataTaskWithRequest:request];
    [self.dataTask resume];
}

- (NSString *)checkIsStoreDisk {
    
    NSString *directory = [self createDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *subPath = [fileManager subpathsAtPath:directory];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF=%@",self.url.lastPathComponent];
    NSArray *array = [subPath filteredArrayUsingPredicate:predicate];
    
    NSString *file = array.firstObject;
    if (!file) {
        return nil;
    }
    
    return [directory stringByAppendingPathComponent:file];
}

- (void)fetchCacheData {
    
    NSString *filePath = [self checkIsStoreDisk];
    if (!filePath) {
        return;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    self->_fileSize = data.length;
    
    if (self->_offset > 0) {
        
        long long length = self.fileSize - self->_offset;
        NSData *subData = [data subdataWithRange:NSMakeRange(self->_offset, length)];
        data = subData;
    }
    
    if ([self.delegate respondsToSelector:@selector(audioDownloader:didReceiveData:)]) {
        [self.delegate audioDownloader:self didReceiveData:data];
    }
    
    if ([self.delegate respondsToSelector:@selector(audioDownloaderReceiveRespone:)]) {
        [self.delegate audioDownloaderReceiveRespone:self];
    }
    
    if ([self.delegate respondsToSelector:@selector(audioDownloader:didCompletionWithData:error:)]) {
        [self.delegate audioDownloader:self didCompletionWithData:data error:nil];
    }
}

#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    if (response.expectedContentLength <= 0) {
        
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    
    if (self->_offset == 0) {
        self->_fileSize = response.expectedContentLength;
    }
    
    [self.data resetBytesInRange:NSMakeRange(0, self.data.length)];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    dispatch_async(dispatch_get_main_queue(), ^{
       
        if (self.data) {
            [self.data appendData:data];
            [self.cacheData appendData:data];
        }
        
        if (self.cacheData.length <= self->_cahceLength) {
            return;
        }
        
        NSData *playData = [self.cacheData subdataWithRange:NSMakeRange(0, self->_cahceLength)];
        [self.cacheData replaceBytesInRange:NSMakeRange(0, self->_cahceLength) withBytes:NULL length:0];
        if ([self.delegate respondsToSelector:@selector(audioDownloader:didReceiveData:)]) {
            [self.delegate audioDownloader:self didReceiveData:playData];
        }
        
        if (!self->_isDownload) {
            if ([self.delegate respondsToSelector:@selector(audioDownloaderReceiveRespone:)]) {
                [self.delegate audioDownloaderReceiveRespone:self];
            }
            self->_isDownload = YES;
        }
    });
}

- (void)URLSession:(NSURLSession *)session task:(nonnull NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    
    dispatch_async(dispatch_get_main_queue(), ^{
       
        if (error && self->_downloadFailureTime < 10) {
            [self reDownload];
            return;
        }
        
        if (self->_offset == 0) {
            
            //保存文件
            NSString *path = [self createDirectory];
            NSString *filePath = [path stringByAppendingPathComponent:self.url.lastPathComponent];
            if ([self.data writeToFile:filePath atomically:YES]) {
            }
        }
        
        if (!error) {
            if ([self.delegate respondsToSelector:@selector(audioDownloader:didReceiveData:)]) {
                [self.delegate audioDownloader:self didReceiveData:self.cacheData];
            }
        }
        
        if ([self.delegate respondsToSelector:@selector(audioDownloader:didCompletionWithData:error:)]) {
            [self.delegate audioDownloader:self didCompletionWithData:self.data error:error];
        }
    });
}

- (NSString *)createDirectory {
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *directory = [path stringByAppendingPathComponent:@"ll_audio"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directory]) {
        [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:NULL error:nil];
    }
    return directory;
}

- (void)reDownload {
    
    [self cancel];
    [self creteDataTaskWithOffset:self.data.length];
    [self.data replaceBytesInRange:NSMakeRange(0, self.data.length) withBytes:NULL length:0];
}

- (void)dealloc
{
    
}

@end
