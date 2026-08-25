# 12306 Ad Block

## v1.1.4 scoped page rules

This build does not replace Objective-C methods. It hides only banner item views
inside `MTBookTicketHomeTopADView`, without changing the surrounding layout, and
injects a precise `.order-recommend-advertisement-wrap` rule into order-page web
views. The log is written inside the app data container at
`Library/Caches/Rails12306AdBlock.log`.

The home banner itself is collapsed without touching its parent wrapper. The
order rule also targets the statically confirmed `OrderAD` component located
after `.added-services-contain`, covering runtime builds that no longer expose
the older advertisement class name.

The travel-services miniapp was identified as preset app `60000002`. Its
confirmed `G0008` top-ad wrapper (`.top-ad-class`) and the horizontal
recommendation banner (`.train-mall`) immediately above “精彩旅程 尽在12306”
are removed. After the native home banner is collapsed, the table's initial
scroll offset is normalized once so the ticket form stays below the navigation
bar; normal scrolling is not continuously overridden.

Launch ads are handled at the UIKit window boundary. After `UIWindow` performs
its original `addSubview:`, only a descendant whose exact runtime class is
`UIAdBgView` is hidden. The tweak does not replace any `AdvertisService` or
`BonSplashAD` implementation and does not skip their initialization lifecycle.

A focused tweak for Railway 12306 5.9.6 (`cn.12306.rails12306`) that removes:

- the launch-page advertisement;
- the native advertisement at the top of the home page;
- the `OrderAD` advertisement at the bottom of the order page;
- the two confirmed advertisement banners on the travel-services page.

It injects only into Railway 12306 and never injects into SpringBoard. The
web rules target only confirmed advertisement wrappers; order, payment, and
normal service elements are not blocked.

The implementation was informed by static analysis of a user-supplied,
decrypted Railway 12306 5.9.6 IPA. The IPA and extracted files are not included.

## Build targets

- rootfull
- rootless (including Dopamine)
- roothide
