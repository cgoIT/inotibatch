# Changelog

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
