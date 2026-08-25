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

// Stage 1: launch advertisement only. Keep AdvertisService's original startup
// and data initialization intact; only report that no ad should be displayed.
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
    RABLog(@"AdvertisService getAdShowFlag -> NO");
    return NO;
}
- (BOOL)checkHaveADDisplay {
    RABLog(@"AdvertisService checkHaveADDisplay -> NO");
    return NO;
}
%end

// Suppress only the final presentation of a launch ad. SDK/service setup is
// allowed to complete, avoiding the nil state caused by the previous build.
%hook BonSplashAD
- (void)showBgView { RABLog(@"blocked BonSplashAD showBgView"); }
- (void)addAdView { RABLog(@"blocked BonSplashAD addAdView"); }
- (void)addLaunchView { RABLog(@"blocked BonSplashAD addLaunchView"); }
- (void)addNoCNLaunchView { RABLog(@"blocked BonSplashAD addNoCNLaunchView"); }
- (void)backToFrontshowAd { RABLog(@"blocked BonSplashAD backToFrontshowAd"); }
- (BOOL)isNeedAgain {
    RABLog(@"BonSplashAD isNeedAgain -> NO");
    return NO;
}
%end

%ctor {
    @autoreleasepool {
        RABLog(@"loaded stage=1 bundle=%@ executable=%@ home=%@", NSBundle.mainBundle.bundleIdentifier,
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
