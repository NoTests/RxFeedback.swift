//
//  RxOAuthTests.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/9/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import Foundation
import XCTest
import RxFeedback
import RxOAuth
import RxSwift
import RxCocoa
import RxTest

class RxOAuthTests: XCTestCase {

}

// Let's use just a simple Int for tests
// Token value is clock value until token is valid
typealias OAuthToken = Int

extension RxOAuthTests {

    func testBasicRequest() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refereshTokenFatalError,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil
            
            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)
                    
                    scheduler.scheduleAt(210) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.success("Hi")
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300)))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 220, event: .success(OAuthResponse.success("Hi")))
                ])
        }
    }

    func testBasicRequest_Parallel() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refereshTokenFatalError,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(210) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.success("Hi")
                            ])
                    }

                    scheduler.scheduleAt(215) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.success("Hi2")
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300)))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 220, event: .success(OAuthResponse.success("Hi"))),
                Request(time: 225, event: .success(OAuthResponse.success("Hi2"))),
                ])
        }
    }

    func testBasicTokenExpired_ByDate_RefreshSucceeded() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenSuccess,
                shouldRefreshNow: { value in value < scheduler.clock })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.success("Hi")
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(500, .refreshing(Version(300))),
                next(503, .fresh(Version(700)))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .success(OAuthResponse.success("Hi")))
                ])
        }
    }
    
    func testBasicTokenExpired_RefreshSucceeded() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenSuccess,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            OAuthResponse<Payload>.success("Hi")
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(513, .fresh(Version(710)))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 523, event: .success(OAuthResponse.success("Hi")))
                ])
        }
    }

    func testBasicTokenExpired_RefreshSucceeded_WaitingForInFlightRequest() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenSuccess,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            OAuthResponse<Payload>.success("Hi")
                            ])
                    }

                    scheduler.scheduleAt(511) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.success("Hi2")
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(513, .fresh(Version(710)))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 523, event: .success(OAuthResponse.success("Hi"))),
                Request(time: 523, event: .success(OAuthResponse.success("Hi2"))),
                ])
        }
    }

    func testBasicTokenExpired_RefreshFailed_InvalidToken() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenInvalid,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(513, .tokenInvalidated(Version(300)))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .success(OAuthResponse.tokenInvalidated))
                ])
        }
    }

    func testBasicTokenExpired_RefreshFailed_InvalidToken_WaitingForInFlightRequest() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenInvalid,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    scheduler.scheduleAt(511) {
                        trace.request(responses: [
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(513, .tokenInvalidated(Version(300)))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .success(OAuthResponse.tokenInvalidated)),
                Request(time: 513, event: .success(OAuthResponse.tokenInvalidated)),
                ])
        }
    }

    func testBasicTokenExpired_RefreshFailed_InvalidToken_Parallel() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenInvalid,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    scheduler.scheduleAt(502) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(512, .refreshing(Version(300))),
                next(513, .tokenInvalidated(Version(300)))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .success(OAuthResponse.tokenInvalidated)),
                Request(time: 513, event: .success(OAuthResponse.tokenInvalidated)),
                ])
        }
    }

    func testBasicTokenExpired_RefreshFailed_InvalidToken_ThenNext() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenInvalid,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    scheduler.scheduleAt(600) {
                        trace.request(responses: [
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(513, .tokenInvalidated(Version(300)))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .success(OAuthResponse.tokenInvalidated)),
                Request(time: 600, event: .success(OAuthResponse.tokenInvalidated)),
                ])
        }
    }

    func testBasicTokenExpired_RefreshFailed_SomeUnimportantError() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenError,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(513, .refreshFailed(Version(300), lastError: SomeWeirdWhoCaresError.Idont))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .error(SomeWeirdWhoCaresError.Idont))
                ])
        }
    }

    func testBasicTokenExpired_RefreshFailed_SomeUnimportantError_WaitingForInFlightRequest() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenError,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    scheduler.scheduleAt(511) {
                        trace.request(responses: [
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(513, .refreshFailed(Version(300), lastError: SomeWeirdWhoCaresError.Idont)),
                next(513, .refreshing(Version(300))),
                next(516, .refreshFailed(Version(300), lastError: SomeWeirdWhoCaresError.Idont)),
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .error(SomeWeirdWhoCaresError.Idont)),
                Request(time: 516, event: .error(SomeWeirdWhoCaresError.Idont))
                ])
        }
    }
    
    func testBasicTokenExpired_RefreshFailed_SomeUnimportantError_ParallelRequests() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenError,
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    scheduler.scheduleAt(502) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }


                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(512, .refreshing(Version(300))),
                next(513, .refreshFailed(Version(300), lastError: SomeWeirdWhoCaresError.Idont)),
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .error(SomeWeirdWhoCaresError.Idont)),
                Request(time: 513, event: .error(SomeWeirdWhoCaresError.Idont))
                ])
        }
    }

    func testBasicTokenExpired_RefreshFailed_SomeUnimportantError_ThenSuccess() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenResponses([
                    .error(SomeWeirdWhoCaresError.Idont),
                    .success(.success(800))
                    ]),
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    scheduler.scheduleAt(600) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.success("Hi again")
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(513, .refreshFailed(Version(300), lastError: SomeWeirdWhoCaresError.Idont)),
                next(600, .refreshing(Version(300))),
                next(603, .fresh(Version(800)))
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .error(SomeWeirdWhoCaresError.Idont)),
                Request(time: 613, event: .success(.success("Hi again"))),
                ])
        }
    }

    func testBasicTokenExpired_RefreshFailed_SomeUnimportantError_UnimportantError() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenResponses([
                    .error(SomeWeirdWhoCaresError.Idont),
                    .error(SomeWeirdWhoCaresError.Idont),
                    ]),
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    scheduler.scheduleAt(600) {
                        trace.request(responses: [
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(513, .refreshFailed(Version(300), lastError: SomeWeirdWhoCaresError.Idont)),
                next(600, .refreshing(Version(300))),
                next(603, .refreshFailed(Version(300), lastError: SomeWeirdWhoCaresError.Idont)),
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .error(SomeWeirdWhoCaresError.Idont)),
                Request(time: 603, event: .error(SomeWeirdWhoCaresError.Idont)),
                ])
        }
    }

    func testBasicTokenExpired_RefreshFailed_SomeUnimportantError_InvalidatedToken() {
        let scheduler = TestScheduler(initialClock: 0, simulateProcessingDelay: false)

        driveOnScheduler(scheduler) {
            let tokenExecutor = OAuth.system(
                initialToken: 300,
                refreshToken: scheduler.refreshTokenResponses([
                    .error(SomeWeirdWhoCaresError.Idont),
                    .success(.tokenInvalidated)
                    ]),
                shouldRefreshNow: { _ in false })

            var trace: CommunicationTrace! = nil

            let res = scheduler.start { () -> Observable<TokenState<OAuthToken>> in
                tokenExecutor.asObservable().flatMap { executor -> Observable<TokenState<OAuthToken>> in

                    trace = CommunicationTrace(scheduler: scheduler, executor: executor)

                    scheduler.scheduleAt(500) {
                        trace.request(responses: [
                            OAuthResponse<Payload>.tokenInvalidated,
                            ])
                    }

                    scheduler.scheduleAt(600) {
                        trace.request(responses: [
                            ])
                    }

                    return executor.state.asObservable()
                }
            }

            XCTAssertEqual(res.events, [
                next(200, .fresh(Version(300))),
                next(510, .refreshing(Version(300))),
                next(513, .refreshFailed(Version(300), lastError: SomeWeirdWhoCaresError.Idont)),
                next(600, .refreshing(Version(300))),
                next(603, .tokenInvalidated(Version(300))),
                ])

            XCTAssertEqual(trace.requests, [
                Request(time: 513, event: .error(SomeWeirdWhoCaresError.Idont)),
                Request(time: 603, event: .success(.tokenInvalidated)),
                ])
        }
    }
}

extension TokenState: Equatable {
    public static func == (lhs: TokenState<Token>, rhs: TokenState<Token>) -> Bool {
        switch (lhs, rhs) {
        case let (.fresh(lhs), .fresh(rhs)):
            return lhs.value == rhs.value
        case (.fresh, _):
            return false
        case let (.refreshing(lhs), .refreshing(rhs)):
            return lhs.value == rhs.value
        case (.refreshing, _):
            return false
        case let (.refreshFailed(lhs, lError), .refreshFailed(rhs, rError)):
            return lhs.value == rhs.value && "\(lError)" == "\(rError)"
        case (.refreshFailed, _):
            return false
        case let (.tokenInvalidated(lhs), .tokenInvalidated(rhs)):
            return lhs.value == rhs.value
        case (.tokenInvalidated, _):
            return false
        }
    }
}

typealias Payload = String

extension Request: Equatable {
    public static func == (lhs: Request, rhs: Request) -> Bool {
        return "\(lhs)" == "\(rhs)"
    }
}

struct Request {
    let time: TestScheduler.VirtualTime
    let event: SingleEvent<OAuthResponse<Payload>>
}

class CommunicationTrace {
    let scheduler: TestScheduler
    let executor: OAuthExecutor<OAuthToken>
    var requests: [Request] = []

    init(scheduler: TestScheduler, executor: OAuthExecutor<OAuthToken>) {
        self.scheduler = scheduler
        self.executor = executor
    }

    func request(responses: [OAuthResponse<Payload>]) {
        var numberOfRequests = 0
        _ = Single.deferred { () -> Single<OAuthResponse<Payload>> in
                    return self.executor.authenticate(request: { token in token.flatMap { token in
                            defer { numberOfRequests += 1 }
                            if token < self.scheduler.clock {
                                guard case .tokenInvalidated = responses[numberOfRequests] else {
                                    fatalError("Token has expired, you have to return invalidated token")
                                }
                                return Single.just(OAuthResponse<Payload>.tokenInvalidated)
                            }
                            return Single.just(responses[numberOfRequests])
                        }.delay(10.0, scheduler: self.scheduler)
                    })
                }
                .subscribe { event in
                    let request = Request(
                        time: self.scheduler.clock,
                        event: event
                    )
                    if numberOfRequests != responses.count {
                        fatalError("Not all responses have been used")
                    }
                    self.requests.append(request)
                }
    }
}

enum SomeWeirdWhoCaresError: Error {
    case Idont
}

extension TestScheduler {
    func refereshTokenFatalError(token: OAuthToken) -> Single<OAuthResponse<OAuthToken>> {
        fatalError()
    }

    func refreshTokenSuccess(token: OAuthToken) -> Single<OAuthResponse<OAuthToken>> {
        return Single.deferred {
            return Single.just(OAuthResponse.success(self.clock + 200))
        }
        .delay(3.0, scheduler: self)
    }

    func refreshTokenInvalid(token: OAuthToken) -> Single<OAuthResponse<OAuthToken>> {
        return Single.deferred {
                return Single.just(OAuthResponse.tokenInvalidated)
            }
            .delay(3.0, scheduler: self)
    }

    func refreshTokenError(token: OAuthToken) -> Single<OAuthResponse<OAuthToken>> {
        return Single.deferred {
                return Single.error(SomeWeirdWhoCaresError.Idont)
            }
            .delaySubscription(3.0, scheduler: self)
    }

    func refreshTokenResponses(_ responses: [SingleEvent<OAuthResponse<OAuthToken>>]) -> (_ token: OAuthToken) -> Single<OAuthResponse<OAuthToken>> {
        var tried = 0
        return { token in
            return Single<OAuthResponse<OAuthToken>>.create { observer in
                defer { tried += 1 }
                observer(responses[tried])
                return Disposables.create()
            }
            .delaySubscription(3.0, scheduler: self)
        }
    }
}
