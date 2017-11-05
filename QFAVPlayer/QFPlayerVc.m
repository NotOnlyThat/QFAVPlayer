//
//  QFPlayerVc.m
//  QFAVPlayer
//
//  Created by Quinn_F on 2017/11/5.
//  Copyright © 2017年 Quinn. All rights reserved.
//

#import "QFPlayerVc.h"
#import <AVFoundation/AVFoundation.h>
#import "QFFileHandle.h"
#import "QFAVPlayerView.h"

@interface QFPlayerVc ()
@property(nonatomic,strong)QFAVPlayerView *qf_playerView;
@end

@implementation QFPlayerVc

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configAVPlayerWithURL:@"http://01n-data.oss-cn-hangzhou.aliyuncs.com/media/ugc/video_record/400.mp4"];
}
-(id)qf_playerView{
    if (_qf_playerView == nil) {
        _qf_playerView = [[QFAVPlayerView alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
        [self.view addSubview:_qf_playerView];
    }
    return _qf_playerView;
}
-(void)configAVPlayerWithURL:(NSString *)url{
    NSString * cacheFilePath = [QFFileHandle cacheFileExistsWithURL:url];
    if (cacheFilePath){
        [self.qf_playerView qf_loadLocalWithURL:cacheFilePath];
    }else{
        [self.qf_playerView qf_loadNetWithURL:url];
    }
}


@end
