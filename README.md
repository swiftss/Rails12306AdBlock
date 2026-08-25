# 12306 Ad Block

## v1.0.4 injection-only diagnostic baseline

This build has no app-class hooks and no notification observers. It only writes
one line when the tweak is loaded, so it intentionally does not remove ads. The
log is written inside the app data container at
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
