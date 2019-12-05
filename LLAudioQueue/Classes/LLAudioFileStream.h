//
//  LLAudioFileStream.h
//  LLAudioQueue
//
//  Created by wilson on 2019/11/28.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "LLAudioData.h"

NS_ASSUME_NONNULL_BEGIN

@class LLAudioFileStream;
@protocol LLAudioFileStreamDelegate <NSObject>

@optional

/// 可以处理解析后的数据回调
/// @param audioFileStream audioFileStream
- (void)didReadyToProductPacketWithAudioFileStream:(LLAudioFileStream *)audioFileStream;

/// 成功解析数据回调
/// @param audioFileStream audioFileStream
/// @param audioDatas 解析后的数据
- (void)audioFileStream:(LLAudioFileStream *)audioFileStream didParseDatas:(NSArray *)audioDatas;

/// 解析错误回调
/// @param audioFileStream audioFileStream
/// @param error 错误信息
- (void)audioFileStream:(LLAudioFileStream *)audioFileStream didParseFailure:(NSError *)error;
@end

///  解析常用音频数据
@interface LLAudioFileStream : NSObject

/// 根据FileTypeID初始化一个解析音频数据对象
/// @param fileType 解析文件类型
/// @param error 返回错误
- (instancetype)initWithFileType:(AudioFileTypeID)fileType error:(NSError **)error;

/// 解析文件类型
@property (nonatomic,readonly) AudioFileTypeID fileType;

/// 音频格式
@property (nonatomic,readonly) AudioStreamBasicDescription format;

/// 是否可以处理解析成功后的数据 
@property (nonatomic,readonly) BOOL readyToProductPacket;

///  数据大小
@property (nonatomic,readonly) UInt64 audioByteSize;

/// 代理
@property (nonatomic,weak) id<LLAudioFileStreamDelegate> delegate;

@property (nonatomic,readonly) NSInteger maxPacketSize;

@property (nonatomic,assign) NSInteger bitRate;

@property (nonatomic,assign) SInt64 dataOffset;

@property (nonatomic,assign) NSTimeInterval duration;

///  总数据大小 
@property (nonatomic,assign) long long fileSize;

/// 解析音频数据
/// @param data 音频数据
- (void)parseData:(NSData *)data;

/// 关闭解析数据
- (void)closeAudioFileStream;

- (void)reset;
@end

NS_ASSUME_NONNULL_END
