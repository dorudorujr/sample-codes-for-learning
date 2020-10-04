//
//  RootViewEntity.swift
//  AnaMile
//
//  Created by yamamotosaika on 2016/01/28.
//
//

import UIKit

import ObjectMapper

/// チュートリアル〜ログイン画面のEntity
class RootViewEntity: Mappable {

    private static var entitys: [RootViewEntity]?

    /// id
    private(set) var viewIdentifier = ""

    /// ADB Analytics送信画面名
    private(set) var analyticsPageName = ""

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        viewIdentifier <- map["viewIdentifier"]
        analyticsPageName <- map["analyticsPageName"]
    }

    /**
     RootViewList.plistを元にEntityを生成

     - returns: [RootViewEntity]
     */
    class func map() -> [RootViewEntity] {

        //// entitysに値が入っていたら値を返す
        if let entitys = RootViewEntity.entitys {
            return entitys
        }
        let source = FileUtil.loadPlistArray("RootViewList")    ////json形式でクラス名などが記載されているjsonをRootViewListから取得

        ////jsonファイルをmapperでオブジェクトにする
        if let result = Mapper<RootViewEntity>().mapArray(JSONObject: source) {
            RootViewEntity.entitys = result
            return result
        } else {
            return []
        }
    }
}
