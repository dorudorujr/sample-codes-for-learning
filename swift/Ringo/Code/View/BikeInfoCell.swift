//
//  BikeInfoCell.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/01/26.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import Foundation
import UIKit
import ApplicationModel
import ApplicationConfig
import RxSwift
import GoogleMaps

public final class BikeInfoCell: UITableViewCell {
    
    @IBOutlet private weak var pointNameLabel: UILabel!
    @IBOutlet private weak var moneyOfMinute: UILabel!
    @IBOutlet private weak var restBikeStatus: UILabel!
    @IBOutlet private weak var restBikeStatusImage: UIImageView!
    @IBOutlet private weak var heightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var checkinButton: UIButton!                     //使い方ボタン
    @IBOutlet private weak var mySuicaKeyHowToButton: UIButton!
    @IBOutlet private weak var closeLineView: UIView!
    @IBOutlet private weak var detailButton: UIButton!
    @IBOutlet private weak var creditCardOrNotSuicaImage: UIImageView!
    @IBOutlet private weak var creditLabelOrNotSuicaLabel: UILabel!
    @IBOutlet private weak var locationNameLabel: UILabel!
    @IBOutlet private weak var suicaImage: UIImageView!
    
    var pointName: String {
        return pointNameLabel.text!
    }
    
    var getPointNameLabel: UILabel {
        return pointNameLabel
    }
    
    var getLocationNameLabel: UILabel {
        return locationNameLabel
    }
    
    var restBikeStatusText: String {
        return restBikeStatus.text!
    }
    
    var disposeBag = DisposeBag()
    private var initHeight: CGFloat?
    private var parent: BikeListViewController?
    
    enum gradationType {
        case white
        case gradation
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        
        initHeight = heightConstraint.constant
        heightConstraint.constant = closeLineView.frame.origin.y
        bind()
    }
    
    override public func prepareForReuse() {
        super.prepareForReuse()
        addGradationCell(graLayer: CAGradientLayer(), type: .white)
    }

    public func config(data: BikeLocationInfoEntity, parent: BikeListViewController, index: Int) {
        self.parent = parent
        pointNameLabel.text = data.portName
        let position = CLLocationCoordinate2D(latitude: data.portLatitude, longitude: data.portLongitude)
        parent.reverseGeocodeCoordinate(position, index: index)
        
        restBikeStatus.text = String(data.availableUnits) + "台"
        restBikeStatus.textColor = UIColor.ringoGreen
        switch data.availableUnits {
        case 0:
            restBikeStatus.text = "なし"
            restBikeStatus.textColor = UIColor.textRed
            restBikeStatusImage.image = Asset.imgStatusFull.image
        case 1..<10:
            restBikeStatusImage.image = Asset.imgStatusScarce.image
        default:
            restBikeStatusImage.image = Asset.imgStatusVacant.image
        }
        let provider = providerType(rawValue: data.portProviderCode)!
        switch provider {
        case .docomo:
            useRingoKeySetup()
        default:
            mySuicaKeyHowToButton.isHidden = true
            suicaImage.isHidden = true
            checkinButton.isHidden = false
        }
    }
    
    private func bind() {
        detailButton.rx.tap
            .subscribe { [unowned self] _ in
                if ApplicationStore.instance.state.suicaIdi.isNotEmpty {
                    self.parent?.performSegue(withIdentifier: StoryboardSegue.BikeTab.toPayment.rawValue, sender: nil)
                } else {
                    self.parent?.performSegue(withIdentifier: StoryboardSegue.BikeTab.toUsageSuica.rawValue, sender: nil)
                }
            }
            .disposed(by: disposeBag)
        
        checkinButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.parent?.performSegue(withIdentifier: StoryboardSegue.BikeTab.toMySuica.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)
    }
    
    private func useRingoKeySetup() {
        if ApplicationStore.instance.state.suicaIdi.isNotEmpty {
            if ApplicationStore.instance.state.creditCards.isNotEmpty {
                let defaultCard = ApplicationStore.instance.state.creditCards.first(where: { $0.cardSlot! == ApplicationStore.instance.state.defaultCardSlot })
                let type = CreditCardBrand(rawValue: (defaultCard?.cardBrandCode)!)
                creditCardOrNotSuicaImage.image = Asset.cardBrandIamge(type: type!)
                creditLabelOrNotSuicaLabel.text = (defaultCard?.cardNumber ?? "" ) + "(月末支払)"
            } else {
                creditLabelOrNotSuicaLabel.text = ""
                creditCardOrNotSuicaImage.image = Asset.cardBrandIamge(type: .other)
            }
            creditLabelOrNotSuicaLabel.textColor = UIColor.textBlack
            detailButton.setTitle("詳細", for: .normal)
        } else {
            creditCardOrNotSuicaImage.image = Asset.imgSMysuicakeyRed.image
            creditLabelOrNotSuicaLabel.text = "Ringo Key 未登録"
            creditLabelOrNotSuicaLabel.textColor = UIColor.ringoRed
            detailButton.setTitle("使い方", for: .normal)
        }
        mySuicaKeyHowToButton.isHidden = ApplicationStore.instance.state.suicaIdi.isEmpty
        //suicaImage.isHidden = ApplicationStore.instance.state.suicaIdi.isEmpty
        checkinButton.isHidden = ApplicationStore.instance.state.suicaIdi.isNotEmpty
    }
    
    func acordion(open: Bool) {
        heightConstraint.constant = (open) ? initHeight! : closeLineView.frame.origin.y
    }
    
    func addGradationCell(graLayer: CAGradientLayer, type: gradationType) {
        let clear = UIColor(color: UIColor.white, alpha: 0.0).cgColor
        let white = UIColor.white.cgColor
        switch type {
        case .white:
            graLayer.colors = [white, white]
            graLayer.startPoint = CGPoint(x: 0.5, y: 0)
            graLayer.endPoint = CGPoint(x: 0.5, y: 1)
        case .gradation:
            graLayer.colors = [clear, white]
        }
        graLayer.frame = bounds
        layer.mask = graLayer
    }
    
}
