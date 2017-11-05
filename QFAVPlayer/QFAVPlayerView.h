//
//  QFAVPlayer.h
//  QFAVPlayer
//
//  Created by Quinn_F on 2017/11/5.
//  Copyright © 2017年 Quinn. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface QFAVPlayerView : UIView
- (void)qf_loadLocalWithURL:(NSString*)qf_url;
- (void)qf_loadNetWithURL:(NSString*)qf_url;

/**
 *  进入全屏模式
 */
- (void)goToLandscape;
/**
 *  退出全屏模式
 */
- (void)goToPortrait;
@end
