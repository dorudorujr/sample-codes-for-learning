//
//  RootView.swift
//  AnaMile
//
//  Created by 西村 拓 on 2016/01/20.
//
//

import UIKit

import RxSwift

import SnapKit

import ObjectMapper

import Reachability

////ログイン画面や言語設定画面などなど
class RootView: BaseView {
    /// Rx
    private let disposeBag = DisposeBag()

    /// 子View配列
    private var layerArray: [RootViewBase] = []

    /// 白背景の初期値
    static let WHITE_ALPHA: CGFloat = 0.7

    /// Background
    @IBOutlet private var bgView: UIView!
    
    private var bgImageView = UIView()

    // Window
    private static var rootWindow: UIWindow?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // シングルトン生成
        _ = RootViewModel.create()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        addLayer()

        configureInitialView()

        bind()
    }

    /**
     言語居住地設定〜チュートリアル〜ログインを画面に追加
     */
    private final func addLayer() {
        guard let viewEntity = RootViewModel.sharedInstance?.rootViewEntity else {
            return
        }

        for e in viewEntity {

            // ログイン画面まで一度でもたどり着いていたら、それ以前の画面は生成しない
            //// RootViewBase.alreadyReachedLast(): 到達しているかどうかのフラグを取得して判定している
            if RootViewBase.alreadyReachedLast() &&
                e.viewIdentifier != "LoginView" {
                return
            }

            let createdClass = AppInfoUtil.classFromString(e.viewIdentifier) as! RootViewBase.Type      ////クラスを生成
            ////クラスからUIViewを生成
            guard let view = createdClass.create() as? RootViewBase else {
                log.error("Init view error : " + e.viewIdentifier)
                return
            }
            layerArray.insert(view, at: 0)  ////指定位置に要素を挿入
            addSubview(view)
            view.snp.makeConstraints { make -> Void in
                make.top.leading.trailing.bottom.equalTo(self)
            }
            view.viewSetting()      ////表示状態を設定(デフォルトは非表示)
            view.analyticsPageName = e.analyticsPageName
        }
    }

    /**
     初期表示状態を設定
     */
    private final func configureInitialView() {
        bgView.alpha = (RootViewBase.alreadyReachedLast()) ? 0.0 : RootView.WHITE_ALPHA

        // 最初のページを表示
        layerArray.first?.viewSetting(false)
        // Analytics
        layerArray.first?.sendAnalytics()
    }

    /**
     Rx
     */
    private final func bind() {

        RootViewModel.sharedInstance?.currentPageIndex
            .asObservable()
            .filterNil()
            .subscribe(onNext: { [weak self] i -> Void in

                guard let
                    oldView = self?.layerArray[i],
                    let newView = self?.layerArray[i + 1] else {
                        return
                }

                UIView.animate(withDuration: 0.3, animations: {
                    // 表示中のlayerを消す
                    oldView.alpha = 0.0
                    oldView.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)

                    newView.alpha = 1.0
                    newView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                    // Analytics
                    newView.sendAnalytics()

                    newView.updateReachedView()

                    // ホワイト背景のアルファを調整
                    self?.bgView.alpha =
                        RootView.WHITE_ALPHA - (RootView.WHITE_ALPHA / CGFloat(RootViewModel.sharedInstance!.rootViewEntity.count)) * CGFloat(i + 1)
                    }, completion: { _ in
                        oldView.removeFromSuperview()
                })
            })
            .disposed(by: disposeBag)

        // アクション検知
        RootViewModel.sharedInstance?.action.asObservable()
            .filter { $0 != nil}
            .map { $0! }
            .subscribe(onNext: {[weak self] error in
                switch error {
                case .LoginButtonTapped:
                    self?.loginButtonTapped()
                case .NewRegisterUrlOpen:
                    self?.openWebViewController(url: URLListModel.map().loginRegisterButton)
                case .ForgetPasswordUrlOpen:
                    self?.openWebViewController(url: URLListModel.map().loginForgetPasswordButton)
                case .WhatIsWebPasswordUrlOpen:
                    self?.openWebViewController(url: URLListModel.map().loginWhatButton)
                case .ANAPrivacyPolicy:
                    self?.openWebViewController(url: URLListModel.map().privacyPolicy)
                }

                RootViewModel.sharedInstance?.action.value = nil
            })
            .disposed(by: disposeBag)

        // ログイン
        AppStatusModel.shared.userModel.user.asObservable()
            .filter { _ in AppStatusModel.shared.loginState.value != .isNotLogin }
            .filter { $0?.retCode == .Success }
            .subscribe(onNext: { [weak self] _ in
                self?.loginSuccess()
                AppStatusModel.shared.service.udpate()
            })
            .disposed(by: disposeBag)

        // ログインエラー
        AppStatusModel.shared.userModel.error.asObservable()
            .filterNil()
            .subscribe(onNext: { [weak self] in
                self?.loginFailure(error: $0)
            })
            .disposed(by: disposeBag)

        // 演出準備待機
        AppStatusModel.shared.isReadyToLogin.asObservable()
            .filter { _ in AppStatusModel.shared.loginState.value != .isNotLogin }
            .filter { $0 }
            .subscribe(onNext: { [weak self] _ in
                LoadingView.dismiss()

                self?.didReadyToLogin()
            })
            .disposed(by: disposeBag)
    }

    /**
     ログイン成功時
     */
    private final func loginSuccess() {
        // Root Singletonを解放
        RootViewModel.terminate()
        AppStatusModel.shared.startMonitoringReadyToLogin(auto: false)
    }

    /**
     ログイン失敗時
     */
    private final func loginFailure(error: NSError) {
        isUserInteractionEnabled = true
        // TODO:NSError+CustomにJsonMapppingErrorかModelMappingErrorでないかを返すプロパティを追加して
        _ = DialogView.show(
            title: String(localizedKey: "ErrorLoginErrorHeading"),
            message: error.code == NSError(errorType: .jsonMappingError).code || error.code == NSError(errorType: .modelMappingError).code ? String(localizedKey: "ErrorLoginMaintenanceText") : error.localizedDescription,
            buttonTitles: [
                (title: String(localizedKey: "ComOK"), buttonType: .normal)
            ])
    }

    /**
     ログイン演出へ
     */
    private final func didReadyToLogin() {

        UIView.animate(
            withDuration: 7.2,
            delay: 0.7,
            options: UIView.AnimationOptions(), animations: {
                self.alpha = 0.0
                self.bgImageView.alpha = 0.0
        }, completion: { [weak self] _ in
            self?.removeFromSuperview()
            self?.bgImageView.removeFromSuperview()
            
            AppStatusModel.shared.isReadyToLogin.value = false
            
            RootView.rootWindow?.rootViewController = nil
            RootView.rootWindow?.windowLevel = UIWindow.Level(rawValue: -1000)
            RootView.rootWindow = nil
            
            guard
                let app = UIApplication.shared.delegate,
                let appWindow = app.window,
                let window = appWindow else {
                    return
            }
            window.makeKeyAndVisible()
        })
    }

    // MARK: - Action
    /**
     ログインボタン押下時
     */
    private final func loginButtonTapped() {

        isUserInteractionEnabled = false

        guard let
            rootViewModel = RootViewModel.sharedInstance,
            let userParameter = Mapper<UserParameter>().map(JSON: [
            "amcno": rootViewModel.userId.value,
            "pass": rootViewModel.password.value
            ]) else {
                return
        }

        AppStatusModel.shared.userModel.login(parameter: userParameter)
    }

    /**
     RootViewインスタンス表示
     */
    private final func showOnWindow(animated: Bool) {
        let viewController = UIViewController()
        RootView.rootWindow = RootView.createWindow()
        RootView.rootWindow?.rootViewController = viewController
        //背景画像
        bgImageView = UIImageView(image: UIImage(named: "splash_bg"))
        viewController.view.addSubview(bgImageView)
        
        bgImageView.snp.makeConstraints({ make in
            make.edges.equalTo(viewController.view)
        })
        
        //rootViewを追加する
        viewController.view.addSubview(self)
        // 制約
        self.snp.makeConstraints({ make in
            make.top.equalTo(viewController.topLayoutGuide.snp.bottom)
            make.leading.trailing.bottom.equalTo(viewController.view)
        })

        // アニメーション
        let alphaTuple = (animated) ? (CGFloat(0), CGFloat(1)) : (CGFloat(1), CGFloat(1))
        viewController.view.alpha = alphaTuple.0

        RootView.rootWindow?.makeKeyAndVisible()

        UIView.animate(withDuration: 0.3, animations: {
            viewController.view.alpha = alphaTuple.1
        })
    }

    /**
     Window生成
     */
    private class final func createWindow() -> UIWindow {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = UIColor.clear
        window.windowLevel = UIWindow.Level.normal + 100
        return window
    }

     /**
     RootView表示

     - parameter animated: 表示アニメーション有無（default = false）
     */
    class final func showOnWindow(animated: Bool) {
        if RootView.rootWindow != nil {
            return
        }

        guard let rootView = RootView.create() as? RootView else {
            return
        }

        rootView.showOnWindow(animated: animated)
    }

    private final func openWebViewController(url: URL?) {
        // CardFaceViewControllerで表示するが、表示の仕方がGLの動作タイミングの都合で違うので処理をRoot専用にする
        // (ログイン前はGLが動いてないので、CardFaceViewController側のWebViewを使いたくない)

        // WebView
        guard
            let url = url,
            let rootController = RootView.rootWindow?.rootViewController,
            let controller = UIStoryboard(
                name: "WebView",
                bundle: Bundle.main)
                .instantiateInitialViewController() as? WebViewController
            else {
                return
        }
        controller.url = url
        controller.showBackground = true
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve

        rootController.present(controller, animated: true, completion: nil)
    }
}
