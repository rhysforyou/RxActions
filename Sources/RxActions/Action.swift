import RxSwift
import RxCocoa

/// `Action` represents a repeatable work like `SignalProducer`. But on top of the
/// isolation of produced `Signal`s from a `SignalProducer`, `Action` provides
/// higher-order features like availability and mutual exclusion.
///
/// Similar to a produced `Signal` from a `SignalProducer`, each unit of the repreatable
/// work may output zero or more values, and terminate with or without an error at some
/// point.
///
/// The core of `Action` is the `execute` closure it created with. For every execution
/// attempt with a varying input, if the `Action` is enabled, it would request from the
/// `execute` closure a customized unit of work — represented by a `SignalProducer`.
/// Specifically, the `execute` closure would be supplied with the latest state of
/// `Action` and the external input from `apply()`.
///
/// `Action` enforces serial execution, and disables the `Action` during the execution.
public final class Action<Input, Output> {
    private struct ActionState<Value> {
        var isEnabled: Bool {
            return isUserEnabled && !isExecuting
        }

        var isUserEnabled: Bool
        var isExecuting: Bool
        var value: Value
    }

    private var execute: ((Action<Input, Output>, Input) -> Observable<Output>)! = nil
    private let eventsSubject: PublishSubject<Event<Output>>
    private let disabledErrorsSubject: PublishSubject<()>
    private let isExecutingRelay: BehaviorRelay<Bool>
    private let isEnabledRelay: BehaviorRelay<Bool>

    private let disposeBag: DisposeBag

    /// A signal of all events generated from all units of work of the `Action`.
    ///
    /// In other words, this sends every `Event` from every unit of work that the `Action`
    /// executes.
    public var events: Observable<Event<Output>> {
        return eventsSubject.asObservable()
    }

    /// A signal of all values generated from all units of work of the `Action`.
    ///
    /// In other words, this sends every value from every unit of work that the `Action`
    /// executes.
    public var values: Observable<Output> {
        return events.flatMap { Observable.from(optional: $0.element) }
    }

    /// A signal of all errors generated from all units of work of the `Action`.
    ///
    /// In other words, this sends every error from every unit of work that the `Action`
    /// executes.
    public var errors: Observable<Error> {
        return events.flatMap { Observable.from(optional: $0.error) }
    }

    /// A signal of all completed events generated from applications of the action.
    ///
    /// In other words, this will send completed events from every signal generated
    /// by each SignalProducer returned from apply().
    public var completed: Observable<()> {
        return events.flatMap { Observable.from(optional: $0.isCompleted ? () : nil) }
    }

    /// A signal of all failed attempts to start a unit of work of the `Action`.
    public var disabledErrors: Observable<()> {
        return disabledErrorsSubject.asObservable()
    }

    /// Whether the action is currently executing.
    public var isExecuting: Observable<Bool> {
        return isExecutingRelay.asObservable()
    }

    /// Whether the action is currently enabled.
    public var isEnabled: Observable<Bool> {
        return isEnabledRelay.asObservable()
    }

    /// Initializes an `Action` that would be conditionally enabled depending on its
    /// state.
    ///
    /// When the `Action` is asked to start the execution with an input value, a unit of
    /// work — represented by a `SignalProducer` — would be created by invoking
    /// `execute` with the latest state and the input value.
    ///
    /// - note: `Action` guarantees that changes to `state` are observed in a
    ///         thread-safe way. Thus, the value passed to `isEnabled` will
    ///         always be identical to the value passed to `execute`, for each
    ///         application of the action.
    ///
    /// - note: This initializer should only be used if you need to provide
    ///         custom input can also influence whether the action is enabled.
    ///         The various convenience initializers should cover most use cases.
    ///
    /// - parameters:
    ///   - state: A property to be the state of the `Action`.
    ///   - isEnabled: A predicate which determines the availability of the `Action`,
    ///                given the latest `Action` state.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to be
    ///              executed by the `Action`.
    public init<State>(state: BehaviorRelay<State>, enabledIf isEnabled: @escaping (State) -> Bool, execute: @escaping (State, Input) -> Observable<Output>) {
        let isUserEnabled = isEnabled

        disposeBag = DisposeBag()

        // `Action` retains its state property.
        disposeBag.insert(Disposables.create {
            _ = state
        })

        eventsSubject = PublishSubject()
        disabledErrorsSubject = PublishSubject()

        let actionState = BehaviorRelay(value: ActionState(isUserEnabled: true, isExecuting: false, value: state.value))

        isExecutingRelay = BehaviorRelay(value: false)
        isEnabledRelay = BehaviorRelay(value: true)

        func modifyActionState<Result>(_ action: (inout ActionState<State>) throws -> Result) rethrows -> Result {
            let oldState = actionState.value
            var newState = oldState
            let result = try action(&newState)
            actionState.accept(newState)

            defer {
                if oldState.isEnabled != newState.isEnabled {
                    isEnabledRelay.accept(newState.isEnabled)
                }

                if oldState.isExecuting != newState.isExecuting {
                    isExecutingRelay.accept(newState.isExecuting)
                }
            }

            return result
        }

        state.asObservable()
            .subscribe(onNext: { value in
                modifyActionState { state in
                    state.value = value
                    state.isUserEnabled = isUserEnabled(value)
                }
            })
            .disposed(by: disposeBag)

        self.execute = { action, input
            in return Observable.create { observer in

                let latestState: State? = modifyActionState { state in
                    guard state.isEnabled else {
                        return nil
                    }

                    state.isExecuting = true
                    return state.value
                }

                guard let state = latestState else {
                    observer.onError(ActionError.disabled)
                    action.disabledErrorsSubject.onNext(())
                    return Disposables.create()
                }

                let interruptHandle = execute(state, input)
                    .subscribe { event in
                        switch event {
                        case .error(let error):
                            observer.onError(ActionError.executionFailed(error))
                        default:
                            observer.on(event)
                        }
                        action.eventsSubject.onNext(event)
                    }

                return Disposables.create {
                    interruptHandle.dispose()
                    modifyActionState { $0.isExecuting = false }
                }
            }
        }
    }


    /// Initializes an `Action` that uses a property as its state.
    ///
    /// When the `Action` is asked to start the execution, a unit of work — represented by
    /// a `SignalProducer` — would be created by invoking `execute` with the latest value
    /// of the state.
    ///
    /// - parameters:
    ///   - state: A property to be the state of the `Action`.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
    ///              be executed by the `Action`.
    public convenience init<State>(state: BehaviorRelay<State>, execute: @escaping (State, Input) -> Observable<Output>) {
        self.init(state: state, enabledIf: { _ in true }, execute: execute)
    }

    /// Initializes an `Action` that would be conditionally enabled.
    ///
    /// When the `Action` is asked to start the execution with an input value, a unit of
    /// work — represented by a `SignalProducer` — would be created by invoking
    /// `execute` with the input value.
    ///
    /// - parameters:
    ///   - isEnabled: A property which determines the availability of the `Action`.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to be
    ///              executed by the `Action`.
    public convenience init(enabledIf isEnabled: BehaviorRelay<Bool>, execute: @escaping (Input) -> Observable<Output>) {
        self.init(state: isEnabled, enabledIf: { $0 }) { _, input in
            execute(input)
        }
    }

    /// Initializes an `Action` that uses a property of optional as its state.
    ///
    /// When the `Action` is asked to start executing, a unit of work (represented by
    /// a `SignalProducer`) is created by invoking `execute` with the latest value
    /// of the state and the `input` that was passed to `apply()`.
    ///
    /// If the property holds a `nil`, the `Action` would be disabled until it is not
    /// `nil`.
    ///
    /// - parameters:
    ///   - state: A property of optional to be the state of the `Action`.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
    ///              be executed by the `Action`.
    public convenience init<State>(unwrapping state: BehaviorRelay<State?>, execute: @escaping (State, Input) -> Observable<Output>) {
        self.init(state: state, enabledIf: { $0 != nil }) { state, input in
            execute(state!, input)
        }
    }

    /// Initializes an `Action` that would always be enabled.
    ///
    /// When the `Action` is asked to start the execution with an input value, a unit of
    /// work — represented by a `SignalProducer` — would be created by invoking
    /// `execute` with the input value.
    ///
    /// - parameters:
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to be
    ///              executed by the `Action`.
    public convenience init(execute: @escaping (Input) -> Observable<Output>) {
        self.init(enabledIf: BehaviorRelay(value: true), execute: execute)
    }

    /// Create a `SignalProducer` that would attempt to create and start a unit of work of
    /// the `Action`. The `SignalProducer` would forward only events generated by the unit
    /// of work it created.
    ///
    /// If the execution attempt is failed, the producer would fail with
    /// `ActionError.disabled`.
    ///
    /// - parameters:
    ///   - input: A value to be used to create the unit of work.
    ///
    /// - returns: A producer that forwards events generated by its started unit of work,
    ///            or emits `ActionError.disabled` if the execution attempt is failed.
    public func apply(_ input: Input) -> Observable<Output> {
        return execute(self, input)
    }

    deinit {
        eventsSubject.onCompleted()
        disabledErrorsSubject.onCompleted()
    }
}

extension Action where Input == Void {
    /// Create a `SignalProducer` that would attempt to create and start a unit of work of
    /// the `Action`. The `SignalProducer` would forward only events generated by the unit
    /// of work it created.
    ///
    /// If the execution attempt is failed, the producer would fail with
    /// `ActionError.disabled`.
    ///
    /// - returns: A producer that forwards events generated by its started unit of work,
    ///            or emits `ActionError.disabled` if the execution attempt is failed.
    public func apply() -> Observable<Output> {
        return apply(())
    }

    /// Initializes an `Action` that uses a property of optional as its state.
    ///
    /// When the `Action` is asked to start the execution, a unit of work — represented by
    /// a `SignalProducer` — would be created by invoking `execute` with the latest value
    /// of the state.
    ///
    /// If the property holds a `nil`, the `Action` would be disabled until it is not
    /// `nil`.
    ///
    /// - parameters:
    ///   - state: A property of optional to be the state of the `Action`.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
    ///              be executed by the `Action`.
    public convenience init<State>(unwrapping state: BehaviorRelay<State?>, execute: @escaping (State) -> Observable<Output>) {
        self.init(unwrapping: state) { state, _ in
            execute(state)
        }
    }

    /// Initializes an `Action` that uses a property as its state.
    ///
    /// When the `Action` is asked to start the execution, a unit of work — represented by
    /// a `SignalProducer` — would be created by invoking `execute` with the latest value
    /// of the state.
    ///
    /// - parameters:
    ///   - state: A property to be the state of the `Action`.
    ///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
    ///              be executed by the `Action`.
    public convenience init<State>(state: BehaviorRelay<State>, execute: @escaping (State) -> Observable<Output>) {
        self.init(state: state) { state, _ in
            execute(state)
        }
    }
}
