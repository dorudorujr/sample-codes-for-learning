//
//  ChangeNewWordViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/02/28.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import ReSwift
import ApplicationModel
import ApplicationConfig
import ApplicationLib

// g-005-3, l-003, l-004
final class ChangeNewWordViewController: UIViewController, EmailPasswordValidatable {
    
    @IBOutlet private weak var newWordLabel: UILabel!
    @IBOutlet private weak var fieldSuppordLabel: UILabel!
    @IBOutlet private weak var newPasswordField: UITextField!
    @IBOutlet private weak var confirmNewPasswordField: UITextField!
    
    private let disposeBag = DisposeBag()
    private let completeView = CompleteView()
    var loginFlow = false
    var changeTarget: String?
    var securityCode: String?
    var mailAddress: String?
    
    private let store = RxStore(store: Store<ChangeNewWordViewState>(reducer: ChangeNewWordViewReducer.handleAction, state: nil))
    
    private var requestCreator: ReSetUserSettingActionCreatable! {
        willSet {
            if requestCreator != nil {
                fatalError()
            }
        }
    }

    func inject(requestCreator: ReSetUserSettingActionCreatable) {
        self.requestCreator = requestCreator
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if loginFlow {
            sendTrackingScreen(name: GoogleAnalyticsScreen.changePasswordSendConfirmFromLosgin)
        } else {
            sendTrackingScreen(name: GoogleAnalyticsScreen.changePasswordSendConfirm)
        }
        
        setValidation(of: newPasswordField)
        setValidation(of: confirmNewPasswordField)
        
        setupCompleteView(completeView: completeView, disposedBag: disposeBag)
        completeView.text = L10n.l004ChangePasswordCompletedMessage

        if loginFlow {
            navigationBarSetup(titleText: L10n.l001ChangePasswordSendConfirmMailTitle, fontSize: 14)
        } else {
            navigationBarSetup(titleText: changeTarget! + L10n.l001ChangePasswordConfirmChange, fontSize: 14)
        }
        
        if ChangeTarget.mailAddress == changeTarget {
            newPasswordField.textContentType = .emailAddress
        }
        
        newWordLabel.text = L10n.l003ChangePasswordConfirmNew + changeTarget! + L10n.l003ChangePasswordConfirmInputFor
        fieldSuppordLabel.text = L10n.l003ChangePasswordConfirmNew + changeTarget!
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.l003ChangePasswordChange, style: .plain, target: nil, action: nil)
        navigationItem.rightBarButtonItem?.isEnabled = false
        navigationController?.navigationBar.addShadow()
        
        keyboardHideViewUp(disposeBag: disposeBag)
        bind()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.rightBarButtonItem?.isEnabled = false
    }
    
    func setValidation(of: UITextField) {
        of.delegate = of
    }
    
    func bind() {
        
        Observable.combineLatest(newPasswordField.rx.text, confirmNewPasswordField.rx.text)
            .subscribe({ [weak self] in
                let newPassword = $0.element?.0?.isNotEmpty
                let confirmPassword = $0.element?.1?.isNotEmpty
                self?.navigationItem.rightBarButtonItem?.isEnabled = (newPassword! && confirmPassword!)
            })
            .disposed(by: disposeBag)
        
        store.isComplete
            .filter { $0 }
            .subscribe({ _ in
                self.completeView.fadein(animFinish: { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                        self.view.addSubview(self.completeView)
                        self.completeView.isHidden = true
                        self.navigationController?.popToRootViewController(animated: true)
                    })
                })
                
            })
            .disposed(by: disposeBag)
        
        navigationItem.rightBarButtonItem?.rx.tap
            .subscribe({ [unowned self] _ in
                self.view.endEditing(true)
                
                if let error = self.newPasswordField.text?.checkError(confirm: self.confirmNewPasswordField.text!) {
                    self.store.dispatch(ReSetPasswordErrorAction(error: error))
                    return
                }
                
                let param = ReSetPasswordParameter(mailAddress: (self.mailAddress)!, confirmationCode: self.securityCode, newPassword: self.newPasswordField.text!)
                
                self.store.dispatch((self.requestCreator.reSetPasswordPut(parameter: param, disposeBag: self.disposeBag)))
                KeyChainUtil.shared.set(key: KeyChainKey.password, value: self.newPasswordField.text!)
            })
            .disposed(by: disposeBag)
        
        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }
    
}

extension RxStore where AnyStateType == ChangeNewWordViewState {
    
    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }.distinctUntilChanged()
    }
    
    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }
    
    var isComplete: Observable<Bool> {
        return stateObservable.map { $0.isComplete }.distinctUntilChanged()
    }
    
}
