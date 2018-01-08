# QFAVPlayer

1.添加变下变播功能
2.最简单的必不可少的逻辑代码
3.功能分类
123
<h3>一、使用方法 </h3>

```
- (void)viewDidLoad {
[super viewDidLoad];
[self configAVPlayerWithURL:@"http://lavaweb-10015286.video.myqcloud.com/hong-song-mei-gui-mu-2.mp4"];
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
```
<h3>二、部分截图 </h3>https://github.com/NotOnlyThat/QFAVPlayer
<测试>
<img src="https://github.com/NotOnlyThat/QFAVPlayer/blob/master/Screenshots/path.png">
<测试>
<h3>三、运行结果 </h3>
<img src="https://github.com/NotOnlyThat/QFAVPlayer/blob/master/Screenshots/cache.png">
