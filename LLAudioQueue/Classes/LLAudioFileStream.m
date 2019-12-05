//
//  LLAudioFileStream.m
//  LLAudioQueue
//
//  Created by wilson on 2019/11/28.
//

#import "LLAudioFileStream.h"

#define  BitRateEstimationMaxPackets 5000
#define  BitRateEstimationMinPackets 10

@interface LLAudioFileStream () {
    
    AudioFileStreamID _streamId;
    NSTimeInterval _packetDuration;
    
    UInt64 _processedPacketsCount;
    UInt64 _processedPacketsSizeTotal;
}

@property (nonatomic,strong) NSError *erro;
@end

@implementation LLAudioFileStream

- (instancetype)initWithFileType:(AudioFileTypeID)fileType error:(NSError *__autoreleasing  _Nullable *)error {
    
    self = [super init];
    if (self) {
        
        self->_fileType = fileType;
        if (error) {
            self.erro = *error;
        }
        
        [self createFileStream];
    }
    return self;
}

#pragma mark - Public Method
- (void)parseData:(NSData *)data {
    
    if (!self->_streamId) {
        [self createFileStream];
    }
    
    OSStatus status = AudioFileStreamParseBytes(self->_streamId, (UInt32)[data length], [data bytes], 0);
    if (status != noErr) {
        [self generatorError:@"AudioFileStreamParseBytes" code:status];
    }
}


#pragma mark - Private Method
- (void)createFileStream {
    
    OSStatus status = AudioFileStreamOpen((__bridge void * _Nullable)(self), LLAudioFileStreamPropertyCallback, LLAudioFileStreamPacketCallback, self.fileType, &_streamId);
    if (status != noErr) {
        [self generatorError:@"AudioFileStreamOpen failure" code:status];
    }
}

- (void)generatorError:(NSString *)errorString code:(UInt32)code {
    
    if (code != 0) {
        NSError *error = [NSError errorWithDomain:errorString code:code userInfo:nil];
        self.erro = error;
        
        if ([self.delegate respondsToSelector:@selector(audioFileStream:didParseFailure:)]) {
            [self.delegate audioFileStream:self didParseFailure:error];
        }
    }
}

#pragma mark - Callback
static void LLAudioFileStreamPropertyCallback(
                                              void *                            inClientData,
                                              AudioFileStreamID                inAudioFileStream,
                                              AudioFileStreamPropertyID        inPropertyID,
                                              AudioFileStreamPropertyFlags *    ioFlags) {
    
    LLAudioFileStream *audioStream = (__bridge LLAudioFileStream *)(inClientData);
    [audioStream handleAudioFileStreamPropertyId:inPropertyID];
}

static void LLAudioFileStreamPacketCallback(
                                            void *                            inClientData,
                                            UInt32                            inNumberBytes,
                                            UInt32                            inNumberPackets,
                                            const void *                    inInputData,
                                            AudioStreamPacketDescription    *inPacketDescriptions) {
    
    LLAudioFileStream *audioStream = (__bridge LLAudioFileStream *)(inClientData);
    [audioStream handleAudioFileStreamNumberBytes:inNumberBytes numberPackets:inNumberPackets data:inInputData packetDesc:inPacketDescriptions];
}

#pragma mark - Callback Method
//音频信息解析回调
- (void)handleAudioFileStreamPropertyId:(AudioFileStreamPropertyID)propertyId {
    
    if (propertyId == kAudioFileStreamProperty_DataFormat) {
        
        UInt32 size = sizeof(self->_format);
        OSStatus status = AudioFileStreamGetProperty(self->_streamId, propertyId, &size, &self->_format);
        if (status != noErr) {
            [self generatorError:@"AudioFileStreamGetProperty kAudioFileStreamProperty_DataFormat error" code:status];
        }
        [self calculatePacketDuration];
        
    }else if (propertyId == kAudioFileStreamProperty_FormatList) {
        
        Boolean outWriteable;
        UInt32 formatListSize;
        OSStatus status = AudioFileStreamGetPropertyInfo(self->_streamId, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
        if (status != noErr)
        {
            [self generatorError:@"AudioFileStreamGetPropertyInfo kAudioFileStreamProperty_FormatList error" code:status];
        }

        //获取formatlist
        AudioFormatListItem *formatList = malloc(formatListSize);
        status = AudioFileStreamGetProperty(self->_streamId, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
        if (status != noErr)
        {
            [self generatorError:@"AudioFileStreamGetProperty kAudioFileStreamProperty_FormatList error" code:status];
        }

        //选择需要的格式
        for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i++)
        {
            AudioStreamBasicDescription pasbd = formatList[i].mASBD;
            self->_format = pasbd;
            [self calculatePacketDuration];
        }
        free(formatList);
    }else if (propertyId == kAudioFileStreamProperty_DataOffset) {
        
        UInt32 dataOffsetSize = sizeof(self->_dataOffset);
        OSStatus status = AudioFileStreamGetProperty(self->_streamId, propertyId, &dataOffsetSize, &self->_dataOffset);
        if (status != noErr) {
            [self generatorError:@"AudioFileStreamGetProperty kAudioFileStreamProperty_DataOffset" code:status];
        }
        [self calculatePacketDuration];
    }else if (propertyId == kAudioFileStreamProperty_ReadyToProducePackets) {
        
        //解析数据成功
        self->_readyToProductPacket = YES;
        
        //获取数据大小
        UInt64 audioDataByteCount;
        UInt32 byteCountSize = sizeof(audioDataByteCount);
        OSStatus status = AudioFileStreamGetProperty(self->_streamId, kAudioFileStreamProperty_AudioDataByteCount, &byteCountSize, &audioDataByteCount);
        if (status != noErr)
        {
            //错误处理
            [self generatorError:@"AudioFileStreamGetProperty kAudioFileStreamProperty_AudioDataByteCount" code:status];
        }
        self->_audioByteSize = audioDataByteCount;
        
        //获取数据帧大小
        UInt32 packetCount;
        UInt32 packetCountSize = sizeof(packetCount);
        status = AudioFileStreamGetProperty(self->_streamId, kAudioFileStreamProperty_PacketSizeUpperBound, &packetCountSize, &packetCount);
        if (status != noErr) {
            [self generatorError:@"AudioFileStreamGetProperty kAudioFileStreamProperty_AudioDataPacketCount" code:status];
        }
        self->_maxPacketSize = packetCount;
    
        if ([self.delegate respondsToSelector:@selector(didReadyToProductPacketWithAudioFileStream:)]) {
            [self.delegate didReadyToProductPacketWithAudioFileStream:self];
        }
    }else if (propertyId == kAudioFileStreamProperty_BitRate) {
        
        //获取bitrate
//        UInt32 size = sizeof(self->_bitrate);
//        OSStatus status = AudioFileStreamGetProperty(self->_streamId, kAudioFileStreamProperty_BitRate, &size, &self->_bitrate);
//        if (status != noErr) {
//            [self generatorError:@"AudioFileStreamGetProperty kAudioFileStreamProperty_BitRate error" code:status];
//        }
    }else if (propertyId == kAudioFileStreamProperty_MaximumPacketSize) {
        
        NSLog(@"获取最大的数据包大小...");
    }
}

//数据快解析回调
- (void)handleAudioFileStreamNumberBytes:(UInt32)inNumberBytes
                           numberPackets:(UInt32)inNumberPackets
                                    data:(const void *)bytes
                              packetDesc:(AudioStreamPacketDescription *)inPacketDescription {
    
    if (inNumberBytes == 0 ||
        inNumberPackets == 0) {
        return;
    }
    
    if (inPacketDescription == NULL) {
        
        UInt32 sizePerPacket = inNumberBytes / inNumberPackets;
        AudioStreamPacketDescription *packetDesc = malloc(sizeof(AudioStreamPacketDescription) * inNumberPackets);
        
        UInt32 offset = 0;
        for (int index = 0; index < inNumberPackets; index ++) {
        
            if (index == inNumberPackets - 1) {
                
                packetDesc[index].mDataByteSize = sizePerPacket;
            }else {
             
                packetDesc[index].mDataByteSize = inNumberBytes - offset;
            }
            offset = index * sizePerPacket;
            packetDesc[index].mStartOffset = offset;
        }
        
        inPacketDescription = packetDesc;
        free(packetDesc);
    }
    
    NSMutableArray *dataArray = [NSMutableArray new];
    for (int index = 0; index < inNumberPackets; index ++) {
        
        SInt64 packetOffset = inPacketDescription[index].mStartOffset;
        NSData *data = [NSData dataWithBytes:bytes + packetOffset length:inPacketDescription[index].mDataByteSize];
        LLAudioData *audioData = [[LLAudioData alloc] initWithBytes:data packetDescription:inPacketDescription[index]];
        audioData.offset = packetOffset;
        [dataArray addObject:audioData];
        
        if (_processedPacketsCount < BitRateEstimationMaxPackets) {
            _processedPacketsSizeTotal += audioData.packetDescription.mDataByteSize;
            _processedPacketsCount += 1;
            [self calculateBitRate];
            [self calculateDuration];
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(audioFileStream:didParseDatas:)]) {
        [self.delegate audioFileStream:self didParseDatas:dataArray];
    }
}

- (void)calculateBitRate
{
    if (_packetDuration && _processedPacketsCount > BitRateEstimationMinPackets && _processedPacketsCount <= BitRateEstimationMaxPackets) {
        double averagePacketByteSize = _processedPacketsSizeTotal / _processedPacketsCount;
        _bitRate = 8.0 * averagePacketByteSize/_packetDuration;
    }
}

- (void)calculateDuration
{
    if (_fileSize > 0  && _bitRate > 0) {
        _duration = ((_fileSize-_dataOffset)*8.0)/_bitRate;
    }
}

- (void)calculatePacketDuration
{
    if (self->_format.mSampleRate > 0) {
        self->_packetDuration = self->_format.mFramesPerPacket / self->_format.mSampleRate;
    }
}

- (void)closeAudioFileStream {
    
    if (_streamId) {
        AudioFileStreamClose(_streamId);
        _streamId = NULL;
    }
}

- (void)reset {
    self->_packetDuration = 0;
    self->_processedPacketsCount = 0;
    self->_processedPacketsSizeTotal = 0;
}

- (void)dealloc
{
    [self closeAudioFileStream];
}

@end
