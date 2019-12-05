//
//  LLAudioThreadLock.m
//  LLAudioQueue
//
//  Created by wilson on 2019/11/22.
//

#import "LLAudioThreadLock.h"

#import <pthread.h>

@interface LLAudioThreadLock ()

@property (nonatomic,assign) pthread_mutex_t mutex;
@property (nonatomic,assign) pthread_cond_t cond;

@end

@implementation LLAudioThreadLock

- (instancetype)init {
    
    self = [super init];
    if (self) {
        
        [self mutexInit];
    }
    return self;
}

- (void)lockWait {
    
    [self mutexWait];
}

- (void)unlockSignal {
    
    [self mutexSignal];
}

#pragma mark - mutex
- (void)mutexInit
{
    pthread_mutex_init(&_mutex, NULL);
    pthread_cond_init(&_cond, NULL);
}

- (void)mutexDestory
{
    pthread_mutex_destroy(&_mutex);
    pthread_cond_destroy(&_cond);
}

- (void)mutexWait
{
    pthread_mutex_lock(&_mutex);
    pthread_cond_wait(&_cond, &_mutex);
    pthread_mutex_unlock(&_mutex);
}

- (void)mutexSignal
{
    pthread_mutex_lock(&_mutex);
    pthread_cond_signal(&_cond);
    pthread_mutex_unlock(&_mutex);
}

- (void)dealloc
{
    [self mutexDestory];
}

@end
