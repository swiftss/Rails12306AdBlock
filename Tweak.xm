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

static BOOL RABInterestingView(UIView *view, NSString **detail) {
    NSString *className = NSStringFromClass(view.class);
    NSString *lowerName = className.lowercaseString;
    if ([lowerName containsString:@"splash"] || [lowerName containsString:@"advert"] ||
        [lowerName hasSuffix:@"adview"] || [lowerName containsString:@"skip"]) {
        *detail = className;
        return YES;
    }
    if ([view isKindOfClass:UILabel.class]) {
        NSString *text = ((UILabel *)view).text ?: @"";
        if ([text containsString:@"跳过"] || [text containsString:@"广告"]) {
            *detail = [NSString stringWithFormat:@"%@ text=%@", className, text];
            return YES;
        }
    }
    if ([view isKindOfClass:UIButton.class]) {
        NSString *title = [(UIButton *)view titleForState:UIControlStateNormal] ?: @"";
        if ([title containsString:@"跳过"] || [title containsString:@"广告"]) {
            *detail = [NSString stringWithFormat:@"%@ title=%@", className, title];
            return YES;
        }
    }
    return NO;
}

static void RABScanView(UIView *view, NSUInteger depth) {
    if (!view || depth > 40) return;
    NSString *detail = nil;
    if (RABInterestingView(view, &detail)) {
        NSMutableArray<NSString *> *parents = [NSMutableArray array];
        UIView *parent = view.superview;
        for (NSUInteger index = 0; parent && index < 4; index++, parent = parent.superview) {
            [parents addObject:NSStringFromClass(parent.class)];
        }
        RABLog(@"candidate=%@ frame=%@ hidden=%d alpha=%.2f parents=%@", detail,
            NSStringFromCGRect(view.frame), view.hidden, view.alpha,
            [parents componentsJoinedByString:@" <- "]);
    }
    for (UIView *child in view.subviews) RABScanView(child, depth + 1);
}

static void RABRunScan(NSUInteger pass) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray<UIWindow *> *windows = UIApplication.sharedApplication.windows;
        RABLog(@"ui-scan pass=%lu windows=%lu", (unsigned long)pass, (unsigned long)windows.count);
        for (UIWindow *window in windows) RABScanView(window, 0);
        if (pass < 12) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{ RABRunScan(pass + 1); });
        }
    });
}

%ctor {
    @autoreleasepool {
        RABLog(@"loaded stage=0B-ui-scan-no-hooks bundle=%@ executable=%@ home=%@", NSBundle.mainBundle.bundleIdentifier,
            NSProcessInfo.processInfo.processName, NSHomeDirectory());
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{ RABRunScan(1); });
    }
}
