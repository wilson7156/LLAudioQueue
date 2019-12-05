//
//  LLAudioThreadLock.h
//  LLAudioQueue
//
//  Created by wilson on 2019/11/22.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLAudioThreadLock : NSObject

- (void)lockWait;
- (void)unlockSignal;
@end

NS_ASSUME_NONNULL_END
