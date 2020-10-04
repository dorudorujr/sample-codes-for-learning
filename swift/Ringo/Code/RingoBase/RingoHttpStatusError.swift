//
//  RingoHttpStatusError.swift
//  ApplicationModel
//
//  Created by 溝口 健 on 2018/06/14.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import ApplicationConfig
import ApplicationLib
import Foundation

public struct RingoHttpStatusError: Error {
    public let urlPath: String
    public let method: String
    public let statusCode: Int
    public let responseBody: String?
    public var localErrorMessage = ""
    
    public var message: String? {
        //responseBodyがnilならmessageはnil
        guard let body = responseBody else {
            return nil
        }
        //localErrorMessageがあったらmessageはlocalErrorMessageの内容
        if localErrorMessage.isNotEmpty {
            return localErrorMessage
        }
        //JSONDecoderはtryなりdo catchなり必要
        let decoder = JSONDecoder()
        do {
            let data = body.data(using: RequestBase.defaultResponseEncoding)!       //stringをutf8のdata型に変換
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)  //jsonをデコード
            var key = String(urlPath + "_" + method + "_" + String(statusCode) + "_" + errorResponse.message)
            //Localizedから指定した文言を取得
            if NSLocalizedString(key, tableName: "ServerErrorLocalizable", comment: "") != key {
                return NSLocalizedString(key, tableName: "ServerErrorLocalizable", comment: "")
            } else {
                key = "_―_" + String(statusCode) + "_" + errorResponse.message
                return NSLocalizedString(key, tableName: "ServerErrorLocalizable", comment: "")
            }
        } catch let error {
            log.debug("Error object couldn't be decoded: \(error)")
            return nil
        }
    }
    
    public init(localErrorMessage: String) {
        urlPath = ""
        method = ""
        statusCode = -1
        responseBody = ""
        self.localErrorMessage = localErrorMessage
    }
    
    public init(url: String, method: String, statusCode: Int, responseBody: String?) {
        let index = (url.index(of: "?") != nil ) ? url.index(of: "?") : url.endIndex
        self.urlPath = (url.isNotEmpty) ? String(url[Environment.instance.apiHost.endIndex..<url.index(index!, offsetBy: 0)]) : ""
        self.method = method
        self.statusCode = statusCode
        self.responseBody = responseBody
    }
}
