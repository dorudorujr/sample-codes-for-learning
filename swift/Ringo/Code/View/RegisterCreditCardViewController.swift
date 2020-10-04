//
//  RegisterCreditCard.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/02/13.
//  Copyright © 2018年 Team Lab. All rights reserved.
//
//デフォルトカードのみの編集:空いているスロットにpostしてchangeDefaultCardでもともとのカードをデリート
//

import Foundation
import UIKit
import RxSwift
import ReSwift
import ApplicationModel
import ApplicationConfig
import ApplicationLib

// c-003, h-002, h-003
//クレジットカードの編集は削除してから再登録
final class RegisterCreditCardViewController: UIViewController, CardNameValidatable {

    @IBOutlet private weak var cardNumber: UITextField!                 //カード番号入力欄
    @IBOutlet private weak var expirationDateMM: UITextField!           //有効期限月
    @IBOutlet private weak var expirationDateYY: UITextField!           //有効期限年
    @IBOutlet private weak var securityCode: UITextField!               //セキュリティコード入力欄
    @IBOutlet private weak var cardName: UITextField!                   //カード名入力欄
    @IBOutlet private weak var saveButton: UIButton!                    //保存ボタン
    @IBOutlet private weak var deleteButton: UIButton!                  //右上の削除ボタン
    @IBOutlet private weak var securityHelpButton: UIButton!            //セキュリティコードの右の画像ボタン
    @IBOutlet private weak var securityCodeBottom: NSLayoutConstraint!
    @IBOutlet private weak var creditCardImage: UIImageView!            //カード画像
    @IBOutlet private weak var creditCardLogoImage: UIImageView!        //カードのロゴ画像
    @IBOutlet private weak var creditCardNumberLabel: UILabel!          //カード番号Label
    @IBOutlet private weak var creditCardNameLabel: UILabel!            //カード名Label
    @IBOutlet private weak var infoInputView: UIView!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var scrollViewBottomConstraint: NSLayoutConstraint!
    
    var state: ViewState = .none
    var isDefaultCard = false       //編集を行うのがデフォルトカードかどうか
    var emptyCardSlot: Int = 0
    var isUnpaid = false
    var isCardEmpty = false
    var selectedCardInfo: PaymentCardInfoEntity?
    var isRegisterCardName = false          //カード名のみの登録かどうかのflag?
    private var selectedCardInfoData: PaymentCardInfoEntity!
    private var defaultViewOrigin: CGPoint?

    enum ViewState {
        case signup
        case changeInfo
        case addCard
        case none
    }

    private let store = RxStore(store: Store<RegisterCreditCardViewState>(reducer: RegisterCreditCardViewReducer.handleAction, state: nil))
    private var requestCreator: RegisterCreditCardActionCreatable! {
        willSet {
            if requestCreator != nil {
                fatalError()
            }
        }
    }

    private var unPaidInfoRequestCreator: UnPaidInfoActionCreatable! {
        willSet {
            if unPaidInfoRequestCreator != nil {
                fatalError()
            }
        }
    }

    private let disposeBag = DisposeBag()
    private let completeView = CompleteView()
    private var changeInfoFlow = false
    private var delete = false
    private var finish = PublishSubject<Void>()

    func inject(requestCreator: RegisterCreditCardActionCreatable, unPaidInfoRequestCreator: UnPaidInfoActionCreatable) {
        self.requestCreator = requestCreator
        self.unPaidInfoRequestCreator = unPaidInfoRequestCreator
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setValidation(of: cardName)
        
        switch state {
        case .signup:
            sendTrackingScreen(name: GoogleAnalyticsScreen.inputCreditCardInfo)
        case .changeInfo:
            sendTrackingScreen(name: GoogleAnalyticsScreen.changeCreditCardInfo)
        case .addCard:
            sendTrackingScreen(name: GoogleAnalyticsScreen.cregitCardInfo)
        default: break
        }
        
        setupCompleteView(completeView: completeView, disposedBag: disposeBag)

        navigationController?.navigationBar.tintColor = UIColor.white
        if state == .changeInfo {
            
            selectedCardInfoData = selectedCardInfo!        //
            
            title(text: L10n.h003ChangeCreditcardInfoTitle, color: UIColor.ringoGreen, fontSize: 14)
            saveButton.setTitle(L10n.h003ChangeCreditcardInfoChangeSave, for: .normal)
            
            creditCardImage.image = Asset.cardImage(index: selectedCardInfoData.cardSlot!)
            let type = CreditCardBrand(rawValue: selectedCardInfoData.cardBrandCode!)
            creditCardLogoImage.image = Asset.cardLogoIamge(type: type!)
            creditCardNumberLabel.text = selectedCardInfo?.cardNumber
            
            //TODO: cardName サーバー対応するまでkeyChainに保存
            switch selectedCardInfoData.cardSlot! {
            case 1:
                creditCardNameLabel.text = KeyChainUtil.shared.get(key: KeyChainKey.cardName1)
            case 2:
                creditCardNameLabel.text = KeyChainUtil.shared.get(key: KeyChainKey.cardName2)
            case 3:
                creditCardNameLabel.text = KeyChainUtil.shared.get(key: KeyChainKey.cardName3)
            case 4:
                creditCardNameLabel.text = KeyChainUtil.shared.get(key: KeyChainKey.cardName4)
            default:
                creditCardNameLabel.text = KeyChainUtil.shared.get(key: KeyChainKey.cardName5)
            }
            
        } else {
            title(text: L10n.c003CompletedInputCreditcardInfoInputCreditCard, color: UIColor.ringoGreen, fontSize: 14)
        }
        navigationController?.navigationBar.deleteShadow()
        navigationController?.navigationBar.tintColor = UIColor.ringoGreen
        deleteButton.isHidden = state != .changeInfo
        
        keyboardHideViewUp(disposeBag: disposeBag, scrollView: scrollView, scrollBottomConstraint: scrollViewBottomConstraint)
        
        bind()

        store.dispatch(ResetCreditCardAction())
    }
    
    func setValidation(of: UITextField) {
        of.delegate = of
    }
    
    private func bind() {
        uiBind()
        coreBind()
        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }

    private func uiBind() {
        //.editingChanged:文字を入力した時
        //.orEmpty: 空文字やnilはオブザーブしない&String? → Stringに変換してくれている
        let cardNumberStream = cardNumber.rx.controlEvent([.editingChanged]).flatMap { [unowned self] in self.cardNumber.rx.text.orEmpty }
        let expirationMMStream = expirationDateMM.rx.controlEvent([.editingChanged]).flatMap { [unowned self] in self.expirationDateMM.rx.text.orEmpty }
        let expirationYYStream = expirationDateYY.rx.controlEvent([.editingChanged]).flatMap { [unowned self] in self.expirationDateYY.rx.text.orEmpty }
        let securityCodeStream = securityCode.rx.controlEvent([.editingChanged]).flatMap { [unowned self] in self.securityCode.rx.text.orEmpty }
        let cardNameStream = cardName.rx.controlEvent([.editingChanged]).flatMap { [unowned self] in self.cardName.rx.text.orEmpty }

        //入力制限
        Observable.merge(cardNumberStream, expirationMMStream, expirationYYStream)
            .filter { !$0.isNumeric() && $0.isNotEmpty  || ($0.validationTextCount(validationCount: CreditCard.numberLimit, compOperator: .Greater)) }
            .subscribe({ [unowned self] in
                var text = $0.element
                text?.removeLast()
                self.updateText(fieldText: $0.element!, updateText: text!)
            })
            .disposed(by: disposeBag)

        //入力制限
        Observable.merge(expirationMMStream, expirationYYStream)
            .filter { !$0.isNumeric() && $0.isNotEmpty  || ($0.validationTextCount(validationCount: CreditCard.yymmLimit, compOperator: .Greater)) }
            .subscribe({ [unowned self] in
                var text = $0.element
                text?.removeLast()
                self.updateText(fieldText: $0.element!, updateText: text!)
            })
            .disposed(by: disposeBag)

        securityCodeStream
            .filter { !$0.isNumeric() && $0.isNotEmpty  || ($0.validationTextCount(validationCount: CreditCard.securityLimit, compOperator: .Greater)) }
            .subscribe({ [unowned self] in
                var text = $0.element
                text?.removeLast()
                self.updateText(fieldText: $0.element!, updateText: text!)
            })
            .disposed(by: disposeBag)
        
        //入力したNameが画像のLabelにリアルタイムで反映される
        cardNameStream
            .subscribe({ _ in
                self.creditCardNameLabel.text = self.cardName.text
            })
            .disposed(by: disposeBag)
        
        //入力制限
        cardNameStream
            .filter { ($0.validationTextCount(validationCount: CreditCard.cardNameMax, compOperator: .Greater)) }
            .subscribe({ [unowned self] in
                var text = $0.element
                text?.removeLast()
                self.updateText(fieldText: $0.element!, updateText: text!)
            })
            .disposed(by: disposeBag)

        //セーブボタンの有効無効の判断
        Observable.combineLatest(cardNumber.rx.text, expirationDateMM.rx.text, expirationDateYY.rx.text, securityCode.rx.text, cardName.rx.text)
            .subscribe({ [unowned self] in
                let checkNumber = ($0.element?.0?.validationTextCount(validationCount: CreditCard.numberLimit, compOperator: .Equal))! || ($0.element?.0?.validationTextCount(validationCount: CreditCard.numberLimitDinners, compOperator: .Equal))!
                let checkMMDate = $0.element?.1?.isNotEmpty
                let checkYYDate = $0.element?.2?.isNotEmpty
                let checkCode = $0.element?.3?.isNotEmpty
                let cardName = $0.element?.4?.isNotEmpty
                
                switch self.state {
                case .changeInfo:
                    if cardName! {
                        self.saveButton.isEnabled = true
                        self.isRegisterCardName = cardName! && !checkNumber || !checkMMDate! || !checkYYDate! || !checkCode!
                    } else {
                        self.saveButton.isEnabled = (checkNumber && checkMMDate! && checkYYDate! && checkCode!)
                        self.isRegisterCardName = false
                    }
                default:
                    self.saveButton.isEnabled = (checkNumber && checkMMDate! && checkYYDate! && checkCode!)
                }
                self.saveButton.changeColor()
            })
            .disposed(by: disposeBag)

        saveButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.saveButtonBehaviour()
            })
            .disposed(by: disposeBag)

        //セキュリティコードについての説明alert表示
        //今は未実装
        securityHelpButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.delete = false
                Alert.show(to: self, title: L10n.h002CreditcardInfoSecureCodeDescription, style: .ok)
                    .subscribe()
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)

        deleteButton.rx.tap
            .subscribe({ [unowned self] _ in
                Alert.show(to: self, message: L10n.h003ChangeCreditcardInfoDeleteAlert, style: .custom(buttons: [(.ok, .default), (.cancel, .cancel)]))
                    .subscribe {
                        guard let result = $0.element else { return }
                        if result == .ok {
                            self.delete = true
                            let param = DeleteCreditCardParameter(cardSlot: self.selectedCardInfoData.cardSlot!)
                            self.store.dispatch(self.requestCreator.delete(parameter: param, disposeBag: self.disposeBag))
                            self.changeCardName(slot: self.selectedCardInfoData.cardSlot!)
                        }
                    }
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)
    }
    
    private func coreBind() {
        //外部APIを使用して認証が通ったらキャッチ
        store.token
            .filter { $0.isNotEmpty }
            .subscribe({ [unowned self] in
                // cardSlotは1~5なので注意
                var slot = 0
                //編集状態&デフォルトカードじゃなければ通る
                if self.changeInfoFlow && self.isOtherThanDefaultCard() {
                    slot = (self.selectedCardInfo?.cardSlot)!
                } else {
                    slot = self.emptyCardSlot
                }
                let param = RegisterCreditCardParameter(cardToken: $0.element!, cardSlot: self.state == .signup ? 1 : slot)
                self.store.dispatch(self.requestCreator.post(parameter: param, disposeBag: self.disposeBag))
            })
            .disposed(by: disposeBag)

        //postが成功した時にtrue
        store.regist
            .filter { $0 }
            .subscribe({ [unowned self] _ in
                if self.isDefaultCard {
                    //サーバにデフォルトカードのスロットを伝えている
                    let param = UpdateDefaultCardParameter(cardSlot: self.emptyCardSlot)
                    self.store.dispatch(self.requestCreator.put(parameter: param, disposeBag: self.disposeBag))
                } else {
                    self.finish.onNext(Void())
                }
            })
            .disposed(by: disposeBag)

        store.deleted
            .filter { $0 }
            .subscribe({ [unowned self] _ in
                self.deleteBehaviour()
            })
            .disposed(by: disposeBag)
        
        //未払いの時
        store.paymentUnpaided
            .filter { $0 }
            .subscribe({ [unowned self] _ in
                self.dismiss(animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        //デフォルトカードの情報を更新した時true
        //putをした時
        store.changeDefaultCard
            .filter { $0 }
            .subscribe({ [unowned self] _ in
                if self.isOtherThanDefaultCard() {
                    self.finish.onNext(Void())
                } else {
                    let param = DeleteCreditCardParameter(cardSlot: (self.selectedCardInfo?.cardSlot)!)
                    self.store.dispatch(self.requestCreator.delete(parameter: param, disposeBag: self.disposeBag))
                }
            })
            .disposed(by: disposeBag)

        finish
            .subscribe({ [unowned self] _ in
                switch self.state {
                case .signup, .addCard:
                    self.completeView.text = "追加完了"
                case .changeInfo:
                    if self.delete {
                        self.completeView.text = "削除完了"
                        let newCardInfo = ApplicationStore.instance.state.creditCards.filter { $0 != self.selectedCardInfo }
                        ApplicationStore.instance.dispatch(UpdateCreaditCardAction(newCardInfo: newCardInfo))
                        ApplicationStore.instance.dispatch(UpdateTaxiPaymentCardSlot(taxiPaymentCardSlot: ApplicationStore.instance.state.defaultCardSlot))
                    } else {
                        self.completeView.text = "編集完了"
                    }
                default: break
                }
                self.completeView.fadein(animFinish: { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                        self.view.endEditing(true)
                        self.view.addSubview(self.completeView)
                        if self.state == .signup {
                            self.performSegue(withIdentifier: StoryboardSegue.CardRegister.toTutorial.rawValue, sender: nil)
                        } else if self.state == .addCard && (self.isUnpaid || self.isCardEmpty) {
                            //クレジットカードが一つも登録していない状態でのカード追加の場合
                            //未収状態の場合？
                            self.finishUnpaidOrCardEmpty()
                        } else {
                            if self.isRegisterCardName {
                                //cellのカードを更新
                                let nav = self.navigationController
                                let paymentViewController = nav?.viewControllers[(nav?.viewControllers.count)!-2] as! PaymentViewController
                                paymentViewController.reloadCellView()
                            }
                            self.navigationController?.popViewController(animated: true)
                        }
                    })
                })
                self.store.dispatch(ResetCreditCardAction())
            })
            .disposed(by: disposeBag)
    }
    private func saveButtonBehaviour() {
        switch state {
        case .signup, .addCard:
            veriTransRegist()
        case .changeInfo:
            //カード名のみの変更の場合
            if self.isRegisterCardName {
                self.changeCardName(slot: (selectedCardInfo?.cardSlot)!)
                finish.onNext(Void())
                return
            }
            changeInfoFlow = true
            //デフォルトカードじゃない場合
            //putAPIがないので一回削除して再度登録し直す？
            if !isDefaultCard {
                self.changeCardName(slot: (selectedCardInfo?.cardSlot)!)
                let param = DeleteCreditCardParameter(cardSlot: (selectedCardInfo?.cardSlot)!)
                store.dispatch(requestCreator.delete(parameter: param, disposeBag: disposeBag))
                return
            }
            //デフォルトカードの他にカードがある場合
            if isOtherThanDefaultCard() {
                //first(where): 条件に合致する一番最初の要素を取得
                let mockSlot = ApplicationStore.instance.state.creditCards.first(where: { $0.cardSlot! != selectedCardInfo?.cardSlot })!.cardSlot!
                self.changeCardName(slot: (selectedCardInfo?.cardSlot)!)
                let param = UpdateDefaultCardParameter(cardSlot: mockSlot)
                //デフォルトカードじゃない場合はput?
                store.dispatch(requestCreator.put(parameter: param, disposeBag: disposeBag))
            } else {
                //デフォルトカードオンリーで編集を行なった場合(いまのところ)
                veriTransRegist()
            }
        default: break
        }
    }

    private func deleteBehaviour() {
        switch state {
        case .changeInfo:
            if changeInfoFlow {
                if isOtherThanDefaultCard() || !isDefaultCard {
                    veriTransRegist()
                } else {
                    finish.onNext(Void())
                }
            } else {
                //ただの削除の場合
                self.store.dispatch(ResetCreditCardAction())
                finish.onNext(Void())
            }
        default: break
        }
    }
    
    private func finishUnpaidOrCardEmpty() {
        if isCardEmpty {
            dismiss(animated: true, completion: nil)
        } else {
            Alert.show(to: self, message: L10n.h001PaymentListAlertPayThisCard, style: .custom(buttons: [(.ok, .default), (.cancel, .cancel)]))
                .subscribe({ [unowned self] in
                    guard let result = $0.element else { return }
                    if result == .ok {
                        self.store.dispatch(self.unPaidInfoRequestCreator.post(parameter: PaymentUnPaidParameter(cardSlot: (self.selectedCardInfo?.cardSlot)!), disposeBag: self.disposeBag))
                    } else {
                        self.navigationController?.popViewController(animated: true)
                    }
                }).disposed(by: self.disposeBag)
        }
    }

    private func veriTransRegist() {
        var mm = expirationDateMM.text!
        if expirationDateMM.text!.count == 1 {
            mm = "0" + expirationDateMM.text!
        }

        //クレジットカードが有効かどうかの確認？
        //外部API使用
        let param = VeriTransRegistCreditCardParameter(cardNumber: cardNumber.text!, cardExpire: mm + "/" + expirationDateYY.text!, securityCode: securityCode.text!, tokenApiKey: Veritrans.apiTokenKey, lang: "en")
        store.dispatch(requestCreator.veritransPost(parameter: param, disposeBag: disposeBag))
        
        self.changeCardName(slot: self.emptyCardSlot)
    }

    private func updateText(fieldText: String, updateText: String) {
        switch fieldText {
        case cardNumber.text!:
            cardNumber.text = updateText
        case expirationDateMM.text!:
            expirationDateMM.text = updateText
        case expirationDateYY.text!:
            expirationDateYY.text = updateText
        case securityCode.text!:
            securityCode.text = updateText
        case cardName.text!:
            cardName.text = updateText
        default: break
        }
    }
    
    //TODO: cardName サーバー対応するまでkeyChainに保存
    private func changeCardName(slot: Int) {
        switch slot {
        case 1:
            KeyChainUtil.shared.set(key: KeyChainKey.cardName1, value: self.cardName.text!)
        case 2:
            KeyChainUtil.shared.set(key: KeyChainKey.cardName2, value: self.cardName.text!)
        case 3:
            KeyChainUtil.shared.set(key: KeyChainKey.cardName3, value: self.cardName.text!)
        case 4:
            KeyChainUtil.shared.set(key: KeyChainKey.cardName4, value: self.cardName.text!)
        case 5:
            KeyChainUtil.shared.set(key: KeyChainKey.cardName4, value: self.cardName.text!)
        default:
            break
        }
    }

    private func isOtherThanDefaultCard() -> Bool {
        return ApplicationStore.instance.state.creditCards.count > 1
    }
}

extension RxStore where AnyStateType == RegisterCreditCardViewState {

    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }.distinctUntilChanged()
    }

    var token: Observable<String> {
        return stateObservable.map { $0.token }.distinctUntilChanged()
    }

    var error: Observable<Error?> {
        return stateObservable.map { $0.error }
    }

    var regist: Observable<Bool> {
        return stateObservable.map { $0.regist }.distinctUntilChanged()
    }
    
    var paymentUnpaided: Observable<Bool> {
        return stateObservable.map { $0.paymentUnpaided }.distinctUntilChanged()
    }

    var deleted: Observable<Bool> {
        return stateObservable.map { $0.deleted }.distinctUntilChanged()
    }

    var changeDefaultCard: Observable<Bool> {
        return stateObservable.map { $0.changeDefaultCard }.distinctUntilChanged()
    }
}
