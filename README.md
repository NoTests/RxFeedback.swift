# RxFeedback

[![Travis CI](https://travis-ci.org/NoTests/RxFeedback.swift.svg?branch=master)](https://travis-ci.org/NoTests/RxFeedback.swift) ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20-333333.svg) ![pod](https://img.shields.io/cocoapods/v/RxFeedback.svg) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

[20min video pitch](https://academy.realm.io/posts/try-swift-nyc-2017-krunoslav-zaher-modern-rxswift-architectures/)

The simplest architecture for [RxSwift](https://github.com/ReactiveX/RxSwift)

<img src="https://github.com/kzaher/rxswiftcontent/raw/master/RxFeedback.png" width="502px" />

```swift
    typealias Feedback<State, Event> = (Observable<State>) -> Observable<Event>

    public static func system<State, Event>(
            initialState: State,
            reduce: @escaping (State, Event) -> State,
            feedback: Feedback<State, Event>...
        ) -> Observable<State>
```

# Why

* Straightforward
    * if it's state -> State
    * if it's a way to modify state -> Event/Command
    * it it's an effect -> encode it into part of state and then design a feedback loop
* Declarative
    * System behavior is first declaratively specified and effects begin after subscribe is called => Compile time proof there are no "unhandled states"
* Debugging is easier
    * A lot of logic is just normal pure function that can be debugged using Xcode debugger, or just printing the commands.

* Can be applied on any level
    * [Entire system](https://kafka.apache.org/documentation/)
    * application (state is stored inside a database, CoreData, Firebase, Realm)
    * view controller (state is stored inside `system` operator)
    * inside feedback loop (another `system` operator inside feedback loop)
* Works awesome with dependency injection
* Testing
    * Reducer is a pure function, just call it and assert results
    * In case effects are being tested -> TestScheduler
* Can model circular dependencies
* Completely separates business logic from effects (Rx).
    * Business logic can be transpiled between platforms (ShiftJS, C++, J2ObjC)

# Examples

## Simple UI Feedback loop

```swift
Observable.system(
    initialState: 0,
    reduce: { (state, event) -> State in
            switch event {
            case .increment:
                return state + 1
            case .decrement:
                return state - 1
            }
        },
    scheduler: MainScheduler.instance,
    scheduledFeedback:
        // UI is user feedback
        bind { state in
            ([
                state.map(String.init).bind(to: label.rx.text)
            ], [
                plus.rx.tap.map { Event.increment },
                minus.rx.tap.map { Event.decrement }
            ])
        }
    )
```

<img src="https://github.com/kzaher/rxswiftcontent/raw/master/Counter.gif" width="320px" />

## Play Catch

Simple automatic feedback loop.

```swift
Observable.system(
    initialState: State.humanHasIt,
    reduce: { (state: State, event: Event) -> State in
        switch event {
            case .throwToMachine:
                return .machineHasIt
            case .throwToHuman:
                return .humanHasIt
            }
        },
    scheduler: MainScheduler.instance,
    scheduledFeedback:
        // UI is human feedback
        bindUI,
        // NoUI, machine feedback
        react(query: { $0.machinePitching }, effects: { () -> Observable<Event> in
            return Observable<Int>
                .timer(1.0, scheduler: MainScheduler.instance)
                .map { _ in Event.throwToHuman }
        })
)

```

<img src="https://github.com/kzaher/rxswiftcontent/raw/master/PlayCatch.gif" width="320px" />

## Paging

```swift
Driver.system(
    initialState: State.empty,
    reduce: State.reduce,
    feedback:
        // UI, user feedback
        bindUI,
        // NoUI, automatic feedback
        react(query: { $0.loadNextPage }, effects: { resource in
            return URLSession.shared.loadRepositories(resource: resource)
                .asDriver(onErrorJustReturn: .failure(.offline))
                .map(Event.response)
        })
    )
```

Run `RxFeedback.xcodeproj` > `Example` to find out more.

# Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate RxFeedback into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'RxFeedback', '~> 1.0'
```

Then, run the following command:

```bash
$ pod install
```
### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate RxFeedback into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "NoTests/RxFeedback" ~> 1.0
```

Run `carthage update` to build the framework and drag the built `RxFeedback.framework` into your Xcode project. As `RxFeedback` depends on `RxSwift` and `RxCocoa` you need to drag the `RxSwift.framework` and `RxCocoa.framework` into your Xcode project as well.

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.

Once you have your Swift package set up, adding RxFeedback as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.


```swift
dependencies: [
    .package(url: "https://github.com/NoTests/RxFeedback.swift.git", majorVersion: 1)
]
```

# Difference from other architectures

* Elm - pretty close, feedback loops for effects instead of `Cmd`, which effects to perform are encoded into state and queried by feedback loops
* Redux - kind of like this, but feedback loops instead of middleware
* Redux-Observable - observables observe state vs. being inside middleware between view and state
* Cycle.js - no simple explanation :), ask [@andrestaltz](https://twitter.com/andrestaltz)
* MVVM - separates state from effects and doesn't require a view
