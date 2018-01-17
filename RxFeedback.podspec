Pod::Spec.new do |s|
  s.name         = "RxFeedback"
  s.version      = "1.0.2"
  s.summary      = "Simplest architecture for RxSwift. State + feedback loops."
  s.description  = <<-DESC
    Simplest architecture for RxSwift. State + feedback loops.
    
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
  DESC
  s.homepage     = "https://github.com/NoTests/RxFeedback.swift"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Krunoslav Zaher" => "krunoslav.zaher@gmail.com" }
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/NoTests/RxFeedback.swift.git", :tag => s.version.to_s }
  s.source_files  = "Sources/**/*.swift"
  s.frameworks  = "Foundation"

  s.dependency 'RxSwift', '~> 4.0'
  s.dependency 'RxCocoa', '~> 4.0'
end