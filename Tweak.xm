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

// Stage 0A: test one presentation-layer hook only. Do not alter behavior yet.
// AdvertisService is deliberately untouched because hooking its startup path
// caused the app to terminate during launch on Dopamine/iOS 17.
%hook BonSplashAD
- (void)addNoCNLaunchView {
    RABLog(@"BonSplashAD addNoCNLaunchView enter");
    %orig;
    RABLog(@"BonSplashAD addNoCNLaunchView returned");
}
%end

%ctor {
    @autoreleasepool {
        RABLog(@"loaded stage=0A-single-bonsplash-hook bundle=%@ executable=%@ home=%@", NSBundle.mainBundle.bundleIdentifier,
            NSProcessInfo.processInfo.processName, NSHomeDirectory());
    }
}
