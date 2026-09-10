# Third-party notices

iosClaw’s original code is licensed under the Apache License 2.0. The optional developer QA material under `qa-vendor/` is sourced from upstream projects and is not required for the Mac-only product path.

## WebDriverAgent

`qa-vendor/WebDriverAgent/` includes the upstream WebDriverAgent source and its accompanying BSD license. Preserve [`qa-vendor/WebDriverAgent/LICENSE`](qa-vendor/WebDriverAgent/LICENSE) when redistributing or modifying that material.

## Appium and the XCUITest driver

The optional Node fixtures reference Appium 3 and `appium-xcuitest-driver`. Their package metadata declares Apache-2.0 licensing. Dependency licenses and notices are distributed by npm packages and must be preserved when those packages are installed or bundled.

## Apple components

Xcode, the iOS Simulator, iPhone Mirroring, macOS frameworks, Apple SDKs, and Apple trademarks are provided by Apple under Apple’s applicable terms. iosClaw does not redistribute those components.

When adding a dependency, record its source, version, and license here or in the relevant package manifest, and do not commit generated dependency directories.
