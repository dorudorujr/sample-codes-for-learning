//
//  PaymentHistoryViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/02/23.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa
import ReSwift
import ApplicationConfig
import ApplicationModel
import ApplicationLib

// i-001-1
final class PaymentHistoryViewController: UIViewController {

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var tabBar: UITabBar!    //タクシーとバイクで選べる上にあるやつ
    @IBOutlet private weak var selectBarViewLeftConstraint: NSLayoutConstraint!

    private var selectedCell = Variable<HistoryCell?>(nil)

    private var taxiList = Variable<[PaymentHistoryEntity]>([])
    private var bikeList = Variable<[PaymentHistoryEntity]>([])
    private var bikeRefreshNotify: PublishSubject<String>?
    private var taxiRefreshNotify: PublishSubject<String>?
    private var bikeHistoryRefresh: UIRefreshControl?
    private var taxiHistoryRefresh: UIRefreshControl?
    var tagNum = 0
    
    private let store = RxStore(store: Store<PaymentHistoryState>(reducer: PaymentHistoryReducer.handleAction, state: nil))
    private var requestCreator: PaymentHistoryActionCreatable! {
        willSet {
            if requestCreator != nil {
                fatalError()
            }
        }
    }
    private let disposeBag = DisposeBag()

    func inject(requestCreator: PaymentHistoryActionCreatable) {
        self.requestCreator = requestCreator
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //navigationBarSetup(ご利用履歴の文字)
        navigationBarSetup(titleText: L10n.i0012PaymentHistoryBikeTitle, fontSize: 14.0, modal: true, dispose: disposeBag)
        navigationController?.navigationBar.ringoGreen()

        //map:配列の要素全てに処理を施したいときに使う
        //setTitleTextAttributes:tabBar選択時の色の設定変更
        tabBar.items?.map { $0.setTitleTextAttributes([NSAttributedStringKey.font: UIFont(name: Font.YuGothic.bold, size: 14)!], for: .normal) }
        tabBar.tintColor = UIColor.white
        tabBar.unselectedItemTintColor = UIColor(color: UIColor.textThinGrey, alpha: Alpha.disable)

        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)


        //バックグラウンドで非同期処理
        OperationQueue.main.addOperation({
            self.tabBar.selectedItem = self.tabBar.items?[self.tagNum]
            self.selectBarViewLeftConstraint.constant = self.scrollView.contentSize.width / 2 * CGFloat(self.tagNum)
            self.scrollView.contentOffset = CGPoint(x: self.scrollView.contentSize.width * CGFloat(self.tagNum), y: 0)
        })
            //初期表示のdispatch
            //上にある日付を取得
            //ご利用月を取得
            self.store.dispatch(self.requestCreator.getHistoryMonth(parameter: HistoryMonthParameter(), disposeBag: self.disposeBag))
        
        navigationController?.navigationBar.ringoGreen()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //Storyboardのidentifierで遷移先を指定
        //ご利用履歴表示時に「.toBikePaymentHisotry」と「.toTaxiPaymentHisotry」二つ呼んでいる？
        switch StoryboardSegue.PaymentHistory(rawValue: segue.identifier!)! {
        case .toDetail:
            let next = segue.destination as! PaymentHistoryDetailViewController
            let cell = selectedCell.value
            //cellの情報を次の画面の情報に再利用
            next.usageId = cell?.usageId
            next.dateLabelText = cell?.getDateLabel.text
            next.statusLabelText = cell?.getStatusLabel.text
            next.statusLabelColor = (cell?.getStatusLabel.textColor)!
            next.mobilityText = cell?.getMobilityLabel.text
            next.priceLabelText = cell?.getPriceLabel.text
            if tagNum == 0 {
                next.isTaxiPayment = true
            }
        case .toBikePaymentHisotry:
            let next = segue.destination as! HistorySortViewController
            //引数の値を代入している
            next.setbindTaret(historyInfo: bikeList, selectedCell: selectedCell, dropDownData: store.monthly)
            bikeRefreshNotify = next.refreshNotify      //日付がやってくる(dropdownで選択された月)
            bikeHistoryRefresh = next.historyRefresh
        case .toTaxiPaymentHisotry:
            let next = segue.destination as! HistorySortViewController
            next.hiddenBillingCardView = true
            next.setbindTaret(historyInfo: taxiList, selectedCell: selectedCell, dropDownData: store.monthly)
            taxiRefreshNotify = next.refreshNotify
            taxiHistoryRefresh = next.historyRefresh
        case .toPayament:
            let navi = segue.destination as! UINavigationController
            let next = navi.topViewController as! PaymentViewController
            next.selectedIndex = ApplicationStore.instance.state.defaultCardSlot - 1
        default:
            break
        }
    }

    private func bind() {
        //日付が空じゃなければrequestを飛ばす
        store.monthly
            //空じゃなければ
            .filter { $0.isNotEmpty }
            .subscribe { [unowned self] in
                let month = ($0.element?.first?.month)!
                ApplicationStore.instance.dispatch(RegistSelectMonthAction(selectMonth: month)) //dorpdownで選択した月を変更
                self.bikeRequest(month: month)      //履歴取得
                self.taxiRequest(month: month)      //履歴取得
            }
            .disposed(by: disposeBag)

        store.historyTaxiInfo
            .bind(to: taxiList)     //historyTaciInfoの値をtaxiListに反映させてる
            .disposed(by: disposeBag)

        store.historyBikeInfo
            .bind(to: bikeList)     //historyBikeInfoの値をbikeListに反映
            .disposed(by: disposeBag)

        tabBar.rx.didSelectItem
            .subscribe({ [unowned self] in
                if let tag = $0.element?.tag {
                    //横にスクロールするアニメーションを設定
                    self.scrollView.setContentOffset(CGPoint(x: self.scrollView.contentSize.width * CGFloat(tag), y: 0), animated: true)
                    UIView.animate(withDuration: Animation.duration, animations: {
                        //上の黄色いバーを移動
                        self.selectBarViewLeftConstraint.constant = self.scrollView.contentSize.width / 2 * CGFloat(tag)
                    })
                    self.tagNum = tag
                }
            })
            .disposed(by: disposeBag)

        //月が更新(選択月が変更されたら)
        taxiRefreshNotify?
            .subscribe({ [unowned self] in
                self.taxiRequest(month: $0.element!)
            })
            .disposed(by: disposeBag)

        bikeRefreshNotify?
            .subscribe({ [unowned self] in
                self.bikeRequest(month: $0.element!)
            })
            .disposed(by: disposeBag)

        //HistorySortViewControllerに値を渡した。
        //HistorySortViewControllerに渡したselectedCellがtableView.rx.itemSelectedと繋がっている
        selectedCell
            .asObservable()
            .filter { $0 != nil }
            .subscribe({ [weak self] _ in
                self?.performSegue(withIdentifier: StoryboardSegue.PaymentHistory.toDetail.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)

        store.isLoading
            .filter { !$0 }
            .subscribe({ [unowned self] _ in
                self.bikeHistoryRefresh?.endRefreshing()    //くるくる終了する(tableViewの上部に表示されているやつ)
                self.taxiHistoryRefresh?.endRefreshing()
            })
            .disposed(by: disposeBag)

        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }

    private func taxiRequest(month: String) {
        let param = PaymentHistoryParameter(month: month)
            self.store.dispatch(self.requestCreator.getTaxi(parameter: param, disposeBag: self.disposeBag))
    }

    private func bikeRequest(month: String) {
        let param = PaymentHistoryParameter(month: month)
            self.store.dispatch(self.requestCreator.getBike(parameter: param, disposeBag: self.disposeBag))
    }
}

extension RxStore where AnyStateType == PaymentHistoryState {

    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }

    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }
    }

    var monthly: Observable<[HistoryMonthEntity]> {
        return stateObservable.map { $0.monthly ?? [] }.distinctUntilChanged { $0 == $1 }
    }

    var historyBikeInfo: Observable<[PaymentHistoryEntity]> {
        return stateObservable.map { $0.historyBikeInfo ?? [] }.distinctUntilChanged()  //PaymentHistoryStateのhistoryBikeInfo
    }

    var historyTaxiInfo: Observable<[PaymentHistoryEntity]> {
        return stateObservable.map { $0.historyTaxiInfo ?? [] }.distinctUntilChanged()
    }
}
