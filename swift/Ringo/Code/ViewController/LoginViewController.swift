//
//  LoginView.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/02/06.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa
import ReSwift
import ApplicationModel
import ApplicationConfig
import ApplicationLib
import SpriteKit

final class LoginViewController: UIViewController, EmailPasswordValidatable {
    
    @IBOutlet private weak var idLine: UILabel!
    @IBOutlet private weak var passwordLine: UILabel!
    @IBOutlet private weak var idViewField: UITextField!
    @IBOutlet private weak var passwordViewField: UITextField!
    @IBOutlet private weak var loginButton: UIButton!
    @IBOutlet private weak var passwordHelpButton: UIButton!
    @IBOutlet private weak var signupButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var scrollViewConstraint: NSLayoutConstraint!

    private let loadingView = LoadingView(frame: CGRect.zero)

    private let store = RxStore(store: Store<LoginViewState>(reducer: LoginViewReducer.handleAction, state: nil))
    private var requestCreator: LoginActionCreatable! {
        willSet {
            if requestCreator != nil {
                fatalError()
            }
        }
    }
    
    private var canLoginProcess = false
    private let disposeBag = DisposeBag()

    func inject(requestCreator: LoginActionCreatable) {
        self.requestCreator = requestCreator
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sendTrackingScreen(name: GoogleAnalyticsScreen.login)

        navigationController?.navigationBar.deleteShadow()
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        setValidation(of: idViewField)
        setValidation(of: passwordViewField)
        
        idViewField.bindTapWhenShowPasteMenu(disposeBag: disposeBag)
        
        UserDefaults.standard.removeObject(forKey: ApiHeader.authorization)
        view.effectConfetti(whiteColor: false)
        bind()
        keyboardHideViewUp(disposeBag: disposeBag, scrollView: scrollView, scrollBottomConstraint: scrollViewConstraint)
        checkVertionRequest()
    }

    override func didMove(toParentViewController parent: UIViewController?) {
        super.didMove(toParentViewController: parent)
        idLine.borderViewBottom(color: UIColor.borderLine)
        passwordLine.borderViewBottom(color: UIColor.borderLine)
        scrollView.contentOffset = CGPoint(x: 0.0, y: 0.0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let statusbar = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            statusbar.backgroundColor = UIColor.clear
        }
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch StoryboardSegue.Login(rawValue: segue.identifier!)! {
        case .toHelpPassword:
            let next = segue.destination as! SendMailViewController
            next.loginFlow = true
            next.changeTarget = ChangeTarget.password
        default:
            break
        }
    }
    
    func setValidation(of: UITextField) {
        of.delegate = of
    }

    private func bind() {

        Observable.combineLatest(idViewField.rx.text, passwordViewField.rx.text)
            .subscribe({ [unowned self] in
                self.loginButton.isEnabled = ($0.element?.0?.isNotEmpty)! && ($0.element?.1?.isNotEmpty)!
            })
            .disposed(by: disposeBag)

        loginButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.canLoginProcess = true
                KeyChainUtil.shared.set(key: KeyChainKey.mailAddress, value: self.idViewField.text!)
                KeyChainUtil.shared.set(key: KeyChainKey.password, value: self.passwordViewField.text!)
                let param = LoginParameter(mailAddress: self.idViewField.text!, password: self.passwordViewField.text!)
                ApplicationStore.instance.dispatch(self.requestCreator.post(parameter: param, disposeBag: self.disposeBag))
            })
            .disposed(by: disposeBag)

        passwordHelpButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.performSegue(withIdentifier: StoryboardSegue.Login.toHelpPassword.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)
        
        signupButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.performSegue(withIdentifier: StoryboardSegue.Login.toTermOfService.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(NSNotification.Name.UIApplicationWillEnterForeground)
            .filter { _ in UIApplication.topViewController() is LoginViewController }
            .subscribe { [unowned self] _ in
                self.checkVertionRequest()
            }
            .disposed(by: disposeBag)
        
        store.necessity
            .filter { $0 == 1 } // 0：不要、1：必要
            .subscribe({ [unowned self] _ in
                Alert.show(to: self, message: L10n.a001LoginAlertAppversion, style: .custom(buttons: [(.link, .default)]))
                    .subscribe {
                        guard let url = URL(string: Environment.instance.downloadServer) else { return }
                        UIApplication.shared.open(url, options: ["Authorization": Environment.instance.updateUserIDPW], completionHandler: nil)
                    }
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)

        ApplicationStore.instance.authToken
            .filter { _ in self.canLoginProcess && UIApplication.topViewController() is LoginViewController }
            .subscribe({ [unowned self] in
                self.canLoginProcess = false
                UserDefaults.standard.set($0.element!, forKey: ApiHeader.authorization)
                self.idViewField.text = ""
                self.passwordViewField.text = ""
                ApplicationStore.instance.dispatch(LoginResetAction())
                self.performSegue(withIdentifier: StoryboardSegue.Login.toMain.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)
        
        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }
    
    private func checkVertionRequest() {
        store.dispatch(NecessityResetAction())
        let version = AppInfoUtil.bundleShortVersionString()
        let ver = version.components(separatedBy: ".").reduce("", { $0 + $1 })
        store.dispatch(requestCreator.get(parameter: CheckAppVersionParameter(appVersion: Int(ver)!), disposeBag: disposeBag))
    }
}

extension RxStore where AnyStateType == LoginViewState {

    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }.distinctUntilChanged()
    }

    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }
    
    var necessity: Observable<Int> {
        return stateObservable.map { $0.necessity ?? -1 }.distinctUntilChanged()
    }
}

extension Alert.ActionType {
    static var link: Alert.ActionType {
        return .custom(title: "開く")
    }
}
