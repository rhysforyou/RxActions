//
//  ActionSpec.swift
//  WoolyTests
//
//  Created by Rhys Powell on 3/9/18.
//  Copyright © 2018 Rhys Powell. All rights reserved.
//

import Foundation
import Quick
import Nimble
import RxSwift
import RxCocoa
import RxBlocking
import RxTest
import RxActions

class ActionSpec: QuickSpec {
    override func spec() {
        describe("Action") {
            var action: Action<Int, String>!
            var enabled: BehaviorRelay<Bool>!
            var disposeBag: DisposeBag!

            var executionCount = 0
            var completedCount = 0
            var values: [String] = []
            var errors: [NSError] = []

            var scheduler: TestScheduler!
            let testError = NSError(domain: "ActionSpec", code: 1, userInfo: nil)

            beforeEach {
                executionCount = 0
                completedCount = 0
                values = []
                errors = []
                enabled = BehaviorRelay(value: false)
                disposeBag = DisposeBag()

                scheduler = TestScheduler(initialClock: 0)
                action = Action(enabledIf: enabled) { number in
                    return Observable.create { observer in
                        executionCount += 1

                        if number % 2 == 0 {
                            observer.onNext("\(number)")
                            observer.onNext("\(number)\(number)")
                            scheduler.scheduleAt(1, action: {
                                observer.onCompleted()
                            })
                        } else {
                            scheduler.scheduleAt(1, action: {
                                observer.onError(testError)
                            })
                        }

                        return Disposables.create()
                    }
                }

                action.values.subscribe(onNext: { values.append($0) }).disposed(by: disposeBag)
                action.errors.subscribe(onNext: { errors.append($0 as NSError) }).disposed(by: disposeBag)
                action.completed.subscribe(onNext: { _ in completedCount += 1 }).disposed(by: disposeBag)
            }

            it("should be disabled and not executing after initialization") {
                expect(try? action.isEnabled.toBlocking().first()) == false
                expect(try? action.isExecuting.toBlocking().first()) == false
            }

            it("should error if executed while disabled") {
                var receivedError: ActionError?
                var disabledErrorsTriggered = false

                action.disabledErrors.subscribe(onNext: { _ in
                    disabledErrorsTriggered = true
                }).disposed(by: disposeBag)

                action.isEnabled
                    .subscribe()
                    .disposed(by: disposeBag)

                action.apply(0)
                    .subscribe(onError: { receivedError = $0 as? ActionError })
                    .disposed(by: disposeBag)

                expect(receivedError).notTo(beNil())
                expect(disabledErrorsTriggered) == true
            }

            it("should enable and disable based on the given property") {
                enabled.accept(true)
                expect(try? action.isEnabled.toBlocking().first()) == true
                expect(try? action.isExecuting.toBlocking().first()) == false

                enabled.accept(false)
                expect(try? action.isEnabled.toBlocking().first()) == false
                expect(try? action.isExecuting.toBlocking().first()) == false
            }

            it("should not deadlock when its executing state affects its state property without constituting a feedback loop") {
                action.isExecuting
                    .map { !$0 }
                    .bind(to: enabled)
                    .disposed(by: disposeBag)

                expect(enabled.value) == true
                expect(try? action.isEnabled.toBlocking().first()) == true
                expect(try? action.isExecuting.toBlocking().first()) == false

                let disposable = action.apply(0).subscribe()
                expect(enabled.value) == false
                expect(try? action.isEnabled.toBlocking().first()) == false
                expect(try? action.isExecuting.toBlocking().first()) == true

                disposable.dispose()
                expect(enabled.value) == true
                expect(try? action.isEnabled.toBlocking().first()) == true
                expect(try? action.isExecuting.toBlocking().first()) == false
            }

            it("should not deadlock when its enabled state affects its state property without constituting a feedback loop") {
                // Emulate control binding: When a UITextField is the first responder and
                // is being disabled by an `Action`, the control events emitted might
                // feedback into the availability of the `Action` synchronously, e.g.
                // via a `MutableProperty` or `ValidatingProperty`.
                var isFirstResponder = false

                action.isEnabled
                    .filter { isActionEnabled in !isActionEnabled && isFirstResponder }
                    .map { _ in () }
                    .subscribe(onNext: { _ in enabled.accept(false) })
                    .disposed(by: disposeBag)

                enabled.accept(true)
                expect(enabled.value) == true
                expect(try? action.isEnabled.toBlocking().first()) == true
                expect(try? action.isExecuting.toBlocking().first()) == false

                isFirstResponder = true
                let disposable = action.apply(0).subscribe()
                expect(enabled.value) == false
                expect(try? action.isEnabled.toBlocking().first()) == false
                expect(try? action.isExecuting.toBlocking().first()) == true

                disposable.dispose()
                expect(enabled.value) == false
                expect(try? action.isEnabled.toBlocking().first()) == false
                expect(try? action.isExecuting.toBlocking().first()) == false

                enabled.accept(true)
                expect(enabled.value) == true
                expect(try? action.isEnabled.toBlocking().first()) == true
                expect(try? action.isExecuting.toBlocking().first()) == false
            }
        }
    }
}
