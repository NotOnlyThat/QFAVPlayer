//
//  QFAVPlayer.m
//  QFAVPlayer
//
//  Created by Quinn_F on 2017/11/5.
//  Copyright © 2017年 Quinn. All rights reserved.
//

#import "QFAVPlayerView.h"
#import "QFAVAssetResourceLoader.h"
#import "NSURL+Scheme.h"
#import "QFFileHandle.h"

@interface QFAVPlayerView()<QFAVAssetResourceLoaderDelegate>

@property(nonatomic,strong)AVPlayer *qf_player;
@property(nonatomic,strong)AVPlayerItem *qf_playerItem;

@property(nonatomic,strong)AVPlayerLayer *qf_playerLayer;
@property(nonatomic,strong)QFAVAssetResourceLoader *qf_resourceLoader;
@property (nonatomic, strong) id timeObserver;

@end

@implementation QFAVPlayerView

- (void)qf_loadLocalWithURL:(NSString*)qf_url{

    NSURL *url = [NSURL fileURLWithPath:qf_url];
    self.qf_playerItem = [AVPlayerItem playerItemWithURL:url];
    NSLog(@"有缓存，播放缓存文件");
    [self congfigPlayer];
    //Observer
    [self addObserver];
}
- (void)qf_loadNetWithURL:(NSString*)qf_url{
    NSLog(@"无缓存，播放网络文件");

    NSURL *url = [[NSURL alloc] initWithString:qf_url];
    self.qf_resourceLoader = [[QFAVAssetResourceLoader alloc]init];
    self.qf_resourceLoader.delegate = self;
    AVURLAsset * asset = [AVURLAsset URLAssetWithURL:[url customSchemeURL] options:nil];
    [asset.resourceLoader setDelegate:self.qf_resourceLoader queue:dispatch_get_main_queue()];
    self.qf_playerItem = [AVPlayerItem playerItemWithAsset:asset];
    [self congfigPlayer];
    //Observer
    [self addObserver];
}
- (void)congfigPlayer{
    self.qf_player = [AVPlayer playerWithPlayerItem:self.qf_playerItem];
    self.qf_playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.qf_player];
    self.qf_playerLayer.frame = self.bounds;
    self.qf_playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.layer addSublayer:self.qf_playerLayer];
    [self.qf_player play];
}
- (void)play{

    [self.qf_player play];
}


- (void)pause{
    [self.qf_player pause];

}

#pragma mark - QFAVAssetResourceLoaderDelegate
- (void)loader:(QFAVAssetResourceLoader *)loader cacheProgress:(CGFloat)progress {

    NSLog(@"progress ::: %f",progress);
}


#pragma mark - NSNotification 打断处理

- (void)audioSessionInterrupted:(NSNotification *)notification{
    //通知类型
    NSDictionary * info = notification.userInfo;
    // AVAudioSessionInterruptionTypeBegan ==
    if ([[info objectForKey:AVAudioSessionInterruptionTypeKey] integerValue] == 1) {
        [self.qf_player pause];
    }else{
        [self.qf_player play];
    }
}


#pragma mark - KVO
- (void)addObserver {
    AVPlayerItem * songItem = self.qf_playerItem;
    //播放完成
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished) name:AVPlayerItemDidPlayToEndTimeNotification object:songItem];
    //播放进度
//    __weak typeof(self) weakSelf = self;
    self.timeObserver = [self.qf_player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        CGFloat current = CMTimeGetSeconds(time);
        CGFloat total = CMTimeGetSeconds(songItem.duration);
        
        NSLog(@"total :%f /n current / total :%f",total,current / total);
    }];
    [self.qf_player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
    [songItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [songItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [songItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [songItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    
}

- (void)removeObserver {
    AVPlayerItem * songItem = self.qf_playerItem;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.timeObserver) {
        [self.qf_player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    [songItem removeObserver:self forKeyPath:@"status"];
    [songItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [songItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [songItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [self.qf_player removeObserver:self forKeyPath:@"rate"];
    [self.qf_player replaceCurrentItemWithPlayerItem:nil];
}

/**
 *  通过KVO监控播放器状态
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    AVPlayerItem * songItem = object;
    if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        NSArray * array = songItem.loadedTimeRanges;
        CMTimeRange timeRange = [array.firstObject CMTimeRangeValue]; //本次缓冲的时间范围
        NSTimeInterval totalBuffer = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration); //缓冲总长度
        NSLog(@"共缓冲%.2f",totalBuffer);
    }

}

- (void)playbackFinished {
    NSLog(@"播放完成");

}





- (void)goToLandscape{
    [[UIDevice currentDevice]setValue:[NSNumber numberWithInteger:UIDeviceOrientationPortrait]  forKey:@"orientation"];//这句话是防止手动先把设备置为横屏,导致下面的语句失效.
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationLandscapeLeft] forKey:@"orientation"];
    
    self.qf_playerLayer.frame = [UIScreen mainScreen].bounds;
}
- (void)goToPortrait{
    
    [[UIDevice currentDevice]setValue:[NSNumber numberWithInteger:UIDeviceOrientationLandscapeLeft]  forKey:@"orientation"];//这句话是防止手动先把设备置为竖屏,导致下面的语句失效.
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationPortrait] forKey:@"orientation"];
    self.qf_playerLayer.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 230);
    
    
}

@end
