//
//  HistoryCell.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/02/23.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import Foundation
import UIKit
import SwiftDate
import ApplicationModel
import ApplicationConfig

final class HistoryCell: UITableViewCell {

    @IBOutlet private weak var mobilityLabel: UILabel!                          //kmタクシーとか一番上のLabel
    @IBOutlet private weak var statusLabel: UILabel!                            //状態の入力値
    @IBOutlet private weak var selectPaymentTextLabel: UILabel!                 //お支払い方法Label
    @IBOutlet private weak var selectPaymentLabel: UILabel!                     //お支払い方法入力値
    @IBOutlet private weak var dateLabel: UILabel!                              //日時入力値
    @IBOutlet private weak var priceLabel: UILabel!                             //料金入力値
    @IBOutlet private weak var selectPaymentLabelBottom: NSLayoutConstraint!    //一番下とお支払い方法Labelとの制約
    @IBOutlet private weak var frameView: UIView!

    private(set) var usageId: String?

    public var getDateLabel: UILabel {
        return dateLabel
    }

    public var getStatusLabel: UILabel {
        return statusLabel
    }

    public var getMobilityLabel: UILabel {
        return mobilityLabel
    }

    public var getPriceLabel: UILabel {
        return priceLabel
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        selectionStyle = .none
        frameView.addDropShadow(type: .paymentHistoryCell)
    }

    public func config(data: PaymentHistoryEntity, taxi: Bool = true) {
        mobilityLabel.text = data.serviceName
        
        // 支払い情報のところは、２種類(プリペイドかポストペイ)あるがどちらもクレジットカードのため表記はクレジットカードのみで対応
        selectPaymentLabel.text = "クレジットカード"
        let rome = Region(tz: TimeZoneName.asiaTokyo, cal: CalendarName.gregorian, loc: LocaleName.japanese)
        if let date = DateInRegion(string: data.startDate, format: .custom("yyyy-MM-dd'T'HH:mm:ss"), fromRegion: rome)?.string() {
            dateLabel.text = date + "~"
        }
        priceLabel.text = "¥" +  (data.usageAmount == 0 ? " 未確定" : String.stringByCurrencyFormat(value: data.usageAmount))

        self.usageId = data.usageId

        if !taxi {
            selectPaymentLabelBottom.constant = 8
            selectPaymentTextLabel.isHidden = true
            selectPaymentLabel.isHidden = true
            frameView.layoutIfNeeded()
            self.setCycleStatus(num: data.payStatusCode)
        } else {
            self.setTaxiStatus(num: data.payStatusCode)
        }
    }

    private func setTaxiStatus(num: Int) {
        switch num {
        case TaxiPayStatusCode.Cancel.rawValue:
            _ = statusLabel.setText(text: "決済予約キャンセル")
            _ = statusLabel.textColor = UIColor.textGrey
        case TaxiPayStatusCode.Wait.rawValue:
            _ = statusLabel.setText(text: "決済処理中")
            _ = statusLabel.textColor = UIColor.textGrey
        case TaxiPayStatusCode.TimeOut.rawValue:
            _ = statusLabel.setText(text: "決済タイムアウト")
            _ = statusLabel.textColor = UIColor.textGrey
        case TaxiPayStatusCode.Success.rawValue:
            _ = statusLabel.setText(text: "●決済完了")
            _ = statusLabel.textColor = UIColor.textGreen
        case TaxiPayStatusCode.CardError.rawValue:
            _ = statusLabel.setText(text: "●決済失敗(カード不正)")
            _ = statusLabel.textColor = UIColor.textRed
        case TaxiPayStatusCode.SystemError.rawValue:
            _ = statusLabel.setText(text: "●決済失敗(システムエラー)")
            _ = statusLabel.textColor = UIColor.textRed
        default:
            _ = statusLabel.setText(text: "●決済失敗")
            _ = statusLabel.textColor = UIColor.textRed
        }
    }

    private func setCycleStatus(num: Int) {
        switch num {
        case CyclePayStatusCode.PayMonthly.rawValue, CyclePayStatusCode.PayMonthlyWait.rawValue, CyclePayStatusCode.PayMonthlySuccess.rawValue, CyclePayStatusCode.PaymentUnPaid.rawValue:
            _ = statusLabel.setText(text: "●月次決済完了")
            _ = statusLabel.textColor = UIColor.textGrey
        case CyclePayStatusCode.Unsettled.rawValue:
            _ = statusLabel.setText(text: "●返却完了")
            _ = statusLabel.textColor = UIColor.textGreen
        case CyclePayStatusCode.PayMonthlyError.rawValue:
            _ = statusLabel.setText(text: "●失敗")
            _ = statusLabel.textColor = UIColor.textRed
        default:
            _ = statusLabel.setText(text: "●失敗")
            _ = statusLabel.textColor = UIColor.textRed
        }
    }
}
