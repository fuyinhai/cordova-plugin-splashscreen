<!--
# license: Licensed to the Apache Software Foundation (ASF) under one
#         or more contributor license agreements.  See the NOTICE file
#         distributed with this work for additional information
#         regarding copyright ownership.  The ASF licenses this file
#         to you under the Apache License, Version 2.0 (the
#         "License"); you may not use this file except in compliance
#         with the License.  You may obtain a copy of the License at
#
#           http://www.apache.org/licenses/LICENSE-2.0
#
#         Unless required by applicable law or agreed to in writing,
#         software distributed under the License is distributed on an
#         "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#         KIND, either express or implied.  See the License for the
#         specific language governing permissions and limitations
#         under the License.
-->

# cordova-plugin-splashscreen

[![Build Status](https://travis-ci.org/apache/cordova-plugin-splashscreen.svg)](https://travis-ci.org/apache/cordova-plugin-splashscreen)

This plugin displays and hides a splash screen during application launch.

## Installation 

    // npm hosted (new) id
    cordova plugin add cordova-plugin-splashscreen
    // you may also install directly from this repo
    cordova plugin add https://github.com/apache/cordova-plugin-splashscreen.git

## Supported Platforms

- Amazon Fire OS
- Android
- BlackBerry 10
- iOS
- Windows Phone 7 and 8
- Windows 8
- Windows
- Browser


## Methods

- splashscreen.show
- splashscreen.hide

### Android Quirks

In your `config.xml`, you need to add the following preferences:

    <preference name="SplashScreen" value="foo" />
    <preference name="SplashScreenDelay" value="10000" />
    <preference name="SplashMaintainAspectRatio" value="true|false" />

Where foo is the name of the splashscreen file, preferably a 9 patch file. Make sure to add your splashcreen files to your res/xml directory under the appropriate folders. The second parameter represents how long the splashscreen will appear in milliseconds. It defaults to 3000 ms. See [Icons and Splash Screens](http://cordova.apache.org/docs/en/edge/config_ref_images.md.html)
for more information.

"SplashMaintainAspectRatio" preference is optional. If set to true, splash screen drawable is not stretched to fit screen, but instead simply "covers" the screen, like CSS "background-size:cover". This is very useful when splash screen images cannot be distorted in any way, for example when they contain scenery or text. This setting works best with images that have large margins (safe areas) that can be safely cropped on screens with different aspect ratios.

The plugin reloads splash drawable whenever orientation changes, so you can specify different drawables for portrait and landscape orientations.

### Browser Quirks

You can use the following preferences in your `config.xml`:

    <platform name="browser">
        <preference name="SplashScreen" value="images/browser/splashscreen.jpg" /> <!-- defaults to "img/logo.png" -->
        <preference name="SplashScreenDelay" value="10000" /> <!-- defaults to "3000" -->
        <preference name="SplashScreenBackgroundColor" value="green" /> <!-- defaults to "#464646" -->
        <preference name="ShowSplashScreen" value="false" /> <!-- defaults to "true" -->
        <preference name="SplashScreenWidth" value="600" /> <!-- defaults to "170" -->
        <preference name="SplashScreenHeight" value="300" /> <!-- defaults to "200" -->
    </platform>


### iOS Quirks

- `FadeSplashScreen` (boolean, defaults to `true`): Set to `false` to
  prevent the splash screen from fading in and out when its display
  state changes.

        <preference name="FadeSplashScreen" value="false"/>

- `FadeSplashScreenDuration` (float, defaults to `2`): Specifies the
  number of seconds for the splash screen fade effect to execute.

        <preference name="FadeSplashScreenDuration" value="4"/>

- `ShowSplashScreenSpinner` (boolean, defaults to `true`): Set to `false`
  to hide the splash-screen spinner.

        <preference name="ShowSplashScreenSpinner" value="false"/>

## splashscreen.hide

Dismiss the splash screen.

    navigator.splashscreen.hide();


### BlackBerry 10, WP8, iOS Quirk

The `config.xml` file's `AutoHideSplashScreen` setting must be
`false`. To delay hiding the splash screen for two seconds, add a
timer such as the following in the `deviceready` event handler:

        setTimeout(function() {
            navigator.splashscreen.hide();
        }, 2000);

## splashscreen.show

Displays the splash screen.

    navigator.splashscreen.show();


Your application cannot call `navigator.splashscreen.show()` until the app has
started and the `deviceready` event has fired. But since typically the splash
screen is meant to be visible before your app has started, that would seem to
defeat the purpose of the splash screen.  Providing some configuration in
`config.xml` will automatically `show` the splash screen immediately after your
app launch and before it has fully started and received the `deviceready`
event. See [Icons and Splash Screens](http://cordova.apache.org/docs/en/edge/config_ref_images.md.html)
for more information on doing this configuration. For this reason, it is
unlikely you need to call `navigator.splashscreen.show()` to make the splash
screen visible for app startup.






##  默认引导页数目和域名配置 参数
```
	<preference name="GUIDE_DEF_NUM"/>
    <preference name="CONFIG_URL"/>
    
```



## 动态加载 引导页和配置 加载页的 配置文件
```
            1). 启动页与引导页配置文件存放位置及命名
                项目目录/public/guide_config.txt

            2). guide_config.txt 内容说明
                {
                    "我是注释":"splashVersion启动页版本号，发布时默认为0，有更换需求时递增；guideVersion引导页版本号，发布时默认为0，有更换需求时递增；guideNum引导页页数，对应修改为新引导页页数；guideShowVersion引导页是否显示版本号，发布时默认为0，有需要显示新引导页时递增；",
                    "splashVersion":0,
                    "guideVersion":0,
                    "guideShowVersion":0,
                    "guideNum":0
                }
                splashVersion启动页版本号，有更换需求时递增；
                guideVersion引导页版本号，有更换需求时递增；
                guideNum引导页页数，对应修改为新引导页页数；
                guideShowVersion引导页是否显示版本号，有需要显示新引导页时递增；
                注：1). 修改引导页时，记得同时修改引导页页数;
                    2). 。
```
##加载页 动态配置的 图片命名规则 默认 meteor默认配置一致。

```
例：	   Default-667h.png
		Default-736h.png
		Default-568h@2x~iphone.png
		Default@2x~iphone.png
		Default~iphone.png
	
	存放路径为：项目目录/public/splash/ 
```


## 默认引导页 配置

```
	因为无法在meteor工程中直接配置默认引导页的图片，故需要在打包app时执行如下操作：
	1，把 cordova-plugin-splashscreen/src/ios/GuideImage 整个目录拖入到Xcode工程Resource目录下。
	2，如需更换为自己项目图片，命名规则需和该目录下图片命名规则一致。




    android端启动页图片存放位置及命名规则：
    项目目录/public/splash/splash.png

    android端启动页图片存放位置及命名规则：
    项目目录/public/guides/guide_1.png
    项目目录/public/guides/guide_2.png
    项目目录/public/guides/guide_3.png
    启动页多张时，图片名字后缀数字递增。

    
```



