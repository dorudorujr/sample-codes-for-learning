//
//  BikeListViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/01/26.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa
import ReSwift
import ApplicationModel
import ApplicationConfig
import CoreLocation
import GoogleMaps

public final class BikeListViewController: UITableViewController {

    var store: RxStore<HomeViewState>?
    var tapMarker: PublishSubject<GMSMarker>?
    var selectedCell = PublishSubject<BikeInfoCell>()
    var bikeRefresh = PublishSubject<Void>()
    let bikeRefreshControl = UIRefreshControl()                                  //引っ張って更新
    var nowPositionKeeper: NowPositionKeepable!

    private var cells = [BikeInfoCell]()                                        //表示されているbikeポートのcell
    private var totalCellsObservable = Variable<[BikeLocationInfoEntity]>([])   //ポート情報
    private var openManage = [Bool]()
    private var gradations = [CAGradientLayer]()        //スクロールして上に見切れたら半透明になるあれ？
    private var refreshTrack = true

    private let disposeBag = DisposeBag()

    public override func viewDidLoad() {
        super.viewDidLoad()
        sendTrackingScreen(name: GoogleAnalyticsScreen.homeCycle)

        tableView.rowHeight = UITableViewAutomaticDimension     //セルの高さを適切な高さに設定(レイアウトが全てAutoLayoutで組まれていれば)
        tableView.estimatedRowHeight = 102                      //estimatedRowHeight を使うとテーブルを表示するときに見積もりの高さを先に計算するので、実際のセルの高さの計算を遅らせることができる
        tableView.refreshControl = bikeRefreshControl

        bind()
    }

    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch StoryboardSegue.BikeTab(rawValue: segue.identifier!)! {
        case .toPayment:
            let navi = segue.destination as! UINavigationController
            let next = navi.topViewController as! PaymentViewController
            next.selectedIndex = ApplicationStore.instance.state.defaultCardSlot - 1
        default:
            break
        }
    }

    private func bind() {
        //bikeポートの情報が更新されたら
        totalCellsObservable.asDriver()
            .asObservable().bind(to: tableView.rx.items(cellIdentifier: "BikeInfoCell", cellType: BikeInfoCell.self)) { [unowned self] index, element, cell in
                cell.config(data: element, parent: self, index: index)

                //すでに表示したcellかどうか調べている？
                if self.openManage.count <= index {
                    self.cells.append(cell)
                    self.openManage.append(false)
                    let gradientLayer = CAGradientLayer()       //グラデーション設定
                    self.gradations.append(gradientLayer)
                } else {
                    self.cells[index] = cell
                }
                if self.store?.state.locationEntity?.count == index {
                    self.sendTrackingEvent(category: Mobirity_ResourcePort_Resource.category.rawValue, action: Mobirity_ResourcePort_Resource.action.rawValue, value: NSNumber(value: index))
                }
                if self.gradations.count > index {
                    cell.addGradationCell(graLayer: self.gradations[index], type: .white)
                }
                if self.openManage.count > index {
                    cell.acordion(open: self.openManage[index])
                }
            }
            .disposed(by: disposeBag)

        //ポートの情報が更新されたらイベントを検知
        store?.locationEntity
            .subscribe({
                var entity = $0.element!
//                TODO:Bike位置情報ソート 必要になればコメントはずす
//                entity = self.sortBikePortSort(bikeEntity: entity)
                self.totalCellsObservable.value.removeAll()
                self.totalCellsObservable.value = entity
            })
            .disposed(by: disposeBag)

        //ポートの情報が更新されたらイベントを検知
        store?.locationEntity
            .filter { _ in self.refreshTrack }
            .subscribe({ [unowned self] in
                let providerCode = $0.element!.map { $0.portProviderCode ?? 0 }
                providerCode.forEach {
                    switch providerType(rawValue: $0) {
                    case .docomo?:
                        if ApplicationStore.instance.state.suicaIdi.isEmpty {
                            self.sendTrackingScreen(name: GoogleAnalyticsScreen.cyclePointUnregistB)
                        } else {
                            self.sendTrackingScreen(name: GoogleAnalyticsScreen.cycleInfoRegistB)
                        }
                    default: break
                    }
                }
                self.refreshTrack = false
            })
            .disposed(by: disposeBag)

        //ピンをタップしたら
        tapMarker?
            .subscribe({ [unowned self] marker in
                self.totalCellsObservable.value = (self.store?.state.locationEntity)!
                //first:Arrayを操作して、条件に合致する一番最初の要素を取得したいとします。
                //タップしたマーカの名前とリストの名前が一致した最初のデータを取得
                guard let data = self.totalCellsObservable.value.first(where: { $0.portName == (marker.element?.title)! }) else { return }
                let cell = self.tableView.visibleCells.first as! BikeInfoCell
                cell.config(data: data, parent: self, index: 0)
                self.acordion(cell: cell, index: IndexPath(row: self.cells.index(of: cell)!, section: 0), appoint: true)
            })
            .disposed(by: disposeBag)

        tableView.rx.itemSelected
            .subscribe({ [unowned self] in
                let index = $0.element!
                guard let cell = self.tableView.cellForRow(at: index) as? BikeInfoCell else { return }
                self.sendTrackingEvent(category: Mobirity_ResourceBikeShare_Resource.category.rawValue, action: Mobirity_ResourceBikeShare_Resource.action.rawValue, label: cell.restBikeStatusText)

                let indexRow = clamp(value: index.row, lowerLimit: 0, upperLimit: self.openManage.count - 1)
                if !self.openManage[indexRow] {
                    self.selectedCell.onNext(cell)
                }
                self.acordion(cell: cell, index: IndexPath(row: indexRow, section: 0))
            })
            .disposed(by: disposeBag)

        tableView.rx.didScroll
            .filter({self.tableView.contentOffset.y > 0})
            .subscribe({ [unowned self] _ in
                for cell in self.cells {
                    if let row = self.cells.index(of: cell) {
                        self.addGradation(cell: cell, index: IndexPath(row: row, section: 0))
                    }
                }
            })
            .disposed(by: self.disposeBag)

        Observable.merge(ApplicationStore.instance.suicaIdi.map { _ in Void.self }, ApplicationStore.instance.defaultCardIndex.map { _ in Void.self })
            .subscribe({ [unowned self] _ in
                self.tableView.reloadData()
            })
            .disposed(by: self.disposeBag)

        bikeRefreshControl.rx.controlEvent(.valueChanged)
            .subscribe({ [unowned self] _ in
                self.refreshTrack = true
                self.sendTrackingEvent(category: IntegratedViewPort_Search.category.rawValue, action: IntegratedViewPort_Search.action.rawValue, label: ApplicationStore.instance.state.ruid)
                self.bikeRefresh.onNext(())
            })
            .disposed(by: disposeBag)
    }

    private func sortBikePortSort(bikeEntity: [BikeLocationInfoEntity]) -> [BikeLocationInfoEntity] {
        let nowposition = self.nowPositionKeeper.read()
        let nowLatitude = nowposition.latitude
        let nowLongitude = nowposition.longitude
        var entity = bikeEntity
        entity.sort(by: { pow(abs($0.portLatitude - nowLatitude), 2.0) + pow(abs($0.portLongitude - nowLongitude), 2.0) < pow(abs($1.portLatitude - nowLatitude), 2.0) + pow(abs($1.portLongitude - nowLongitude), 2.0)})
        return entity
    }

    //住所検索
    public func reverseGeocodeCoordinate(_ coordinate: CLLocationCoordinate2D, index: Int) {
        var locationAddress = ""
        let geocoder = GMSGeocoder()
        geocoder.reverseGeocodeCoordinate(coordinate) { response, _ in
            guard let address = response?.firstResult(), let lines = address.lines else {
                return
            }
            locationAddress = String(lines[0].suffix(lines[0].count - PostalCode.size))
            if self.cells.count > index {
                self.cells[index].getLocationNameLabel.text = locationAddress
            }
        }
    }

    //cellを開く処理
    private func acordion(cell: BikeInfoCell, index: IndexPath, appoint: Bool? = nil) {
        //openManageの値をtrueに変更してcellを開く設定をする？
        openManage[index.row] = (appoint == nil) ? !openManage[index.row] : appoint!
        tableView.beginUpdates()                                                    //cellを開くアニメーション開始
        cell.acordion(open: (appoint == nil) ? openManage[index.row] : appoint!)    //cellの高さを開く高さに変更
        tableView.endUpdates()                                                      //cellを開くアニメーション終了
        UIView.animate(withDuration: Animation.duration) {
            //再描画する
            cell.contentView.layoutIfNeeded()
        }
        if openManage[index.row] {
            //指定したindexのcellが画面上の特定の位置にくるまで、テーブルビューをスクロールする
            tableView.scrollToRow(at: index, at: .top, animated: true)
            let whiteLayer = CAGradientLayer()
            whiteLayer.frame = cell.bounds
            cell.addGradationCell(graLayer: whiteLayer, type: .white)
        }
    }

    private func addGradation(cell: BikeInfoCell, index: IndexPath) {
        if tableView.visibleCells.isEmpty { return }
        let cellArray = tableView.visibleCells.map({
            $0.frame.origin.y-tableView.contentOffset.y })
        let minY = cellArray.min()
        let cellIndex = cellArray.index { $0 == minY }!
        let topCell = tableView.visibleCells[cellIndex]
        let gradientLayer = CAGradientLayer()

        gradientLayer.startPoint = CGPoint(x: 0.5, y:
            (abs((topCell.frame.origin.y)-self.tableView.contentOffset.y))/topCell.bounds.height)
        gradientLayer.endPoint = CGPoint(x: 0.5, y:
            (abs((topCell.frame.origin.y)-self.tableView.contentOffset.y))/topCell.bounds.height+0.1)

        gradations[index.row] = gradientLayer

        if index == IndexPath(row: cells.index(of: topCell as! BikeInfoCell)!, section: 0) {
            cell.addGradationCell(graLayer: gradations[index.row], type: .gradation)
        } else {
            cell.addGradationCell(graLayer: gradations[index.row], type: .white)
        }
    }

}
