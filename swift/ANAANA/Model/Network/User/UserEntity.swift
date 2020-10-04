//
//  UserEntity.swift
//  AnaMile
//
//  Created by 西村 拓 on 2015/12/17.
//
//

import UIKit
import ObjectMapper
import KeychainAccess
import SwiftDate

/// ユーザー情報格納用Entity
class UserEntity: Responsible {
    
    /// APIステータスコード
    private(set) var retCode = AppStatusModel.ReturnCodeType.UnKnown

    /// AMC会員番号
    var amcNo: String = "                "
 
    /// パスワード
    var password: String = ""

    /// ユーザー名
    var jName: String = "                    "
    var eName: String = "                    "

    /// 保持マイル
    private(set) var mile = 0
    
    /// 次年度ステイタス発行種別
    var elteUpdateKindNext: ElteUpdateKind = .A
    
    /// 前年度プレミアムステータス
    var ettsCodeBefore: EttsCodeType = .AMC
    
    /// エリートステータスコード
    var ettsCode: EttsCodeType = .AMC
    
    /// 次年度プレミアムステータス
    var ettsCodeNext: EttsCodeType = .AMC

    /// 会員種別コード
    var memberKindCode: MemberKindCodeType = .AID
    
    /// 会員種別コード
    var creditKindCode: CreditKindCodeType = .None

    /// アプリ上で使うステータスコード
    var cardFaceType: CardFaceType {
        return CardFaceType(sfcCode: sfcCode, ettsCode: ettsCode)
    }

    /// SFC判別 (0: 本会員, 1: 家族会員, 2: ノンクレジットSFC会員, 空: 非SFC会員）
     var sfcCode: String = ""

    /// モバイルプラス会員 1:入会済み
    var mobilePlusStatus = ""

    /// 保有Skyコイン
    private(set) var coin = 0

    /// 生年月日
    private(set) var birthDate = ""

    /// ユニーククッキー
    private(set) var uniqueCookie = ""

    /// 送付物使用言語コード
    private(set) var letrLanguage = ""

    /// タイトルコード
    /// 性別判別 (MR: male, MS: female）
    private(set) var titleCode: String = ""

    /// Webパスワード認証フラグ
    private(set) var webPassFlg = false

    /// プレミアムポイント
    private(set) var premiumPoint = 0

    /// プレミアムポイントANAグループ運航便分
    private(set) var premiumPointANA = 0

    /// AFA/JFM会員コード
    private(set) var afaCode = ""

    /// AFA/JFMに登録しているプライム会員の場合は合算マイル数
    private(set) var afaMile = 0

    /// ライフタイムマイル トータル
    private(set) var lifeTimeMile = 0

    /// ライフタイムマイル ANA
    private(set) var lifeTimeMileANA = 0

    /// ライフタイムマイルステータス トータル
    private(set) var lifeTimeStatus = ""

    /// ライフタイムマイルステータス ANA
    private(set) var lifeTimeStatusANA = ""

    /// ライフタイムマイルステータス名称 トータル
    private(set) var lifeTimeName = ""

    /// ライフタイムマイルスステータス名称 ANA
    private(set) var lifeTimeNameANA = ""

    /// ダイヤモンド取得履歴
    private(set) var diamondCount = 0

    /// 保有アップグレードポイント（今年度）
    private(set) var upgradePoint = 0

    /// 保有アップグレードポイント（来年度）
    private(set) var upgradePointNextYear = 0

    /// 獲得予定アップグレードポイント
    private(set) var upgradePointScheduled = 0

    /// マイル有効期限
    private(set) var expireMile = [ExpirePointEntity]()
    
    // MARK: 近傍
    /// 近傍プレミアムステータスコード
    private(set) var neighborNextEttsCodeString: String?
    /// 達成までに必要なプレミアムポイント
    private(set) var neighborNextPoint: String?
    /// 達成までに必要なプレミアムポイント (ANAグループ運航便分)
    private(set) var neighborNextGroupPoint: String?
    var neighborNextEttsCodeType: EttsCodeType? {
        guard let s = neighborNextEttsCodeString else { return nil }
        return EttsCodeType(rawValue: s)
    }
    var neighborNextCardFaceType: CardFaceType? {
        guard let s = neighborNextEttsCodeString else { return nil }
        return CardFaceType(rawValue: s)
    }
    var neighborInfo: NeighborInfo {
        return NeighborInfo(nextEttsCode: neighborNextEttsCodeString ?? "", nextPoint: neighborNextPoint ?? "0", nextGroupPoint: neighborNextGroupPoint ?? "0", displayedAt: Date().dateAtStartOf(.day))
    }
    /// 来年のstatusが変わらない
    var isNextNeighborStepUp: Bool {
        guard let neighborNextEttsCodeType = neighborNextEttsCodeType else { return false }
        return neighborNextEttsCodeType.intValue() > ettsCode.intValue()
    }
    
    /// User情報がcacheからかどうかflag
    /// loadCacheUser()時だけtrueに設定
    /// login failed時にOfflie Errorを出すかどうか判定用
    /// SeeAlso: CardFaceViewController.didLoginFailure(:)
    private(set) var isCaching = false
    
    /// Cocos用マイル情報
    var expireMileGraphData: NSArray {
        return expireMile.map { ["date": $0.date, "point": $0.point] } as NSArray
    }

    /// Skyコイン有効期限
    private(set) var expireCoin = [ExpirePointEntity]()

    required init?(map: Map) {}

    func mapping(map: Map) {
        retCode <- (map["retcode"], TransformOf<AppStatusModel.ReturnCodeType, String>(
            fromJSON: {
                if let value = $0 {
                    return AppStatusModel.ReturnCodeType(rawValue: value)
                } else {
                    return .UnKnown
                }
            },
            toJSON: {
                $0.map { $0.rawValue
                } })
        )
        guard retCode == .Success else { return }
        amcNo <- map["record.amcno"]
        jName <- map["record.jname"]
        eName <- map["record.ename"]
        mile <- map["record.mile_n"]
        elteUpdateKindNext <- (map["record.elteupdtknd_n"], TransformOf<ElteUpdateKind, String>(
            fromJSON: {
                if let value = $0 {
                    return ElteUpdateKind(rawValue: value)
                } else {
                    return ElteUpdateKind.A
                }
            },
            toJSON: {
                $0.map { $0.rawValue
                } })
        )
        ettsCodeBefore <- (map["record.ettscode_b"], TransformOf<EttsCodeType, String>(
            fromJSON: {
                if let value = $0 {
                    return EttsCodeType(rawValue: value)
                } else {
                    return EttsCodeType.AMC
                }
            },
            toJSON: {
                $0.map { $0.rawValue
                } })
        )
        ettsCode <- (map["record.ettscode"], TransformOf<EttsCodeType, String>(
            fromJSON: {
                if let value = $0 {
                    return EttsCodeType(rawValue: value)
                } else {
                    return EttsCodeType.AMC
                }
            },
            toJSON: {
                $0.map { $0.rawValue
                } })
        )
        ettsCodeNext <- (map["record.ettscode_n"], TransformOf<EttsCodeType, String>(
            fromJSON: {
                if let value = $0 {
                    return EttsCodeType(rawValue: value)
                } else {
                    return EttsCodeType.AMC
                }
            },
            toJSON: {
                $0.map { $0.rawValue
                } })
        )
        memberKindCode <-  (map["record.mebrkindcod"], TransformOf<MemberKindCodeType, String>(
            fromJSON: {
                if let value = $0 {
                    return MemberKindCodeType(rawValue: value)
                } else {
                    return MemberKindCodeType.AID
                }
            },
            toJSON: {
                $0.map { $0.rawValue
                } })
        )
        creditKindCode <-  (map["record.crcdkindcod"], TransformOf<CreditKindCodeType, String>(
            fromJSON: {
                if let value = $0 {
                    return CreditKindCodeType(rawValue: value)
                } else {
                    return CreditKindCodeType.None
                }
        },
            toJSON: {
                $0.map { $0.rawValue
                } })
        )

        sfcCode <- map["record.sfccode"]
        mobilePlusStatus <- map["record.mbilplusstts"]
        coin <- map["record.coin_n"]
        birthDate <- map["record.dob"]
        uniqueCookie <- map["record.unique_cookie"]
        letrLanguage <- map["record.letrlang"]
        titleCode <- map["record.title"]
        webPassFlg <- map["record.webPassFlg"]
        premiumPoint <- map["record.ppt_n"]
        premiumPointANA <- map["record.pptnh_n"]
        afaCode <- map["record.afacode"]
        afaMile <- map["record.afamile_n"]
        lifeTimeMile <- map["record.ltm_n"]
        lifeTimeMileANA <- map["record.ltmnh_n"]
        lifeTimeStatus <- map["record.ltmsts"]
        lifeTimeStatusANA <- map["record.ltmstsnh"]
        lifeTimeName <- map["record.ltmnam"]
        lifeTimeNameANA <- map["record.ltmnamnh"]
        diamondCount <- (map["record.dcnt"], StringIntTransform())
        upgradePoint <- map["record.ugp_n"]
        upgradePointNextYear <- map["record.nugp_n"]
        upgradePointScheduled <- map["record.nugp_e"]
        expireMile <- map["record.expmile"]
        expireCoin <- map["record.expcoin"]
        
        neighborNextEttsCodeString <- map["record.neigh_ettscode"]
        neighborNextPoint <- map["record.needppt"]
        neighborNextGroupPoint <- map["record.needpptnh"]
    }
    
    /// ユーザーIDとパスワードを更新
    final func updateUserAccount(_ amcNo: String, password: String) {
        let keychain = Keychain()
        keychain.set(amcNo, forKey: .account)
        keychain.set(password, forKey: .password)
    }
    
    /// ユーザー情報をJSON Stringでキーチェーンに保存
    final func cacheUser() {
        guard let json = toJSONString() else { return }
        Keychain().set(json, forKey: .cachedUser)
    }

    /**
     キーチェーンからUserEntity情報を読み込む
     - returns: 必要な情報をすべて復元できた場合trueが返る
     */
    final class func loadUserAccount() -> Bool {
        let keychain = Keychain()
        guard keychain.get(forKey: .account) != nil, keychain.get(forKey: .password) != nil else { return false }
        return true
    }
    
    /// ユーザー情報をキーチェーンから取得
    static var cachedUser: UserEntity? {
        guard let json = Keychain().get(forKey: .cachedUser) else { return nil }
        let user = UserEntity(JSONString: json)
        user?.isCaching = true
        return user
    }

    /// ユーザー情報をキーチェーンから破棄する
    final class func deleteUserAccount() {
        let keychain = Keychain()

        keychain.remove(forKey: .account)
        keychain.remove(forKey: .password)
        keychain.remove(forKey: .ettsCodeNextBackup)
        keychain.remove(forKey: .elteUpdateKindNextBackup)
        keychain.remove(forKey: .million)
        keychain.remove(forKey: .cachedUser)
    }

    /**
     空の値が混ざるので、マイルとスカイコインデータを調整する

     - parameter mile: マイル指定ならtrue
     - parameter range:  必要なデータ範囲（Months）
     */
    final func updatePoints(_ mile: Bool, range: Int) {
        var date = Date()
        let region = Region(calendar: Calendars.gregorian, zone: Zones.asiaTokyo, locale: Locales.japaneseJapan)        ////日時を生成
        
        // サーバーのデータ分けTimezonはJST。そしてどのTimeZoneでも、当地時間の月に対応するJSTデータを利用する。なので当地時間と同じyyとMMのJST date生成必要。
        // Example: Treat 2018/03/31 15:00 UTC as 2018/03/31 15:00 JST(Not 2018/04/01 00:00 JST)
        ////JST = 日本標準時
        ////現在年、月の15日の日時を生成
        date = DateInRegion(year: date.year, month: date.month, day: 15, hour: 0, minute: 0, second: 0, nanosecond: 0, region: region).date
        
        var result = [ExpirePointEntity]()

        let points = (mile) ? expireMile : expireCoin
        
        for _ in 0..<range {
            let dateString = date.toString("yyyyMM", timeZone: TimeZone(abbreviation: "JST"))

            var entity = ExpirePointEntity.empty(dateString)

            points.filter { $0.date == dateString }.forEach { entity = $0 }

            entity.toDate = date
            entity.dateToShow = date.toString("yyyy.MM", timeZone: TimeZone(abbreviation: "JST"))

            result.append(entity)

            date = date.dateByAdding(1, .month).date
        }

        if mile {
            expireMile = result
        } else {
            expireCoin = result
        }
    }

    final func isSfcRegularMember() -> Bool {
        return sfcCode == "0"
    }

    final func isSfcMember() -> Bool {
        return sfcCode != ""
    }

    final func isAnaCardMember() -> Bool {
        return memberKindCode == .ACH
    }

    final func isMobilePlusMember() -> Bool {
        return mobilePlusStatus == "1"
    }
}

// MARK: Enum
extension UserEntity {
    /// エリートステータスコード (D: ダイヤモンド, P: プラチナ, B: ブロンズ, ACH: ANAカード, AID: その他AMC会員)
    enum EttsCodeType: String {
        case diamond = "D"
        case platinum = "P"
        case bronze = "B"
        case ANA = "ACH"
        case AMC = "AID"
        
        func intValue() -> Int {
            switch self {
            case .AMC:
                return 1
            case .ANA:
                return 2
            case .bronze:
                return 3
            case .platinum:
                return 4
            case .diamond:
                return 5
            }
        }
    }
    
    /* ステイタス発行種別
     N、R、Eだけ通常
     (A：体験版
     N：通常
     E：早期
     R：後追い
     T：強制
     G：下駄履かせ
     D：体験版
     I：体験版
     O：体験版
     W：複数年認知
     空)*/
    enum ElteUpdateKind: String {
        case A
        case N
        case E
        case R
        case T
        case G
        case D
        case I
        case O
        case W
        
        func isNormal() -> Bool {
            if self == .E {
                return true
            }
            return false
        }
    }
    
    /// 会員種別コード、( ACH: ANAカード、AID: AMCカード )
    enum MemberKindCodeType: String {
        case AID
        case ACH
    }
    
    /// クレジットカードコード (WHT：一般,GLD：ゴールド,PRM：プレミアム)
    enum CreditKindCodeType: String {
        case None = ""
        case WHT
        case GLD
        case PRM
    }
    
    /// アプリで使用するステータスコード
    enum CardFaceType: String {
        case diamond = "D"
        case platinum = "P"
        case SFC = "SFC"
        case bronze = "B"
        case normal = "N"
        
        init(sfcCode: String, ettsCode: EttsCodeType) {
            if ettsCode == .diamond || ettsCode == .platinum {
                self = CardFaceType(rawValue: ettsCode.rawValue)!
            } else if sfcCode != "" {
                self = .SFC
            } else if ettsCode == .bronze {
                self = .bronze
            } else {
                self = .normal
            }
        }
        
        func imageSuffix() -> String {
            switch self {
            case .normal:
                return "_nr"
            case .bronze:
                return "_bz"
            case .SFC:
                return "_sf"
            case .platinum:
                return "_pt"
            case .diamond:
                return "_dm"
            }
        }
        
        func urlParameterSuffix() -> String {
            switch self {
            case .normal:
                return "nr"
            case .bronze:
                return "bz"
            case .SFC:
                return "sf"
            case .platinum:
                return "pt"
            case .diamond:
                return "dm"
            }
        }
        
        func universalString() -> String {
            switch self {
            case .normal:
                return "Normal"
            case .bronze:
                return "Bronze"
            case .SFC:
                return "SFC"
            case .platinum:
                return "Platinum"
            case .diamond:
                return "Diamond"
            }
        }
        
        func cocosCardFaceType() -> Int32 {
            switch self {
            case .normal:
                return 0
            case .bronze:
                return 2
            case .SFC:
                return 1
            case .platinum:
                return 3
            case .diamond:
                return 4
            }
        }
    }
}
