//
//  NotificationViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/02/20.
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

final class NotificationViewController: UIViewController {
    
    @IBOutlet private weak var notificationTable: UITableView!
    @IBOutlet private weak var zeroView: UIView!
  
  
    private let notifyRefresh = UIRefreshControl() //引っ張って更新する関数
    
    private var latestNoticeId = 0      //最新のNoticeId?
    private var selectedCell = Variable<NotificationCell?>(nil)
  
    //Redux からステート変更の通知が来たら Variableを更新するクラスの作成
    private let store = RxStore(store: Store<NotificationViewState>(reducer: NotificationViewReducer.handleAction, state: nil))
    private var requestCreator: NotificationActionCreatable! {
        willSet {
            //DI関連でnilじゃないといけない？（シングルトン関連）
            if requestCreator != nil {
                //デバック用
                fatalError()
            }
        }
    }
    private let disposeBag = DisposeBag()
  
    //オブジェクトの注入(DI)
    func inject(requestCreator: NotificationActionCreatable) {
        self.requestCreator = requestCreator
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sendTrackingScreen(name: GoogleAnalyticsScreen.notify)  //トラッキングできるようにする設定
        navigationBarSetup(titleText: "お知らせ", fontSize: 14, modal: true, dispose: disposeBag)
        navigationController?.navigationBar.ringoGreen()
        navigationController?.navigationBar.addShadow()
        
        notificationTable.refreshControl = notifyRefresh
        
        bind()  //rxの設定を一括で登録
        //初期表示
        store.dispatch(requestCreator.get(parameter: NotificationParameter(latestNoticeId: 0), disposeBag: disposeBag))
    }
    
    //画面遷移時、値を渡している
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let next = segue.destination as! DetailViewCotnroller
        next.selected = selectedCell.value
    }
    
    private func bind() {
        //tableviewの表示設定
        store.notifications.asDriver(onErrorJustReturn: [])
            .asObservable().bind(to: notificationTable.rx.items(cellIdentifier: "NotificationCell", cellType: NotificationCell.self)) { [unowned self] (index, element, cell) in
                cell.config(data: element, read: index <= self.store.state.readNoticeId!)
            }
            .disposed(by: disposeBag)
        
        //お知らせがなにもない時の処理?
        store.notifications.asObservable()
            .subscribe({ [unowned self] in
                self.zeroView.isHidden = $0.element!.isNotEmpty 
                if $0.element!.isNotEmpty {
                    self.store.dispatch(self.requestCreator.put(parameter: ReadNotificationParameter(readNoticeId: (self.store.state.noticeInfo?.count)! - 1), disposeBag: self.disposeBag))
                }
            })
            .disposed(by: disposeBag)
        //.rx.itemSelectedはrxswiftでデフォルトである記述方法
        //テーブルビューのセルを選択した際の処理
        //(self.notificationTable.cellForRow(at: $0) as? NotificationCell)!がtrueならbind(to: selectedCell)に知らせ行く？
        notificationTable.rx.itemSelected
            //mapによって選択したcell(selectedCell)に変換
            .map { [unowned self] in (self.notificationTable.cellForRow(at: $0) as? NotificationCell)! }
            .asObservable()
            .bind(to: selectedCell)
            .disposed(by: disposeBag)   //破棄
        
        selectedCell
            .asObservable()
            .filter { $0 != nil }
            .subscribe({ [weak self] in
                $0.element??.open()
                self?.performSegue(withIdentifier: StoryboardSegue.Notify.toNotificationDetail.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)
        //スワイプしたら値を更新
        notifyRefresh.rx.controlEvent(.valueChanged)
            .subscribe({ [unowned self] _ in
                self.store.dispatch(self.requestCreator.get(parameter: NotificationParameter(latestNoticeId: 0), disposeBag: self.disposeBag))
            })
            .disposed(by: disposeBag)
        
        store.isLoading
            .filter { !$0 }
            .subscribe { [unowned self] _ in
                //ロード中ではなかったらロードインジケーター（くるくる）が終了
                self.notifyRefresh.endRefreshing()
            }
            .disposed(by: disposeBag)
        
        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }
}

//「[NotificationViewState]の場合のみ有効になる定義を、これから定義します」という意味
//RxStore<AnyStateType>の型NotificationViewStateの場合のみに拡張を行う
extension RxStore where AnyStateType == NotificationViewState {
    
    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }
    
    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }
    }
    //notifiInfo?
    //stateObservableをNotificationViewState.noticeInfoでmapする
    var notifications: Observable<[NotificanotificationtionEntity]> {
        return stateObservable.map { $0.noticeInfo ?? [] }.distinctUntilChanged { $0 == $1 }
    }
    
    var readNoticeId: Observable<Int?> {
        return stateObservable.map { $0.readNoticeId }.distinctUntilChanged { $0 == $1 }
    }
}
