# Changelog

## [0.2.0](https://github.com/capawesome-team/cordova-live-update/compare/v0.1.2...v0.2.0) (2026-11-24)


### ⚠ BREAKING CHANGES

* `sync()` and `fetchLatestBundle()` now reject when the update check fails, for example when the device is offline or the server answers with an error status. Before, a failed check resolved without an update.

### Features

* use the new update check and report failed updates ([#11](https://github.com/capawesome-team/cordova-live-update/issues/11)) ([29053bd](https://github.com/capawesome-team/cordova-live-update/commit/29053bdd4ed6995595644b594b2bd6c5b0e11a69))


### Bug Fixes

* resolve without an update when the update check is answered with status 503 ([#13](https://github.com/capawesome-team/cordova-live-update/issues/13)) ([078535b](https://github.com/capawesome-team/cordova-live-update/commit/078535bb427b36fafa026acb1e6a7177f723fb26))

## [0.1.2](https://github.com/capawesome-team/cordova-live-update/compare/v0.1.1...v0.1.2) (2026-11-19)


### Bug Fixes

* delete temporary download files after the bundle was added or the download failed ([#10](https://github.com/capawesome-team/cordova-live-update/issues/10)) ([2f755ca](https://github.com/capawesome-team/cordova-live-update/commit/2f755ca5b002e71c0cfdc41430c5ab8cf1e705c9))
* **ios:** validate HTTP status, ignore `URLCache` and overwrite leftover files ([#8](https://github.com/capawesome-team/cordova-live-update/issues/8)) ([35d8d37](https://github.com/capawesome-team/cordova-live-update/commit/35d8d3737b7e88b6815c8c2259a114240214ee8b))

## [0.1.1](https://github.com/capawesome-team/cordova-live-update/compare/v0.1.0...v0.1.1) (2026-11-12)


### Features

* **ios:** support Swift Package Manager ([#5](https://github.com/capawesome-team/cordova-live-update/issues/5)) ([66d80d8](https://github.com/capawesome-team/cordova-live-update/commit/66d80d8b5f4871d24a6848f52a07e89e71aac629))

## 0.1.0 (2026-06-02)


### Features

* initial implementation ([#1](https://github.com/capawesome-team/cordova-live-update/issues/1)) ([4077db1](https://github.com/capawesome-team/cordova-live-update/commit/4077db1b767400f43894d81327b93708109fcebb))
