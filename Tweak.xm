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

static void RABInstallOrderRule(WKWebView *webView) {
    static NSString *script =
        @"(function(){"
         "if(window.__rails12306AdBlockInstalled){return 'present';}"
         "window.__rails12306AdBlockInstalled=true;"
         "function hideOrderAd(){"
           "var nodes=document.querySelectorAll('.order-recommend-advertisement-wrap');"
           "for(var i=0;i<nodes.length;i++){"
             "nodes[i].style.setProperty('display','none','important');"
             "nodes[i].style.setProperty('height','0','important');"
             "nodes[i].style.setProperty('min-height','0','important');"
             "nodes[i].style.setProperty('margin','0','important');"
             "nodes[i].style.setProperty('padding','0','important');"
           "}"
           "return nodes.length;"
         "}"
         "var count=hideOrderAd();"
         "var root=document.documentElement||document;"
         "new MutationObserver(hideOrderAd).observe(root,{childList:true,subtree:true});"
         "return 'installed:'+count;"
        "})()";
    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (!error && [result isKindOfClass:NSString.class] &&
            [(NSString *)result hasPrefix:@"installed:"]) {
            RABLog(@"order rule %@ url=%@", result, webView.URL.absoluteString ?: @"(no-url)");
        }
    }];
}

static void RABProcessView(UIView *view, BOOL insideTopAd) {
    if (!view) return;
    NSString *className = NSStringFromClass(view.class);
    BOOL nowInsideTopAd = insideTopAd || [className isEqualToString:@"MTBookTicketHomeTopADView"];

    // Hide only the confirmed banner item views. Do not modify their container,
    // wrapper, table, frame, or constraints; those also participate in ticket search.
    if (nowInsideTopAd && [className isEqualToString:@"MTBookTicketHomeADView"]) {
        view.hidden = YES;
        view.alpha = 0;
        view.userInteractionEnabled = NO;
        if (!RABLoggedHomeAd) {
            RABLoggedHomeAd = YES;
            RABLog(@"hidden home banner items only; layout preserved");
        }
    }

    if ([view isKindOfClass:WKWebView.class]) RABInstallOrderRule((WKWebView *)view);
    for (UIView *child in view.subviews) RABProcessView(child, nowInsideTopAd);
}

static void RABRunSafePass(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                RABProcessView(window, NO);
            }
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{ RABRunSafePass(); });
    });
}

%ctor {
    @autoreleasepool {
        RABLog(@"loaded stage=home-and-order-no-hooks bundle=%@ executable=%@ home=%@", NSBundle.mainBundle.bundleIdentifier,
            NSProcessInfo.processInfo.processName, NSHomeDirectory());
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{ RABRunSafePass(); });
    }
}
