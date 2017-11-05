//
//  QFAVAssetResourceLoader.h
//  QFAVPlayer
//
//  Created by Quinn_F on 2017/11/5.
//  Copyright © 2017年 Quinn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#define MimeType @"video/mp4"

@class QFAVAssetResourceLoader;

@protocol QFAVAssetResourceLoaderDelegate <NSObject>

@required
- (void)loader:(QFAVAssetResourceLoader *)loader cacheProgress:(CGFloat)progress;

@optional
- (void)loader:(QFAVAssetResourceLoader *)loader failLoadingWithError:(NSError *)error;

@end


@interface QFAVAssetResourceLoader : NSObject<AVAssetResourceLoaderDelegate>
@property (nonatomic, weak) id<QFAVAssetResourceLoaderDelegate> delegate;
@property (atomic, assign) BOOL seekRequired; //Seek标识
@property (nonatomic, assign) BOOL cacheFinished;

- (void)stopLoading;

@end
