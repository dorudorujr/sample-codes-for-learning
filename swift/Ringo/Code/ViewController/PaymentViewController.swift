//
//  PaymentViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/03/01.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import Foundation
import ApplicationModel
import ApplicationConfig
import ApplicationLib
import ReSwift
import RxCocoa
import RxGesture
import RxSwift
import UIKit

// h-001
final class PaymentViewController: UIViewController {

    @IBOutlet private weak var cardCollectionView: UICollectionView!    //横スクロールのカード画像のCollectionView
    @IBOutlet private weak var detailCollectionView: UICollectionView!  //横スクロールのカード情報のCollectionView
    @IBOutlet private weak var addCardButton: UIButton!                 //追加ボタン

    private var cardCells = [PaymentCardCell]()         //カード画像のcell
    private var cells = [PaymentCardInfoCell]()         //カード情報のcell
    private var labels = [UILabel]()
    private var rightBarButton: UIBarButtonItem?
    private let cardCellSize = CGSize(width: 224.0, height: 137.0) // CardCellの固定サイズ

    public var userStatus: Int {
        return store.state.paymentStatus
    }

    public var userStatusAsObservable: Observable<Int> {
        return store.userStatus.asObservable()
    }

    var isCloseButtonHide = false
    var selectedIndex: Int?
    var selectNowIndex: Int = 0
    var isPaymentUnPaid = false
    
    var isTaxiTab = false
    
    var requestCardSlot = 0
    var beforeCardSlot = 0
    
    private let store = RxStore(store: Store<PaymentCardInfoViewState>(reducer: PaymentCardInfoViewReducer.handleAction, state: nil))

    //表示されているクレジットカード情報達
    private var paymentCardInfoRequestCreator: PaymentCardInfoActionCreatable! {
        willSet {
            if paymentCardInfoRequestCreator != nil {
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

    private var userStatusRequestCreator: UserStatusActionCreatable! {
        willSet {
            if userStatusRequestCreator != nil {
                fatalError()
            }
        }
    }

    private let disposeBag = DisposeBag()

    func inject(paymentCardInfoRequestCreator: PaymentCardInfoActionCreatable, unPaidInfoRequestCreator: UnPaidInfoActionCreatable, userStatusRequestCreator: UserStatusActionCreatable) {
        self.paymentCardInfoRequestCreator = paymentCardInfoRequestCreator
        self.unPaidInfoRequestCreator = unPaidInfoRequestCreator
        self.userStatusRequestCreator = userStatusRequestCreator
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sendTrackingScreen(name: GoogleAnalyticsScreen.paymentList)

        navigationBarSetup(titleText: L10n.h001PaymentListTitle, color: UIColor.ringoGreen, fontSize: 14, modal: true, visibleLeft: !isCloseButtonHide, dispose: disposeBag)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false    //スワイプで戻るを無効？ 
        navigationController?.navigationBar.deleteShadow()
        navigationController?.navigationBar.ringoGreen(color: UIColor.white)
        rightBarButton = UIBarButtonItem(title: L10n.h001PaymentListEdit, style: .plain, target: nil, action: nil)
        setBarRightButton()

        addCardButton.addCorner(corner: [.topLeft], cornerValue: 80)        //ボタンの形を変形
        cardCollectionView.delegate = self      //cellタップ処理に必要
        detailCollectionView.delegate = self    //cellタップ処理に必要
        bind()
    }

    override func didMove(toParentViewController parent: UIViewController?) {
        super.didMove(toParentViewController: parent)

        if let index = selectedIndex {
            scrollCardView(next: index)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        scrollCardView(next: 0)
        navigationController?.navigationBar.changeColor(color: UIColor.white)
        navigationController?.navigationBar.tintColor = UIColor.ringoGreen
        setBarRightButton()

        store.dispatch(paymentCardInfoRequestCreator.get(parameter: PaymentCardInfoParameter(), disposeBag: disposeBag))

        store.dispatch(userStatusRequestCreator.get(parameter: UserStatusParameter(), disposeBag: disposeBag))

        store.dispatch(unPaidInfoRequestCreator.get(parameter: UnPaidInfoParameter(), disposeBag: disposeBag))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch StoryboardSegue.Payment(rawValue: segue.identifier!)! {
        //編集ボタン
        case .toCardInfo:
            let next = segue.destination as! RegisterCreditCardViewController
            next.isDefaultCard = ApplicationStore.instance.state.defaultCardSlot == store.state.creditCards[selectNowIndex].cardSlot!   //デフォルトカードと編集しようとしているカードが同じかどうか
            next.state = .changeInfo                                        //カードの追加か編集か判別
            next.emptyCardSlot = emptySlot()                                //総カード数
            next.selectedCardInfo = store.state.creditCards[selectNowIndex] //カード情報
        //追加ボタン
        case .toRegisterCard:
            let next = segue.destination as! RegisterCreditCardViewController
            next.state = .addCard
            next.emptyCardSlot = emptySlot()
            next.isUnpaid = isCloseButtonHide
            next.isCardEmpty = store.state.creditCards.isEmpty      //配列が空かどうかチェック
            if store.state.creditCards.isNotEmpty {
                next.selectedCardInfo = ApplicationStore.instance.state.creditCards[selectNowIndex]
            }
        }
    }

    func bind() {

        store.creditCards
            .do { self.cardCells.removeAll() }
            .bind(to: cardCollectionView.rx.items(cellIdentifier: "PaymentCardCell", cellType: PaymentCardCell.self)) { [unowned self] (index, data, cell) in
                cell.config(index: index, userStatus: self.userStatus, cardData: data)
                //追加か編集か？
                if self.cardCells.count <= index {
                    self.cardCells.append(cell)
                } else {
                    self.cardCells[index] = cell
                }
            }
            .disposed(by: disposeBag)

        store.creditCards
            .do { self.cells.removeAll() }
            .bind(to: detailCollectionView.rx.items(cellIdentifier: "PaymentCardInfoCell", cellType: PaymentCardInfoCell.self)) { [unowned self] (index, data, cell) in
                cell.config(data: data, index: index, userStatus: self.userStatus, isTaxiTab: self.isTaxiTab)
                //セルの数と一致しなかったらセルを増やす
                if self.cells.count <= index {
                    
                    cell.taxiPaymentSelected = {
                        ApplicationStore.instance.dispatch(UpdateTaxiPaymentCardSlot(taxiPaymentCardSlot: cell.cardSlot))
                        self.dismiss(animated: true, completion: nil)
                    }
                
                    cell.paymentUnPaid = {
                        self.isPaymentUnPaid = true
                        self.updateDefaultCard(cardSlot: cell.cardSlot)
                    }
                    
                    cell.defaultCardChange = {
                        self.updateDefaultCard(cardSlot: cell.cardSlot)
                    }
                    
                    self.cells.append(cell)
                } else {
                    self.cells[index] = cell
                }
            }
            .disposed(by: disposeBag)

        Observable.combineLatest(store.creditCards, store.defaultCardSlot)
            .filter { $0.1 != nil }
            .subscribe { [unowned self] in
                if let creditCards = $0.element?.0, let defaultCardSlot = $0.element?.1 {
                    ApplicationStore.instance.dispatch(UpdateCreditCardDataAction(creditCards: creditCards, defaultCardSlot: defaultCardSlot))
                    self.addCardButton.isHidden = self.isMaxSlot()
                }
            }
            .disposed(by: disposeBag)

        addCardButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.performSegue(withIdentifier: StoryboardSegue.Payment.toRegisterCard.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)

        navigationItem.rightBarButtonItem?.rx.tap
            .subscribe({ [unowned self] _ in
                self.performSegue(withIdentifier: StoryboardSegue.Payment.toCardInfo.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)

        //デフォルトカードのスロットを変更したらtrue(putAPIをたたいたら)
        store.changedDefaultCard
            .filter { $0 }
            .subscribe({ [unowned self] _ in
                self.beforeCardSlot = ApplicationStore.instance.state.defaultCardSlot
                if self.isPaymentUnPaid {
                    let param = PaymentUnPaidParameter(cardSlot: self.requestCardSlot)
                        self.store.dispatch(self.unPaidInfoRequestCreator.post(parameter: param, disposeBag: self.disposeBag))
                    self.isPaymentUnPaid = false
                }
                let creditCards = ApplicationStore.instance.state.creditCards
                ApplicationStore.instance.dispatch(UpdateCreditCardDataAction(creditCards: creditCards, defaultCardSlot: self.requestCardSlot))
                //enumeratedでindexを作成して
                //offsetで作成したindexにアクセスしている?
                self.cells.enumerated().forEach { cell in
                    //ボタンの変更を行なっている
                    cell.element.defaultCard(check: (self.requestCardSlot-1 == cell.offset))
                }
                self.cardCells.enumerated().forEach { cardCell in
                    cardCell.element.defaultCard(check: (self.requestCardSlot-1 == cardCell.offset))
                }
                self.detailCollectionView.reloadData()
            })
            .disposed(by: disposeBag)

        store.paymentUnpaided
            .filter { $0 }
            .subscribe({ [unowned self] _ in
                self.dismiss(animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
        
        //未収情報があったらカードを使えなくする
        userStatusAsObservable
            .filter { $0 != -1 }
            .subscribe({ [unowned self] in
                let defaultIndex = PaymentCardInfoCell.selectedIndex.value
                self.cardCollectionView.reloadData()
                self.detailCollectionView.reloadData()
                if defaultIndex >= 0 && defaultIndex < (self.cells.count) && $0.element == UserStatus.isUnpaid {
                    self.cells[PaymentCardInfoCell.selectedIndex.value].stopUseCard()
                    self.cardCells[PaymentCardInfoCell.selectedIndex.value].stopUseCard()
                }
            })
            .disposed(by: disposeBag)

        Observable.merge(cardCollectionView.rx.swipeGesture(.left).asObservable(), detailCollectionView.rx.swipeGesture(.left).asObservable())
            .subscribe({ [unowned self] _ in
                self.scrollCardView(next: 1)
            })
            .disposed(by: disposeBag)

        Observable.merge(cardCollectionView.rx.swipeGesture(.right).asObservable(), detailCollectionView.rx.swipeGesture(.right).asObservable())
            .subscribe({ [unowned self] _ in
                self.scrollCardView(next: -1)
            })
            .disposed(by: disposeBag)
        
        Observable.merge(store.error, ApplicationStore.instance.error)
            .filter { $0 != nil && self.navigationController?.topViewController == self }
            .subscribe { [unowned self] in
                let error = $0.element
                var message = ""
                var selectButton: Alert.ActionType = .ok
                switch error {
                case let error as RingoHttpStatusError:
                    if let message = error.message {
                        if message.isEmpty {
                            return
                        }
                    }
                    message = error.message ?? ""
                // TODO: 利用規約取得APIがstatuscodeが200番台でもレスポンスの形が違うので暫定処理(MappingErrorは表示させたいものであはる)
                case let error as MappingError:
                    print(error.localizedDescription)
                    return
                default: break
                }
                // OS Defaultのメッセージぽい、暫定対応
                if error!!.localizedDescription == "The Internet connection appears to be offline." {
                    message = offlineMessage
                    selectButton = .retry
                }
                Alert.show(to: self, message: (message.isNotEmpty) ? message : error!!.localizedDescription, style: .custom(buttons: [(selectButton, .default)]))
                    .subscribe {
                        //未収清算失敗の際のアラートであればデフォを戻す
                        if self.store.state.paymentUnpaidError {
                            self.updateDefaultCard(cardSlot: self.beforeCardSlot)
                            self.store.dispatch(PaymentUnPaidAlertEndAction())
                        }
                    }
                    .disposed(by: self.disposeBag)
            }
            .disposed(by: disposeBag)
        
        commonBind(isLoading: store.isLoading, disposeBag: disposeBag)
    }

    private func scrollCardView(next: Int) {
        let now = detailCollectionView.contentOffset.x
        let index = nearIndex(now: now, offset: UIScreen.main.bounds.size.width)
        let nextIndex = clamp(value: index + next, lowerLimit: 0, upperLimit: ApplicationStore.instance.state.creditCards.count - 1)
        selectNowIndex = (nextIndex == -1 ? 0 : nextIndex)
        var result = clamp(value: cardCellSize.width * CGFloat(nextIndex), lowerLimit: 0.0, upperLimit: cardCollectionView.contentSize.width)
        cardCollectionView.setContentOffset(CGPoint(x: result, y: cardCollectionView.contentOffset.y), animated: true)  //位置を変更
        result = clamp(value: UIScreen.main.bounds.size.width * CGFloat(nextIndex), lowerLimit: 0.0, upperLimit: detailCollectionView.contentSize.width)
        detailCollectionView.setContentOffset(CGPoint(x: result, y: detailCollectionView.contentOffset.y), animated: true)
    }

    private func setBarRightButton() {
        //クレジットカードが登録されているのなら編集ボタンを表示
        if ApplicationStore.instance.state.creditCards.isEmpty {
            navigationItem.rightBarButtonItem = nil
        } else {
            navigationItem.rightBarButtonItem = rightBarButton
        }
    }

    //now:現在のcorrectionViewの位置
    //offset:画面サイズ
    private func nearIndex(now: CGFloat, offset: CGFloat) -> Int {
        var minIndex = 0
        var minDiff: CGFloat = 10000.0
        for i in 0..<cardCells.count {
            let diff = min(fabs(offset * CGFloat(i) - now), minDiff)
            if diff < minDiff {
                minIndex = i
                minDiff = diff
            }
        }
        return minIndex
    }

    //空いているスロットを返す
    private func emptySlot() -> Int {
        let slots = store.state.creditCards.map { $0.cardSlot! }
        let emptyFirst = [1, 2, 3, 4, 5].first(where: { !slots.contains($0) })
        if let emptyCardSlot = emptyFirst {
             return emptyCardSlot
        }
        return 0
    }

    private func isMaxSlot() -> Bool {
        return ApplicationStore.instance.state.creditCards.count == CreditCard.registMax
    }

    private func updateDefaultCard(cardSlot: Int) {
        let param = UpdateDefaultCardParameter(cardSlot: cardSlot)
            self.store.dispatch(self.paymentCardInfoRequestCreator.put(parameter: param, disposeBag: self.disposeBag))
        requestCardSlot = cardSlot
    }
    
}

extension PaymentViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if collectionView == cardCollectionView {
            return CGSize(width: (collectionView.frame.size.width - cardCellSize.width + collectionView.contentInset.left) / 2.0, height: 0.0)
        }
        return CGSize.zero
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if collectionView == cardCollectionView {
            return CGSize(width: (collectionView.frame.size.width - cardCellSize.width + collectionView.contentInset.left) / 2.0, height: 0.0)
        }
        return CGSize.zero
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == cardCollectionView {
            return cardCellSize
        }
        return CGSize(width: UIScreen.main.bounds.size.width, height: collectionView.bounds.size.height)
    }
}

extension RxStore where AnyStateType == PaymentCardInfoViewState {

    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }

    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }
    }

    var creditCards: Observable<[PaymentCardInfoEntity]> {
        return stateObservable.map { $0.creditCards }.distinctUntilChanged { $0 == $1 }
    }

    var unPaidInfo: Observable<[UnPaidInfoEntity]> {
        return stateObservable.map { $0.unPaidInfos }
    }

    var paymentUnpaided: Observable<Bool> {
        return stateObservable.map { $0.paymentUnpaided }.distinctUntilChanged()
    }
    
    var paymentUnpaidError: Observable<Bool> {
        return stateObservable.map { $0.paymentUnpaidError }.distinctUntilChanged()
    }

    var userStatus: Observable<Int> {
        return stateObservable.map { $0.paymentStatus }.distinctUntilChanged { $0 == $1 }
    }

    var defaultCardSlot: Observable<Int?> {
        return stateObservable.map { $0.defaultSlot }.distinctUntilChanged { $0 == $1 }
    }

    var changedDefaultCard: Observable<Bool> {
        return stateObservable.map { $0.changedDefaultCard }.distinctUntilChanged()
    }
}
