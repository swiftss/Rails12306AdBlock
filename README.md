# 12306 Ad Block

## v1.1.2 home gap and OrderAD test

This build does not replace Objective-C methods. It hides only banner item views
inside `MTBookTicketHomeTopADView`, without changing the surrounding layout, and
injects a precise `.order-recommend-advertisement-wrap` rule into order-page web
views. The log is written inside the app data container at
`Library/Caches/Rails12306AdBlock.log`.

The home banner itself is collapsed without touching its parent wrapper. The
order rule also targets the statically confirmed `OrderAD` component located
after `.added-services-contain`, covering runtime builds that no longer expose
the older advertisement class name.

A focused tweak for Railway 12306 5.9.6 (`cn.12306.rails12306`) that removes:

- the launch-page advertisement;
- the native advertisement at the top of the home page;
- the `OrderAD` advertisement at the bottom of the order page.

It injects only into Railway 12306 and never injects into SpringBoard. The
order-page rule targets only `.order-recommend-advertisement-wrap`; order,
payment, and normal service elements are not blocked.

The implementation was informed by static analysis of a user-supplied,
decrypted Railway 12306 5.9.6 IPA. The IPA and extracted files are not included.

## Build targets

- rootfull
- rootless (including Dopamine)
- roothide
