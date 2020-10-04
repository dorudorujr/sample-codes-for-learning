//
//  SideMenuRootViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/01/31.
//  Copyright © 2018年 Team Lab. All rights reserved.
//
import Foundation
import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RxGesture
import ReSwift
import ApplicationConfig
import ApplicationModel
import ApplicationLib

final class SideMenuRootViewController: UIViewController, UserInfoKeepable, CardInfoManageable {
    
    @IBOutlet private weak var nameLabel: UILabel!                          //一番上の名前Label
    @IBOutlet private weak var mailLabel: UILabel!                          //一番上のアドレスLabel
    @IBOutlet private weak var nameMailOpeningView: UIView!                 //名前とアドレスのview
    @IBOutlet private weak var previewSelectedViewFrame: UIView!            //多分端にあるgoogle map
    @IBOutlet private weak var selectedView: UIView!                        //画面全体?
    @IBOutlet private weak var otherMenuButton: UIButton!                   //アプリについて
    @IBOutlet private weak var openBrowserButton: UIButton!                 //フィードバック
    @IBOutlet private weak var previewViewMargin: NSLayoutConstraint!

    private let previewMarginPer: CGFloat = 0.17
    private var homeViewController: HomeViewController?                     //home画面
    private var menuList: UITableView?
    private var prepearHomeView = false
    private var nextPayment = false                                         //お支払いcellをタップしたか調べるフラグ
    var nowPositionKeeper: NowPositionKeepable!                             //現在値

    private let store = RxStore(store: Store<SideMenuViewState>(reducer: SideMenuViewReducer.handleAction, state: nil))

    //ユーザ情報(Mockでは名前とメアドのみ)
    private var userInfoRequest: UserInfoActionCreatable! {
        willSet {
            if userInfoRequest != nil {
                fatalError()
            }
        }
    }
    private var paymentActionCreatable: PaymentCardInfoActionCreatable! {
        willSet {
            if paymentActionCreatable != nil {
                fatalError()
            }
        }
    }

    //ユーザが所持している?Suika
    private var suicaInfoActionCreatable: SuicaInfoActionCreatable! {
        willSet {
            if suicaInfoActionCreatable != nil {
                fatalError()
            }
        }
    }
    
    
    private let animationEase = UICubicTimingParameters(controlPoint1: CGPoint(x: 0.77, y: 0.0), controlPoint2: CGPoint(x: 0.27, y: 1.0))   //アニメーションの流れ方設定?
    private let selectedCellIndex = Variable<Int>(-1)           //tableviewから選んだcellの位置
    private let disposeBag = DisposeBag()

    public var firstName: String {
        return store.state.firstName
    }

    public var lastName: String {
        return store.state.lastName
    }

    public var mailAddress: String {
        return store.state.mailAddress
    }
    
    //ユーザ情報
    public var userData: [String] {
        return [store.state.lastName + " " + store.state.firstName, store.state.mailAddress, "", store.state.docomoId, ""]
    }

    func inject(userInfoRequest: UserInfoActionCreatable, paymentRequestCreator: PaymentCardInfoActionCreatable, suicaInfoRequestCreator: SuicaInfoActionCreatable) {
        self.userInfoRequest = userInfoRequest
        self.paymentActionCreatable = paymentRequestCreator
        self.suicaInfoActionCreatable = suicaInfoRequestCreator
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        previewViewMargin.constant = UIScreen.main.bounds.size.width * previewMarginPer * -1        //スライドしたgoogle mapのサイズ!
        selectedCellIndex.value = -1
        
        TransitionHelper.shared.transitionIn = resizePreviewView
        TransitionHelper.shared.transitionOut = resizeFullScreenView
        TransitionHelper.shared.dataUpdate = updateUserInfo
        TransitionHelper.shared.navigationPopToRoot = navigationPopToRoot
        
        bind()

        store.dispatch(userInfoRequest.get(parameter: UserInfoParameter(), disposeBag: disposeBag))
        store.dispatch(suicaInfoActionCreatable.get(parameter: SuicaInfoParameter(), disposeBag: disposeBag))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)    //navigationBarを隠す
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // storyboardで設定すると挙動がおかしくなるため
        previewSelectedViewFrame.isUserInteractionEnabled = false       //previewSelectedViewFrame側のtap動作を停止？

        //レイアウト系の処理
        //
        selectedView.snp.remakeConstraints({
            if #available(iOS 11.0, *) {
                $0.edges.equalTo(self.additionalSafeAreaInsets)
            } else {
                $0.edges.equalToSuperview()
            }
        })
        self.view.layoutIfNeeded()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch StoryboardSegue.Main(rawValue: segue.identifier!)! {
        case .toHome:
            let navi = segue.destination as! UINavigationController     //遷移先のController
            let next = navi.topViewController as! HomeViewController
            self.homeViewController = next                              //ホーム画面のViewController
            next.sideUserInfoKeeper = self
            next.sideCardInfoManager = self
            self.nowPositionKeeper = next
        case .toMenuList:
        //ざっくりtableViewの設定をしている
            if let menuListViewController = segue.destination as? UITableViewController {
                menuList = menuListViewController.tableView
                menuList?.delegate = self
                _ = menuList?.rx.setDelegate(self)
            }
        default :
            break
        }
    }

    private func bind() {
        //combineLatest: 複数の変数のいずれかが変更された場合にそれぞれの最新の値をまとめて受け取れるようになります。
        //               変数をバラバラに監視していた場合だと処理を複数箇所に書く必要がありますが、1つにまとめることでわかりやすくなります。
        Observable.combineLatest(store.lastName, store.firstName)
            .map { ($0.isNotEmpty && $1.isNotEmpty) ? $0 + " " +  $1 : NameStatus.noSet }   //map はイベントの各要素を別の要素に変換します。
            .bind(to: nameLabel.rx.text)                                                    //store.lastName,store.firstNameの値をnameLabel.rx.textに反映
            .disposed(by: disposeBag)

        store.mailAddress.asDriver(onErrorJustReturn: "")
            .distinctUntilChanged()
            .drive(mailLabel.rx.text)
            .disposed(by: disposeBag)

        //creditCards: クレジットカード情報, defaultCardSlot: デフォルトカードの配列番号?
        Observable.combineLatest(store.creditCards, store.defaultCardSlot)
            .filter { $0.1 != nil }
            .subscribe { [unowned self] in
                //クレジットカードの配列とデフォルトカードが設定されているかnilチェック？
                guard let creditCards = $0.element?.0, let defaultCardSlot = $0.element?.1 else { return }
                ApplicationStore.instance.dispatch(UpdateCreditCardDataAction(creditCards: creditCards, defaultCardSlot: defaultCardSlot))
                ApplicationStore.instance.dispatch(UpdateTaxiPaymentCardSlot(taxiPaymentCardSlot: ApplicationStore.instance.state.defaultCardSlot))
                if creditCards.isEmpty {
                    Alert.show(to: self, message: L10n.e003SideMenuAlertCredit, style: .ok)
                        .subscribe {
                            self.homeViewController?.performSegue(withIdentifier: StoryboardSegue.Home.toRegistCard.rawValue, sender: nil)
                        }
                        .disposed(by: self.disposeBag)
                }
            }
            .disposed(by: disposeBag)
        
        //NotificationCenter:イベントの検知系
        //アプリがフォアグラウンドになったことを通知
        NotificationCenter.default.rx.notification(NSNotification.Name.UIApplicationWillEnterForeground)
            .subscribe { [unowned self] _ in
                self.checkCardSlot()        //クレジットカード情報を更新(storeにアパッチしている)
                self.update()
            }
            .disposed(by: disposeBag)

        menuList?.rx.itemSelected
            .subscribe({ [unowned self] in
                self.selectedCellIndex.value = $0.element!.row
                self.otherInteractionDisabled()
            })
            .disposed(by: disposeBag)

        selectedCellIndex.asObservable()
            .filter { $0 != -1 }
            .subscribe({ [unowned self] in
                //seguecellかどうか調べている
                guard let cell = self.menuList?.cellForRow(at: IndexPath(row: $0.element!, section: 0)) as? SegueCell else { return }
                if cell.segue == "tokmApp" {    //フルクルcell
                    if self.canParking() {      //タクシーが呼べる場所かどうか調べる
                        self.openFulculApp()    //フルクルアプリ起動
                    } else {
                        Alert.show(to: self, title: L10n.error004CantRideAreaMessage, style: .ok)
                    }
                } else {
                    self.homeViewController?.performSegue(withIdentifier: cell.segue, sender: nil)      //home画面のperformSegueで飛ぶ
                    self.nextPayment = (cell.segue == StoryboardSegue.Home.toPayment.rawValue)          //お支払いcellをタップしたか調べている
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Animation.duration) {
                    self.resizeFullScreenView(switchButtonChangeLayer: true)
                }
            })
            .disposed(by: disposeBag)

        otherMenuButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.homeViewController?.performSegue(withIdentifier: StoryboardSegue.Home.toOtherMenu.rawValue, sender: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + Animation.duration) {
                    self.resizeFullScreenView(switchButtonChangeLayer: true)
                }
            })
            .disposed(by: disposeBag)

        //mergeの（）の中のobservableをまとめて通知？
        Observable.merge(nameLabel.rx.tapGesture().asObservable(), mailLabel.rx.tapGesture().asObservable(), nameMailOpeningView.rx.tapGesture().asObservable())
            .skip(3)          //現在値は無視(1で現在値なのでそれが3個分無視),変化だけを監視したいので
            .subscribe({ [unowned self] _ in
                self.otherInteractionDisabled()
                self.homeViewController?.performSegue(withIdentifier: StoryboardSegue.Home.toUserInfo.rawValue, sender: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + Animation.duration) {
                    self.resizeFullScreenView(switchButtonChangeLayer: true)
                }
            })
            .disposed(by: disposeBag)

        previewSelectedViewFrame.rx.tapGesture()            //viewのtapにイベントを追加？
            .when(.recognized)
            .subscribe({ [unowned self] _ in
                self.otherInteractionDisabled()
                self.resizeFullScreenView()
            })
            .disposed(by: disposeBag)

        openBrowserButton.rx.tap
            .subscribe({ _ in
                let url = URL(string: RingoSupport.feedbackURL)
                if UIApplication.shared.canOpenURL(url!) {
                    UIApplication.shared.open(url!, options: [:], completionHandler: nil)
                }
            })
            .disposed(by: disposeBag)
        
        store.suicaIdi
            .subscribe({
                ApplicationStore.instance.dispatch(RegistSuicaIdiAction(suicaIdi: $0.element!))
            })
            .disposed(by: disposeBag)
        
        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }
    
    private func openFulculApp() {
        guard let url = URL(string: OtherApp.fulcul) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            guard let url = URL(string: AppStore.fulcul) else {
                return
            }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    private func canParking() -> Bool {
        
        let nowPosition = nowPositionKeeper.read()
        let longitude = nowPosition.longitude
        let latitude = nowPosition.latitude
        
        if TaxiProhibitArea.Ginza.squareLatitudeSouth <= latitude && latitude <= TaxiProhibitArea.Ginza.squareLatitudeNorth && TaxiProhibitArea.Ginza.squareLongitudeWest <= longitude && longitude <= TaxiProhibitArea.Ginza.squareLongitudeEast {
            return false
        }
        
        return true
    }
    
    func updateUserInfo() {
        store.dispatch(userInfoRequest.get(parameter: UserInfoParameter(), disposeBag: disposeBag))
    }
    
    func checkCardSlot() {
        store.dispatch(paymentActionCreatable.get(parameter: PaymentCardInfoParameter(), disposeBag: disposeBag))
    }
    
    func update() {
        checkCardSlot()
    }
    
    func navigationPopToRoot() {
        navigationController?.popToRootViewController(animated: true)       //トップ画面に戻る
    }

    func resizePreviewView() {
        previewSelectedViewFrame.isUserInteractionEnabled = true
        toUserInfoInteractive(is: true)
        let animation = UIViewPropertyAnimator(duration: Animation.sideMenu, timingParameters: animationEase)
        animation.addAnimations {
            self.selectedView.snp.remakeConstraints({
                $0.edges.equalTo(self.previewSelectedViewFrame)
            })
            self.homeViewController?.menuButtonInfo.snp.remakeConstraints({
                $0.top.equalTo((self.homeViewController?.menuButtonInfo.superview?.snp.top)!).offset(0)
            })
            self.view.layoutIfNeeded()
        }
        animation.addCompletion { _ in
            self.selectedCellIndex.value = -1
        }
        animation.startAnimation()
    }

    func resizeFullScreenView(switchButtonChangeLayer: Bool = false) {
        previewSelectedViewFrame.isUserInteractionEnabled = false       //横のmapを押せなくしている
        let animation = UIViewPropertyAnimator(duration: Animation.sideMenu, timingParameters: animationEase)
        animation.addAnimations {
            self.selectedView.snp.remakeConstraints({       //全ての制約を解除する
                if #available(iOS 11.0, *) {
                    $0.edges.equalTo(self.additionalSafeAreaInsets)     //この指定されているものを解除
                } else {
                    $0.edges.equalToSuperview()
                }
            })
            self.homeViewController?.menuButtonInfo.snp.remakeConstraints({
                $0.top.equalTo((self.homeViewController?.menuButtonInfo.superview?.snp.top)!).offset(40)
            })
            self.view.layoutIfNeeded()
        }
        animation.addCompletion { _ in
            self.menuList?.isUserInteractionEnabled = true
            self.homeViewController?.menuButtonInfo.isUserInteractionEnabled = true
        }
        animation.startAnimation()
    }

    func otherInteractionDisabled() {
        menuList?.isUserInteractionEnabled = false      //tableviewのcellをタップできなくしている
        toUserInfoInteractive(is: false)
        previewSelectedViewFrame.isUserInteractionEnabled = false
    }
    
    func toUserInfoInteractive(is enable: Bool) {
        nameLabel.isUserInteractionEnabled = enable1            //nameLabelをタップできなくしている
        mailLabel.isUserInteractionEnabled = enable             //mailLabelをタップできなくしている
        nameMailOpeningView.isUserInteractionEnabled = enable   //viewをタップできなくしている
    }
}

extension SideMenuRootViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // 話し合いで%を決定 メニューは６なので
        return tableView.frame.height / CGFloat(6.0) * 0.82
    }
}

extension RxStore where AnyStateType == SideMenuViewState {
    
    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }

    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }.distinctUntilChanged()
    }

    var creditCards: Observable<[PaymentCardInfoEntity]> {
        return stateObservable.map { $0.creditCards ?? [] }
    }
    
    var defaultCardSlot: Observable<Int?> {
        return stateObservable.map { $0.defaultSlot }.distinctUntilChanged { $0 == $1 }
    }

    var mailAddress: Observable<String> {
        return stateObservable.map { $0.mailAddress }.distinctUntilChanged { $0 == $1 }
    }

    var lastName: Observable<String> {
        return stateObservable.map { $0.lastName }.distinctUntilChanged { $0 == $1 }
    }

    var firstName: Observable<String> {
        return stateObservable.map { $0.firstName }.distinctUntilChanged { $0 == $1 }
    }
    
    var docomoId: Observable<String> {
        return stateObservable.map { $0.docomoId }.distinctUntilChanged { $0 == $1 }
    }
    
    var suicaIdi: Observable<String> {
        return stateObservable.map { $0.suicaIdi }.distinctUntilChanged { $0 == $1 }
    }
}
