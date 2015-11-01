/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVSplashScreen.h"
#import <Cordova/CDVViewController.h>
#import <Cordova/CDVScreenOrientationDelegate.h>
#import "CDVViewController+SplashScreen.h"

#define kSplashScreenDurationDefault 0.25f


@implementation CDVSplashScreen

- (void)pluginInitialize
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageDidLoad) name:CDVPageDidLoadNotification object:self.webView];
    
    [self setVisible:YES];
    
    //
    
    //第一次启动 默认引导页
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"firstLaunch"] == NO)
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"firstLaunch"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"downLaunch"];
        
        
        //动态配置
        [[NSUserDefaults standardUserDefaults]  setInteger:1 forKey:@"splashVersion"];
        [[NSUserDefaults standardUserDefaults]  setInteger:1 forKey:@"guideVersion"];
        [[NSUserDefaults standardUserDefaults]  setInteger:1 forKey:@"guideShowVersion"];
        
        [self showGuidepage];
    }
    else if([[NSUserDefaults standardUserDefaults] boolForKey:@"downLaunch"] == NO)
    {//启用 动态加载的 引导页
        [self showDowloadGuideInfo];
    }
}

- (void)show:(CDVInvokedUrlCommand*)command
{
    [self setVisible:YES];
}

- (void)hide:(CDVInvokedUrlCommand*)command
{
    [self setVisible:NO];
}

- (void)pageDidLoad
{
    id autoHideSplashScreenValue = [self.commandDelegate.settings objectForKey:[@"AutoHideSplashScreen" lowercaseString]];
    
    // if value is missing, default to yes
    if ((autoHideSplashScreenValue == nil) || [autoHideSplashScreenValue boolValue]) {
        [self setVisible:NO];
    }
    
    static NSInteger count = 0;
    if (count == 0)
    {
        count ++;
        [self getConfigFile];
        //        [self splashUpdateImage:1];
        //        [self guidePageUpdata:1 guideNum:3];
    }
    
    //    [self getConfigFile];//获取加载页
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
    [self updateImage];
}

- (void)createViews
{
    /*
     * The Activity View is the top spinning throbber in the status/battery bar. We init it with the default Grey Style.
     *
     *     whiteLarge = UIActivityIndicatorViewStyleWhiteLarge
     *     white      = UIActivityIndicatorViewStyleWhite
     *     gray       = UIActivityIndicatorViewStyleGray
     *
     */
    
    // Determine whether rotation should be enabled for this device
    // Per iOS HIG, landscape is only supported on iPad and iPhone 6+
    CDV_iOSDevice device = [self getCurrentDevice];
    BOOL autorotateValue = (device.iPad || device.iPhone6Plus) ?
    [(CDVViewController *)self.viewController shouldAutorotateDefaultValue] :
    NO;
    
    [(CDVViewController *)self.viewController setEnabledAutorotation:autorotateValue];
    
    NSString* topActivityIndicator = [self.commandDelegate.settings objectForKey:[@"TopActivityIndicator" lowercaseString]];
    UIActivityIndicatorViewStyle topActivityIndicatorStyle = UIActivityIndicatorViewStyleGray;
    
    if ([topActivityIndicator isEqualToString:@"whiteLarge"]) {
        topActivityIndicatorStyle = UIActivityIndicatorViewStyleWhiteLarge;
    } else if ([topActivityIndicator isEqualToString:@"white"]) {
        topActivityIndicatorStyle = UIActivityIndicatorViewStyleWhite;
    } else if ([topActivityIndicator isEqualToString:@"gray"]) {
        topActivityIndicatorStyle = UIActivityIndicatorViewStyleGray;
    }
    
    UIView* parentView = self.viewController.view;
    parentView.userInteractionEnabled = NO;  // disable user interaction while splashscreen is shown
    _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:topActivityIndicatorStyle];
    _activityView.center = CGPointMake(parentView.bounds.size.width / 2, parentView.bounds.size.height / 2);
    _activityView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin
    | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    [_activityView startAnimating];
    
    // Set the frame & image later.
    _imageView = [[UIImageView alloc] init];
    [parentView addSubview:_imageView];
    
    id showSplashScreenSpinnerValue = [self.commandDelegate.settings objectForKey:[@"ShowSplashScreenSpinner" lowercaseString]];
    // backwards compatibility - if key is missing, default to true
    if ((showSplashScreenSpinnerValue == nil) || [showSplashScreenSpinnerValue boolValue]) {
        [parentView addSubview:_activityView];
    }
    
    // Frame is required when launching in portrait mode.
    // Bounds for landscape since it captures the rotation.
    [parentView addObserver:self forKeyPath:@"frame" options:0 context:nil];
    [parentView addObserver:self forKeyPath:@"bounds" options:0 context:nil];
    
    [self updateImage];
}

- (void)destroyViews
{
    [(CDVViewController *)self.viewController setEnabledAutorotation:[(CDVViewController *)self.viewController shouldAutorotateDefaultValue]];
    
    [_imageView removeFromSuperview];
    [_activityView removeFromSuperview];
    _imageView = nil;
    _activityView = nil;
    _curImageName = nil;
    
    self.viewController.view.userInteractionEnabled = YES;  // re-enable user interaction upon completion
    [self.viewController.view removeObserver:self forKeyPath:@"frame"];
    [self.viewController.view removeObserver:self forKeyPath:@"bounds"];
}

- (CDV_iOSDevice) getCurrentDevice
{
    CDV_iOSDevice device;
    
    UIScreen* mainScreen = [UIScreen mainScreen];
    CGFloat mainScreenHeight = mainScreen.bounds.size.height;
    CGFloat mainScreenWidth = mainScreen.bounds.size.width;
    
    int limit = MAX(mainScreenHeight,mainScreenWidth);
    
    device.iPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    device.iPhone = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone);
    device.retina = ([mainScreen scale] == 2.0);
    device.iPhone5 = (device.iPhone && limit == 568.0);
    // note these below is not a true device detect, for example if you are on an
    // iPhone 6/6+ but the app is scaled it will prob set iPhone5 as true, but
    // this is appropriate for detecting the runtime screen environment
    device.iPhone6 = (device.iPhone && limit == 667.0);
    device.iPhone6Plus = (device.iPhone && limit == 736.0);
    
    return device;
}

- (NSString*)getImageName:(UIInterfaceOrientation)currentOrientation delegate:(id<CDVScreenOrientationDelegate>)orientationDelegate device:(CDV_iOSDevice)device
{
    // Use UILaunchImageFile if specified in plist.  Otherwise, use Default.
    NSString* imageName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UILaunchImageFile"];
    
    NSUInteger supportedOrientations = [orientationDelegate supportedInterfaceOrientations];
    
    // Checks to see if the developer has locked the orientation to use only one of Portrait or Landscape
    BOOL supportsLandscape = (supportedOrientations & UIInterfaceOrientationMaskLandscape);
    BOOL supportsPortrait = (supportedOrientations & UIInterfaceOrientationMaskPortrait || supportedOrientations & UIInterfaceOrientationMaskPortraitUpsideDown);
    // this means there are no mixed orientations in there
    BOOL isOrientationLocked = !(supportsPortrait && supportsLandscape);
    
    if (imageName) {
        imageName = [imageName stringByDeletingPathExtension];
    } else {
        imageName = @"Default";
    }
    
    if (device.iPhone5) { // does not support landscape
        imageName = [imageName stringByAppendingString:@"-568h"];
    } else if (device.iPhone6) { // does not support landscape
        imageName = [imageName stringByAppendingString:@"-667h"];
    } else if (device.iPhone6Plus) { // supports landscape
        if (isOrientationLocked) {
            imageName = [imageName stringByAppendingString:(supportsLandscape ? @"-Landscape" : @"")];
        } else {
            switch (currentOrientation) {
                case UIInterfaceOrientationLandscapeLeft:
                case UIInterfaceOrientationLandscapeRight:
                    imageName = [imageName stringByAppendingString:@"-Landscape"];
                    break;
                default:
                    break;
            }
        }
        imageName = [imageName stringByAppendingString:@"-736h"];
        
    } else if (device.iPad) { // supports landscape
        if (isOrientationLocked) {
            imageName = [imageName stringByAppendingString:(supportsLandscape ? @"-Landscape" : @"-Portrait")];
        } else {
            switch (currentOrientation) {
                case UIInterfaceOrientationLandscapeLeft:
                case UIInterfaceOrientationLandscapeRight:
                    imageName = [imageName stringByAppendingString:@"-Landscape"];
                    break;
                    
                case UIInterfaceOrientationPortrait:
                case UIInterfaceOrientationPortraitUpsideDown:
                default:
                    imageName = [imageName stringByAppendingString:@"-Portrait"];
                    break;
            }
        }
    }
    
    return imageName;
}

// Sets the view's frame and image.
- (void)updateImage
{
    NSString* imageName = [self getImageName:[[UIApplication sharedApplication] statusBarOrientation] delegate:(id<CDVScreenOrientationDelegate>)self.viewController device:[self getCurrentDevice]];
    
    if (![imageName isEqualToString:_curImageName]) {
        UIImage* img = [UIImage imageNamed:imageName];
        _imageView.image = img;
        _curImageName = imageName;
    }
    
    // Check that splash screen's image exists before updating bounds
    if (_imageView.image) {
        [self updateBounds];
    } else {
        NSLog(@"WARNING: The splashscreen image named %@ was not found", imageName);
    }
}

- (void)updateBounds
{
    UIImage* img = _imageView.image;
    CGRect imgBounds = (img) ? CGRectMake(0, 0, img.size.width, img.size.height) : CGRectZero;
    
    CGSize screenSize = [self.viewController.view convertRect:[UIScreen mainScreen].bounds fromView:nil].size;
    UIInterfaceOrientation orientation = self.viewController.interfaceOrientation;
    CGAffineTransform imgTransform = CGAffineTransformIdentity;
    
    /* If and only if an iPhone application is landscape-only as per
     * UISupportedInterfaceOrientations, the view controller's orientation is
     * landscape. In this case the image must be rotated in order to appear
     * correctly.
     */
    BOOL isIPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    if (UIInterfaceOrientationIsLandscape(orientation) && !isIPad) {
        imgTransform = CGAffineTransformMakeRotation(M_PI / 2);
        imgBounds.size = CGSizeMake(imgBounds.size.height, imgBounds.size.width);
    }
    
    // There's a special case when the image is the size of the screen.
    if (CGSizeEqualToSize(screenSize, imgBounds.size)) {
        CGRect statusFrame = [self.viewController.view convertRect:[UIApplication sharedApplication].statusBarFrame fromView:nil];
        if (!(IsAtLeastiOSVersion(@"7.0"))) {
            imgBounds.origin.y -= statusFrame.size.height;
        }
    } else if (imgBounds.size.width > 0) {
        CGRect viewBounds = self.viewController.view.bounds;
        CGFloat imgAspect = imgBounds.size.width / imgBounds.size.height;
        CGFloat viewAspect = viewBounds.size.width / viewBounds.size.height;
        // This matches the behaviour of the native splash screen.
        CGFloat ratio;
        if (viewAspect > imgAspect) {
            ratio = viewBounds.size.width / imgBounds.size.width;
        } else {
            ratio = viewBounds.size.height / imgBounds.size.height;
        }
        imgBounds.size.height *= ratio;
        imgBounds.size.width *= ratio;
    }
    
    _imageView.transform = imgTransform;
    _imageView.frame = imgBounds;
}

- (void)setVisible:(BOOL)visible
{
    if (visible == _visible) {
        return;
    }
    _visible = visible;
    
    id fadeSplashScreenValue = [self.commandDelegate.settings objectForKey:[@"FadeSplashScreen" lowercaseString]];
    id fadeSplashScreenDuration = [self.commandDelegate.settings objectForKey:[@"FadeSplashScreenDuration" lowercaseString]];
    
    float fadeDuration = fadeSplashScreenDuration == nil ? kSplashScreenDurationDefault : [fadeSplashScreenDuration floatValue];
    
    if ((fadeSplashScreenValue == nil) || ![fadeSplashScreenValue boolValue]) {
        fadeDuration = 0;
    }
    
    // Never animate the showing of the splash screen.
    if (visible) {
        if (_imageView == nil) {
            [self createViews];
        }
    } else if (fadeDuration == 0) {
        [self destroyViews];
    } else {
        __weak __typeof(self) weakSelf = self;
        
        [UIView transitionWithView:self.viewController.view
                          duration:fadeDuration
                           options:UIViewAnimationOptionTransitionNone
                        animations:^(void) {
                            __typeof(self) strongSelf = weakSelf;
                            if (strongSelf != nil) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [strongSelf->_activityView setAlpha:0];
                                    [strongSelf->_imageView setAlpha:0];
                                });
                            }
                        }
                        completion:^(BOOL finished) {
                            if (finished) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [weakSelf destroyViews];
                                });
                            }
                        }
         ];
    }
}


#pragma mark 获取配置参数 文件 guide_config.txt
-(void)getConfigFile
{
    //插件 参数CONFIG_URL 配置域名
    id serverSetting = [self.commandDelegate.settings objectForKey:[@"CONFIG_URL" lowercaseString]];
    if (serverSetting == nil) {
        NSLog(@"server == nil");
        return;
    }
    
    NSString *urlStr = [NSString stringWithFormat:@"%@",serverSetting];// @"http://192.168.5.249:3000";
    NSString *path = [urlStr stringByAppendingString:@"guide_config.txt"];
    
    
    NSURL *url = [NSURL URLWithString:path];
    dispatch_queue_t queue =dispatch_queue_create("loadGuide_config",NULL);
    dispatch_async(queue, ^{
        
        NSData *resultData = [NSData dataWithContentsOfURL:url];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            if (resultData ==nil)
                return ;
            
            NSError *error=nil;
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:resultData options:kNilOptions error:&error];
            if (error)
            {
                NSLog(@"json 错误 %@",[error localizedDescription]);
                return ;
            }
            
            NSLog(@"%@",dic);
            
            //            {
            //                "我是注释":"",
            //                "splashVersion":1,
            //                "guideVersion":1,
            //                "guideShowVersion":1,
            //                "guideNum":3
            //            }
            
            NSNumber *splashVersion = [dic objectForKey:@"splashVersion"];
            NSInteger localSplashVersion = [[NSUserDefaults standardUserDefaults] integerForKey:@"splashVersion"];
            if ([splashVersion integerValue] > localSplashVersion)
            {
                //跟新 启动页
                [self splashUpdateImage:[splashVersion integerValue]];
            }
            
            
            
            NSNumber *guideVersion = [dic objectForKey:@"guideVersion"];
            NSInteger localGuideVersion= [[NSUserDefaults standardUserDefaults] integerForKey:@"guideVersion"];
            if ([guideVersion integerValue] > localGuideVersion)
            {
                //更新 引导页图片
                NSNumber *guideNum = [dic objectForKey:@"guideNum"];
                [self guidePageUpdata:[guideVersion integerValue] guideNum:[guideNum integerValue]];
            }
            
            
            
            NSNumber *guideShowVersion = [dic objectForKey:@"guideShowVersion"];
            NSInteger localGuideShowVersion= [[NSUserDefaults standardUserDefaults] integerForKey:@"guideShowVersion"];
            if ([guideShowVersion integerValue] > localGuideShowVersion)
            {
                //跟新  显示引导页 的版本号
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"downLaunch"];
                [[NSUserDefaults standardUserDefaults] setInteger:[guideShowVersion integerValue] forKey:@"guideShowVersion"];
            }
        });
    });
}


// 跟新启动页的 图片
-(void)splashUpdateImage:(NSInteger)Version
{
    id serverSetting = [self.commandDelegate.settings objectForKey:[@"CONFIG_URL" lowercaseString]];
    if (serverSetting == nil) {
        NSLog(@"server == nil");
        return;
    }
    
    
    CGFloat viewH = [UIScreen mainScreen].bounds.size.height;
    NSString *imageName=@"Default";
    NSString *imageAllName;
    
    if (viewH == 320)
    {
        imageAllName = [imageName stringByAppendingString:@"~iphone"];
    }
    else if (viewH == 480)
    {
        imageAllName = [imageName stringByAppendingString:@"@2x~iphone"];
    }
    else if(viewH == 568)
    {
        imageAllName = [imageName stringByAppendingString:@"-568h@2x~iphone"];
    }
    else if (viewH == 667)
    {
        imageAllName = [imageName stringByAppendingString:@"-667h"];
    }
    else if (viewH == 736)
    {
        imageAllName = [imageName stringByAppendingString:@"-736h"];
    }
    
    NSString *server = [NSString stringWithFormat:@"%@",serverSetting];
    NSString *imageUrlStr  = [server stringByAppendingString:[NSString stringWithFormat:@"splash/%@.png",imageAllName]];
    
    
    imageUrlStr = @"https://ss0.bdstatic.com/5aV1bjqh_Q23odCf/static/superman/img/logo/bd_logo1_31bdc765.png";
    NSURL *url = [NSURL URLWithString:imageUrlStr];
    dispatch_queue_t queue =dispatch_queue_create("loadImage",NULL);
    dispatch_async(queue, ^{
        
        NSData *resultData = [NSData dataWithContentsOfURL:url];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (resultData == nil)
            {
                NSLog(@"更新 splashUpdateImage 图片失败！");
                return ;
            }
            
            NSString *imageNamePath = [[NSBundle mainBundle] pathForResource:imageAllName ofType:@"png"];
            NSData *imageData = [[NSData alloc]initWithContentsOfFile:imageNamePath];
            if (imageData == nil)
            {
                NSLog(@"没有找到 图片");
            }
            
            BOOL isWrite = [resultData writeToFile:imageNamePath atomically:YES];
            if (isWrite)
            {
                [[NSUserDefaults standardUserDefaults] setInteger:Version forKey:@"splashVersion"];
                NSLog(@"跟新成功");
            }
            
            NSError *error;
            [resultData writeToFile:imageNamePath options:NSDataWritingAtomic error:&error];
            if (error) {
                NSLog(@"%@",[error localizedDescription]);
            }
            
            
        });
    });
}

//更新 引导页 图片
- (void)guidePageUpdata:(NSInteger)Version guideNum:(NSInteger)guideNum
{
    id serverSetting = [self.commandDelegate.settings objectForKey:[@"CONFIG_URL" lowercaseString]];
    if (serverSetting == nil) {
        NSLog(@"server == nil");
        return;
    }
    
    CGFloat viewH = [UIScreen mainScreen].bounds.size.height;
    NSString *imageName=@"guide";
    NSString *imageAllName;
    
    if (viewH == 480)
    {
        imageAllName = [imageName stringByAppendingString:@"-480h"];
    }
    else if(viewH == 568)
    {
        imageAllName = [imageName stringByAppendingString:@"-568h"];
    }
    else if (viewH == 667)
    {
        imageAllName = [imageName stringByAppendingString:@"-667h"];
    }
    else if (viewH == 736)
    {
        imageAllName = [imageName stringByAppendingString:@"-736h"];
    }
    
    char count='a';
    for (int i=0; i<guideNum; i++)
    {
        char countAt=count+i;
        NSString *imageViewName=[[NSString stringWithFormat:@"%c-",countAt] stringByAppendingString:imageAllName];
        
        NSString *server = [NSString stringWithFormat:@"%@",serverSetting];
        NSString *imageUrlStr  = [server stringByAppendingString:[NSString stringWithFormat:@"guides/%@",imageViewName]];
        NSString *path =[NSString stringWithFormat:@"%@/%@.png",[ NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0],imageViewName];
        
        [self downLoadImage:imageUrlStr name:imageViewName path:path];
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:Version forKey:@"guideVersion"];
    [[NSUserDefaults standardUserDefaults] setInteger:guideNum forKey:@"guideNum"];
}

//多线程下载 引导页 图片
- (void)downLoadImage:(NSString*)imageUrl name:(NSString*)imageName path:(NSString*)path
{
    if (imageUrl == nil || imageName == nil || path == nil)
        return;
    
    //    imageUrl = @"https://ss0.bdstatic.com/5aV1bjqh_Q23odCf/static/superman/img/logo/bd_logo1_31bdc765.png";
    NSURL *url = [NSURL URLWithString:imageUrl];
    dispatch_queue_t queue =dispatch_queue_create("loadImage",NULL);
    dispatch_async(queue, ^{
        
        NSData *resultData = [NSData dataWithContentsOfURL:url];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (resultData == nil)
            {
                NSLog(@"下载图片失败");
                return ;
            }
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if (![fileManager fileExistsAtPath:path]) {
                [fileManager createFileAtPath:path contents:nil attributes:nil];
            }
            
            // 图片下载 引导页
            BOOL isWrite = [resultData writeToFile:path atomically:YES];
            NSLog(@"写入结果 %d",isWrite);
        });
    });
}


#pragma mark 默认 引导页
- (void)showGuidepage
{
    //插件参数配置的 默认启动页数目
    id pagesCount = [self.commandDelegate.settings objectForKey:[@"GUIDE_DEF_NUM" lowercaseString]];
    if (pagesCount == nil || [pagesCount integerValue] ==0)
        return;
    
    CGFloat viewW = [UIScreen mainScreen].bounds.size.width;
    CGFloat viewH = [UIScreen mainScreen].bounds.size.height;
    
    NSInteger pages = [pagesCount integerValue];
    NSLog(@"w=%f;h=%f",viewW,viewH);
    
    [self.viewController.navigationController setNavigationBarHidden:YES];
    
    _guideView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,0,viewW+1,viewH)];
    _guideView.bounces = NO;
    _guideView.showsHorizontalScrollIndicator = NO;
    _guideView.showsVerticalScrollIndicator = NO;
    _guideView.pagingEnabled = YES;
    _guideView.delegate = self;
    [_guideView setContentSize:CGSizeMake(viewW*pages, viewH)];
    
    
    NSString *imageName=@"guide";
    NSString *imageAllName;
    
    if (viewH == 480)
    {
        imageAllName = [imageName stringByAppendingString:@"-480h"];
    }
    else if(viewH == 568)
    {
        imageAllName = [imageName stringByAppendingString:@"-568h"];
    }
    else if (viewH == 667)
    {
        imageAllName = [imageName stringByAppendingString:@"-667h"];
    }
    else if (viewH == 736)
    {
        imageAllName = [imageName stringByAppendingString:@"-736h"];
    }
    
    char count='a';
    for (int i=0; i<pages; i++)
    {
        char countAt=count+i;
        NSString *imageViewName=[[NSString stringWithFormat:@"%c-",countAt] stringByAppendingString:imageAllName];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(i*viewW,0, viewW,viewH)];
        imageView.userInteractionEnabled = YES;
        UIImage *image = [UIImage imageNamed:imageViewName];
        if (image == nil)
            image = [UIImage imageNamed:[[NSString stringWithFormat:@"%c-",countAt] stringByAppendingString:imageName]];
        
        if (image == nil)
        {
            NSLog(@"没有找到 引导页图片 1:%@ 2:%@",imageViewName,[[NSString stringWithFormat:@"%c-",countAt] stringByAppendingString:imageName]);
            return;
        }
        
        //
        imageView.image = image;
        
        //最后一张图片 加上btn
        if (i==pages-1)
        {
            UISwipeGestureRecognizer* swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
            [swipeGesture setDirection:UISwipeGestureRecognizerDirectionLeft];
            swipeGesture.delegate = self;
            [imageView addGestureRecognizer:swipeGesture];
        }
        
        [_guideView addSubview:imageView];
    }
    
    [self.viewController.view addSubview:_guideView];
}

-(void) handleSwipeGesture :(UISwipeGestureRecognizer*) recognizer
{
    if(recognizer.state == UIGestureRecognizerStateEnded){
        if(recognizer.direction == UISwipeGestureRecognizerDirectionLeft){
            [self startUseApp];
        }
    }
}

-(void)startUseApp
{
    [_guideView removeFromSuperview];
}


#pragma  -mark scrollview delegate
-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    //    NSInteger page = scrollView.contentOffset.x /self.view.bounds.size.width;
    
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark 显示经过动态配置的 引导页
- (void)showDowloadGuideInfo
{
    NSInteger pages = [[NSUserDefaults standardUserDefaults] integerForKey:@"guideNum"];
    
    id serverSetting = [self.commandDelegate.settings objectForKey:[@"CONFIG_URL" lowercaseString]];
    if (serverSetting == nil) {
        NSLog(@"server == nil");
        return;
    }
    
    CGFloat viewW = [UIScreen mainScreen].bounds.size.width;
    CGFloat viewH = [UIScreen mainScreen].bounds.size.height;
    
    [self.viewController.navigationController setNavigationBarHidden:YES];
    _guideView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,0,viewW+1,viewH)];
    _guideView.bounces = NO;
    _guideView.showsHorizontalScrollIndicator = NO;
    _guideView.showsVerticalScrollIndicator = NO;
    _guideView.pagingEnabled = YES;
    [_guideView setContentSize:CGSizeMake(viewW*pages, viewH)];
    
    //检测图片是否下载
    NSString *imageName=@"guide";
    NSString *imageAllName;
    
    if (viewH == 480)
    {
        imageAllName = [imageName stringByAppendingString:@"-480h"];
    }
    else if(viewH == 568)
    {
        imageAllName = [imageName stringByAppendingString:@"-568h"];
    }
    else if (viewH == 667)
    {
        imageAllName = [imageName stringByAppendingString:@"-667h"];
    }
    else if (viewH == 736)
    {
        imageAllName = [imageName stringByAppendingString:@"-736h"];
    }
    
    char count='a';
    BOOL isDown=YES;
    for (int i=0; i<pages; i++)
    {
        char countAt=count+i;
        NSString *imageViewName=[[NSString stringWithFormat:@"%c-",countAt] stringByAppendingString:imageAllName];
        
        NSString *server = [NSString stringWithFormat:@"%@",serverSetting];
        NSString *imageUrlStr  = [server stringByAppendingString:[NSString stringWithFormat:@"guides/%@.png",imageViewName]];
        NSString *path =[NSString stringWithFormat:@"%@/%@.png",[ NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0],imageViewName];
        
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image == nil)
        {
            [self downLoadImage:imageUrlStr name:imageViewName path:path];
            isDown = NO;
        }
    }
    
    if (isDown == NO)
        return;
    
    
    char imageCount='a';
    for (int i=0; i<pages; i++)
    {
        char countAt=imageCount+i;
        NSString *imageViewName=[[NSString stringWithFormat:@"%c-",countAt] stringByAppendingString:imageAllName];
        NSString *path =[NSString stringWithFormat:@"%@/%@",[ NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0],imageViewName];
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(i*viewW,0, viewW,viewH)];
        imageView.userInteractionEnabled = YES;
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image == nil)
        {
            NSLog(@"加载 图片失败 %@",path);
            return;
        }
        
        //
        imageView.image = image;
        
        //最后一张图片 加上btn
        if (i == pages-1)
        {
            UISwipeGestureRecognizer* swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
            [swipeGesture setDirection:UISwipeGestureRecognizerDirectionLeft];
            swipeGesture.delegate = self;
            [imageView addGestureRecognizer:swipeGesture];
        }
        
        [_guideView addSubview:imageView];
    }
    
    [self.viewController.view addSubview:_guideView];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"downLaunch"];
}

@end





