//
//  LLAudioQueueBuffer.m
//  LLAudioQueue
//
//  Created by wilson on 2019/11/28.
//

#import "LLAudioQueueBuffer.h"
#import "LLAudioThreadLock.h"
#import <objc/runtime.h>


#define BUFFER_COUNT 2

@interface LLAudioData (LLAdd)

@property (nonatomic) AudioStreamPacketDescription *packetDescs;
@property (nonatomic) NSInteger packetCount;
@end

@implementation LLAudioData (LLAdd)

- (void)setPacketDescs:(AudioStreamPacketDescription *)packetDescs {
    objc_setAssociatedObject(self, "packetDesc", (__bridge id _Nullable)(packetDescs), OBJC_ASSOCIATION_ASSIGN);
}

- (AudioStreamPacketDescription *)packetDescs {
    return (__bridge AudioStreamPacketDescription *)(objc_getAssociatedObject(self, "packetDesc"));
}

- (void)setPacketCount:(NSInteger)packetCount {
    objc_setAssociatedObject(self, "packetCount", @(packetCount), OBJC_ASSOCIATION_ASSIGN);
}

- (NSInteger)packetCount {
    return [objc_getAssociatedObject(self, "packetCount") integerValue];
}

@end

@implementation LLAudioQueueBuffer
@end

@interface LLAudioQueueBufferThread () {
    
    BOOL _shouldCancel;
    
}

@property (nonatomic,strong) NSMutableArray *dataArray;
@property (nonatomic,strong) NSMutableArray *bufferArray;
@property (nonatomic,strong) LLAudioThreadLock *threadLock;
@end

@implementation LLAudioQueueBufferThread

- (instancetype)initWithBufferCount:(NSUInteger)bufferCount
                         audioQueue:(AudioQueueRef)audioQueue {
    
    self = [super init];
    if (self) {
        
        self->_bufferCount = bufferCount;
        self->_audioQueue = audioQueue;
        [self createBuffers];
        self.threadLock = [LLAudioThreadLock new];
        
    }
    return self;
}

#pragma mark - Publick Method
- (void)appendData:(NSArray<LLAudioData *> *)audioDatas {
    
    if (!self.dataArray) {
        self.dataArray = [NSMutableArray new];
    }
    [self.dataArray addObjectsFromArray:audioDatas];
    [self.threadLock unlockSignal];
}

- (void)enqueueBuffer:(AudioQueueBufferRef)bufferRef {
    
    for (LLAudioQueueBuffer *queueBuffer in self.bufferArray) {
        if (queueBuffer.buffer == bufferRef) {
            queueBuffer.isUse = NO;
            break;
        }
    }

    [self.threadLock unlockSignal];
    self->_hasPlayBuffer = NO;

    //检查是否都播放完毕
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isUse=0"];
    NSArray *array = [self.bufferArray filteredArrayUsingPredicate:predicate];

    if (array.count == self.bufferArray.count && self.dataArray.count == 0) {
        self->_hasPlayBuffer = YES;
        if ([self.delegate respondsToSelector:@selector(didPlayFinishWithBufferThread:)]) {
            [self.delegate didPlayFinishWithBufferThread:self];
        }
    }
}

- (void)enqueue {
    if (self.threadLock) {
        [self.threadLock unlockSignal];
    }
}

- (void)cancel {
    self->_shouldCancel = YES;
    [self destroyBuffers];
    [self.threadLock unlockSignal];
    [super cancel];
    
}

- (void)destroyBuffers {
    
    for (LLAudioQueueBuffer *buffer in self.bufferArray) {
        AudioQueueFreeBuffer(self->_audioQueue, buffer.buffer);
    }
    [self.bufferArray removeAllObjects];
}

#pragma mark - main Method
- (void)main {
    
    @autoreleasepool {
        @synchronized (self) {

            while (!self->_shouldCancel) {

                //获取可用的buffer,如果没有则线程暂停
                LLAudioQueueBuffer *queueBuffer = [self getBuffer];
                if (queueBuffer) {

                    LLAudioData *audioData = [self calculateAudioDataPerBuffer];
                    if (audioData) {
                        [self enqueuBuffer:queueBuffer audioData:audioData];
                    }else {
                        [self.threadLock lockWait];
                    }
                }else {
                    [self.threadLock lockWait];
                }
            }
        }
    }
}

#pragma mark - Private Method
- (void)createBuffers {
    
    if (!self.bufferArray) {
        self.bufferArray = [NSMutableArray new];
    }
    
    for (NSInteger index = 0; index < self.bufferCount; index ++) {
        
        AudioQueueBufferRef buffer;
        OSStatus status = AudioQueueAllocateBuffer(self->_audioQueue, BUFFER_SIZE, &buffer);
        if (status != noErr) {
            
        }
        LLAudioQueueBuffer *queueBuffer = [LLAudioQueueBuffer new];
        queueBuffer.buffer = buffer;
        
        [self.bufferArray addObject:queueBuffer];
    }
}

- (LLAudioQueueBuffer *)getBuffer {

    for (LLAudioQueueBuffer *buffer in self.bufferArray) {
        if (!buffer.isUse) {
            return buffer;
        }
    }
    return nil;
}

/// 计算当前的可以播放的音频数据
- (LLAudioData *)calculateAudioDataPerBuffer {
    
    if (self->_shouldCancel) {
        [self.dataArray removeAllObjects];
        [self destroyBuffers];
        return nil;
    }
    
    NSInteger packetCount = 0;
    NSInteger size = 0;
    
    //计算需要添加到buffer的数据包大小
    for (NSInteger index = 1; index <= self.dataArray.count; index++) {
        
        if (self.dataArray.count == 0) {
            return nil;
        }
        LLAudioData *audioData = [self.dataArray objectAtIndex:index-1];
        if (!audioData) {
            return nil;
        }
        size += [audioData.data length];
        if (size > BUFFER_SIZE) {
            index--;
            packetCount = index;
            break;
        }
        packetCount = index;
    }
    if (packetCount == 0) {
        return nil;
    }
    
    //将多个数据对象合并成一个
    NSMutableData *data = [NSMutableData new];
    AudioStreamPacketDescription *desc = malloc(sizeof(AudioStreamPacketDescription) * packetCount);
    
    for (NSInteger index = 0; index < packetCount; index++) {
        
        if (self.dataArray.count == 0) {
            return nil;
        }
        LLAudioData *audioData = [self.dataArray objectAtIndex:index];
        AudioStreamPacketDescription des = audioData.packetDescription;
        des.mStartOffset = [data length];
        desc[index] = des;
        [data appendData:audioData.data];
    }
    
    LLAudioData *audioData = [[LLAudioData alloc] initWithBytes:data packetDescription:desc[0]];
    audioData.packetDescs = desc;
    audioData.packetCount = packetCount;
    [self.dataArray removeObjectsInRange:NSMakeRange(0, packetCount)];
    return audioData;
}

- (void)enqueuBuffer:(LLAudioQueueBuffer *)queueBuffer audioData:(LLAudioData *)audioData {
    
    queueBuffer.isUse = YES;
    //拷贝数据并添加播放对列中
    memcpy(queueBuffer.buffer->mAudioData, [audioData.data bytes], [audioData.data length]);
    queueBuffer.buffer->mAudioDataByteSize = (UInt32)[audioData.data length];
    self->_lastEnqueueDataSize = audioData.data.length;
    
    OSStatus status = AudioQueueEnqueueBuffer(self->_audioQueue, queueBuffer.buffer, (int)audioData.packetCount, audioData.packetDescs);
    if (status == noErr) {

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(canPlayWithBufferThread:)]) {
                [self.delegate canPlayWithBufferThread:self];
            }
        });
    }else {
    };
}
@end
