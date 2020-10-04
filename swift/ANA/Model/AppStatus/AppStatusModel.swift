//
//  AppStatusModel.swift
//  AnaMile
//
//  Created by 西村 拓 on 2015/11/05.
//  Copyright © 2015年 TakuNishimura. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa
import FirebasePerformance
import RealmSwift

class AppStatusModel: CocosStatus {
    /// Singleton
    static let shared = AppStatusModel()

    /// applicationState
    var applicationState = Variable(UIApplication.State.inactive)

    /// Login State
    var loginState = Variable(LoginState.isNotLogin)

    /// SettingView State
    var isOpenSettingView = Variable(false)

    /// User
    let userModel = UserModel()
    
    /// DMID
    let dmid = DmidModel()

    /// Service
    let service = ServiceModel()

    /// Info
    let info = InfoModel()

    /// QR
    let qr = QRModel()

    /// Rx
    let disposeBag = DisposeBag()
    
    let cotentsEntityArray = ContentViewEntity.map()

    /// GL側にCocosViewステータスをわたすためのパラメーター
    var cocosViewStatus = Variable(CocosViewStatus.normal)

    /// ログイン演出準備完了ステータス
    private(set) var isReadyToLogin = Variable(false)

    /// ログイン演出完了ステータス
    private(set) var didFinishLoginAnimation = Variable(false)
    private(set) var didFinishNativeLoginAnimation = Variable(false)
    
    /// Menu開けたら動画表示しない、すぐRecoverUIModeに変更（SettingからMenu開ける時だけ）
    private(set) var menuRecoverUIMode = Variable(false)

    /// initialViewのポジションインデックス
    var initialIndexHorizontal = 0

    /// 現在の視点階層の深さ
    var viewPointDepth = Variable(CGFloat(0.0))

    /// 現在の視点階層のX位置
    var viewPointHorizontal = Variable(CGFloat(0.0))

    /// メインコンテンツのアルファ値
    var mainContentsAlpha = Variable(CGFloat(1.0))

    /// Menu ボタンのselectステータス
    var menuButtonSelected = BehaviorRelay(value: false)

    /// 移動先X位置（移動先があるときにdefaultViewPointHorizontalの値を指定）
    var destinationViewX = Variable(CGFloat(0.0))

    /// Web表示URL
    var bottomWebViewUrl: Variable<URL?> = Variable(nil)
    
    /// modal Web表示URL
    var modalWebViewUrl: Variable<URL?> = Variable(nil)

    /// RecommendListの表示リクエスト
    var showRecommendList = Variable(false)
    
    /// Searchの表示リクエスト
    var showSearch = Variable(false)

    /// ショップのライフスタイル/トラベル表示切り替え要求
    var showShopGroup = Variable( (group: ShopGroupType.lifeStyle, category:"") )

    /// 現在表示中の画面名（Analyticsに使用）
    var currentDisplayedViewName = ""

    /// 最終更新時刻
    private(set) var lastUpdateTime = Variable<Date?>(UserDefaults.standard.date(forKey: .lastUpdatedAt))

    /// info最終閲覧時刻
    private(set) var lastReadInfoTime = Variable<Date?>(UserDefaults.standard.date(forKey: .lastReadInfoAt))
    
    /// 目標設定最終時刻
    private(set) var lastSetMileGoalTime = Variable<Date?>(UserDefaults.standard.date(forKey: .lastSetMileGoalAt))
    
    /// 目標設定動画.目標設定resetしたらこれがtrueになる.そして毎回Menu再生成する時trueになる（目標設定したら）
    /// scrollviewでgoalcellがvisible判定用。判定成功したらfalseになる.
    private(set) var shouldShowMileAnime = Variable(false)
    
    /// 目標設定動画(scrollviewでgoalcellがvisible成功したら、trueになる。動画完了したらfalseになる)
    private(set) var shouldStartShowMileAnime = Variable(false)

    override init () {
        super.init()
        
        setDeviceSpec()

        bind()
    }

    // MARK: - Rx
    private final func bind() {
        // 画面X軸連動
        viewPointHorizontal.asObservable()
            .distinctUntilChanged()
            .subscribe(onNext: { [unowned self] e in

                // 現在のX座標
                let positionX = e / (UIConst.contentsWidth + UIConst.contentsMargin)

                // 基準となるViewの座標と比較した値
                let adjustedX = positionX  - CGFloat(self.initialIndexHorizontal)

                // 現在の指定の深さの設定値
                self.viewPointDepth.value = CGFloat(abs(adjustedX))

                // Cocos連携用の値を格納
                AppStatusModel.setOffsetX(positionX)
            })
            .disposed(by: disposeBag)

        // CocosViewStatus
        cocosViewStatus.asObservable()
            .subscribe(onNext: { CocosStatus.setView($0.rawValue) })
            .disposed(by: disposeBag)

        // status更新
        userModel.user.asObservable()
            .filterNil()
            .subscribe(onNext: {[unowned self] _ in
                AppStatusModel.shared.userModel.saveMillionMiler(MillionMilerType.currentStatus(user: self.userModel.user.value))
            })
            .disposed(by: disposeBag)

        // info最終閲覧日時をuserDefaultsに保存
        lastReadInfoTime.asObservable()
            .filterNil()
            .subscribe(onNext: {
                UserDefaults.standard.set($0, forKey: .lastReadInfoAt)
            }).disposed(by: disposeBag)
        
        // goal最終設定日時をuserDefaultsに保存
        lastSetMileGoalTime.asObservable()
            .filterNil()
            .subscribe(onNext: {
                UserDefaults.standard.set($0, forKey: .lastSetMileGoalAt)
            }).disposed(by: disposeBag)
        
        // lastUpdateTimeをuserDefaultsに保存
        lastUpdateTime.asObservable()
            .filterNil()
            .subscribe(onNext: {
                UserDefaults.standard.set($0, forKey: .lastUpdatedAt)
            }).disposed(by: disposeBag)
    }
    
    private final func setDeviceSpec() {
        // 端末スペック
        switch AppInfoUtil.deviceType() {
        case .iPhone4_1, .iPhone5_1, .iPhone5_2, .iPhone5_3, .iPhone5_4, .iPhone6_1, .iPhone6_2, .iPhone7_1, .iPhone7_2:
            CocosStatus.setDeviceSpecLow(true)
        default:
            CocosStatus.setDeviceSpecLow(false)
        }
    }

    /// メインコンテンツアルファコントロール
    final func animateContentsAlpha(to alpha: CGFloat) {
       /// ホームアルファコントロール
        UIView.animate(withDuration: 0.4) { [unowned self] in
            self.mainContentsAlpha.value = alpha
        }
    }
    
    /// ログインAPIと経済圏APIをセットでたたく
    final func login(parameter: UserParameter) -> Observable<(Void?, Void?, Void?, Void?)> {
        // リロードのAPI
        let obserber = Observable
            .zip(
                AppStatusModel.shared.userModel.complete.asObservable().filter { $0 != nil },
                AppStatusModel.shared.dmid.complete.asObservable().filter { $0 != nil },
                AppStatusModel.shared.service.complete.asObservable().filter { $0 != nil },
                AppStatusModel.shared.info.complete.asObservable().filter { $0 != nil }
                ) { ($0, $1, $2, $3) }

        userModel.login(parameter: parameter)
        dmid.udpate()
        service.udpate()
        info.getLatestInfo()

        return obserber
    }

    /// ログインAPI取得完了後、ログイン演出の準備を開始する
    //// アニメーション周りの準備を行っている？
    final func startMonitoringReadyToLogin(auto: Bool) {
        let trace = Performance.startTrace(name: "Login Effects Prepare")
        
        // パラメータリセット
        isReadyToLogin.value = false
        didFinishLoginAnimation.value = false
        didFinishNativeLoginAnimation.value = false
        
        trace?.stop()
        
        // ログイン演出準備監視
        startMonitoringReady {
            AppStatusModel.shared.isReadyToLogin.value = true
        }
        
        let cocosTimeTrace = Performance.startTrace(name: "Cocos Prepare and Login Animation")

        // ログイン演出準備開始
        // Trigger cocos create first cardFace
        // CardFace情報はUserModel.updateStatus(:)時にすでにcocosに渡した
        cocosViewStatus.value = (auto) ? .autoLogin : .login

        // ログイン演出アニメーション終了フラグ監視
        startMonitoringFinishLoginAnimation {
            AppStatusModel.shared.didFinishLoginAnimation.value = true
            cocosTimeTrace?.stop()
        }
    }

    /// リプレイストリガー引いた
    final func startMonitoringFinishReplace() {
        // パラメータリセット
        didFinishLoginAnimation.value = false

        // ログイン演出アニメーション終了フラグ監視
        startMonitoringFinishLoginAnimation {
            AppStatusModel.shared.didFinishLoginAnimation.value = true
        }
        
        // Trigger cocos update cardFace
        // CardFace情報はUserModel.updateStatus(:)時にすでにcocosに渡した
        AppStatusModel.shared.cocosViewStatus.value = .replace
    }

    /// 言語別表示タイプの更新
    final func updateViewType() {
        guard let regionId = LanguageStatusModel.fetchRegionId() else { return }
        LanguageStatusModel.updateViewType(regionId: regionId)
    }

    // MARK: - Perpetuate
    
    /// 最終更新時刻保存
    final class func updateLastUpdateTime() {
        AppStatusModel.shared.lastUpdateTime.value = Date()
    }

    /**
     永続化されたデータを復元する

     - returns: 正常に復元が完了したらtrueを返す
     */
    @discardableResult      //// _ = fetchKeyChainData()としなくて済むようになる(返り値を使わなくて良くなる)
    ////キーチェーンにaccountとpasswordが存在するか確認
    final func fetchKeyChainData() -> Bool {
        if userModel.loadUser() && qr.loadQRString() {
            return true
        }

        return false
    }
    
    /// お気に入りデータをRealmから復元する
    final func fetchFavouriteData() {
        service.loadFavouriteShopList()
    }

    /// 保存されている情報をすべて破棄する
    final func clear() {
        lastSetMileGoalTime.value = nil
        lastReadInfoTime.value = nil
        lastUpdateTime.value = nil
        info.clear()
        cleanStatusModelFlag()
        GreetingFlagHelper.deleteAllFlag()
        NeighborHelper.reset()
        MileGoalHelper.removeGoalInfo()
        UserModel.deleteUser()
        QRModel.deleteQRString()
        ViewedShopEntity.clear()
        FavShopEntity.clear()
    }
    
    private final func cleanStatusModelFlag() {
        UserDefaults.standard.removeObject(forKey: .lastSetMileGoalAt)
        UserDefaults.standard.removeObject(forKey: .lastReadInfoAt)
    }

    // MARK: - Util
    
    func updateCocosCardFace(_ cardFaceType: UserEntity.CardFaceType, mileGraphData: NSArray) {
        CocosStatus.updateCardFaceType(UInt32(cardFaceType.cocosCardFaceType()), graphData: mileGraphData as? [Any])
    }
}

// MARK: Enum
extension AppStatusModel {
    /**
     ログイン状態管理用
     
     - isNotLogin:     未ログイン状態
     - isTryLogin:     ログインボタン押下 ~ ログイン演出完了
     - isTryAutoLogin: オートログイントリガー発火 ~ ログイン演出完了
     - isTryUpdate:    設定画面の更新ボタン押下 ~ ステータス更新完了
     - isLogin:        ログイン中
     - isOfflineMode:  オフラインモードでキーチェーンデータを表示している状態
     */
    enum LoginState {
        case isNotLogin
        case isTryLogin
        case isTryAutoLogin
        case isTryUpdate
        case isTryFetch
        case isLogin
        case isAutoLogin
        case isOfflineMode
        case isCheckingVersion
    }
    
    /**
     リターンコード一覧
     
     - Success:          ログイン成功
     - ValidationError:  送信パラメータのバリデーションチェックエラー
     - AccountError:     会員番号とパスワードの組み合わせが一致しない
     - AccountLockError: 認証エラーを10回以上間違え、アカウントロックされている
     - NotFoundError:    会員番号に該当するユーザーが存在しない
     - UnKnown:          不明なエラー
     - ServiceError:     サービス画面が閲覧不可（ショップリスト0件）
     */
    enum ReturnCodeType: String {
        case Success = "0"
        case ValidationError = "101"
        case AccountError = "201"
        case AccountLockError = "210"
        case NotFoundError = "301"
        case ServiceError = "1001"
        case UnKnown = "999"
        
        // エラーメッセージのローカライズKey
        func localizedKeyDescriptionKey() -> String {
            switch self {
            case .Success:
                return ""
            case .ValidationError:
                return String(localizedKey: "ErrorLoginError101")
            case .AccountError:
                return String(localizedKey: "ErrorLoginError201")
            case .AccountLockError:
                return String(localizedKey: "ErrorLoginError210")
            case .NotFoundError:
                return String(localizedKey: "ErrorLoginError301")
            case .UnKnown:
                return String(localizedKey: "ErrorLoginError999")
            case .ServiceError:
                return String(localizedKey: "ComNodataText")
            }
        }
        
        func code() -> Int {
            return Int(self.rawValue)!
        }
    }
    
    /**
     ミリオンマイラータイプ
     
     - A050: ライフタイムANA分が50万以上
     - A100: ライフタイムANA分が100万以上
     - A200: ライフタイムANA分が200万以上
     - A300: ライフタイムANA分が300万以上
     - L100: ライフタイム提携会社との合計が100万以上
     - NONE: 非ミリオンマイラー
     */
    enum MillionMilerType: String {
        case A050
        case A100
        case A200
        case A300
        case L100
        case NONE
        
        /**
         ライフタイムステータスからミリオンマイラータイプ取得
         */
        static func currentStatus(user: UserEntity?) -> MillionMilerType {
            guard let user = user else {
                return .NONE
            }
            return parseStatus(user)
        }
        
        /**
         データからミリオンマイラータイプ取得
         */
        static func extractUserStatus(_ user: UserEntity?) -> MillionMilerType {
            guard let user = user else {
                return .NONE
            }
            return parseStatus(user)
        }
        
        private static func parseStatus(_ user: UserEntity) -> MillionMilerType {
            if let result = MillionMilerType(rawValue: user.lifeTimeStatusANA) {
                return result
            }
            
            if MillionMilerType(rawValue: user.lifeTimeStatus) != nil {
                return .L100
            } else {
                return .NONE
            }
        }
        
    }
    
    /// CocosViewStatus
    enum CocosViewStatus: Int32 {
        case normal = 0
        case login
        case autoLogin
        case showQR
        case showWebView
        case centerBlur
        case logout
        case replace
    }
}

// MARK: Realm migration
extension AppStatusModel {
    // Realm schema version管理
    enum RealmSchemaVersion: UInt64 {
        case initial = 1 // 初期
        case viewedShop = 2 // ShopEntityForRealmカラム追加(addedAtAppVersion), App version 1.3.2
    }
    
    // Realm schema version更新するたびにここを更新
    static var currentSchemaRealmVersion: RealmSchemaVersion {
        return .viewedShop
    }
    
    class func migration() {
        let currentRealmVersion = AppStatusModel.currentSchemaRealmVersion.rawValue
        Realm.Configuration.defaultConfiguration = Realm.Configuration(schemaVersion: currentRealmVersion, migrationBlock: { (migration, oldVersion) in
            // ShopEntityForRealm.addedAtAppVersion追加と初期値付与
            if oldVersion < RealmSchemaVersion.viewedShop.rawValue {
                migration.enumerateObjects(ofType: ViewedShopEntity.className(), { (_, new) in
                    guard let new = new else { return }
                    // 1.3.2以前の履歴
                    new["addedAtVersion"] = Int(RealmSchemaVersion.initial.rawValue)
                })
            }
            // 追加のmigration処理....
            
        })
    }
}
