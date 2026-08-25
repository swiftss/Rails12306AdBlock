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

static void RABZeroHeightConstraints(UIView *view) {
    for (NSLayoutConstraint *constraint in view.constraints) {
        if (constraint.firstAttribute == NSLayoutAttributeHeight &&
            (constraint.firstItem == view || constraint.secondItem == view)) {
            constraint.constant = 0;
        }
    }
}

static void RABHideKnownHomeAd(UIView *view) {
    if (![NSStringFromClass(view.class) isEqualToString:@"MTBookTicketHomeTopADView"]) return;
    if (!view.hidden) RABLog(@"hide home-top-ad frame=%@", NSStringFromCGRect(view.frame));
    view.hidden = YES;
    view.alpha = 0;
    view.userInteractionEnabled = NO;
    CGRect frame = view.frame;
    frame.size.height = 0;
    view.frame = frame;
    RABZeroHeightConstraints(view);

    // The app places the ad in a plain wrapper directly under its table view.
    UIView *wrapper = view.superview;
    if (wrapper && [wrapper.superview isKindOfClass:UITableView.class]) {
        wrapper.hidden = YES;
        CGRect wrapperFrame = wrapper.frame;
        wrapperFrame.size.height = 0;
        wrapper.frame = wrapperFrame;
        RABZeroHeightConstraints(wrapper);
    }
}

static void RABScanView(UIView *view, NSUInteger depth) {
    if (!view || depth > 40) return;
    RABHideKnownHomeAd(view);
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
        NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
        RABLog(@"ui-scan pass=%lu windows=%lu", (unsigned long)pass, (unsigned long)windows.count);
        for (UIWindow *window in windows) RABScanView(window, 0);
        if (pass < 100) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{ RABRunScan(pass + 1); });
        }
    });
}

%ctor {
    @autoreleasepool {
        RABLog(@"loaded stage=1A-home-hide-fast-scan bundle=%@ executable=%@ home=%@", NSBundle.mainBundle.bundleIdentifier,
            NSProcessInfo.processInfo.processName, NSHomeDirectory());
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{ RABRunScan(1); });
    }
}
