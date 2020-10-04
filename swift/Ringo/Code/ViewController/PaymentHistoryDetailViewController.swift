import Foundation
import UIKit
import RxSwift
import ReSwift
import RxDataSources
import ApplicationModel
import ApplicationConfig
import ApplicationLib
import SnapKit

final class PaymentHistoryDetailViewController: UIViewController {

    @IBOutlet private weak var mobilityLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var priceLabel: UILabel!
    @IBOutlet private weak var mobilityIcon: UIImageView!
    @IBOutlet private weak var bikeContainerView: UIView!
    @IBOutlet private weak var taxiContainerView: UIView!
    
    var serviceType: Int?
    var usageId: String?
    var mobilityText: String?
    var dateLabelText: String?
    var statusLabelText: String?
    var statusLabelColor: UIColor?
    
    var priceLabelText: String?
    var isTaxiPayment = false
    
    private var tableView: UITableView?
    
    private let store = RxStore(store: Store<PaymentHistoryDetailState>(reducer: PaymentHistoryDetailReducer.handleAction, state: nil))

    private var requestCreator: PaymentHistoryDetailActionCreatable! {
        willSet {
            if requestCreator != nil {
                fatalError()
            }
        }
    }
    private var reSendReceiptRequestCreator: ReSendReceiptActionCreatable! {
        willSet {
            if reSendReceiptRequestCreator != nil {
                fatalError()
            }
        }
    }

    private let disposeBag = DisposeBag()

    func inject(requestCreator: PaymentHistoryDetailActionCreatable, reSendReceiptRequestCreator: ReSendReceiptActionCreatable) {
        self.requestCreator = requestCreator
        self.reSendReceiptRequestCreator = reSendReceiptRequestCreator
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sendTrackingScreen(name: GoogleAnalyticsScreen.cyclePaymentDetail)
        
        dateLabel.text = dateLabelText
        statusLabel.text = statusLabelText
        statusLabel.textColor = statusLabelColor
        mobilityLabel.text = mobilityText
        priceLabel.text = priceLabelText
        
        switchContainerView(taxi: isTaxiPayment)
        
        if isTaxiPayment {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "再送信", style: .plain, target: nil, action: nil)
            mobilityIcon.image = Asset.iconTaxi.image
        } else {
            mobilityIcon.image = Asset.iconBike.image
        }

        navigationController?.navigationBar.addShadow()
        
        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let param = PaymentHistoryDetailParameter(usageId: usageId!)
        
        switchContainerView(taxi: isTaxiPayment)
        
        if isTaxiPayment {
            store.dispatch(requestCreator.getTaxi(parameter: param, disposeBag: disposeBag))
        } else {
            store.dispatch(requestCreator.getBike(parameter: param, disposeBag: disposeBag))
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch StoryboardSegue.PaymentHisotryDetail(rawValue: segue.identifier!)! {
        case .toBikeDetail:
            if !isTaxiPayment {
                let next = segue.destination as? UITableViewController
                SizingContainerView(next: next!)
            }
        case .toTaxiDetail:
            if isTaxiPayment {
                let next = segue.destination as? UITableViewController
                SizingContainerView(taxi: true, next: next!)
            }
        }
    }

    func bind() {
        navigationItem.rightBarButtonItem?.rx.tap
            .subscribe({ [unowned self] _ in
                Alert.show(to: self, title: L10n.i0011PaymentHistoryTaxiAlertResendRecipt, style: .custom(buttons: [(.cancel, .cancel), (.ok, .default)]))
                    .subscribe {
                        guard let result = $0.element else { return }
                        if result == .ok {
                                let param = ReSendTaxiReceiptParameter(usageId: self.usageId!)
                                self.store.dispatch(self.reSendReceiptRequestCreator.postResendTaxiReceipt(parameter: param, disposeBag: self.disposeBag))
                        }
                    }
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)
        
        store.detailValue
            .filter { $0.isNotEmpty }
            .subscribe({ [unowned self] _ in
                self.tableView?.reloadData()
            })
            .disposed(by: disposeBag)

        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }
    
    func switchContainerView(taxi: Bool) {
        bikeContainerView.isHidden = taxi
        taxiContainerView.isHidden = !taxi
    }
    
    func SizingContainerView(taxi: Bool = false, next: UITableViewController) {
        tableView = next.tableView
        tableView?.delegate = self
        if taxi {
            taxiContainerView.snp.remakeConstraints({
                $0.height.equalTo((tableView?.frame.height)!)
            })
        } else {
            bikeContainerView.snp.remakeConstraints({
                $0.height.equalTo((tableView?.frame.height)!)
            })
        }
        view.layoutIfNeeded()
    }
    
}

extension PaymentHistoryDetailViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return HistoryDetailCellStatus.headerSize
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if store.state.detailElement.isEmpty {
            return
        }
        let cell = cell as! HistoryDetailCell
        cell.config(detail: store.state.detailElement[indexPath.section][indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = UIColor.background
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.textGrey
        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 12)
    }
}

extension RxStore where AnyStateType == PaymentHistoryDetailState {

    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }

    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }
    }

    var detailValue: Observable<[String]> {
        return stateObservable.map { [$0.usageId, $0.usageProvider, $0.startPort, $0.endPort, $0.carNumber, "", $0.startDate, $0.endDate] }
    }
    
}