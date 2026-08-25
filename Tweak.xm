#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

static NSString *RABLogPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/Rails12306AdBlock.log"];
}

static void RABLog(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", NSDate.date, message];
    NSLog(@"[Rails12306AdBlock] %@", message);
    @synchronized(NSFileHandle.class) {
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        NSString *path = RABLogPath();
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!handle) {
            [data writeToFile:path atomically:YES];
        } else {
            [handle seekToEndOfFile];
            [handle writeData:data];
            [handle closeFile];
        }
    }
}

static BOOL RABLoggedLaunchAd = NO;

static BOOL RABHideLaunchContainer(UIView *view) {
    if (!view) return NO;
    BOOL found = NO;
    if ([NSStringFromClass(view.class) isEqualToString:@"UIAdBgView"]) {
        view.hidden = YES;
        view.alpha = 0;
        view.userInteractionEnabled = NO;
        found = YES;
        if (!RABLoggedLaunchAd) {
            RABLoggedLaunchAd = YES;
            RABLog(@"hidden launch container UIAdBgView frame=%@", NSStringFromCGRect(view.frame));
        }
    }
    for (UIView *child in view.subviews) {
        if (RABHideLaunchContainer(child)) found = YES;
    }
    return found;
}

// Keep the complete launch-ad lifecycle intact and hide only its final UIKit
// container after it has been attached to a window. No 12306 private method is
// replaced, avoiding the launch crashes seen with AdvertisService/BonSplashAD.
%hook UIWindow
- (void)addSubview:(UIView *)view {
    %orig;
    RABHideLaunchContainer(view);
}
%end

static void RABInstallWebRules(WKWebView *webView) {
    static NSString *script =
        @"(function(){"
         "if(window.__rails12306AdBlockV3Installed){return 'present';}"
         "window.__rails12306AdBlockV3Installed=true;"
         "function hideAds(){"
           "var nodes=document.querySelectorAll('.order-recommend-advertisement-wrap,#app>.added-services-contain~*,.top-ad-class,.train-mall');"
           "for(var i=0;i<nodes.length;i++){"
             "nodes[i].style.setProperty('display','none','important');"
             "nodes[i].style.setProperty('height','0','important');"
             "nodes[i].style.setProperty('min-height','0','important');"
             "nodes[i].style.setProperty('margin','0','important');"
             "nodes[i].style.setProperty('padding','0','important');"
           "}"
           "return nodes.length;"
         "}"
         "var count=hideAds();"
         "var root=document.documentElement||document;"
         "new MutationObserver(hideAds).observe(root,{childList:true,subtree:true});"
         "return 'installed:'+count;"
        "})()";
    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (!error && [result isKindOfClass:NSString.class] &&
            [(NSString *)result hasPrefix:@"installed:"]) {
            RABLog(@"web ad rules %@ url=%@", result, webView.URL.absoluteString ?: @"(no-url)");
        }
    }];
}

static void RABProcessView(UIView *view) {
    if (!view) return;
    if ([view isKindOfClass:WKWebView.class]) RABInstallWebRules((WKWebView *)view);
    for (UIView *child in view.subviews) RABProcessView(child);
}

static void RABRunSafePass(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                RABHideLaunchContainer(window);
                RABProcessView(window);
            }
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{ RABRunSafePass(); });
    });
}

%ctor {
    @autoreleasepool {
        RABLog(@"loaded stage=window-launch-hide bundle=%@ executable=%@ home=%@", NSBundle.mainBundle.bundleIdentifier,
            NSProcessInfo.processInfo.processName, NSHomeDirectory());
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{ RABRunSafePass(); });
    }
}
