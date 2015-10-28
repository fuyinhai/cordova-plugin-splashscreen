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
    
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"downLaunch"];
    
    
    //第一次启动 默认引导页
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"firstLaunch"] == NO)
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"firstLaunch"];
        [self showGuidepage];
    }
    else if([[NSUserDefaults standardUserDefaults] boolForKey:@"downLaunch"] == NO)
    {//启用 动态加载的 引导页
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"downLaunch"];
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
    
    [self getGuideViewInfo];//获取引导页
    [self getLoadPageInfo];//获取加载页
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



#pragma mark 动态变更启动 load 页面
//获取 LoadPageInfo
-(void)getLoadPageInfo
{
    id loadPageInfoUrl = [self.commandDelegate.settings objectForKey:[@"LoadPageInfoUrl" lowercaseString]];
    if (loadPageInfoUrl == nil) {
        NSLog(@"LoadPageInfoUrl == nil");
        return;
    }
    
    CGFloat viewH = [UIScreen mainScreen].bounds.size.height;
    CGFloat viewW = [UIScreen mainScreen].bounds.size.width;
    
    NSDictionary *paramter = [[NSDictionary alloc] initWithObjects:@[[NSString stringWithFormat:@"%f",viewH],[NSString stringWithFormat:@"%f",viewW]] forKeys:@[@"height",@"width"]];
    
    
    [HttpResponse postRequestWithPath:loadPageInfoUrl paramters:paramter finshedBlock:^(NSData *data){
        
        NSError *error=nil;
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (error)
        {
            NSLog(@"json 错误 %@",[error localizedDescription]);
            return ;
        }
        
        //数据错误
        NSString *respCode=[NSString stringWithFormat:@"%@",[dic objectForKey:@"respCode"]];
        if (![respCode isEqualToString:@"10020"])
        {
            NSLog(@"%@",[NSString stringWithFormat:@"%@",[dic objectForKey:@"respMsg"]]);
            return;
        }
        
        NSDictionary *jsonData = [dic objectForKey:@"data"];
        
        //比较版本
        NSString *path =[NSString stringWithFormat:@"%@/LoadPageInfo",[ NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
        NSDictionary *oldData = [[NSDictionary alloc] initWithContentsOfFile:path];
        
        NSString *jsonDataVersion = [NSString stringWithFormat:@"%@",[jsonData objectForKey:@"Version"]];
        NSString *oldDataVersion = [NSString stringWithFormat:@"%@",[oldData objectForKey:@"Version"]];
        
        if ([jsonDataVersion isEqualToString:oldDataVersion])
            return;
        
        
        //更新图片
        NSString *loadImageUrl = [NSString stringWithFormat:@"%@",[jsonData objectForKey:@"loadImageUrl"]];
        NSString *imageName = [self getImageName:[[UIApplication sharedApplication] statusBarOrientation] delegate:(id<CDVScreenOrientationDelegate>)self.viewController device:[self getCurrentDevice]];
        
        if ([imageName isEqualToString:@"Default-568h"])
            imageName = @"Default-568h@2x~iphone";
        
        [self downLoadImage:loadImageUrl name:imageName path:nil];
        
    } errorBlock:^(NSString *error){
        NSLog(@"%@",error);
    }];
}


//多线程下载图片
- (void)downLoadImage:(NSString*)imageUrl name:(NSString*)imageName path:(NSString*)path
{
    NSString *imageUrlStr = nil;
    if (imageUrl == nil)
        imageUrlStr = @"http://i5.download.fd.pchome.net/t_600x1024/g1/M00/0A/1B/oYYBAFP24pSIW6XtAATAWwYPjvkAAB3owHl2ywABMBz933.jpg";
    else
        imageUrlStr = imageUrl;
    
    
    NSURL *url = [NSURL URLWithString:imageUrlStr];
    dispatch_queue_t queue =dispatch_queue_create("loadImage",NULL);
    dispatch_async(queue, ^{
        
        NSData *resultData = [NSData dataWithContentsOfURL:url];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            if (path == nil)
            {
                //更新照片  加载页
                if ([imageName isEqualToString:@"Default"])
                {
                    NSString *imageAllNamePath2 = [[NSBundle mainBundle] pathForResource:@"Default@2x" ofType:@"png"];
                    [resultData writeToFile:imageAllNamePath2 atomically:YES];
                }
                
                NSString *imageAllNamePath = [[NSBundle mainBundle] pathForResource:imageName ofType:@"png"];
                
                NSData *imageData = [[NSData alloc] initWithContentsOfFile:imageAllNamePath];
                if (imageData == nil)
                {
                    NSLog(@"没有找到 图片");
                }
                
                BOOL isWrite = [resultData writeToFile:imageAllNamePath atomically:YES];
                NSLog(@"%d",isWrite);
            }
            else
            {// 图片下载 引导页
                NSString *imagePath = [path stringByAppendingString:imageName];
                BOOL isWrite = [resultData writeToFile:imagePath atomically:YES];
                NSLog(@"%d",isWrite);
            }
        });
    });
}

#pragma mark 默认 引导页
- (void)showGuidepage
{
    id pagesCount = [self.commandDelegate.settings objectForKey:[@"guideImageCount" lowercaseString]];
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




#pragma mark 动态配置引导页
//获取 guideInfo 引导页 信息
-(void)getGuideViewInfo
{
    id guideInfoUrl = [self.commandDelegate.settings objectForKey:[@"guidePageInfoUrl" lowercaseString]];
    if (guideInfoUrl == nil) {
        NSLog(@"guidePageInfoUrl == nil");
        return;
    }
    
    CGFloat viewW = [UIScreen mainScreen].bounds.size.width;
    CGFloat viewH = [UIScreen mainScreen].bounds.size.height;
    NSDictionary *paramter = [[NSDictionary alloc] initWithObjects:@[[NSString stringWithFormat:@"%f",viewH],[NSString stringWithFormat:@"%f",viewW]] forKeys:@[@"height",@"width"]];
    
    [HttpResponse postRequestWithPath:guideInfoUrl paramters:paramter finshedBlock:^(NSData *data){
        NSError *error=nil;
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (error)
        {
            NSLog(@"json 错误 %@",[error localizedDescription]);
            return ;
        }
        
        //数据错误
        NSString *respCode=[NSString stringWithFormat:@"%@",[dic objectForKey:@"respCode"]];
        if (![respCode isEqualToString:@""])
        {
            NSLog(@"%@",[NSString stringWithFormat:@"%@",[dic objectForKey:@"respMsg"]]);
            return;
        }
        
        NSDictionary *guideInfo = [dic objectForKey:@"data"];
        
        
        //比较版本
        NSString *path =[NSString stringWithFormat:@"%@/GuidePageInfo",[ NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
        NSDictionary *oldData = [[NSDictionary alloc] initWithContentsOfFile:path];
        
        NSString *jsonDataVersion = [NSString stringWithFormat:@"%@",[guideInfo objectForKey:@"Version"]];
        NSString *oldDataVersion = [NSString stringWithFormat:@"%@",[oldData objectForKey:@"Version"]];
        
        if ([jsonDataVersion isEqualToString:oldDataVersion])
            return;
        
        
        //更新 文件
        [guideInfo writeToFile:path atomically:YES];
        
        //跟新 图片
        NSArray *imageArray = [guideInfo objectForKey:@"imageArray"];
        [self loadImageArray:imageArray];
        
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"downLaunch"];
        
    } errorBlock:^(NSString *error){
        NSLog(@"%@",error);
    }];
}


- (void)showDowloadGuideInfo
{
    NSString *path =[NSString stringWithFormat:@"%@/GuidePageInfo",[ NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
    NSDictionary *guideInfo = [[NSDictionary alloc] initWithContentsOfFile:path];
    NSInteger pages = [[NSString stringWithFormat:@"%@",[guideInfo objectForKey:@"pages"]] integerValue];
    
    CGFloat viewW = [UIScreen mainScreen].bounds.size.width;
    CGFloat viewH = [UIScreen mainScreen].bounds.size.height;
    
    [self.viewController.navigationController setNavigationBarHidden:YES];
    _guideView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,0,viewW+1,viewH)];
    _guideView.bounces = NO;
    _guideView.showsHorizontalScrollIndicator = NO;
    _guideView.showsVerticalScrollIndicator = NO;
    _guideView.pagingEnabled = YES;
    //    _guideView.delegate = self;
    [_guideView setContentSize:CGSizeMake(viewW*pages, viewH)];
    
    NSArray *imageArray = [guideInfo objectForKey:@"imageArray"];
    NSString *pathPhoto = [NSString stringWithFormat:@"%@/",[ NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
    
    //检测图片是否下载
    for (NSDictionary *dic in imageArray)
    {
        NSString *name = [NSString stringWithFormat:@"%@",[dic objectForKey:@"name"]];
        NSString *imagePath = [pathPhoto stringByAppendingString:[NSString stringWithFormat:@"%@.png",name]];
        
        UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
        if (image == nil)
        {
            [self loadImageArray:imageArray];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"downLaunch"];
            
            return;
        }
    }
    
    
    for (int i=0; i<pages; i++)
    {
        NSDictionary *dic = [imageArray objectAtIndex:i];
        NSString *name = [NSString stringWithFormat:@"%@",[dic objectForKey:@"name"]];
        
        NSString *imagePath = [pathPhoto stringByAppendingString:[NSString stringWithFormat:@"%@.png",name]];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(i*viewW,0, viewW,viewH)];
        imageView.userInteractionEnabled = YES;
        UIImage *image = [UIImage imageNamed:imagePath];
        
        if (image == nil)
        {
            NSLog(@"加载 图片失败 %@",imagePath);
            return;
        }
        
        //
        imageView.image = image;
        [_guideView addSubview:imageView];
        
        //最后一张图片 加上btn
        if (i == pages-1)
        {
            UIButton* button  = [UIButton buttonWithType:UIButtonTypeCustom];
            button.frame = CGRectMake(25., viewH*4./5., viewW-50., 50.);
            button.backgroundColor = [UIColor colorWithRed:45/255.f green:168/255.f blue:225/255.f alpha:1];
            [button setTitle:NSLocalizedString(@"立即使用",nil) forState:UIControlStateNormal];
            [button addTarget:self action:@selector(startUseApp) forControlEvents:UIControlEventTouchUpInside];//UIControlEventTouchUpInside
            [imageView addSubview:button];
            [self.viewController.view addSubview:_guideView];
        }
    }
}

- (void)loadImageArray:(NSArray*)imageArray
{
    for (NSDictionary *dic in imageArray)
    {
        NSString *imageName = [NSString stringWithFormat:@"%@",[dic objectForKey:@"imageName"]];
        NSString *imageUrl = [NSString stringWithFormat:@"%@",[dic objectForKey:@"imageUrl"]];
        NSString *path = [NSString stringWithFormat:@"%@/",[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
        
        [self downLoadImage:imageUrl name:imageName path:path];
    }
}

@end






#pragma mark  网络获取接口
@implementation HttpResponse

+ (void)postRequestWithPath:(NSString *)path
                  paramters:(NSDictionary *)paramters
               finshedBlock:(FinishBlock)finshblock
                 errorBlock:(ErrorBlock)errorblock
{
    HttpResponse *httpRequest = [[HttpResponse alloc]init];
    httpRequest.finishBlock = finshblock;
    httpRequest.errorBlock = errorblock;
    
    
    NSString *urlStr = [@"" stringByAppendingString:path];
    NSString *urlStradd = [urlStr stringByAppendingString:[HttpResponse parseParams:paramters]];
    NSLog(@"%@",urlStradd);
    
    NSURL *url = [NSURL URLWithString:[urlStradd stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSMutableURLRequest *requset = [[NSMutableURLRequest alloc]initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30];
    
    
    [requset setHTTPMethod:@"POST"];
    [requset setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [requset setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    
    NSURLConnection *connection = [[NSURLConnection alloc]initWithRequest:requset delegate:httpRequest];
    [connection start];
    NSLog(connection ? @"连接创建成功" : @"连接创建失败");
    
    
    //    NSString *urlString = @"https://www.baidu.com/img/bdlogo.png";
}


/**
 *  接收到服务器回应的时回调
 */
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (!self.resultData)
    {
        self.resultData = [[NSMutableData alloc]init];
    }
    else
    {
        [self.resultData setLength:0];
    }
    
    if ([response respondsToSelector:@selector(allHeaderFields)]) {
        NSDictionary *dic = [httpResponse allHeaderFields];
        NSLog(@"[network]allHeaderFields:%@",[dic description]);
    }
}


/**
 *  接收到服务器传输数据的时候调用，此方法根据数据大小执行若干次
 */
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.resultData appendData:data];
}


/**
 *  数据传完之后调用此方法
 */
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (self.resultData != nil)
    {
        if (self.finishBlock)
            self.finishBlock(self.resultData);
    }
    else
    {
        if (self.errorBlock)
            self.errorBlock(@"resultData = nil ");
    }
}


/**
 *  网络请求过程中，出现任何错误（断网，连接超时等）会进入此方法
 */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"network error : %@", [error localizedDescription]);
    
    if (self.errorBlock)
    {
        self.errorBlock([error localizedDescription]);
    }
}

//拼接参数
+ (NSString *)parseParams:(NSDictionary *)params
{
    NSString *keyValueFormat;
    NSMutableString *result = [[NSMutableString alloc] init];
    //实例化一个key枚举器用来存放dictionary的key
    NSEnumerator *keyEnum = [params keyEnumerator];
    id key;
    while (key = [keyEnum nextObject])
    {
        keyValueFormat = [NSString stringWithFormat:@"%@=%@&",key,[params valueForKey:key]];
        [result appendString:keyValueFormat];
        //NSLog(@"post()方法参数解析结果：%@",result);
    }
    return result;
}

@end






