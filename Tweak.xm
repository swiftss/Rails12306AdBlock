#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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

// Stage 0 baseline: observe the launch-ad path without changing any behavior.
// Every hook calls and returns the original implementation.
%hook AdvertisService
- (void)start {
    RABLog(@"AdvertisService start -> original");
    %orig;
}
- (void)initialize:(id)value {
    RABLog(@"AdvertisService initialize -> original");
    %orig;
}
- (void)dataSuccess:(id)data {
    RABLog(@"AdvertisService dataSuccess -> original");
    %orig;
}
- (BOOL)getAdShowFlag {
    BOOL result = %orig;
    RABLog(@"AdvertisService getAdShowFlag -> original=%d", result);
    return result;
}
- (BOOL)checkHaveADDisplay {
    BOOL result = %orig;
    RABLog(@"AdvertisService checkHaveADDisplay -> original=%d", result);
    return result;
}
%end

%hook BonSplashAD
- (void)showBgView { RABLog(@"BonSplashAD showBgView -> original"); %orig; }
- (void)addAdView { RABLog(@"BonSplashAD addAdView -> original"); %orig; }
- (void)addLaunchView { RABLog(@"BonSplashAD addLaunchView -> original"); %orig; }
- (void)addNoCNLaunchView { RABLog(@"BonSplashAD addNoCNLaunchView -> original"); %orig; }
- (void)backToFrontshowAd { RABLog(@"BonSplashAD backToFrontshowAd -> original"); %orig; }
- (BOOL)isNeedAgain {
    BOOL result = %orig;
    RABLog(@"BonSplashAD isNeedAgain -> original=%d", result);
    return result;
}
%end

%ctor {
    @autoreleasepool {
        RABLog(@"loaded stage=0-baseline bundle=%@ executable=%@ home=%@", NSBundle.mainBundle.bundleIdentifier,
            NSProcessInfo.processInfo.processName, NSHomeDirectory());
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                RABLog(@"UIApplicationDidFinishLaunching");
            }];
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                RABLog(@"UIApplicationDidBecomeActive");
            }];
    }
}
