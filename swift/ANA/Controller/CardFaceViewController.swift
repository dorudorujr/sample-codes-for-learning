//
//  CardFaceViewController.swift
//  AnaMile
//
//  Created by 西村 拓 on 2015/11/04.
//  Copyright © 2015年 TakuNishimura. All rights reserved.
//

import UIKit

import SnapKit

import ObjectMapper

import RxSwift
import RxCocoa

import Reachability
import Firebase
import FirebasePerformance

/// コンテンツ画面すべての土台となるController
class CardFaceViewController: CocosBaseController, UIScrollViewDelegate {

    /// ヘッダ
    @IBOutlet private weak var headerView: UIView!

    /// メニューボタン
    @IBOutlet private final weak var menuButton: MenuButton!
    @IBOutlet private final weak var menuButtonEffectView: MenuButtonEffectView!
    
    @IBOutlet private weak var menuButtonBottomConstraint: NSLayoutConstraint!

    /// CardFace
    @IBOutlet private weak var scrollviewTopConstraint: NSLayoutConstraint!

    /// QR
    @IBOutlet private weak var qrView: QRView!

    /// Rx
    private let disposeBag = DisposeBag()

    /// ScrollView
    @IBOutlet private weak var contentsScrollView: UIScrollView!
    @IBOutlet private weak var contentsContainer: UIView!

    /// WEbView
    @IBOutlet private final weak var whiteBGTopOffset: NSLayoutConstraint!
    @IBOutlet private final weak var webContainer: UIView!
    @IBOutlet private final weak var webTitleLabel: UILabel!
    
    /// Menu
    private var menuViewController: MenuNavigationController?
    /// Menu表示animation中flag, button連打対応
    private var isShowingMenu = false

    /// Contents
    var contentsLayerArray = [BaseContentsView]()
    let cotentsEntityArray = AppStatusModel.shared.cotentsEntityArray
    
    // version
    private let versionCheckModel = VersionCheckModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // スプラッシュを最初から生成
        /// スプラッシュ: 一番最初の起動時のロード的な画面
        if let splashView = SplashView.create() as? SplashView {    /// create:xibからUIViewを生成
            view.addSubview(splashView)
            splashView.frame = view.bounds
            splashView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        }

        // Rx
        bind()
        
        setupUI()

        // 言語別表示更新
        AppStatusModel.shared.updateViewType()
        
        // バージョンチェック処理
        checkVersion()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return (AppStatusModel.shared.userModel.savedCardFaceType == .SFC) ? .lightContent : .darkContent
        } else {
            return (AppStatusModel.shared.userModel.savedCardFaceType == .SFC) ? .lightContent : .default
        }
    }
    
    private func setupUI() {
        if #available(iOS 11.0, *) {
            whiteBGTopOffset.constant = view.safeAreaInsets.top + UIApplication.shared.statusBarFrame.size.height
        } else {
            whiteBGTopOffset.constant = topLayoutGuide.length + UIApplication.shared.statusBarFrame.size.height
        }
        menuButtonBottomConstraint.constant = -UIConst.bottomVerticalMargin
        contentsScrollView.decelerationRate = UIScrollView.DecelerationRate.fast    ////ユーザーが指を離した後の減速度を決定する浮動小数点値。
    }

    // MARK: - Init Layer
    
    /// コンテンツレイヤー描画
    private final func removeLayers() {
        contentsContainer.subviews.forEach {
            $0.removeFromSuperview()
        }
        contentsLayerArray = [BaseContentsView]()
    }

    private final func addLayer() {
        Benchmark.startProcess("addLayer")
        
        // 描画済のものがあればスルー
        guard contentsLayerArray.isEmpty else { return }

        // 描画済のものがあればクリア
        removeLayers()

        var previousContentView: BaseContentsView?

        // 描画・制約
        ////cotentsEntityArray:ファイルから各画面のEntityを生成済み
        ////enumerated: indexと要素のタプルを返す
        cotentsEntityArray.enumerated().forEach { (offset, element) in
            Benchmark.startProcess(element.viewIdentifier)
            
            let createdClass = AppInfoUtil.classFromString(element.viewIdentifier) as! BaseContentsView.Type        ////文字列からクラスを生成
            //// クラスからViewを生成
            guard let view = createdClass.create() as? BaseContentsView else {
                log.error("Init view error : " + element.viewIdentifier)
                return
            }
            Benchmark.finishProcess(element.viewIdentifier)
            // 生成したViewへEntity設定
            view.contentViewEntity = element
            
            // initialViewチェック
            if element.isInitialView {
                AppStatusModel.shared.initialIndexHorizontal = offset       ////initialView(最初に表示されるView)を設定
            }
            
            // アクティベート
            ////画面を追加
            contentsLayerArray.append(view)
            contentsContainer.addSubview(view)
            
            // Autolayout設定
            view.snp.makeConstraints {
                $0.height.equalTo(self.view.snp.height)
                $0.width.equalTo(self.view.snp.width)
                $0.top.equalTo(contentsContainer.snp.top)
                
                if let s = previousContentView {
                    // 一個前に生成したView右へ吸着
                    $0.leading.equalTo(s.snp.trailing).offset(UIConst.contentsMargin)
                } else {
                    // 最初だけ親View左へ吸着
                    $0.leading.equalTo(contentsContainer.snp.leading)
                }
            }
            
            previousContentView = view
        }

        // 最後に描画したViewを親View右へ吸着
        previousContentView?.snp.makeConstraints {
            $0.trailing.equalTo(contentsContainer.snp.trailing)
        }
        
        view.layoutIfNeeded()
        Benchmark.finishProcess("addLayer")
    }

    /// バージョンチェック
    private final func checkVersion() {
        AppStatusModel.shared.loginState.value = .isCheckingVersion
        versionCheckModel.checkVersion()
    }

    /// チュートリアル・ログイン画面呼び出し
    private final func showLoginView() {
        // キーチェーンからデータを復元 → 保存されたデータがなければログイン画面を出す
        if AppStatusModel.shared.fetchKeyChainData() {
            autoLogin()
        } else {
            RootView.showOnWindow(animated: false)
        }
    }

    /// 保存済のユーザー情報を使用して自動ログイン
    private final func autoLogin() {
        let trace = Performance.startTrace(name: "Auto Login Prepare")      ////analyticsのトレース開始
        // ユーザー情報を復元できなければログイン画面を出す
        guard let loginParameter = AppStatusModel.shared.userModel.savedLoginParameter else {
            RootView.showOnWindow(animated: false)      ////ログイン画面や言語設定画面などを表示
            return
        }

        // ログインステータスを自動ログインコール状態に
        AppStatusModel.shared.loginState.value = .isTryAutoLogin
        
        // キャッシュのユーザーをロード
        AppStatusModel.shared.userModel.loadCacheUser()
        
        // キャッシュからユーザーが取得できた場合
        if let user = AppStatusModel.shared.userModel.user.value {
            loginSuccess(user: user)
        }
        trace?.stop()
        // 最新の情報を取得
        AppStatusModel.shared.userModel.login(parameter: loginParameter)
    }

    // MARK: - Rx
    private func bind() {
        
        //Menu button
        AppStatusModel.shared.menuButtonSelected
            .asDriver()
            .filter { $0 }
            .drive(onNext: { [unowned self] _ in
                self.showMenu()
            })
            .disposed(by: disposeBag)
        
        AppStatusModel.shared.bottomWebViewUrl
            .asDriver()
            .filterNil()
            .drive(onNext: {[unowned self] url in
                self.showWebView(url: url)
            })
            .disposed(by: disposeBag)
        
        AppStatusModel.shared.modalWebViewUrl
            .asDriver()
            .filterNil()
            .drive(onNext: {[unowned self] url in
                self.showWebView(url: url, isModal: true)
            })
            .disposed(by: disposeBag)

        // Version Check
        versionCheckModel.versionEntity.asDriver()
            .filterNil()
            .drive(onNext: {[weak self] versionEntity in
                guard let self = self else { return }
                ////バージョンアップが必要な時だけダイアログを表示する
                VersionAlertHelper.shared.showUpdateDialogViewIfNeeded(versionEntity: versionEntity.iosVersion, completed: { [unowned self] in
                    self.removeLayers()     ////描画しているViewを全て削除
                    self.showLoginView()
                })
            }).disposed(by: disposeBag)

        versionCheckModel.error.asDriver()
            .filterNil()
            .drive(onNext: {[unowned self] _ in
                // TODO : そんままログインさせちゃっていいか確認
                self.removeLayers()
                self.showLoginView()
            }).disposed(by: disposeBag)
        
        // Info
        AppStatusModel.shared.info.latestInfo.asObservable()
            .filterNil()
            .subscribe(onNext: { [weak self] in
                // Greeting と info があればふわふわする
                let greetingFlag = GreetingSelector.shared.hasNewGreeting

                if $0.isExistingNewInfo(lastReadTime: AppStatusModel.shared.lastReadInfoTime.value) || greetingFlag {
                    self?.menuButtonEffectView.animate()
                }
            }).disposed(by: disposeBag)
        
        AppStatusModel.shared.lastReadInfoTime.asObservable()
            .filterNil()
            .subscribe(onNext: { [weak self] _ in
                self?.menuButtonEffectView.stopAnimation()
            }).disposed(by: disposeBag)

        AppStatusModel.shared.destinationViewX.asObservable()
            .map { CGPoint(x: (UIConst.contentsWidth + UIConst.contentsMargin) * ($0 + 1), y: 0) }
            .subscribe(onNext: { [unowned self] offset in
                self.contentsScrollView.setContentOffset(offset, animated: true)
            })
            .disposed(by: disposeBag)

        // Alpha
        AppStatusModel.shared.mainContentsAlpha
            .asObservable()
            .subscribe(onNext: {[unowned self] alpha in
                self.contentsScrollView.alpha = alpha
                self.headerView.alpha = alpha
                self.menuButton.alpha = alpha
            })
            .disposed(by: disposeBag)

        // User Status
        AppStatusModel.shared.userModel.user.asObservable()
            .filter { $0?.retCode == .Success }
            .map { $0! }
            .subscribe(onNext: { [unowned self] in
                CardFaceViewModel.sharedInstance.lastCardFaceType.value = $0.cardFaceType
                self.loginSuccess(user: $0)
            })
            .disposed(by: disposeBag)
        
        // Update status bar
        AppStatusModel.shared.userModel.user.asObservable()
            .filterNil()
            .subscribe(onNext: {[unowned self] _ in
                self.setNeedsStatusBarAppearanceUpdate()
            })
            .disposed(by: disposeBag)

        // Login Effect
        AppStatusModel.shared.didFinishLoginAnimation
            .asObservable()
            .filter { $0 }
            .subscribe(onNext: { [unowned self] in
                
                self.contentsScrollView.isScrollEnabled = $0

                // 演出終了時はコンテンツが見えるように
                AppStatusModel.shared.mainContentsAlpha.value = 1.0

                LoadingView.dismiss()
                
                // DMID取得 > service, info更新
                AppStatusModel.shared.dmid.udpate()
                
                AppStatusModel.shared.dmid.complete.asObservable()
                    .filterNil()
                    .take(1)
                    .subscribe(onNext: { _ in
                        AppStatusModel.shared.service.udpate()
                        AppStatusModel.shared.info.getLatestInfo()
                    }).disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)

        // Login Error
        AppStatusModel.shared.userModel.error.asObservable()
            .filterNil()
            .subscribe(onNext: { [unowned self] in
                self.didLoginFailure(error: $0)
                // Greetingとinfo表示しない
                AppStatusModel.shared.info.latestInfo.value = nil
                self.menuButtonEffectView.stopAnimation()
            })
            .disposed(by: disposeBag)

        // CardfaceStatus
        CardFaceViewModel.sharedInstance.lastCardFaceType.asObservable()
            .filterNil()
            .distinctUntilChanged()
            .subscribe(onNext: {[unowned self] _ in
                // 設定画面を開いていたら閉じる
                self.dismiss(animated: true, completion: nil)
                // ホームポジションへ移動
                self.moveToHomePosition(animated: false)
            })
            .disposed(by: disposeBag)

        // show RecommendList
        AppStatusModel.shared.showRecommendList.asObservable()
            .distinctUntilChanged()
            .filter { $0 }
            .subscribe(onNext: { [unowned self] _ in
                self.showRecommendList()
            }).disposed(by: disposeBag)
        
        // Logout処理、MenuViewControllerをrealease
        // 次のログイン後、利用する時に再生成する
        // SeeAlso: showMenu()
        AppStatusModel.shared.info.latestInfo
            .asObservable()
            .filter { $0 == nil }
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.menuViewController = nil
            })
            .disposed(by: disposeBag)
        
        // Greetingがあればふわふわする
        GreetingSelector.shared.infos.asDriver()
            .drive(onNext: { [weak self] infos in
                if let info = infos.first, info.showed != true {
                    self?.menuButtonEffectView.isHidden = false
                    self?.menuButtonEffectView.animate()
                }
            })
            .disposed(by: disposeBag)
    }

    /**
     ログイン成功時の処理

     - parameter user: 取得したUserEntity
     */
    private final func loginSuccess(user: UserEntity) {
        // Menu再生成したらMileGoalのanimeを再生準備flagを
        AppStatusModel.shared.shouldShowMileAnime.value = MileGoalHelper.hasGoalInfo()

        switch AppStatusModel.shared.loginState.value {

        case .isTryLogin:
            // ログインステータス更新
            AppStatusModel.shared.loginState.value = .isLogin
            
            resetContentsLayer(false)

        case .isTryAutoLogin:
            didAutoLoginFinished()          ////アニメーション(cocos)周りのフラグ設定

            // ログインステータス更新
            AppStatusModel.shared.loginState.value = .isAutoLogin

            resetContentsLayer(false)

        case .isTryUpdate:
            // ログインステータス更新
            AppStatusModel.shared.loginState.value = .isLogin

        case .isTryFetch:
            // ログインステータス更新
            AppStatusModel.shared.loginState.value = .isLogin

        default: break
        }
    }

    /// コンテンツの再描画
    private final func resetContentsLayer(_ animated: Bool) {
        // コンテンツレイヤー描画
        addLayer()

        // ホームポジションへ移動
        ////contentsScrollViewの位置をinitialIndexHorizontalの位置に
        moveToHomePosition(animated: animated)

        // 演出準備待機
        AppStatusModel.shared.isReadyToLogin.asObservable()
            .filter { _ in AppStatusModel.shared.loginState.value != .isNotLogin }
            .filter { $0 }
            .take(1)
            .subscribe(onNext: { [weak self] _ in
                let trace = Performance.startTrace(name: "Show Top Screen")
                LoadingView.dismiss()

                // 通常ログインかオートログインか
                let isNewLogin = AppStatusModel.shared.loginState.value == .isLogin

                self?.headerView.alpha = 0.0
                self?.menuButton.alpha = 0.0
                self?.menuButtonEffectView.isHidden = true

                // 背景拡大
                UIView.animate(withDuration: 1.5,
                    delay: (isNewLogin) ? 5.0 : 2.0,

                    options: .curveEaseInOut,
                    animations: {
                        self?.headerView.alpha = 1.0
                        self?.menuButton.alpha = 1.0
                    },
                    completion: { _ in
                        self?.menuButtonEffectView.isHidden = false
                        trace?.stop()
                    })
            })
            .disposed(by: disposeBag)
    }

    /// ログイン演出へ
    private final func didAutoLoginFinished() {
        AppStatusModel.shared.startMonitoringReadyToLogin(auto: true)
    }

    /// ログイン失敗時
    private final func didLoginFailure(error: NSError) {
        // TODO:NSError+CustomにJsonMapppingErrorかModelMappingErrorでないかを返すプロパティを追加して
        
        // パスできないときだけここで入れない
        if error.domain == AppInfoUtil.bundleIdentifier() &&
            ( error.code != NSError(errorType: .jsonMappingError).code &&
                error.code != NSError(errorType: .modelMappingError).code ) {
            // APIのレスポンスエラーに対して、処理分岐
            logout(error)
        } else {
            AppStatusModel.shared.loginState.value = .isOfflineMode
        }

        // エラー画面キック用
        AppStatusModel.shared.service.udpate()
    }

    /// エラー > ログアウト
    private final func logout(_ error: NSError) {
        // 未ログインの間はスルー
        guard AppStatusModel.shared.userModel.isLogined else { return }

        // エラーコード200以上が自動ログアウト対象
        if error.code < 200 { return }

        DialogView.show(
            message: error.localizedDescription,
            buttonTitles: [
                (title: String(localizedKey: "ComOK"), buttonType: .normal)
            ])?
        .asDriver(onErrorJustReturn: 0)
        .drive(onNext: { [unowned self] _ in
            // ログイン画面表示
            AppStatusModel.shared.userModel.user.value = nil
            AppStatusModel.shared.loginState.value = .isNotLogin
            AppStatusModel.shared.cocosViewStatus.value = .logout
            AppStatusModel.shared.clear()

            RootView.showOnWindow(animated: true)

            // 設定画面を開いていたら閉じる
            self.dismiss(animated: true, completion: nil)
        })
        .disposed(by: disposeBag)
    }

    // MARK: - Scroll
    /**
    スクロール位置を基準に設定したViewへ移動する
    */
    private func moveToHomePosition(animated: Bool) {
        let homePositionX = (UIConst.contentsWidth + UIConst.contentsMargin) * CGFloat(AppStatusModel.shared.initialIndexHorizontal)
        contentsScrollView.setContentOffset(CGPoint(x: homePositionX, y: 0.0), animated: animated)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        AppStatusModel.shared.viewPointHorizontal.value = scrollView.contentOffset.x
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let vector = velocity.x
        
        let oldPage = Int(scrollView.contentOffset.x / (UIConst.contentsWidth + UIConst.contentsMargin) + 0.5)
        var newPage = oldPage
        
        if vector < -UIConst.flicPagingThreshold {
            newPage -= 1
        }
        
        if vector > UIConst.flicPagingThreshold {
            newPage += 1
        }
        
        if (newPage < 0 || newPage >= cotentsEntityArray.count) && AppStatusModel.shared.didFinishLoginAnimation.value {
            AppStatusModel.shared.menuButtonSelected.accept(true)
        }
        
        newPage = adjustRangeContents(page: newPage)
        
        targetContentOffset.pointee.x = (UIConst.contentsWidth + UIConst.contentsMargin) * CGFloat(newPage)
        
        // Analytics
        sendSwipeActionAnalytics(scrollView, vector: vector)
    }

    // MARK: - Util
    /// 表示中のView取得
    private var currentContentView: UIView? {
        var page = Int(contentsScrollView.contentOffset.x / (UIConst.contentsWidth + UIConst.contentsMargin) + 0.5)
        page = adjustRangeContents(page: page)
        return contentsLayerArray.indices.contains(page) ? contentsLayerArray[page] : nil
    }
    
    /**
    指定した位置が、コンテンツエリア内にあるかどうか

    - parameter position: 指定位置

    - returns: コンテンツ内におさめたページカウントを返す
    */
    private func adjustRangeContents(page: Int) -> Int {
        if page < 0 { return 0 }
        if page >= cotentsEntityArray.count {
            return cotentsEntityArray.count - 1
        }

        return page
    }

    /**
     WEB表示
     isModal : falseなら下部WEB表示.trueならmodalで表示
     */
    final func showWebView(url: URL, isModal: Bool = false) {
        
        // ネットワークチェック
        guard !ReachabilityUtil.shared.isOffline.value else {
            DialogView.showNetworkAlert()
            return
        }

        if isModal {
            guard let viewController = UIStoryboard(name: "WebView", bundle: Bundle.main).instantiateInitialViewController() as? WebViewController
                else { return }
            
            viewController.url = url
            viewController.cardBlur = true
            viewController.modalMode = true
            
            viewController.modalPresentationStyle = .overFullScreen
            present(viewController, animated: true, completion: nil)
            
        } else {
            webContainer.subviews.compactMap { $0 as? WebView }.forEach { $0.dismiss() }
            guard let webView = WebView.create() as? WebView else { return }
            
            webTitleLabel.text = nil
            scrollviewTopConstraint.constant = -view.height()
            
            // GLへ状態渡し
            AppStatusModel.shared.cocosViewStatus.value = .centerBlur
            
            webContainer.addSubview(webView)
            webView.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            webView.loadURL(url)
            
            UIView.animate(withDuration: 0.4, delay: 0.0, options: .curveEaseOut, animations: {
                self.view.layoutIfNeeded()
                }, completion: nil)
            
            // Web
            webView.loadedTitle.asObservable()
                .filterNil()
                .bind(to: webTitleLabel.rx.text)
                .disposed(by: disposeBag)
        }
    }
    
    private func createMenuViewController() -> MenuNavigationController {
        let storyboard = UIStoryboard(name: "MenuContainer", bundle: nil)
        let controller = storyboard.instantiateInitialViewController() as! MenuNavigationController
        // 新規ならまずfalseで
        AppStatusModel.shared.menuRecoverUIMode.value = false
        return controller
    }
    
    private func showMenu() {
        // CardFaceViewControllerが最上位じゃない状態何もしない
        guard let vc = UIApplication.topViewController, vc is CardFaceViewController else { return }
        // Animation中はreturn
        guard !isShowingMenu else { return }
        isShowingMenu = true
        
        // Fade out contentView
        MainViewAnimationHelper.startFadeOutEffect(self.currentContentView)
        
        // Present menu after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
            // MenuContainerViewController reuseの処理まだ実装されていないから、
            // 新しいgreetingある時に再生成する必要がある、アニメーションを再生するため
            if GreetingSelector.shared.hasNewGreeting {
                self.menuViewController = nil
            }
            if self.menuViewController == nil {
                self.menuViewController = self.createMenuViewController()
            }
            guard let controller = self.menuViewController else { return }
            
            controller.modalPresentationStyle = .overFullScreen
            controller.modalTransitionStyle = .crossDissolve
            controller.willDismiss = { [unowned self] in
                MainViewAnimationHelper.startFadeInEffect(self.currentContentView)
            }
            self.present(controller, animated: true, completion: {
                self.isShowingMenu = false
            })
            
            // Analytics
            self.menuButton.sendAnalytics()
        })
    }

    /// RecommendList表示
    private func showRecommendList() {
        let storyboard = UIStoryboard(name: "RecommendList", bundle: nil)
        guard let controller = storyboard.instantiateInitialViewController() else { return }

        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve

        present(controller, animated: true, completion: nil)

        // GLへ状態渡し
        AppStatusModel.shared.cocosViewStatus.value = .centerBlur

        // メインコンテンツアルファコントロール
        AppStatusModel.shared.animateContentsAlpha(to: 0.0)
    }

    // MARK: - Button
    @IBAction private func quButtonTapped(_ sender: UIButton) {
        // Analytics
        AnalyticsModel.trackAction(
            screenName: AppStatusModel.shared.currentDisplayedViewName,
            actionName: "Common_QR_From_" + AppStatusModel.shared.currentDisplayedViewName
        )

        scrollviewTopConstraint.constant = view.frame.height

        // GLへ状態渡し
        AppStatusModel.shared.cocosViewStatus.value = .showQR

        UIView.animate(withDuration: 0.4, delay: 0.0, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.qrView.show()
        })
    }

    @IBAction private func backFromQRButtonTapped(_ sender: UIButton) {
        scrollviewTopConstraint.constant = 0.0
        qrView.dismiss()
        AppStatusModel.shared.cocosViewStatus.value = .normal
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    @IBAction private func userButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Setting", bundle: nil)
        guard let controller = storyboard.instantiateInitialViewController() else { return }

        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve

        present(controller, animated: true, completion: nil)

        // Openフラグ
        AppStatusModel.shared.isOpenSettingView.value = true

        // GLへ状態渡し
        AppStatusModel.shared.cocosViewStatus.value = .centerBlur

        // メインコンテンツアルファコントロール
        AppStatusModel.shared.animateContentsAlpha(to: 0.0)

        // Analytics
        AnalyticsModel.trackAction(
            screenName: AppStatusModel.shared.currentDisplayedViewName,
            actionName: "Common_USER_From_" + AppStatusModel.shared.currentDisplayedViewName
        )
    }

    @IBAction private func backFromWebButtonTapped(_ sender: UIButton) {
        scrollviewTopConstraint.constant = 0.0
        AppStatusModel.shared.bottomWebViewUrl.value = nil
        // GLへ状態渡し
        AppStatusModel.shared.cocosViewStatus.value = .normal
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    // MARK: Analytics
    
    /**
    スワイプ遷移のAction Analytics送信

    - parameter isToRight: 右方向にswipeしたときtrue
    */
    final func sendSwipeActionAnalytics(_ scrollView: UIScrollView, vector: CGFloat) {
        let maxX = ((UIConst.contentsWidth + UIConst.contentsMargin) + 0.5) * CGFloat(contentsLayerArray.count - 1)
        if
            scrollView.contentOffset.x < 0 ||
                scrollView.contentOffset.x > maxX {
                    // Contentページ範囲外のとき無視
                    return
        }

        let actionName = (vector > 0) ? "_Swipe_Right" : "_Swipe_Left"
        AnalyticsModel.trackAction(
            screenName: AppStatusModel.shared.currentDisplayedViewName,
            actionName: AppStatusModel.shared.currentDisplayedViewName + actionName
        )
    }
}
