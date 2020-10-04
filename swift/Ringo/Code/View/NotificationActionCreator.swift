import Foundation
import RxSwift
import ReSwift

public protocol NotificationActionCreatable {
    func get(parameter: NotificationParameter, disposeBag: DisposeBag) -> Store<NotificationViewState>.AsyncActionCreator
    func put(parameter: ReadNotificationParameter, disposeBag: DisposeBag) -> Store<NotificationViewState>.AsyncActionCreator
}

public class NotificationActionCreator: NotificationActionCreatable {
    
    private var request: NotificationRequestable
    private var readRequest: ReadNotificationRequestable
    
    public init(request: NotificationRequestable, readRequest: ReadNotificationRequestable) {
        self.request = request
        self.readRequest = readRequest
    }

    public func get(parameter: NotificationParameter, disposeBag: DisposeBag) -> Store<NotificationViewState>.AsyncActionCreator {
        return { [weak self] (state, store, callback) in
            callback { _, _ in NotificationRequestAction() }
            self?.request.get(parameters: parameter)
                .subscribe( onSuccess: {
                    let action = NotificationAction(readNoticeId: $0.readNoticeId, noticeInfo: $0.noticeInfo)   //正常な処理のAction
                    callback { _, _ in action}
                },
                    onError: {
                        let action = NotificationErrorAction(error: $0) //エラーな処理のAction
                        callback { _, _ in action }
                })
                .disposed(by: disposeBag)
        }
    }
    
    public func put(parameter: ReadNotificationParameter, disposeBag: DisposeBag) -> Store<NotificationViewState>.AsyncActionCreator {
        return { [weak self] (state, store, callback) in
            callback { _, _ in ReadNotificationRequestAction(readNoticeId: parameter.readNoticeId) }
            self?.readRequest.put(parameters: parameter)
                .subscribe( onSuccess: { _ in
                    let action = ReadNotificationAction()
                    callback { _, _ in action}
                },
                onError: {
                    let action = NotificationErrorAction(error: $0)
                    callback { _, _ in action }
                })
                .disposed(by: disposeBag)
        }
    }
}