//
//  LLAudioData.h
//  LLAudioQueue
//
//  Created by wilson on 2019/11/28.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

/// 解析出来的每一个数据对象
@interface LLAudioData : NSObject

- (instancetype)initWithBytes:(NSData *)data
            packetDescription:(AudioStreamPacketDescription)packetDescription;

@property (nonatomic,assign) SInt64 offset;
@property (nonatomic,copy,readonly) NSData *data;
@property (nonatomic,readonly) AudioStreamPacketDescription packetDescription;

@end

NS_ASSUME_NONNULL_END
