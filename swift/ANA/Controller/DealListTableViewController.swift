//
//  DealListTableViewController.swift
//  AnaPayView
//
//  Created by Hodaka Fukushima on 2020/07/02.
//

import AnaPayModel
import ReSwift
import RxCocoa
import RxDataSources
import RxSwift
import RxSwiftExt
import UIKit

protocol DealListTableCoordinatorDelegate: AnyObject {
    func didSelectDeal(_ deal: WalletDealListContentDealInfo)
}

final class DealListTableViewController: UITableViewController {
    typealias State = DealListState
    typealias Store = RxStore<State>
    typealias Coordinator = DealListTableCoordinatorDelegate

    typealias SectionModel = RxDataSources.SectionModel<SectionID, SectionItem>
    typealias DataSource = RxTableViewSectionedReloadDataSource<SectionModel>

    private var store: Store!
    private var coordinator: Coordinator!

    // MARK: - Dependency

    private var dealListRequestActionCreator: WalletDealListRequestActionCreator!
    private var dealNotificationSubscriber: DealNotificationSubscribeActionCreator!

    func inject(dealListRequestActionCreator: WalletDealListRequestActionCreator,
                dealNotificationSubscriber: DealNotificationSubscribeActionCreator) {
        self.dealListRequestActionCreator = dealListRequestActionCreator
        self.dealNotificationSubscriber = dealNotificationSubscriber
    }

    // MARK: - IB Outlet & Views

    private lazy var footerView = LoadingViewCell()

    // MARK: - Rx

    private let disposeBag = DisposeBag()

    private func bind() {
        // ルールの正規表現に意図せずヒットしてしまいwarningが出てしまうためdisable
        // swiftlint:disable:next bind_to
        store.dispatch(dealNotificationSubscriber.subscribe(disposeBag: disposeBag))

        // MARK: input

        Observable
            .merge([
                store.rx.intervalFilterOption.asObservable(),
                store.rx.dealNotificationEvent.withLatestFrom(store.rx.intervalFilterOption).asObservable(),
            ])
            .bind(to: Binder(self) { me, intervalFilterOption in
                me.request(intervalOption: intervalFilterOption, startPosition: 1)
            })
            .disposed(by: disposeBag)

        // cellが一番下に行ったら追加読み込み
        tableView.rx.visibleLastRowEvent
            .withLatestFrom(store.rx.hasMoreResults)
            .filter { $0 }
            .withLatestFrom(store.rx.loadMoreRequestParameter)
            .bind(to: Binder(self) { me, parameter in
                me.request(intervalOption: parameter.intervalOption, startPosition: parameter.startPosition)
            })
            .disposed(by: disposeBag)

        tableView.rx.modelSelected(SectionItem.self)
            .bind(to: Binder(self) { me, item in
                switch item {
                case let .deal(deal):
                    me.coordinator.didSelectDeal(deal)
                }
            })
            .disposed(by: disposeBag)

        // レイアウト再描画時に呼び出し
        tableView.rx.indexPathsForVisibleRows
            .map { $0.first?.section }
            .distinctUntilChanged()
            .unwrap()
            .drive(Binder(self) { me, topSection in
                let sectionTitle = me.dataSource[topSection].model.identity
                let action = State.Action.setVisibleTopSectionTitle(sectionTitle)
                me.store.dispatch(action)
            })
            .disposed(by: disposeBag)

        // MARK: output

        store.rx.sections
            .drive(tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        store.rx.isLoading
            .drive(Binder(self) { me, isLoading in
                isLoading ? me.footerView.show() : me.footerView.dismiss()
            })
            .disposed(by: disposeBag)

        let footer = footerView // インスタンス保持用
        store.rx.hasMoreResults
            .drive(Binder(self) { me, hasMoreResults in
                me.tableView.tableFooterView = hasMoreResults ? footer : UIView()
            })
            .disposed(by: disposeBag)
    }

    // MARK: - View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.apply {
            $0.tableFooterView = footerView
            $0.register(DealListSectionHeaderView.self)
            $0.contentInset.bottom = UIConst.safeAreaInsets.bottom // FIXME: - UIConst使いたくない
        }

        bind()
    }

    // MARK: -

    private lazy var dataSource = DataSource(
        configureCell: { _, tableView, indexPath, item in
            switch item {
            case let .deal(deal):
                return tableView
                    .dequeueReusableCell(classType: DealListTableViewCell.self, for: indexPath)
                    .configure(with: deal)
            }
        }
    )

    private func request(intervalOption: DealListFilterOption.Interval, startPosition: Int) {
        guard let dateInterval = DealListFilterOption.Interval.Formatter().dateInterval(from: intervalOption) else { return }

        store.dispatch(dealListRequestActionCreator.request(
            parameter: dealListRequestActionCreator.makeRequestParameter(
                dateAndTimeFrom: dateInterval.start,
                dateAndTimeTo: dateInterval.end,
                numberFrom: startPosition),
            disposeBag: disposeBag
        ))
    }
}

extension DealListTableViewController {
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return .leastNonzeroMagnitude
        }

        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNonzeroMagnitude
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            return nil
        }

        return tableView
            .dequeueReusable(DealListSectionHeaderView.self)
            .configure(with: dataSource[section].model.identity)
    }
}

extension DealListTableViewController: DependencyInjectable {
    typealias Dependency = (store: Store, coordinator: Coordinator)

    func inject(with dependency: Dependency) {
        store = dependency.store
        coordinator = dependency.coordinator
    }
}

extension DealListTableViewController {
    enum SectionID: IdentifiableType {
        case deals(title: String)

        var identity: String {
            switch self {
            case let .deals(title):
                return title
            }
        }
    }

    enum SectionItem: IdentifiableType, Equatable {
        case deal(WalletDealListContentDealInfo)

        var identity: String {
            switch self {
            case let .deal(d): return d.transId
            }
        }

        var sequence: Int {
            switch self {
            case let .deal(d): return d.sequence
            }
        }
    }
}

extension DealListTableViewController.SectionModel {
    static func make(groupedDeals: [String: [WalletDealListContentDealInfo]]) -> [DealListTableViewController.SectionModel] {
        groupedDeals
            .map { title, deals in
                self.init(model: .deals(title: title), items: deals.map(DealListTableViewController.SectionItem.deal))
            }
            .sorted { $0.sequence < $1.sequence }
    }

    var sequence: Int {
        items.first?.sequence ?? 0
    }
}

extension Reactive where Base: DealListTableViewController.Store {
    var isLoading: Driver<Bool> {
        base.stateObservable.mapAt(\.isLoading)
            .distinctUntilChanged()
            .asDriver(onErrorDriveWith: .never())
    }

    private var deals: Observable<[WalletDealListContentDealInfo]> {
        base.stateObservable.mapAt(\.deals)
            .distinctUntilChanged()
            .unwrap()
    }

    private var totalCount: Observable<Int> {
        base.stateObservable.mapAt(\.totalCount)
            .distinctUntilChanged()
            .unwrap()
    }

    var intervalFilterOption: Driver<DealListFilterOption.Interval> {
        base.stateObservable.mapAt(\.intervalFilterOption)
            .distinctUntilChanged()
            .asDriver(onErrorDriveWith: .never())
    }

    var sections: Driver<[DealListTableViewController.SectionModel]> {
        deals
            .map { deals in
                Dictionary(grouping: deals) { self.base.yMMMDateFormatter.string(from: $0.transTime) }
            }
            .map(DealListTableViewController.SectionModel.make(groupedDeals:))
            .asDriver(onErrorDriveWith: .never())
    }

    var hasMoreResults: Driver<Bool> {
        Observable.combineLatest(totalCount, deals.mapAt(\.count)) { (total: $0, current: $1) }
            .map { $0.current < $0.total }
            .asDriver(onErrorJustReturn: false)
    }

    private var nextStartPosition: Driver<Int> {
        deals
            .map { $0.count + 1 }
            .startWith(1)
            .asDriver(onErrorDriveWith: .never())
    }

    var loadMoreRequestParameter: Driver<(intervalOption: DealListFilterOption.Interval, startPosition: Int)> {
        .combineLatest(intervalFilterOption, nextStartPosition) { (intervalOption: $0, startPosition: $1) }
    }

    var dealNotificationEvent: Signal<Void> {
        base.stateObservable.mapAt(\.dealNotificationPayload)
            .distinctUntilChanged()
            .unwrap()
            .mapTo(())
            .asSignal(onErrorSignalWith: .never())
    }
}
