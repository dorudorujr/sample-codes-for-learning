import Foundation
import UIKit
import DropDown
import RxSwift
import ReSwift
import RxCocoa
import ApplicationModel
import ApplicationConfig
import SwiftDate
import ApplicationLib

// i-001-1
final class HistorySortViewController: UIViewController {

    @IBOutlet private weak var monthlyDropDown: UIButton!   //日付
    @IBOutlet private weak var monthlyPriceLabel: UILabel!  //金額
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var billingCardViewConstraint: NSLayoutConstraint!
    @IBOutlet private weak var billingCardView: UIView!     //支払い設定、明細メール再送ボタンがあるところ
    @IBOutlet private weak var requestPriceLabel: UILabel!  //ご請求額
    @IBOutlet private weak var defaultCardButton: UIButton! //支払い設定
    @IBOutlet private weak var zeroView: UIView!
    @IBOutlet private weak var reSendReCeiptButton: UIButton!   //明細メール再送信ボタン
    @IBOutlet private weak var monthlyDropDownLeftConstraint: NSLayoutConstraint!
    
    var hiddenBillingCardView = false
    let historyRefresh = UIRefreshControl()
    let refreshNotify = PublishSubject<String>()

    private var historyInfo: Variable<[PaymentHistoryEntity]>?
    private var selectedCell: Variable<HistoryCell?>?
    private var dropDownData: Observable<[HistoryMonthEntity]>?

    private let dropDown = DropDown()       //ライブラリ
    private let disposeBag = DisposeBag()

    private let store = RxStore(store: Store<HistorySortViewState>(reducer: HistorySortViewReducer.handleAction, state: nil))

    private var reSendReceiptRequestCreator: ReSendReceiptActionCreatable! {
        willSet {
            if reSendReceiptRequestCreator != nil {
                fatalError()
            }
        }
    }

    func inject(reSendReceiptRequestCreator: ReSendReceiptActionCreatable) {
        self.reSendReceiptRequestCreator = reSendReceiptRequestCreator
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if hiddenBillingCardView {
            sendTrackingScreen(name: GoogleAnalyticsScreen.taxiPaymentHistory)  //タクシーの場合
        } else {
            sendTrackingScreen(name: GoogleAnalyticsScreen.cyclePaymentHistory) //バイクの場合
        }
        
        monthlyDropDown.titleEdgeInsets = UIEdgeInsets(top: 13.5, left: 21.0, bottom: 13.0, right: 42.0)    //テキストの余白
        monthlyDropDown.titleLabel?.minimumScaleFactor = 0.5
        monthlyDropDown.titleLabel?.numberOfLines = 0
        monthlyDropDown.titleLabel?.adjustsFontSizeToFitWidth = true    //ボタンのlabelを可変に
        dropDown.anchorView = monthlyDropDown           //dropdownが表示されるview
        dropDown.bottomOffset = CGPoint(x: 0, y: (dropDown.anchorView?.plainView.bounds.height)!)

        //選択時にトリガされるアクション
        dropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            ApplicationStore.instance.dispatch(RegistSelectMonthAction(selectMonth: item))  //選択している日付の変更
            self.monthlyDropDown.setTitle(item, for: .normal)
            self.reSendReCeiptButton.isEnabled = !self.checkNowMonth(targetMonth: item)     //再送可能か判断して有効無効を指定
            self.changeButtonTextColor()
            self.refreshNotify.onNext(item)
        }
        
        reSendReCeiptButton.isEnabled = !checkNowMonth(targetMonth: monthlyDropDown.titleLabel?.text ?? "")
        changeButtonTextColor()

        tableView.estimatedRowHeight = 142
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.refreshControl = historyRefresh       //リフレッシュ処理の設定
        
        reSendReCeiptButton.isEnabled = !checkNowMonth(targetMonth: monthlyDropDown.titleLabel?.text ?? "")
        changeButtonTextColor()

        //タクシーとバイクで表示が違うのでバイクの場合は表示するという処理
        if hiddenBillingCardView {
            billingCardView.isHidden = true
            requestPriceLabel.isHidden = true
            monthlyPriceLabel.isHidden = true
            requestPriceLabel.text = L10n.i0011PaymentHistoryTaxiUsagePrice
            monthlyDropDownLeftConstraint.constant = HistorySortStatus.DropDownLeftTaxi
            
            billingCardView.layer.borderWidth = 0
            UIView.animate(withDuration: Animation.duration, animations: {
                self.billingCardViewConstraint.constant = 0
                self.view.layoutIfNeeded()
            })
        }

        bind()
    }

    //下記変数に値を代入する処理
    func setbindTaret(historyInfo: Variable<[PaymentHistoryEntity]>, selectedCell: Variable<HistoryCell?>, dropDownData: Observable<[HistoryMonthEntity]>) {
        self.historyInfo = historyInfo
        self.selectedCell = selectedCell
        self.dropDownData = dropDownData
    }

    private func bind() {
        uiBind()
        logicBind()
        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }
    
    private func uiBind() {
        //tableViewに表示
        historyInfo?.asObservable().asDriver(onErrorJustReturn: []).distinctUntilChanged({ return $0 == $1 })
            .asObservable().bind(to: tableView.rx.items(cellIdentifier: "HistoryCell", cellType: HistoryCell.self)) { [unowned self] (_, element, cell) in
                cell.config(data: element, taxi: self.hiddenBillingCardView)
            }
            .disposed(by: disposeBag)
        
        //履歴情報からご請求予定額を算出し表示している。ない場合は何もない画像を表示
        historyInfo?
            .asObservable()
            .subscribe({ [unowned self] in
                var totalPrice = 0
                $0.element?.forEach { totalPrice += $0.usageAmount }
                //値がなかったらなにもない画像を表示？
                if let data = $0.element {
                    self.zeroView.isHidden = data.isEmpty ? false : true
                }
                self.monthlyPriceLabel.text = L10n.i0021PaymentDetailTaxiPrice((totalPrice == 0 ? " -" : String.stringByCurrencyFormat(value: totalPrice)))
            })
            .disposed(by: disposeBag)
        
        defaultCardButton.rx.tap
            .subscribe({ [unowned self] _ in
                self.parent?.performSegue(withIdentifier: StoryboardSegue.PaymentHistory.toPayament.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)
        
        //選択したcellの情報を流す
        tableView.rx.itemSelected
            .map { [unowned self] in (self.tableView.cellForRow(at: $0) as? HistoryCell)! }
            .asObservable()
            .bind(to: selectedCell!)
            .disposed(by: disposeBag)
        
        monthlyDropDown.rx.tap
            .subscribe({ [weak self] _ in
                self?.dropDown.show()
            })
            .disposed(by: disposeBag)
        
        historyRefresh.rx.controlEvent(.valueChanged)
            .filter {
                guard let text = self.monthlyDropDown.titleLabel?.text else { return false }
                return text.isNotEmpty
            }
            .subscribe({ [unowned self] _ in
                //refreshNotifyに現在選択されている日付を送る。
                //refreshNotifyの値が更新されることによってPaymentHistoryViewControllerでapiから値を取得してくる。
                self.refreshNotify.onNext((self.monthlyDropDown.titleLabel?.text!)!)
            })
            .disposed(by: disposeBag)
        
        reSendReCeiptButton.rx.tap
            .subscribe({ [unowned self] _ in
                Alert.show(to: self, title: L10n.i0011PaymentHistoryTaxiAlertResendRecipt, style: .custom(buttons: [(.cancel, .cancel), (.ok, .default)]))
                    .subscribe {
                        guard let result = $0.element else { return }
                        if result == .ok {
                            self.sendTrackingEvent(category: PaymentDetailsResend_BikeShare.category.rawValue, action: PaymentDetailsResend_BikeShare.action.rawValue)
                            let param = ReSendCycleReceiptParameter(month: ApplicationStore.instance.state.selectMonth)
                            //もう一度dispatchしている?
                            self.store.dispatch(self.reSendReceiptRequestCreator.postReSendCycleReceipt(parameter: param, disposeBag: self.disposeBag))
                        }
                    }
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)
        
        store.didSend
            .filter { $0 }
            .subscribe({ _ in
                Alert.show(to: self, title: L10n.i0021PaymentDetailTaxiAlertResendReciptComplete, style: .ok)
            })
            .disposed(by: disposeBag)
    }
    
    private func logicBind() {
        dropDownData!
            .filter { $0.isNotEmpty }
            .map { $0.map { $0.month } }
            .subscribe({ [unowned self] in
                //ドロップダウンのデータをセット
                self.dropDown.dataSource = $0.element.map { $0.map { $0 ?? ""  } }!     //dropdownにデータをセット
                let month = ($0.element?.first)!
                self.monthlyDropDown.setTitle(month, for: .normal)
                self.reSendReCeiptButton.isEnabled = !self.checkNowMonth(targetMonth: month!)
                self.changeButtonTextColor()
            })
            .disposed(by: disposeBag)
    }
    
    private func changeButtonTextColor() {
        self.reSendReCeiptButton.changeColor(enableColor: UIColor.white, disableColor: UIColor.white)
    }
    
    //日付のチェック
    private func checkNowMonth(targetMonth: String) -> Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        let now = Date()
        let nowMonth = f.string(from: now)
        return targetMonth == nowMonth || targetMonth.isEmpty
    }
}

extension RxStore where AnyStateType == HistorySortViewState {
    
    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }
    
    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }
    }
    
    var didSend: Observable<Bool> {
        return stateObservable.map { $0.didSend }
    }
}