import Foundation
import RxSwift
import RxCocoa

public final class CocoaAction<Sender>: NSObject {
    /// The selector for message senders.
    public static var selector: Selector {
        return #selector(CocoaAction<Sender>.execute(_:))
    }

    /// Whether the action is enabled.
    ///
    /// This property will only change on the main thread.
    public let isEnabled: Driver<Bool>

    /// Whether the action is executing.
    ///
    /// This property will only change on the main thread.
    public let isExecuting: Driver<Bool>

    private var _execute: ((Sender) -> Void)! = nil
    private let disposeBag: DisposeBag

    /// Initialize a CocoaAction that invokes the given Action by mapping the
    /// sender to the input type of the Action.
    ///
    /// - parameters:
    ///   - action: The Action.
    ///   - inputTransform: A closure that maps Sender to the input type of the
    ///                     Action.
    public init<Input, Output>(_ action: Action<Input, Output>, _ inputTransform: @escaping (Sender) -> Input) {
        self.disposeBag = DisposeBag()
        isEnabled = action.isEnabled.asDriver(onErrorJustReturn: true)
        isExecuting = action.isExecuting.asDriver(onErrorJustReturn: false)

        super.init()

        _execute = { [unowned self] sender in
            let producer = action.apply(inputTransform(sender))
            producer.subscribe().disposed(by: self.disposeBag)
        }
    }

    /// Initialize a CocoaAction that invokes the given Action.
    ///
    /// - parameters:
    ///   - action: The Action.
    public convenience init<Output>(_ action: Action<(), Output>) {
        self.init(action, { _ in })
    }

    /// Initialize a CocoaAction that invokes the given Action with the given
    /// constant.
    ///
    /// - parameters:
    ///   - action: The Action.
    ///   - input: The constant value as the input to the action.
    public convenience init<Input, Output>(_ action: Action<Input, Output>, input: Input) {
        self.init(action, { _ in input })
    }

    /// Attempt to execute the underlying action with the given input, subject
    /// to the behavior described by the initializer that was used.
    ///
    /// - parameters:
    ///   - sender: The sender which initiates the attempt.
    @IBAction public func execute(_ sender: Any) {
        _execute(sender as! Sender)
    }
}
