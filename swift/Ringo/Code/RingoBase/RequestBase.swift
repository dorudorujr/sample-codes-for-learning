//
//  RequestBase.swift
//  ReduxFramework
//
//  Created by 山本 涼太 on 2017/04/10.
//  Copyright © 2017年 Team Lab. All rights reserved.
//

import Alamofire
import RxSwift
import Foundation
import ApplicationLib

/// APiリクエストのベースとなるクラス
open class RequestBase: NSObject {

    /// Rx
    let requestDisposeBag = DisposeBag()

    /// Request Header
    public static var headers = [String: String]()
    
    /// Response Encode
    // TODO: 案件毎にレスポンスの文字コードを設定
    public static var defaultResponseEncoding = String.Encoding.utf8

    // Time out
    public static var timeoutIntervalForRequest = TimeInterval(15.0) {
        didSet {
            manager = RequestBase.updateManager()
        }
    }
    public static var timeoutIntervalForResource = TimeInterval(20.0) {
        didSet {
            manager = RequestBase.updateManager()
        }
    }

    // Cache Policy
    public static var cachePolicy = NSURLRequest.CachePolicy.useProtocolCachePolicy {
        didSet {
            manager = RequestBase.updateManager()
        }
    }

    /// Alamofire object
    private static var manager = RequestBase.updateManager()

    private final class func updateManager() -> SessionManager {
        let configuration = URLSessionConfiguration.default

        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

        // Time out
        configuration.timeoutIntervalForRequest = RequestBase.timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = RequestBase.timeoutIntervalForResource

        // Cache policy
        configuration.requestCachePolicy = RequestBase.cachePolicy

        return SessionManager(configuration: configuration)
    }

    // Requestオブジェクト
    private var request: DataRequest?

    // リクエスト更新用
    private(set) var requestUrl: URLConvertible!
    private(set) var method = HTTPMethod.get
    private(set) var parameters: Parameters?
    private(set) var encoding: ParameterEncoding!
    private(set) var headers: HTTPHeaders?
    private(set) var responseEncoding = RequestBase.defaultResponseEncoding

    public override init() {
        super.init()
    }
    
    public convenience init(responseEncoding: String.Encoding) {
        self.init()
        self.responseEncoding = responseEncoding
    }

    /**
     基礎設定を指定してリクエストオブジェクト生成
     - parameter hostName:   FQDN
     - parameter path:       URLパス
     - parameter method:     httpメソッド
     - parameter parameters: クエリ
     - parameter encoding:  リクエストエンコードタイプ
     */
    final func createRequest( hostName: String, path: String, method: HTTPMethod, parameters: [String: Any], encoding: ParameterEncoding, headers: [String: String] = RequestBase.headers) -> DataRequest? {

        self.requestUrl = hostName.appending(pathComponent: path)
        self.method = method
        self.parameters = parameters
        self.encoding = encoding
        self.headers = headers
        let optionStatus = ApplicationStore.instance.state.statusCode
        request = RequestBase.manager.request(
            requestUrl,
            method: method,
            parameters: optionStatus.isNotEmpty ? parameters.union(dictionary: optionStatus) : parameters,
            encoding: encoding,
            headers: headers)

        log.debug(self.request.debugDescription)
        return request
    }

    final func updateHeader(headers: HTTPHeaders) {
        self.headers = headers
        request = RequestBase.manager.request(
            requestUrl,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: headers)
    }

    /**
     Add basic authentication
     - parameter user:     username
     - parameter password: password
     */
    final func authenticate(user: String?, password: String?) {
        guard let user = user, let password = password else {
            return
        }

        request?.authenticate(user: user, password: password)
    }

    /**
     レスポンス形式がJsonの場合、Entityを指定してCodableでマッピングまで行う
     - returns: <T: Responsible>
     */
    final func requestJson<T: Responsible>() -> Single<T> {

        let source: Single<T> = Single.create { [weak self] single in

            _ = self?.responseData()
                .subscribe(
                    onSuccess: {
                        if T.self == NothingResponse.self {
                            if let decoded = try? T.decoder.decode(T.self, from: "{}".data(using: .utf8)!) {
                                self?.successLog(resultMessage: String(data: $0, encoding: self?.responseEncoding ?? .utf8) ?? "")
                                single(.success(decoded))
                            }
                        } else {
                            if let decoded = try? T.decoder.decode(T.self, from: $0) {
                                self?.successLog(resultMessage: String(data: $0, encoding: self?.responseEncoding ?? .utf8) ?? "")
                                single(.success(decoded))
                            } else {
                                let error = MappingError.modelMappingError
                                single(.error(error))
                                self?.errorLog(error: error)
                            }
                        }
                }, onError: {
                    single(.error($0))
                }
            )
            
            return Disposables.create()
            }
            .subscribeOn(SerialDispatchQueueScheduler(qos: .default))
            .observeOn(MainScheduler.instance)

        return source
    }

    /**
     レスポンス形式がルート配列のJsonの場合、Entityを指定してCodableでマッピングまで行う
     - returns: <T: [Responsible]>
     */
    final func requestJson<T: Responsible>() -> Single<[T]> {
        let source: Single<[T]> = Single.create { [weak self] single in

            _ = self?.responseData()
                .subscribe(
                    onSuccess: {
                        if let decoded = try? T.decoder.decode(Array<T>.self, from: $0) {
                            self?.successLog(resultMessage: String(data: $0, encoding: self?.responseEncoding ?? .utf8) ?? "")
                            single(.success(decoded))
                        } else {
                            let error = MappingError.modelMappingError
                            single(.error(error))
                            self?.errorLog(error: error)
                        }
                }, onError: {
                    single(.error($0))
                }
            )
            
            return Disposables.create()
            }
            .subscribeOn(SerialDispatchQueueScheduler(qos: .default))
            .observeOn(MainScheduler.instance)

        return source
    }

    /// Alamofireを利用して通信を実行し、Stringを取得する
    final func responseString() -> Single<String> {

        let encoding = responseEncoding
        let source: Single<String> = Single.create { [weak self] single in

            _ = self?.responseData().subscribe(onSuccess: {
                if let string = String(data: $0, encoding: encoding) {
                    single(.success(string))
                } else {
                    let error = MappingError.stringMappingError
                    single(.error(error))
                    self?.errorLog(error: error)
                }
            }, onError: {
                single(.error($0))
            })

            return Disposables.create()
        }

        return source
    }

    /// Alamofireを利用して通信を実行し、Dataを取得する
    final func responseData() -> Single<Data> {
        let source: Single<Data> = Single.create { [weak self] single in
            self?.request?.responseData { response in
                if let statusCode = response.response?.statusCode {
                    //statusCodeがエラーならerror文言生成
                    if statusCode < 200 || statusCode >= 300 {
                        log.debug(String(data: response.data ?? Data(), encoding: self?.responseEncoding ?? .utf8 ))
                        let body = self?.mappingJson(response: response).jsonString
                        let error = RingoHttpStatusError(url: self?.request?.response?.url?.absoluteString ?? "", method: (self?.method.rawValue)!, statusCode: statusCode, responseBody: body)
                        single(.error(error))
                        self?.errorLog(error: error)    //errorLogをコンソールに表示
                        return
                    }
                }

                let result = self?.getData(from: response)
                if let data = result?.data {
                    single(.success(data))  //successをsingleに流す
                } else if let error = result?.error {
                    single(.error(error))
                    self?.errorLog(error: error)
                } else {
                    let error = NSError(errorType: .unknown)
                    single(.error(error))   //errorをsingleに流す
                    self?.errorLog(error: error)
                }
            }

            return Disposables.create()
        }

        return source
    }

    // MARK: - Util
    /// JsonString from Response
    private final func mappingJson(response: DataResponse<Data>) -> (jsonString: String?, error: Error?) {

        if let error = response.error {
            return (nil, error as NSError?)
        }

        if let data = response.data, var jsonString = String(data: data, encoding: responseEncoding) {
            jsonString = jsonString.isEmpty ? "{}" : jsonString
            return (jsonString, nil)
        } else {
            return (nil, MappingError.stringMappingError)
        }
    }

    /// decode DataResponse
    private final func getData(from response: DataResponse<Data>) -> (data: Data?, error: Error?) {
        if let error = response.error {
            return (nil, error as NSError?)
        }

        if let data = response.data {
            return (data, nil)
        } else {
            return (nil, MappingError.dataMappingError)
        }
    }

    // MARK: - Log
    /**
     Success log
     */
    private final func successLog(resultMessage: String) {
        log.debug("\(String(describing: self.request?.request?.url)):Result = \(resultMessage)")
    }

    /**
     Error log
     */
    private final func errorLog(error: Error) {
        switch error {
        case let error as NSError:
            log.debug("\(String(describing: self.request?.request?.url)):Error(\(error.code)) = \(error.localizedDescription)")
        case let error as HttpStatusError:
            let body = error.responseBody ?? ""
            log.debug("\(String(describing: self.request?.request?.url)):Error(\(error.statusCode)) = \(body)")
        default:
            log.debug("\(String(describing: self.request?.request?.url)):ErrorXXX = \(error.localizedDescription)")
        }
        
    }
}
