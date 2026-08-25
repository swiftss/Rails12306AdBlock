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

static BOOL RABLoggedHomeAd = NO;
static BOOL RABLoggedLaunchAd = NO;
static BOOL RABNormalizedHomeOffset = NO;

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

static UITableView *RABAncestorTableView(UIView *view) {
    UIView *ancestor = view.superview;
    while (ancestor) {
        if ([ancestor isKindOfClass:UITableView.class]) return (UITableView *)ancestor;
        ancestor = ancestor.superview;
    }
    return nil;
}

static void RABProcessView(UIView *view, BOOL insideTopAd) {
    if (!view) return;
    NSString *className = NSStringFromClass(view.class);
    BOOL nowInsideTopAd = insideTopAd || [className isEqualToString:@"MTBookTicketHomeTopADView"];

    // Collapse only the confirmed banner view itself. Never alter its plain UIView
    // wrapper, UITableView, or constraints; doing so removed the ticket-search UI.
    if ([className isEqualToString:@"MTBookTicketHomeTopADView"]) {
        UITableView *tableView = RABAncestorTableView(view);
        view.hidden = YES;
        view.alpha = 0;
        view.userInteractionEnabled = NO;
        CGRect frame = view.frame;
        frame.size.height = 0;
        view.frame = frame;
        if (!RABNormalizedHomeOffset && tableView) {
            RABNormalizedHomeOffset = YES;
            [tableView layoutIfNeeded];
            CGFloat top = -tableView.adjustedContentInset.top;
            CGPoint oldOffset = tableView.contentOffset;
            if (oldOffset.y > top + 40.0) {
                [tableView setContentOffset:CGPointMake(oldOffset.x, top) animated:NO];
                RABLog(@"normalized home offset %.1f -> %.1f", oldOffset.y, top);
            }
        }
    }

    if (nowInsideTopAd && [className isEqualToString:@"MTBookTicketHomeADView"]) {
        view.hidden = YES;
        view.alpha = 0;
        view.userInteractionEnabled = NO;
        if (!RABLoggedHomeAd) {
            RABLoggedHomeAd = YES;
            RABLog(@"hidden home banner items only; layout preserved");
        }
    }

    if ([view isKindOfClass:WKWebView.class]) RABInstallWebRules((WKWebView *)view);
    for (UIView *child in view.subviews) RABProcessView(child, nowInsideTopAd);
}

static void RABRunSafePass(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                RABHideLaunchContainer(window);
                RABProcessView(window, NO);
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
