# RxActions

[![Travis (.org)](https://img.shields.io/travis/rhysforyou/RxActions.svg?style=flat-square)](https://travis-ci.org/rhysforyou/RxActions) [![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://github.com/rhysforyou/RxActions/blob/master/LICENSE) ![Carthage Compatible](https://img.shields.io/badge/carthage-compatible-blue.svg?style=flat-square) ![Swift Package Manager Compatible](https://img.shields.io/badge/swiftpm-compatible-blue.svg?style=flat-square)

This framework can be used on top of [RxSwift](https://github.com/ReactiveX/RxSwift) to provide a new _Action_ primitive. An action will perform some work when given an _input_, producing an `Observable` which will generate zero or more values before either completing or terminating in an error.

Actions are useful for performing side-effects in UI programming, and can be conditionally enabled and disabled based on the value of a [`BehaviorRelay`](). This enabled status can be used to, for example, disable a `UIButton`.

## Installation

This library can be installed using either [Carthage](https://github.com/Carthage/Carthatge) or the [Swift Package Manager](https://swift.org/package-manager/)

### Carthage

Add the following line to your `Cartfile`:

```
github "rhysforyou/RxAction"
```

### Swift Package Manager

Add a new package to your _Package.swift_ file's `dependencies` section, and then add _RxActions_ as a dependency of your target.

```swift
let package = Package(
    // ...
    dependencies: [
        .package(url: "https://github.com/rhysforyou/RxActions.git", "4.0.0" ..< "5.0.0"),
        // ...
    ],
    targets: [
        .target(
            name: "MyTarget",
            dependencies: ["RxActions"]),
        // ...
    ]
)
```

## Usage

_Coming soon…_
