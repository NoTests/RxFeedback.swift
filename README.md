# RxFeedback

[![Travis CI](https://travis-ci.org/kzaher/RxFeedback.svg?branch=master)](https://travis-ci.org/kzaher/RxFeedback) ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20-333333.svg) ![pod](https://img.shields.io/cocoapods/v/RxFeedback.svg) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

The simplest architecture for [RxSwift](https://github.com/ReactiveX/RxSwift)

<img src="https://github.com/kzaher/rxswiftcontent/raw/master/RxFeedback.png" width="502px" />

# Why

* Simple
    * If the system doesn't have state -> congrats, you have either a pure function or an observable sequence
    * It the system does have state, here we are :)
    * Interaction with that state is by definition a feedback loop.
    * =>  It's just state + CQRS
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
    feedback:
        // UI is user feedback
        UI.bind { state in
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
    feedback:
        // UI is user feedback
        UI.bind { state in (
            [
                state.map { $0.myStateOfMind }.bind(to: myLabel.rx.text),
                state.map { $0.machineStateOfMind }.bind(to: machinesLabel.rx.text),
                state.map { !$0.doIHaveTheBall }.bind(to: throwTheBallButton.rx.isHidden),
            ], [
                throwTheBallButton.rx.tap.map { Event.throwToMachine }
            ]
        )},
        // NoUI, machine feedback
        react(query: { $0.machinePitching }, effects: pitchBall)
    )

let pitchBall =  { () -> Observable<Event> in
    return Observable<Int>
            .timer(1.0, scheduler: MainScheduler.instance)
            .map { _ in Event.throwToHuman }
}

```

<img src="https://github.com/kzaher/rxswiftcontent/raw/master/PlayCatch.gif" width="320px" />

## Paging

```swift
Driver.system(
    initialState: State.empty,
    reduce: State.reduce,
    feedback:
        // UI, user feedback
        UI.bind { state in (
            [
                state.map { $0.search }.drive(searchText.rx.text),
                state.map { $0.lastError?.displayMessage }.drive(status.rx.textOrHide),
                state.map { $0.results }.drive(searchResults.rx.items(cellIdentifier: "repo"))(configureRepository),

                state.map { $0.loadNextPage?.description }.drive(loadNextPageLabel.rx.textOrHide),
            ], [
                searchText.rx.text.orEmpty.changed.asDriver().map(Event.searchChanged),
                triggerLoadNextPage(state)
            ]
        ) },
        // NoUI, automatic feedback
        react(query: { $0.loadNextPage }, effects: loadNextPage)
    )

func loadNextPage(_ resource: URL) -> Driver<Event> {
    return URLSession.shared.loadRepositories(resource: resource)
        .asDriver(onErrorJustReturn: .failure(.offline))
        .map(Event.response)
}
```

Run `RxFeedback.xcodeproj` > `Example` to find out more.

# Difference from other architectures

* Elm - pretty close, feedback loops for effects instead of `Cmd`, which effects to perform are encoded into state and querried by feedback loops
* Redux - kind of like this, but feedback loops instead of middleware
* Redux-Observable - observables observe state vs. being inside middleware between view and state
* Cycle.js - no simple explanation :), ask @andrestaltz
* MVVM - separates state from effects and doesn't require a view
