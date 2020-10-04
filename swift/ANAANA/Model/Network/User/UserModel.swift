//
//  UserModel.swift
//  AnaMile
//
//  Created by 西村 拓 on 2015/12/17.
//
//

import UIKit
import RxSwift
import Alamofire
import Firebase
import FirebasePerformance
import KeychainAccess
import ObjectMapper

/// ユーザー情報管理モデル
class UserModel: RequestBase {

    /// ユーザー情報Entity
    final let user: Variable<UserEntity?> = Variable(nil)
    
    /// TODO: とりあえずここで
    final let mileGoalEntity: Variable<MileGoalEntity?> = Variable(MileGoalHelper.fetchGoalEntity())
    
    /// TODO: とりあえずここで
    final let goalMile: Variable<Int?> = Variable(MileGoalHelper.fetchGoalMile())
    
    /// API通信完了flg
    final let complete: Variable<Void?> = Variable(nil)

    /// エラー
    final let error: Variable<NSError?> = Variable(nil)
    
    /// CardFace変化比較用
    private var lastCardfaceType: UserEntity.CardFaceType = UserEntity.cachedUser?.cardFaceType ?? .normal
    
    /// キャッシュしたユーザー情報
    private let cachedUser: UserEntity? = UserEntity.cachedUser
    
    /// ミリオンマイラー判別
    var isMillionMiler: Bool {
        guard let savedMillionMiler = savedMillionMiler else { return false }
        switch savedMillionMiler {
        case .A100, .A200, .A300:
            return true
        default:
            return false
        }
    }
    
    /// ログイン判定
    var isLogined: Bool {
        return user.value != nil
    }

    /// ログインリクエスト
    func login(parameter: UserParameter) {
        let trace = Performance.startTrace(name: "Auto Login")
        error.value = nil
        complete.value = nil

        createRequest(hostName: HOST_NAME_USER,
            path: PATH_USER,
            method: .post,
            parameters: parameter.toJSON() as [String : AnyObject],
            encording: URLEncoding.default,
            headers: [: ])?
            .validate(statusCode: 200...LOGIN_RESPONSE_CODE_THRESHOLD)

        if !AUTH_USER.isEmpty && !AUTH_PASS.isEmpty {
            authenticate(AUTH_USER, password: AUTH_PASS)
        }

        requestJson().subscribe(onNext: {[weak self] (response: UserEntity) in
            
            switch response.retCode {
            case .Success:
                // Greeting更新
                GreetingFlagHelper.setGreetingsFlag(response)
                // 新年度で近傍をリセット
                if GreetingFlagHelper.isNewFiscalYear() {
                    NeighborHelper.reset()
                }
                // ログイン成功時は、IDとパスは正しいものとみなし、強制アンラップをかける
                self?.loginSuccess(user: response, amcNo: parameter.amcNo!, password: parameter.pass!)
                
            default:
                // トーストチェック
                ToastCutsom.showLoginToast(String(localizedKey: "LabelHomeAlertSuccess"))
                
                // エラーコードが返ってきた場合、それぞれに処理を行う
                self?.loginFailure(returnCodeType: response.retCode)
            }
            
            }, onError: { [weak self] error in
                let error = error as NSError
                // トーストチェック
                ToastCutsom.showLoginToast(error.code == NSError(errorType: .jsonMappingError).code || error.code == NSError(errorType: .modelMappingError).code ? String(localizedKey: "LabelHomeAlertMaintenance") : String(localizedKey: "LabelHomeAlertFailure"))
                
                self?.error.value = error
                self?.complete.value = ()
                
            }, onCompleted: { [weak self] in
                self?.complete.value = ()
                trace?.stop()
            }, onDisposed: nil)
            .disposed(by: requestDisposeBag)
    }

    /// ログイン成功時の処理
    private final func loginSuccess(user: UserEntity, amcNo: String, password: String) {
        let trace = Performance.startTrace(name: "Auto Login Success")

        // 最終ログイン時刻を更新
        AppStatusModel.updateLastUpdateTime()
        
        // ログイン情報を永続化
        user.updateUserAccount(amcNo, password: password)
        
        // キャッシュ
        user.cacheUser()
        
        // QR文字列を生成
        AppStatusModel.shared.qr.updateQRString(user)
        
        // QR文字列を永続化
        AppStatusModel.shared.qr.saveQRString()
        
        // トーストチェック
        showLoginSuccessToast()
        
        // User情報反映（cocos2Dに渡すなど）
        updateStatus(user: user)
        
        trace?.stop()
    }
    
    /// ログイン成功時のデーター更新
    private final func updateStatus(user: UserEntity) {
        // 言語別表示タイプの更新
        //// UserDefaultに登録してある言語タイプを取得
        if let regionId = LanguageStatusModel.fetchRegionId() {
            LanguageStatusModel.updateViewType(regionId: regionId)      ////言語タイプをUserdefaultに保存していたタイプで更新
        }
        
        // 有効期限切れデータを最適化
        user.updatePoints(true, range: 37)
        user.updatePoints(false, range: 13)
        
        // CardFace情報とmile情報をcocosに渡す
        //// プレミアムステータスコードとか渡している
        AppStatusModel.shared.updateCocosCardFace(user.cardFaceType, mileGraphData: user.expireMileGraphData)
        
        // CardFace変換がある場合、cocosViewStatus.value = .replace
        if user.cardFaceType != lastCardfaceType {
            AppStatusModel.shared.startMonitoringFinishReplace()
        }
        
        // レスポンス保持
        self.user.value = user
        
        // ダイヤ・ミリオンマイラー分岐
        AppStatusModel.setHasExpireDate((!(user.cardFaceType == .diamond) && !AppStatusModel.shared.userModel.isMillionMiler))
        
        // カードフェイスタイプ保持
        lastCardfaceType = user.cardFaceType
    }

    /// ログイン成功時のトースト判別
    private final func showLoginSuccessToast() {
        guard let user = user.value else { return }
        if user.cardFaceType == lastCardfaceType {
            // ステータス変更なし
            ToastCutsom.showLoginToast(String(localizedKey: "LabelHomeAlertSuccess"))
            LoadingView.dismiss()
        } else {
            // ステータス変更あり
            ToastCutsom.showLoginToast(String(localizedKey: "LabelHomeAlertUpdated"))
        }
    }

    /// API通信成功、かつログイン失敗時の処理
    private final func loginFailure(returnCodeType: AppStatusModel.ReturnCodeType) {
        error.value = NSError(
            code: returnCodeType.code(),
            localizedDescription: String(localizedKey: returnCodeType.localizedKeyDescriptionKey())
        )
    }

    /**
     KeyChainからUserEntityを復元する

     - returns: 必要な情報をすべて復元できた場合trueが返る
     */
    final func loadUser() -> Bool {
        return UserEntity.loadUserAccount()
    }
    
    /**
     キャッシュしたユーザー情報を取得
     
     - returns: 必要な情報をすべて復元できた場合trueが返る
     */
    @discardableResult
    final func loadCacheUser() -> Bool {
        guard let user = UserEntity.cachedUser else { return false }
        updateStatus(user: user)
        return true
    }

    /// ユーザー情報を破棄する
    final class func deleteUser() {
        AppStatusModel.shared.userModel.user.value = nil
        UserEntity.deleteUserAccount()
    }
}

// MARK: Keychainに保存する情報
extension UserModel {

    /// UserModel.loadCacheUser()前に
    /// cardFaceTypeが必要ところがあるから、cachedUserから取得
    var savedCardFaceType: UserEntity.CardFaceType {
        return user.value?.cardFaceType ?? cachedUser?.cardFaceType ?? .normal
    }
    
    var savedAmcNo: String? {
        return user.value?.amcNo ?? cachedUser?.amcNo       ////cachedUserでキーチェーンからユーザ情報を取得
    }
    
    /// passwordはメモリーにキャッシュしない
    var savedPassword: String? {
        return Keychain().get(forKey: .password)
    }
    
    var savedLoginParameter: UserParameter? {
        guard let amcNo = savedAmcNo,
            let password = savedPassword,
            let userParameter = Mapper<UserParameter>().map(JSON: ["amcno": amcNo, "pass": password])
            else { return nil }
        return userParameter
    }
    
    // MARK: UserEntityにない情報
    
    /// EttsCodeNextBackup
    var savedEttsCodeNextBackup: UserEntity.EttsCodeType? {
        guard let type = Keychain().get(forKey: .ettsCodeNextBackup) else { return nil }
        return UserEntity.EttsCodeType(rawValue: type)
    }
    
    func saveEttsCodeNextBackup(_ value: UserEntity.EttsCodeType) {
        Keychain().set(value.rawValue, forKey: .ettsCodeNextBackup)
    }
    
    func removeEttsCodeNextBackup() {
        Keychain().remove(forKey: .ettsCodeNextBackup)
    }
    
    /// ElteUpdateKindNextBackup
    var savedElteUpdateKindNextBackup: UserEntity.ElteUpdateKind? {
        guard let type = Keychain().get(forKey: .elteUpdateKindNextBackup) else { return nil }
        return UserEntity.ElteUpdateKind(rawValue: type)
    }
    
    func saveElteUpdateKindNextBackup(_ value: UserEntity.ElteUpdateKind) {
        Keychain().set(value.rawValue, forKey: .elteUpdateKindNextBackup)
    }
    
    func removeElteUpdateKindNextBackup() {
        Keychain().remove(forKey: .elteUpdateKindNextBackup)
    }
    
    /// MillionMiler
    var savedMillionMiler: AppStatusModel.MillionMilerType? {
        if let type = Keychain().get(forKey: .million) {
            return AppStatusModel.MillionMilerType(rawValue: type)
        } else {
            return .NONE
        }
    }
    
    func saveMillionMiler(_ value: AppStatusModel.MillionMilerType) {
        Keychain().set(value.rawValue, forKey: .million)
    }
    
    func removeMillionMiler() {
        Keychain().remove(forKey: .million)
    }
}
