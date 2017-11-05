//
//  QFDownloader.h
//  QFAVPlayer
//
//  Created by Quinn_F on 2017/11/5.
//  Copyright © 2017年 Quinn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QFFileHandle.h"

#define RequestTimeout 10.0

@class QFDownloader;
@protocol QFDownloaderDelegate <NSObject>

@required
- (void)requestTaskDidUpdateCache; //更新缓冲进度代理方法

@optional
- (void)requestTaskDidReceiveResponse;
- (void)requestTaskDidFinishLoadingWithCache:(BOOL)cache;
- (void)requestTaskDidFailWithError:(NSError *)error;

@end
@interface QFDownloader : NSObject
@property (nonatomic, weak) id<QFDownloaderDelegate> delegate;
@property (nonatomic, strong) NSURL * requestURL; //请求网址
@property (nonatomic, assign) NSUInteger requestOffset; //请求起始位置
@property (nonatomic, assign) NSUInteger fileLength; //文件长度
@property (nonatomic, assign) NSUInteger cacheLength; //缓冲长度
@property (nonatomic, assign) BOOL cache; //是否缓存文件
@property (nonatomic, assign) BOOL cancel; //是否取消请求

/**
 *  开始请求
 */
- (void)start;
@end
