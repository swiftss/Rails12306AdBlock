#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

static NSString *const RABOrderCSS =
    @"(function(){"
     "var id='rails12306-adblock-style';"
     "if(!document.getElementById(id)){"
       "var s=document.createElement('style');s.id=id;"
       "s.textContent='.order-recommend-advertisement-wrap{display:none!important;height:0!important;min-height:0!important;margin:0!important;padding:0!important}';"
       "(document.head||document.documentElement).appendChild(s);"
     "}"
     "document.querySelectorAll('.order-recommend-advertisement-wrap').forEach(function(e){e.remove();});"
     "if(!window.__rails12306AdObserver){"
       "window.__rails12306AdObserver=new MutationObserver(function(){"
         "document.querySelectorAll('.order-recommend-advertisement-wrap').forEach(function(e){e.remove();});"
       "});"
       "window.__rails12306AdObserver.observe(document.documentElement,{childList:true,subtree:true});"
     "}"
    "})();";

static void RABInjectOrderCSS(WKWebView *webView) {
    if (!webView) return;
    for (NSNumber *delay in @[@0.1, @0.6, @1.5]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [webView evaluateJavaScript:RABOrderCSS completionHandler:nil];
        });
    }
}

static void RABHideView(UIView *view) {
    view.hidden = YES;
    view.alpha = 0.0;
    view.userInteractionEnabled = NO;
    CGRect frame = view.frame;
    frame.size.height = 0.0;
    view.frame = frame;
}

// The app's advertising coordinator. Disabling start prevents self-hosted,
// BeiZi, and MeiShu launch-ad paths without touching normal app startup.
%hook AdvertisService
- (void)start {}
- (void)getAdInfo {}
- (void)pageStartLoad {}
- (void)pageBecomeActive {}
- (BOOL)getAdShowFlag { return NO; }
- (BOOL)checkHaveADDisplay { return NO; }
%end

// Defensive hooks in case another component creates the splash manager.
%hook BonSplashAD
- (void)showBgView {}
- (void)addAdView {}
- (void)addLaunchView {}
- (void)addNoCNLaunchView {}
- (void)showBtnSkip {}
- (void)backToFrontshowAd {}
- (BOOL)isNeedAgain { return NO; }
- (BOOL)isADShowing { return NO; }
- (BOOL)isSplashShowing { return NO; }
%end

// Native ad carousel at the top of the ticket-booking home page.
%hook MTBookTicketHomeTopADView
- (instancetype)initWithFrame:(CGRect)frame animationScrollDuration:(CGFloat)duration {
    frame.size.height = 0.0;
    id result = %orig(frame, duration);
    RABHideView(result);
    return result;
}
- (void)didMoveToSuperview {
    %orig;
    RABHideView((UIView *)self);
}
- (CGSize)intrinsicContentSize { return CGSizeZero; }
- (void)setFrame:(CGRect)frame {
    frame.size.height = 0.0;
    %orig(frame);
}
- (void)reloadAdsData {}
- (void)loadMaterialsList:(id)list withArriveStationCode:(id)code voiceOverStatus:(BOOL)status {}
%end

%hook MTBookTicketHomeMgrView
- (void)adInfo {}
- (void)updateHomePageADWithData:(id)data {}
- (void)reloadADSource {}
%end

%hook MTBookTicketViewController
- (void)updateHomePageADData:(id)data {}
%end

// The order page is Nebula micro-app 60000003. Hide only its OrderAD node;
// ticket details, payment, and the normal additional-services section remain.
%hook WKWebView
- (void)didMoveToWindow {
    %orig;
    RABInjectOrderCSS(self);
}
- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    WKNavigation *navigation = %orig;
    RABInjectOrderCSS(self);
    return navigation;
}
- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL {
    WKNavigation *navigation = %orig;
    RABInjectOrderCSS(self);
    return navigation;
}
- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    WKNavigation *navigation = %orig;
    RABInjectOrderCSS(self);
    return navigation;
}
%end
