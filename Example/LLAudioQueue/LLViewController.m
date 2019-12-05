//
//  LLViewController.m
//  LLAudioQueue
//
//  Created by 704110362@qq.com on 12/03/2019.
//  Copyright (c) 2019 704110362@qq.com. All rights reserved.
//

#import "LLViewController.h"
#import <LLAudioPlayer.h>


@interface LLViewController ()<LLAudioPlayerDelegate>

@property (nonatomic,strong) LLAudioPlayer *audioPlayer;
@property (weak, nonatomic) IBOutlet UILabel *scheduleLabel;
@property (weak, nonatomic) IBOutlet UILabel *duration;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *label;

@end

@implementation LLViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    NSURL *link = [NSURL URLWithString:@"http://192.168.31.80/music/zuo.mp3"];
    NSURL *link1 = [NSURL URLWithString:@"http://sc1.111ttt.cn/2018/1/03/13/396131213056.mp3"];
    NSURL *link2 = [NSURL URLWithString:@"http://sc1.111ttt.cn/2018/1/03/13/396131212186.mp3"];
    NSString *file = [[NSBundle mainBundle] pathForResource:@"zuo" ofType:@"mp3"];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"anxiang" ofType:@"mp3"];
    NSString *filePath1 = [[NSBundle mainBundle] pathForResource:@"zhiai" ofType:@"mp3"];
    
    NSArray *urls = @[link2,[NSURL fileURLWithPath:file],[NSURL fileURLWithPath:filePath],[NSURL fileURLWithPath:filePath1]];
    self.audioPlayer = [[LLAudioPlayer alloc] initWithURLs:urls error:nil delegate:self];
//    self.audioPlayer.mode = LLAudioPlayerModeRandom;
    [self.audioPlayer play];
    
    self.slider.continuous = NO;
    [self.slider addTarget:self action:@selector(sliderValueChange:) forControlEvents:UIControlEventValueChanged];
}

#pragma mark - LLAudioPlayerDelegate
- (void)audioPlayer:(LLAudioPlayer *)audioPlayer didPlayProgress:(NSProgress *)progress {
 
    //设置时长
    NSString *duraton = [self getDuration:progress.totalUnitCount];
    NSString *schedure = [self getDuration:progress.completedUnitCount];
    
    self.duration.text = duraton;
    self.scheduleLabel.text = schedure;
    
    self.slider.value = progress.fractionCompleted;
}

- (NSString *)getDuration:(NSInteger)duration {
    
    NSInteger minute = duration / 60;
    NSInteger second = duration - minute * 60;
    
    NSString *minuteString = @(minute).stringValue;
    if (minute < 10) {
        minuteString = [NSString stringWithFormat:@"0%@",@(minute).stringValue];
    }
    
    NSString *secondString = @(second).stringValue;
    if (second < 10) {
        secondString = [NSString stringWithFormat:@"0%@",@(second).stringValue];
    }
    return [minuteString stringByAppendingFormat:@":%@",secondString];
}

- (void)audioPlayer:(LLAudioPlayer *)audioPlayer didChangeStatus:(LLAudioPlayerStatus)status {
    
    if (status == LLAudioPlayerStatusPlaying) {
        NSLog(@"播放中...");
    }else if (status == LLAudioPlayerStatusPause) {
        NSLog(@"播放暂停...");
    }else if (status == LLAudioPlayerStatusStop) {
        NSLog(@"播放结束...");
    }else if (status == LLAudioPlayerStatusError) {
        NSLog(@"播放错误...");
    }
}

- (void)audioPlayer:(LLAudioPlayer *)audioPlayer didDownloadingStatus:(LLAudioPlayerDownloadStatus)status {
    
    if (status == LLAudioPlayerDownloadStatusPending) {
        NSLog(@"等待下载...");
    }else if (status == LLAudioPlayerDownloadStatusNormal) {
        NSLog(@"播放中...");
    }else {
        NSLog(@"下载完成");
    }
}

- (IBAction)playButton:(id)sender {
    
    [self.audioPlayer play];
}
- (IBAction)pauseButton:(id)sender {
    [self.audioPlayer pause];
}
- (IBAction)stopButton:(id)sender {
    [self.audioPlayer stop];
}

- (void)sliderValueChange:(UISlider *)slider {
    
    CGFloat value = slider.value;
    [self.audioPlayer seekTimeToProgress:value];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
