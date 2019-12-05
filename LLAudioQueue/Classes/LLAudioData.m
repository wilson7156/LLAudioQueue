//
//  LLAudioData.m
//  LLAudioQueue
//
//  Created by wilson on 2019/11/28.
//

#import "LLAudioData.h"

@implementation LLAudioData

- (instancetype)initWithBytes:(NSData *)data
            packetDescription:(AudioStreamPacketDescription)packetDescription {
    
    self = [super init];
    if (self) {
        
        self->_data = data;
        self->_packetDescription = packetDescription;
    }
    return self;
}

@end
