#if os(iOS)
import UIKit
import RxSwift
import RxCocoa

extension Reactive where Base: UIButton {
    public var pressed: CocoaAction<UIButton>? {
        get {
            var action: CocoaAction<UIButton>?
            action = objc_getAssociatedObject(base, &AssociatedKeys.action) as? CocoaAction<UIButton>
            return action
        }
        set {
            objc_setAssociatedObject(base, &AssociatedKeys.action, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            base.resetActionDisposeBag()

            if let action = newValue {
                action.isEnabled
                    .drive(base.rx.isEnabled)
                    .disposed(by: base.actionDisposeBag)

                self.tap
                    .subscribe(onNext: { [unowned base] _ in action.execute(base) })
                    .disposed(by: base.actionDisposeBag)
            }
        }
    }
}
#endif
