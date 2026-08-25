# 12306 Ad Block

## v1.0.7 hook-free UI scanner

This build does not replace any Objective-C method. During the first seconds of
launch it only scans the visible view hierarchy and records likely ad, splash,
and skip-button views. It intentionally does not remove ads. The log is written
inside the app data container at
`Library/Caches/Rails12306AdBlock.log`.

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
