//
//  RingoRequestBase.swift
//  ApplicationModel
//
//  Created by 溝口 健 on 2018/06/08.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import ApplicationConfig
import Foundation
import Alamofire
import RxSwift
import Foundation
import ApplicationLib

class RingoRequestBase: RequestBase {
    
    //[String: String]: dictionary
    func ringoHeaders() -> [String: String] {
        var header = RequestBase.headers        //header取得
        let token = UserDefaults.standard.string(forKey: ApiHeader.authorization) ?? ""     //token取得
        header = [ApiHeader.authorization: ApiHeader.bearer+token]
        return header
    }
    
    private var tokenRefreshRequest = LoginRequest()    //loginAPIを呼び出すrequest
    
    //get,post,putなどの時に呼び出しを行なっている?
    final func requestJSONWithToken<T: Responsible>() -> Single<T> {
        
        //singleイベントを一回だけ流すobserbable?
        let source: Single<T> = Single.create { [weak self] single in
            //selfがnilなら何も作成しない
            guard let s = self else {
                return Disposables.create()
            }
            
            // 通常のリクエストを実行
            let task: Single<T> = s.requestJson()       //ここでDisposablesがcreateされている
            let disposable = task.subscribe(
                onSuccess: {
                    log.debug("*** API Call success without Token Refresh ***")
                    single(.success($0))
            },
                onError: { error in
                    // エラー時
                    if let e = error as? RingoHttpStatusError, (e.statusCode == 401 || e.statusCode == 500) {
                        // 401エラーならトークンリフレッシュ処理
                        s.refreshToken().flatMap({
                            log.debug("*** Token refresh success! response = \($0) ***")
                            UserDefaults.standard.set($0.authToken, forKey: ApiHeader.authorization)
                            s.updateHeader(headers: s.ringoHeaders())
                            // 元のリクエストを再度実行。
                            return s.requestJson()
                        }).subscribe(
                            onSuccess: {
                                // リフレッシュと元のリクエストがともに成功
                                single(.success($0))
                        },
                            onError: {
                                // いずれかが失敗
                                log.debug("*** API Request error. HTTPStatusCode = \(($0 as NSError).code), error = \($0) ***")
                                single(.error($0))
                        }).disposed(by: s.requestDisposeBag)
                    } else {
                        // その他のエラーの場合処理を停止
                        log.debug("*** Unknown error. HTTPStatusCode = \((error as NSError).code), error = \(error) ***")
                        single(.error(error))
                    }
            })
            return disposable
        }
        return source
    }
    
    final func refreshToken() -> Single<LoginResponse> {
        let params = LoginParameter(mailAddress: ApplicationStore.instance.state.mailAddress, password: ApplicationStore.instance.state.password)
        return tokenRefreshRequest.post(parameters: params)
    }
}
