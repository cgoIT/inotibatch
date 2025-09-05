# Changelog

## [1.4.5](https://github.com/cgoIT/inotibatch/compare/v1.4.4...v1.4.5) (2025-09-02)


### Bug Fixes

* correct usage of printf ([810cfb5](https://github.com/cgoIT/inotibatch/commit/810cfb5dadc5a6d1d2609b8c5433ee91d7f3ddd7))

## [1.4.4](https://github.com/cgoIT/inotibatch/compare/v1.4.3...v1.4.4) (2025-09-02)


### Bug Fixes

* add correct line breaks in processed log ([1e342bc](https://github.com/cgoIT/inotibatch/commit/1e342bc33e0392f378de98da958d99c053e88f37))

## [1.4.3](https://github.com/cgoIT/inotibatch/compare/v1.4.2...v1.4.3) (2025-08-25)


### Bug Fixes

* only print info about queued file if appropriate ([10ebb06](https://github.com/cgoIT/inotibatch/commit/10ebb0698b6ec981f2b9f42989c8242242a15876))

## [1.4.2](https://github.com/cgoIT/inotibatch/compare/v1.4.1...v1.4.2) (2025-08-25)


### Bug Fixes

* only start background batch processing if POST_HOOK_DIR is present ([3b87031](https://github.com/cgoIT/inotibatch/commit/3b87031d02a8a3c92217fd081de55d43cafeb35e))

## [1.4.1](https://github.com/cgoIT/inotibatch/compare/v1.4.0...v1.4.1) (2025-08-25)


### Bug Fixes

* only add files to post process batch file if POST_HOOK_DIR is set and not empty ([7990200](https://github.com/cgoIT/inotibatch/commit/7990200cdb9f983ec4c3c6db9f348f75ad82c6e7))
* only add files to post process batch file if POST_HOOK_DIR is set and not empty ([e3d506a](https://github.com/cgoIT/inotibatch/commit/e3d506ad512b006ab4794280eb89e76ed688ddb5))

## [1.4.0](https://github.com/cgoIT/inotibatch/compare/v1.3.16...v1.4.0) (2025-08-25)


### Features

* switch back to file descriptor based locking ([0cf0698](https://github.com/cgoIT/inotibatch/commit/0cf0698112d0c435be7d404dbfe0e94964eb42c5))
* switch to file-based locking ([eb448a0](https://github.com/cgoIT/inotibatch/commit/eb448a0610387ac3e87efd369c57da44a792feb8))


### Bug Fixes

* better debug logging for filename sanitizing ([f866a27](https://github.com/cgoIT/inotibatch/commit/f866a272094cae150531fb0167c67062c7357ea1))
* correctly set last flush time ([744ae74](https://github.com/cgoIT/inotibatch/commit/744ae74ca77e1961623f844d0eacf4c8b141a828))
* don't use subshells if not needed ([7b3280b](https://github.com/cgoIT/inotibatch/commit/7b3280bb1ef257c29d857cf79ec81047b0cde049))
* improve file handling for batch file ([98721db](https://github.com/cgoIT/inotibatch/commit/98721db4f304fec9416409fb59bbb6a57a108cc9))
* remove too much debug logging ([34b020b](https://github.com/cgoIT/inotibatch/commit/34b020b729a09ab9a93482a9ce48982271cdc308))
* typo in file ([1f17273](https://github.com/cgoIT/inotibatch/commit/1f17273a28b06facc6233bf278f572d06b233610))
* use spool dir instead of tmp for batch spool files ([c506ff2](https://github.com/cgoIT/inotibatch/commit/c506ff24530db80760f327f6c409b017aafb4b54))

## [1.3.16](https://github.com/cgoIT/inotibatch/compare/v1.3.15...v1.3.16) (2025-08-23)


### Bug Fixes

* correctly count batched files ([7d47741](https://github.com/cgoIT/inotibatch/commit/7d4774149fa26fe2954b9a2268269eafa0f1a465))

## [1.3.15](https://github.com/cgoIT/inotibatch/compare/v1.3.14...v1.3.15) (2025-08-23)


### Bug Fixes

* correctly count batched files ([54c5e89](https://github.com/cgoIT/inotibatch/commit/54c5e8950a22563021fac81d4e780af598cbdfdf))
* remember the last flush time in the script and don't get it from the timestamp of the batch file ([39c12b6](https://github.com/cgoIT/inotibatch/commit/39c12b65780bccd089bfd010de26c754ed945426))

## [1.3.14](https://github.com/cgoIT/inotibatch/compare/v1.3.13...v1.3.14) (2025-08-23)


### Bug Fixes

* ensure that batch size and idle timeout are present in background post processing ([3f78807](https://github.com/cgoIT/inotibatch/commit/3f78807c117ce80aa625ab5eb4d1aaa4fe5a456a))

## [1.3.13](https://github.com/cgoIT/inotibatch/compare/v1.3.12...v1.3.13) (2025-08-23)


### Bug Fixes

* add more logging ([2f254e0](https://github.com/cgoIT/inotibatch/commit/2f254e0fc38072e461192e94f39b91b757f058b5))

## [1.3.12](https://github.com/cgoIT/inotibatch/compare/v1.3.11...v1.3.12) (2025-08-23)


### Bug Fixes

* only run hooks if directory is set and not empty ([b2b85e3](https://github.com/cgoIT/inotibatch/commit/b2b85e33e509b33c75281bdf56de0ead395f5b4c))

## [1.3.11](https://github.com/cgoIT/inotibatch/compare/v1.3.10...v1.3.11) (2025-08-23)


### Bug Fixes

* only run hooks if directory is set and not empty ([7d8a7cd](https://github.com/cgoIT/inotibatch/commit/7d8a7cdf9371a63c3ffb0095a914097781da0c62))

## [1.3.10](https://github.com/cgoIT/inotibatch/compare/v1.3.9...v1.3.10) (2025-08-23)


### Bug Fixes

* update template scripts ([fcd479e](https://github.com/cgoIT/inotibatch/commit/fcd479e754b5fcf88920bb92f0e822c4f31cc7f4))

## [1.3.9](https://github.com/cgoIT/inotibatch/compare/v1.3.8...v1.3.9) (2025-08-23)


### Bug Fixes

* change comment in generated scripts ([4edfbb6](https://github.com/cgoIT/inotibatch/commit/4edfbb629ec81de0be0a976f18330277000d4bb3))
* **docs:** add documentation about available env variables and functions for man pages ([913d772](https://github.com/cgoIT/inotibatch/commit/913d7726e49fcb10ec9670e27f151ed6d59f2d93))
* make variable TARGET_OWNER optional ([c5d2675](https://github.com/cgoIT/inotibatch/commit/c5d2675c6a406f8d7a1eb38d53066c3018ab4883))

## [1.3.8](https://github.com/cgoIT/inotibatch/compare/v1.3.7...v1.3.8) (2025-08-17)


### Bug Fixes

* fix postrm, postinst, prerm scripts ([4061f3c](https://github.com/cgoIT/inotibatch/commit/4061f3c0e7469bff8e96334e7ae198eb9a947157))

## [1.3.7](https://github.com/cgoIT/inotibatch/compare/v1.3.6...v1.3.7) (2025-08-17)


### Bug Fixes

* check multiple possible directories for service template file ([dc94876](https://github.com/cgoIT/inotibatch/commit/dc9487680f804d34f9a995e9fc4be766cfb457b6))

## [1.3.6](https://github.com/cgoIT/inotibatch/compare/v1.3.5...v1.3.6) (2025-08-17)


### Bug Fixes

* remove duplicate directories from deb ([86da5fe](https://github.com/cgoIT/inotibatch/commit/86da5fe140722ff351f34648706ce1b04584f7e9))

## [1.3.5](https://github.com/cgoIT/inotibatch/compare/v1.3.4...v1.3.5) (2025-08-16)


### Bug Fixes

* fix postinst file ([9f06814](https://github.com/cgoIT/inotibatch/commit/9f068140c73a03d492d73aa93a3da37d13e892fd))

## [1.3.4](https://github.com/cgoIT/inotibatch/compare/v1.3.3...v1.3.4) (2025-08-16)


### Bug Fixes

* fix postinst file ([d077ef7](https://github.com/cgoIT/inotibatch/commit/d077ef75fb203a454a93950cfd82d7b0e60c1cd6))

## [1.3.3](https://github.com/cgoIT/inotibatch/compare/v1.3.2...v1.3.3) (2025-08-16)


### Bug Fixes

* add codename and sources to ppa ([73eacbd](https://github.com/cgoIT/inotibatch/commit/73eacbdf45d6e7a6da143f0da5e83dd6af0cf221))
* make architecture configurable ([51aea3d](https://github.com/cgoIT/inotibatch/commit/51aea3de1ff5fe453652cc2963caa0ac47c79a5d))

## [1.3.2](https://github.com/cgoIT/inotibatch/compare/v1.3.1...v1.3.2) (2025-08-16)


### Bug Fixes

* add correct path to actions and hooks in example conf ([7b625a3](https://github.com/cgoIT/inotibatch/commit/7b625a36d1b015c0da7c29b5a5277d3a3cf64200))
* correctly generate Release and InRelease files ([caebf64](https://github.com/cgoIT/inotibatch/commit/caebf6421ab4f666cba6a9de1790a98f60e6e811))

## [1.3.1](https://github.com/cgoIT/inotibatch/compare/v1.3.0...v1.3.1) (2025-08-16)


### Bug Fixes

* fix upload to release step ([bc4f74b](https://github.com/cgoIT/inotibatch/commit/bc4f74b6852107128f623e88da406c35cfde046a))

## [1.3.0](https://github.com/cgoIT/inotibatch/compare/v1.2.4...v1.3.0) (2025-08-16)


### Features

* optimize build script to use standard debuild process ([56ab46c](https://github.com/cgoIT/inotibatch/commit/56ab46ca3aa9d5e2d201715d354c8b8cc29af2ec))
* use some more standards for logrotate and systemd ([c252b9d](https://github.com/cgoIT/inotibatch/commit/c252b9d83fdd04c75b244beeb6e08342b6e7e687))


### Bug Fixes

* fix pipeline to detect local runs with act ([6542e1e](https://github.com/cgoIT/inotibatch/commit/6542e1e25739b9a5bd52dbc81813f803b3be53fe))

## [1.2.4](https://github.com/cgoIT/inotibatch/compare/v1.2.3...v1.2.4) (2025-08-13)


### Bug Fixes

* correctly copy the debian scripts to DEBIAN/ ([609a5a2](https://github.com/cgoIT/inotibatch/commit/609a5a28c5c47c0240c0242a8f9efbc224b359f6))

## [1.2.3](https://github.com/cgoIT/inotibatch/compare/v1.2.2...v1.2.3) (2025-08-13)


### Bug Fixes

* **build:** install changelog to the right place ([02df1e2](https://github.com/cgoIT/inotibatch/commit/02df1e24e8d50ab65b95295d4ccd79b1615aa1de))

## [1.2.2](https://github.com/cgoIT/inotibatch/compare/v1.2.1...v1.2.2) (2025-08-12)


### Bug Fixes

* better logging for restarted services ([0572686](https://github.com/cgoIT/inotibatch/commit/05726861520f6055f936a5caa316d9b1a1cfba97))
* use restart instead of start in postinst ([65121d1](https://github.com/cgoIT/inotibatch/commit/65121d1e1048fd35ee373fba33ee35ae77e39c70))

## [1.2.1](https://github.com/cgoIT/inotibatch/compare/v1.2.0...v1.2.1) (2025-08-12)


### Bug Fixes

* move state file for running services to tmp directory ([0c44d26](https://github.com/cgoIT/inotibatch/commit/0c44d269318cfadc0aed07355b1aa00f80281d6a))

## [1.2.0](https://github.com/cgoIT/inotibatch/compare/v1.1.0...v1.2.0) (2025-08-12)


### Features

* restart previously running services after upgrade ([7857f93](https://github.com/cgoIT/inotibatch/commit/7857f9372ef0f4b3c4606740aace2e366cf34e23))


### Bug Fixes

* correctly handle events in inotibatch ([65b2b16](https://github.com/cgoIT/inotibatch/commit/65b2b1618af75d1a72443bfb1fdcd873eb160343))

## [1.1.0](https://github.com/cgoIT/inotibatch/compare/v1.0.0...v1.1.0) (2025-08-12)


### Features

* add event name to log event while processing a file ([e5308a2](https://github.com/cgoIT/inotibatch/commit/e5308a256b3d611d1fa311d9583faae3e6878452))


### Bug Fixes

* better format the status display ([7145018](https://github.com/cgoIT/inotibatch/commit/7145018d9741206327e82c8806a07d29b55d008b))

## 1.0.0 (2025-08-12)


### Features

* first implementation of inotibatch ([111b5bd](https://github.com/cgoIT/inotibatch/commit/111b5bd3e5f7799fcfc82f50ee160c12411bde78))
