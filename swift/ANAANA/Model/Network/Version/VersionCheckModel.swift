//
//  VersionCheckModel.swift
//  AnaMile
//
//  Created by 山本 涼太 on 2017/02/15.
//
//

import RxSwift

import Alamofire
import FirebasePerformance
import SwiftDate

class VersionCheckModel: RequestBase {
    private let disposeBag = DisposeBag()
    private let userDefaultLastCheckedAtKey = "lastCheckedUpdateAt"
   
    ////バージョンチェックを行った日付をUserDefaultsで保持
    private var lastCheckedAt: Date {
        get {
            return UserDefaults.standard.object(forKey: userDefaultLastCheckedAtKey) as? Date ??
                Date(timeIntervalSince1970: 0)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultLastCheckedAtKey)
        }
    }

    final let versionEntity = Variable<VersionCheckEntity?>(nil)

    /// API通信完了flg
    final let complete: Variable<Void?> = Variable(nil)

    /// エラー
    final let error: Variable<NSError?> = Variable(nil)
    
    final func checkVersion() {
        error.value = nil
        complete.value = nil
        let trace = Performance.startTrace(name: "Version Check")   //// firebaseのanalytics

        createRequest(hostName: HOST_NAME_VERSION,
            path: PATH_VERSION,
            method: .get,
            parameters: [:],
            encording: URLEncoding.default,
            headers: [: ])?
            .validate(statusCode: 200...LOGIN_RESPONSE_CODE_THRESHOLD)      ////200~LOGIN_RESPONSE_CODE_THRESHOLDをエラーとして処理するメソッド

        if !AUTH_USER.isEmpty && !AUTH_PASS.isEmpty {
            authenticate(AUTH_USER, password: AUTH_PASS)        ////API(Alamofire)のBasic認証の設定
        }

        requestJson().subscribe(onNext: { [weak self] (response: VersionCheckEntity) in
            self?.lastCheckedAt = Date()
            self?.versionEntity.value = response
            self?.complete.value = ()
            }, onError: { [weak self] in
                self?.error.value = $0 as NSError
                self?.complete.value = ()
            }, onCompleted: { [weak self] in
                self?.complete.value = ()
                trace?.stop()
            }, onDisposed: nil)
            .disposed(by: requestDisposeBag)
    }
}
