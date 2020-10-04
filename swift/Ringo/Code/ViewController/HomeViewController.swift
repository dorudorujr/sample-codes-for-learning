//
//  HomeViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/01/16.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import UIKit
import Foundation
import SnapKit
import GoogleMaps
import RxSwift
import RxCocoa
import RxGesture
import ReSwift
import ApplicationModel
import ApplicationConfig
import ApplicationLib

final class HomeViewController: UIViewController, NowPositionKeepable {

    @IBOutlet private weak var mapParentView: UIView!                       //mapが表示されているview
    @IBOutlet private weak var nearActionViewHeight: NSLayoutConstraint!    //mobilituActionView縦？の制約
    @IBOutlet private weak var mobilityActionView: UIScrollView!            //タクシーや自転車のリスト表示されているview
    @IBOutlet private weak var gradationView: UIView!                       //タクシーや自転車のリスト表示されているviewと画像があるviewをまとめたview
    @IBOutlet private weak var nowLocationButton: UIButton!                 //現在値表示ボタン
    @IBOutlet private weak var taxiButton: UIButton!                        //タクシーの画像したボタン
    @IBOutlet private weak var bikeButton: UIButton!                        //自転車の画像したボタン
    @IBOutlet private weak var foundationView: UIView!                      //リストが下がった時に残るview?
    @IBOutlet private weak var taxiBalloonButton: UIButton!                 //今はなきtaxiの画像の上に表示されている文字列
    @IBOutlet private weak var taxiBalloonLabel: UILabel!
    @IBOutlet private weak var bikeBalloonButton: UIButton!
    @IBOutlet private weak var bikeBalloonLabel: UILabel!
    @IBOutlet private weak var menuButton: UIButton!                        //左のメニューボタン
    @IBOutlet private weak var menuIconImage: UIImageView!                  //左のメニューボタンの画像
    @IBOutlet private weak var menuButtonShadow: UIView!

    var tagNum = 0
    var sideUserInfoKeeper: UserInfoKeepable!
    var sideCardInfoManager: CardInfoManageable!
    var nowPosition = CLLocationCoordinate2D()              //現在値？(CLLocationCoordinate2D:緯度経度)

    private var centerLocation = CLLocationCoordinate2D()
    private var selectedMarker: GMSMarker?
    private var nearActionHeightInitValue: CGFloat = 0.0
    private var selectedMobility: CGFloat = 0               //リストがtaxiなのかbikeなのかの判断材料
    private var locationManager: CLLocationManager?
    private var mapView: GMSMapView?
    private var markers = [GMSMarker]()
    private let tapMapSubject = PublishSubject<Void>()
    private let tapMarker = PublishSubject<GMSMarker>()
    private let locationAuthStatus = PublishSubject<Int32>()
    private var selectedBikeCell: PublishSubject<BikeInfoCell>?
    private var bikeRefresh: PublishSubject<Void>?
    private var bikeRefreshControl: UIRefreshControl?
    
    private var taxiMarkers = [GMSMarker]()

    //サイドメニューの情報?
    public  var menuButtonInfo: UIButton {
        return menuButton
    }

    private let store = RxStore(store: Store<HomeViewState>(reducer: HomeViewReducer.handleAction, state: nil))
    //bikeのマーカの場所取得
    private var requestCreator: HomeViewActionCreatable! {
        willSet {
            if requestCreator != nil {
                fatalError()
            }
        }
    }
    private var checkInRequestCreator: CheckInInfoActionCreatable! {
        willSet {
            if checkInRequestCreator != nil {
                fatalError()
            }
        }
    }
    private var tosRequestCreator: TermOfServiceActionCreatable! {
        willSet {
            if tosRequestCreator != nil {
                fatalError()
            }
        }
    }

    private var userStatusCreator: UserStatusActionCreatable! {
        willSet {
            if userStatusCreator != nil {
            fatalError()
            }
        }
    }
    //タクシーの表示関連
    private var vacantTaxiInfoCreator: VacantTaxiInfoActionCreatable! {
        willSet {
            if vacantTaxiInfoCreator != nil {
                fatalError()
            }
        }
    }

    private var userStatus: Int?

    private let disposeBag = DisposeBag()

    func inject(requestCreator: HomeViewActionCreatable, checkInRequestCreator: CheckInInfoActionCreatable, tosRequestCreator: TermOfServiceActionCreatable, userStatusCreator: UserStatusActionCreatable, vacantTaxiInfoRequestCreator: VacantTaxiInfoActionCreatable) {
        self.requestCreator = requestCreator
        self.checkInRequestCreator = checkInRequestCreator
        self.tosRequestCreator = tosRequestCreator
        self.userStatusCreator = userStatusCreator
        self.vacantTaxiInfoCreator = vacantTaxiInfoRequestCreator
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //サイドメニューのアニメーションの設定の関数を変数に登録？
        TransitionHelper.shared.homeVisible = visibleSideMenu

        parent?.addShadow()     //親viewに影を追加？
        nowLocationButton.addDropShadow(type: .nowLocationButton)
        taxiBalloonButton.addDropShadow(type: .balloonButton)
        bikeBalloonButton.addDropShadow(type: .balloonButton)

        menuButton.addCorner(corner: [.bottomRight, .topRight])     //メニューボタンを丸くしている!
        menuButtonShadow.addDropShadow(type: .menuButton)

        let gradientLayer = CAGradientLayer()               //グラデーションを設定
        gradientLayer.frame = self.view.bounds
        let color1 = UIColor(color: UIColor.gradesionGrey, alpha: Alpha.blur).cgColor
        let color2 = UIColor(color: UIColor.white, alpha: Alpha.blur).cgColor
        gradientLayer.colors = [color1, color2]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradationView.layer.insertSublayer(gradientLayer, at: 0)
        navigationController?.setNavigationBarHidden(true, animated: false)
        setNeedsStatusBarAppearanceUpdate()         //ステータスバーを更新

        nearActionHeightInitValue = nearActionViewHeight.constant   //constant:view間の距離

        locationManager = setupLocationManager(type: .authorizedWhenInUse)      //位置情報の機能を管理クラスを生成(typeはアプリ使用中のみ許可を得る場合)
        locationManager?.startUpdatingLocation()                                //位置情報取得開始

        createMapView()         //map生成
        bind()

        bikeRequest()           //bikeのピンの情報を更新
        taxiRequest()
        store.dispatch(checkInRequestCreator.get(parameter: CheckInInfoParameter(), disposeBag: disposeBag))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        switchTaxiBike(scroll: selectedMobility)        //bikeとtaxiのリストの切り替え関連、最初はtaxiタブを表示している

        store.dispatch(userStatusCreator.get(parameter: UserStatusParameter(), disposeBag: disposeBag))

        //UserDefaults:データの永続化
        //UserDefaults.standard.bool:データの読み込み
        let launchedBefore = UserDefaults.standard.bool(forKey: "launchedBefore")
        if launchedBefore && !isAuthLocation() {
            failureLocationAlert()      //位置情報取得失敗
        } else {
            bikeRequest()       //bikeのポート情報をRequest
            taxiRequest()
        }

        navigationController?.setNavigationBarHidden(true, animated: true)      //navigationbarを隠している
        if let statusbar = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            statusbar.backgroundColor = UIColor.clear
        }
        sideCardInfoManager.update()        //クレジットカード情報を更新
        store.dispatch(TermOfServiceNecessityResetAction())
        store.dispatch(tosRequestCreator.getConsent(parameter: TermOfServiceConsentParamter(), disposeBag: disposeBag))
        store.dispatch(checkInRequestCreator.get(parameter: CheckInInfoParameter(), disposeBag: disposeBag))
        store.dispatch(userStatusCreator.get(parameter: UserStatusParameter(), disposeBag: disposeBag))
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch StoryboardSegue.Home(rawValue: segue.identifier!)! {
        case .toBikeLocations:
            let next = segue.destination as! BikeListViewController
            next.store = store
            next.tapMarker = tapMarker
            next.nowPositionKeeper = self
            selectedBikeCell = next.selectedCell
            bikeRefresh = next.bikeRefresh
            bikeRefreshControl = next.bikeRefreshControl
        case .toTaxiView:
            let next = segue.destination as! TaxiViewController
            next.nowPositionKeeper = self
        case .toPaymentHistory:
            let navi = segue.destination as! UINavigationController
            let next = navi.topViewController as! PaymentHistoryViewController
            next.tagNum = tagNum
        case .toTermOfService:
            let navi = segue.destination as! UINavigationController
            let next = navi.topViewController as! TermOfServiceViewController
            next.fromHome = true
        case .toPayment:
            let navi = segue.destination as! UINavigationController
            let next = navi.topViewController as! PaymentViewController
            next.isCloseButtonHide = (userStatus == UserStatus.isUnpaid) || ApplicationStore.instance.state.creditCards.isEmpty
        case .toRegistCard:
            let navi = segue.destination as! UINavigationController
            let next = navi.topViewController as! RegisterCreditCardViewController
            next.state = .addCard
            next.emptyCardSlot = 1
            next.isCardEmpty = ApplicationStore.instance.state.creditCards.isEmpty
        case .toUserInfo:
            let navi = segue.destination as! UINavigationController
            let next = navi.topViewController as! UserInfoViewController
            next.sideUserInfoKeeper = sideUserInfoKeeper
        default:
            break
        }
    }

    public func visibleSideMenu() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Animation.duration) {
            TransitionHelper.shared.transitionIn()
        }
    }

    private func bind() {
        uiBind()
        logicBind()
    }

    private func uiBind() {
        taxiButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.selectedMobility = 0.0
                self.switchTaxiBike(scroll: 0.0)

            })
            .disposed(by: disposeBag)

        bikeButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.selectedMobility = 1.0
                self.switchTaxiBike(scroll: 1.0)
            })
            .disposed(by: disposeBag)

        tapMapSubject
            .subscribe({ [unowned self] _ in
                self.nearActionViewHeightAnimated(height: 0.0)      //mapを他のところをtapしたら下のリストが閉じる
            })
            .disposed(by: disposeBag)

        nowLocationButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.locationManager?.startUpdatingLocation()
            })
            .disposed(by: disposeBag)

        menuButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.menuButton.isUserInteractionEnabled = false
                TransitionHelper.shared.transitionIn()      //なぜかコメントアウトするとサイドメニューが開かなくなる
            })
            .disposed(by: disposeBag)

        mapView?.rx
            .anyGesture(.tap(), .swipe([.up, .down, .left, .right]))        //複数のジェスチャーを登録
            .when(.recognized)
            .subscribe({ [unowned self] _ in
                self.bikeRequest(distanceCheck: true)
                self.taxiRequest()
            })
            .disposed(by: disposeBag)

        mobilityActionView.rx.swipeGesture(.left)
            .filter { _ in self.selectedMobility != 1.0 }
            .subscribe({ [unowned self] _ in
                self.selectedMobility = 1.0
                self.switchTaxiBike(scroll: 1.0)
            })
            .disposed(by: disposeBag)

        mobilityActionView.rx.swipeGesture(.right)
            .filter { _ in self.selectedMobility != 0.0 }
            .subscribe({ [unowned self] _ in
                self.selectedMobility = 0.0
                self.switchTaxiBike(scroll: 0.0)
            })
            .disposed(by: disposeBag)

        mobilityActionView.rx.didScroll     //スクロールしたことをキャッチ
            .filter { self.mobilityActionView.contentOffset.x == 0.0 && self.selectedMobility == 1.0 }
            .subscribe({ [unowned self] _ in
                self.mobilityActionView.contentOffset = CGPoint(x: self.mobilityActionView.contentSize.width * self.selectedMobility, y: 0)
            })
            .disposed(by: disposeBag)

        let taxiBalloonStream = taxiBalloonButton.rx.tap.map { 0 }
        let bikeBalloonStream = bikeBalloonButton.rx.tap.map { 1 }
        Observable.merge(taxiBalloonStream, bikeBalloonStream)
            .subscribe({ [unowned self]  in
                self.tagNum = $0.element!
                TransitionHelper.shared.transitionIn()
                self.performSegue(withIdentifier: StoryboardSegue.Home.toPaymentHistory.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)

        let taxiStream = store.taxiCheckIn.map { [unowned self] in (count: $0, textLabel: self.taxiBalloonLabel, button: self.taxiBalloonButton) }
        let bikeStream = store.bikeCheckIn.map { [unowned self] in (count: $0, textLabel: self.bikeBalloonLabel, button: self.bikeBalloonButton) }

        //表示するかどうかを決めている
        Observable.merge(taxiStream, bikeStream)
            .subscribe({
                let cnt = $0.element!.count
                let textLabel = $0.element!.textLabel!
                let button = $0.element!.button
                textLabel.text = "\(cnt)台チェックイン中"
                UIView.animate(withDuration: Animation.duration) {
                    textLabel.alpha = (cnt == 0) ? 0.0 : 1.0
                    button?.alpha = (cnt == 0) ? 0.0 : 1.0
                }
            })
            .disposed(by: disposeBag)
    }

    private func logicBind() {
        //アプリがフォアグラウンドになったことを通知
        let willEnterForegroundStream = NotificationCenter.default.rx.notification(NSNotification.Name.UIApplicationWillEnterForeground)
        // バックグラウンドから遷移してきたときに呼ばれる
        let didBecomeActiveStream = NotificationCenter.default.rx.notification(NSNotification.Name.UIApplicationDidBecomeActive)

        Observable.merge(willEnterForegroundStream, didBecomeActiveStream)
            .subscribe { [unowned self] _ in
                if !self.isAuthLocation() {
                    self.failureLocationAlert()     //位置情報取得失敗アラート
                } else {
                    if let alert = UIApplication.topViewController() as? UIAlertController {
                            alert.dismiss(animated: false, completion: nil)     //アラートを閉じる
                    }
                }
                self.sideCardInfoManager.update()       //クレジットカード情報を更新
            }
            .disposed(by: disposeBag)

        Observable.merge(willEnterForegroundStream, didBecomeActiveStream)
            .subscribe { [unowned self] _ in
                self.bikeRequest()
                self.taxiRequest()
            }
            .disposed(by: disposeBag)

        // bikepointを3分に一度リフレッシュ
        Observable<Int>
            .interval(180.0, scheduler: MainScheduler.instance)     //一定間隔で処理を行う
            .subscribe { [unowned self] _ in
                self.bikeRequest()
            }
            .disposed(by: disposeBag)
        
        //taxipointを10秒に一度リフレッシュ
        Observable<Int>
            .interval(10.0, scheduler: MainScheduler.instance)
            .subscribe { [unowned self] _ in
                self.taxiRequest()
            }
            .disposed(by: disposeBag)

        bikeRefresh?
            .subscribe({ [unowned self] _ in
                self.bikeRequest()
            })
            .disposed(by: disposeBag)

        //tapしたマーカは別の変数で別の処理がある。
        //今回は下のリストの列をタップしたらmap上のマーカが移動する処理
        selectedBikeCell?
            .subscribe({ [unowned self] (cell) in
                if let marker = self.markers.first(where: { $0.title == cell.element!.pointName }) {
                    self.changeMarkerIcon(marker: marker)
                }
            })
            .disposed(by: disposeBag)

        //クレジットカード情報を登録しているかどうか？
        store.userStatus// userStatus: 1 で未収情報無し, 2 で未収情報あり
            .subscribe { [unowned self] in
                self.userStatus = $0.element!
                if $0.element == UserStatus.isUnpaid {// TODO:なぜかfilterでは通らないのでif文にしてるがわかればfilterで対応する
                    self.performSegue(withIdentifier: StoryboardSegue.Home.toPayment.rawValue, sender: nil)
                }
            }
            .disposed(by: disposeBag)

        //onErrorJustReturn:エラーなら空配列を返却
        store.locationEntity.asDriver(onErrorJustReturn: [])
            .do { self.markers.removeAll() }        //全削除
            .asObservable()
            .subscribe({ [unowned self] in
                self.mapView?.clear()               //mapViewのマーカを全削除？
                $0.element?.forEach { data in
                    self.createMarker(data: data)   //関数によってマーカ&markersを作成
                }
            })
            .disposed(by: disposeBag)
        
        store.emptyVehicleList.asDriver(onErrorJustReturn: [])
            .do { self.taxiMarkers.removeAll() }
            .asObservable()
            .subscribe({ [unowned self] in
                self.taxiMarkers.forEach { data in
                    data.map = nil
                }
                $0.element?.forEach { data in
                    self.taxiCreateMarker(data: data)
                }
            })
            .disposed(by: disposeBag)

        store.necessity
            .filter { $0 == 1 }
            .subscribe { [unowned self] _ in
                self.performSegue(withIdentifier: StoryboardSegue.Home.toTermOfService.rawValue, sender: nil)   //アカウント作成の画面
            }
            .disposed(by: disposeBag)

        store.isLoading
            .filter { !$0 }
            .subscribe({ [unowned self] _ in
                self.bikeRefreshControl?.endRefreshing()
            })
            .disposed(by: disposeBag)

        locationAuthStatus
            .filter { !self.isAuthLocation(status: CLAuthorizationStatus(rawValue: $0)!) }
            .subscribe({ [unowned self] _ in
                let launchedBefore = UserDefaults.standard.bool(forKey: "launchedBefore")
                if launchedBefore {
                    self.failureLocationAlert()
                } else {
                    UserDefaults.standard.set(true, forKey: "launchedBefore")
                }
            })
            .disposed(by: disposeBag)
        
        store.errorMsg
            .filter { $0.isNotEmpty }
            .subscribe({ [unowned self] in
                let error = $0.element
                Alert.show(to: self, message: L10n.error006CantGetVacantTaxiMessages, style: .custom(buttons: [(.ok, .default)]))
                    .subscribe ()
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)
        
        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }

    private func bikeRequest(distanceCheck: Bool = false) {
        //ピクセル座標を緯度経度に変換
        //mapViewのcenterがおかしくないか調べている
        guard let center = mapView?.projection.coordinate(for: (mapView?.center)!) else { return }
        //下記は2点間の距離の公式
        if distanceCheck {
            let latitude = (centerLocation.latitude - center.latitude) / onekm.latitude         //緯度
            let longitude = (centerLocation.longitude - center.longitude) / onekm.longitude
            let distance = sqrt(pow(latitude, 2) + pow(longitude, 2))
            // 1km以上移動していなければ
            if abs(distance) < 1.0 {
                return
            }
        }
        //移動していたら再度bikeのポイントを再描画
        centerLocation = center
        let param = BikeLocationInfoParameter(centerLongitude: Float(center.longitude), centerLatitude: Float(center.latitude))
        store.dispatch(requestCreator.get(parameter: param, disposeBag: disposeBag))
    }
    
    private func taxiRequest() {
        guard let center = mapView?.projection.coordinate(for: (mapView?.center)!) else { return }
        let param = VacantTaxiInfoParameter(token: Environment.instance.kmApiToken, currentLongitude: center.longitude, currentLatitude: center.latitude, radius: 1000)//kmテスト用
        store.dispatch(vacantTaxiInfoCreator.get(parameter: param, disposeBag: disposeBag))
    }

    private func createMapView() {
        // LocationのPermmisionが許可されない場合は東京駅を刺すように暫定処理
        let camera = GMSCameraPosition.camera(withLatitude: 35.681429, longitude: 139.767030, zoom: 15.0)
        mapView = GMSMapView.customSetup(parent: mapParentView, camera: camera)
        mapView?.delegate = self
        mapView?.snp.makeConstraints({      //制約を付加
            //Superviewのtop,left,bottom,rightに合わせて
            $0.edges.equalToSuperview()
        })
    }

    private func createMarker(data: BikeLocationInfoEntity) {
        let position = CLLocationCoordinate2D(latitude: data.portLatitude, longitude: data.portLongitude)
        let marker = GMSMarker(position: position)
        marker.title = data.portName
        marker.snippet = MarkerType.cycle.rawValue
        marker.icon = changeSizeImage(target: Asset.imgPinGreen.image)
        marker.map = mapView
        markers.append(marker)
    }
    
    private func taxiCreateMarker(data: VacantTaxiInfoEntity) {
        let position = CLLocationCoordinate2D(latitude: Double(data.currentVehicleLatitude)!, longitude: Double(data.currentVehicleLongitude)!)
        let marker = GMSMarker(position: position)
        let taxiImage = Asset.imgTaxi01.image
        marker.snippet = MarkerType.taxi.rawValue
        marker.isFlat = true
        marker.rotation = Double(data.bearing)! + 90 //画像が -90 の角度であったため調整
        marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        marker.icon = taxiImage
        marker.map = mapView
        taxiMarkers.append(marker)
    }

    private func switchTaxiBike(scroll: CGFloat) {
        self.nearActionViewHeightAnimated(height: self.nearActionHeightInitValue)

        //以下snpはボタン処理
        let center = (scroll == 0.0) ? taxiButton : bikeButton
        let end = (scroll != 0.0) ? taxiButton : bikeButton
        view.setNeedsLayout()
        center?.snp.remakeConstraints({
            $0.size.equalTo((center?.bounds.size)!)
            $0.bottom.equalTo(self.mobilityActionView.snp.top).offset(-5)
            $0.centerX.equalToSuperview()
        })
        end?.snp.remakeConstraints({
            $0.size.equalTo((end?.bounds.size)!)
            $0.bottom.equalTo(self.mobilityActionView.snp.top).offset(-5)
            if end == self.taxiButton {
                $0.right.equalTo(self.foundationView.snp.left).offset(40)
            } else {
                $0.left.equalTo(self.foundationView.snp.right).offset(-40)
            }
        })
        UIView.animate(withDuration: Animation.duration, animations: {
            self.view.layoutIfNeeded()      //画面の再描画？
            self.mobilityActionView.contentOffset = CGPoint(x: self.mobilityActionView.contentSize.width * scroll, y: 0)
        })
    }

    //多分タブが開かれるとmapViewがずれる処理
    private func nearActionViewHeightAnimated(height: CGFloat) {
        UIView.animate(withDuration: Animation.duration, animations: {
            self.nearActionViewHeight.constant = height         //タブエリアの高さ指定
            self.mapView?.padding = UIEdgeInsets(top: 0, left: 0, bottom: height + 30, right: 0)
            self.view.layoutIfNeeded()                          //view再描画？
            self.mobilityActionView.layoutIfNeeded()            //view再描画？
        })
    }

    private func isAuthLocation(status: CLAuthorizationStatus = CLLocationManager.authorizationStatus()) -> Bool {  //authorizationStatus:位置情報が上手くいったかのステータスを返却
        switch status {
        case .notDetermined, .denied, .restricted:
            return false
        default: return true
        }
    }

    private func failureLocationAlert() {
        Alert.show(to: self, title: L10n.error002CantGetPositionTitle, message: L10n.error002CantGetPositionMessage, style: .custom(buttons: [(.setting, .default)]))
            .subscribe {
                guard let url = URL(string: UIApplicationOpenSettingsURLString) else { return }
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            .disposed(by: self.disposeBag)
    }

    private func changeMarkerIcon(marker: GMSMarker) {
        //下記コード'selectedMarker = marker'で値を代入
        //一個前tapしたMarkerが存在するならその前回のMarkの画像を代入
        if let selected = selectedMarker {
            selected.icon = changeSizeImage(target: Asset.imgPinGreen.image)
        }
        marker.icon = changeSizeImage(target: Asset.imgPinYellow.image)
        selectedMarker = marker
        let camera = GMSCameraPosition.camera(withLatitude: marker.position.latitude, longitude: marker.position.longitude, zoom: 17.0)
        mapView?.animate(to: camera)
    }

    private func changeSizeImage(target: Image) -> Image? {
        let size = CGSize(width: target.size.width * 0.8, height: target.size.height * 0.8)
        UIGraphicsBeginImageContext(size)
        target.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    func read() -> CLLocationCoordinate2D {
        return nowPosition
    }

}

extension HomeViewController: GMSMapViewDelegate {

    //マーカのtap検出
    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        
        if marker.isMatchTaxi() {
            return true
        }
        
        changeMarkerIcon(marker: marker)
        tapMarker.onNext(marker)
        switchTaxiBike(scroll: 1.0)
        return true
    }

    //mapを他のところをtapしたら検知
    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        tapMapSubject.onNext(Void())
    }

    //ユーザーの操作、地図のアニメーションがアイドル状態になった時に動作するメソッド
    func mapView(_ mapView: GMSMapView, idleAt cameraPosition: GMSCameraPosition) {
        bikeRequest(distanceCheck: true)
        taxiRequest()
    }

    //位置情報は、変化するたびにCLLocationManagerDelegateプロトコルの
    //locationManager(_:didUpdateLocations:)が呼ばれ、ここで現在位置を取得できます。
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            centerLocation = location.coordinate
            nowPosition = location.coordinate
            let param = BikeLocationInfoParameter(centerLongitude: Float(location.coordinate.longitude), centerLatitude: Float(location.coordinate.latitude))
            store.dispatch(requestCreator.get(parameter: param, disposeBag: disposeBag))    //bikeのポート情報取得

            let defaultLocation = nearActionViewHeight.constant == 0.0
            var latitude = location.coordinate.latitude
            if !defaultLocation {
                latitude -= 0.0006
            }
            let camera = GMSCameraPosition.camera(withLatitude: latitude, longitude: location.coordinate.longitude, zoom: 17.0)     //mapの表示を現在位置にしている
            mapView?.animate(to: camera)
        }
        locationManager?.stopUpdatingLocation()
    }

    //位置情報取得に関する許可が変更された際に、locationManager(_:didChangeAuthorization:)でその状態を受け取ることができます。
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationAuthStatus.onNext(status.rawValue)
    }
}

extension RxStore where AnyStateType == HomeViewState {

    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }

    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }
    }

    //bikeポートの情報
    var locationEntity: Observable<[BikeLocationInfoEntity]> {
        return stateObservable.map { $0.locationEntity ?? [] }.distinctUntilChanged { $0 == $1 }
    }
    
    var emptyVehicleList: Observable<[VacantTaxiInfoEntity]> {
        return stateObservable.map { $0.emptyVehicleList ?? [] }
    }
    
    var dispatchFlag: Observable<Bool> {
        return stateObservable.map { $0.dispatchFlag }
    }

    //タクシーがチェックインかどうかのフラグ
    var taxiCheckIn: Observable<Int> {
        return stateObservable.map { $0.taxiCheckIn }
    }

    var bikeCheckIn: Observable<Int> {
        return stateObservable.map { $0.bikeCheckIn }
    }

    var userStatus: Observable<Int?> {
        return stateObservable.map { $0.paymentStatus }.distinctUntilChanged { $0 == $1 }
    }

    //アップデータチェックに使用
    var necessity: Observable<Int> {
        return stateObservable.map { $0.necessity ?? -1 }.distinctUntilChanged()
    }
    
    var errorMsg: Observable<[VacantTaxiInfoErrorEntity]> {
        return stateObservable.map { $0.errorMsg ?? [] }
    }
}
