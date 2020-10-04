//
//  TermOfServiceViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/05/29.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxGesture
import ReSwift
import ApplicationModel
import ApplicationConfig

// b-000
final class TermOfServiceViewController: UIViewController {
    
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var allAgreeButton: UIButton!
    @IBOutlet private weak var nextPageButton: UIButton!
    @IBOutlet private weak var allAgreeImage: UIImageView!
    
    var fromHome = false
    
    private let store = RxStore(store: Store<TermOfServiceViewState>(reducer: TermOfServiceViewReducer.handleAction, state: nil))
    private var requestCreator: TermOfServiceActionCreatable! {
        willSet {
            if requestCreator != nil {
                fatalError()
            }
        }
    }
    
//    private var ruleRequestCreator: RuleInfoActionCreatable! {
//        willSet {
//            if ruleRequestCreator != nil {
//                fatalError()
//            }
//        }
//    }
    
    private var cells: [TermOfServiceCell] = []
    private var checks: [Observable<Bool>] = []
    private var nextURL = ""
    private let disposeBag = DisposeBag()
    
    func inject(requestCreator: TermOfServiceActionCreatable) {
        self.requestCreator = requestCreator
//        self.ruleRequestCreator = ruleRequestCreator
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationController?.setNavigationBarHidden(false, animated: true)
        nextPageButton.changeColor(disableTextColor: UIColor.textThinGrey, disableColor: UIColor.buttonDisableGrey)
        
        navigationBarSetup(titleText: L10n.b000TosAcceptNaviTitle, fontSize: 14.0, modal: true, visibleLeft: false, dispose: disposeBag)
        // TODO: 利用規約フローの見直し
//        if fromHome {
//            if let ruleVersion = KeyChainUtil.shared.get(key: KeyChainKey.ruleVersion) {
//                version = Int(ruleVersion)!
//            }
//        }
        // 現状、規約の更新が関わるまでは最新のもので問題ないので固定で"latest"指定
        store.dispatch(requestCreator.get(parameter: TermOfServiceParamter(version: "latest"), disposeBag: disposeBag))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.addShadow()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch StoryboardSegue.TermOfService(rawValue: segue.identifier!)! {
        case .toWebView:
            let nav = segue.destination as! UINavigationController
            let next = nav.topViewController as! WebViewController
            next.urlString = nextURL
        case .toSignup:
            let next = segue.destination as! SignupViewController
            next.ruleInfo = store.state.ruleInfoList!
        }
    }
    
    private func bind() {
        
        store.ruleInfoList.filter { $0.isNotEmpty }
            .bind(to: tableView.rx.items(cellIdentifier: "TermOfServiceCell", cellType: TermOfServiceCell.self)) {  [weak self] index, element, cell in
                
                cell.config(data: element )
                cell.openLink = {
                    if let url = cell.url {
                        self?.nextURL = url
                        self?.performSegue(withIdentifier: StoryboardSegue.TermOfService.toWebView.rawValue, sender: nil)
                    }
                }
                //配列から指定した要素のindexを取得する
                if self?.cells.index(of: cell) == nil {
                    self?.cells.append(cell)
                    self?.checks.append(cell.checked)
                    // TODO: 配列対応
                    //                    if index == (self?.store.state.termOfService?.count)! - 1 {
                    //
                    //                    }
                    Observable.combineLatest((self?.checks)!)
                        .subscribe {
                            let array = $0.element
                            self?.nextPageButton.isEnabled = (array?.index(of: false) == nil)
                            self?.changeButtonEnable()
                        }
                        .disposed(by: (self?.disposeBag)!)
                }
        }
        
        allAgreeButton.rx.tap
            .subscribe({ [weak self] _ in
                self?.cells.forEach {
                    $0.check()
                }
                
                self?.changeButtonEnable()
            })
            .disposed(by: disposeBag)
        
        nextPageButton.rx.tap
            .subscribe({ [unowned self] _ in
                
                if self.fromHome {
//                    let parameter = AgreementRuleInfoParameter(ruleId: [1])     //TODO:規約取得APIが未実装なため仮の値を使用
//                    self.store.dispatch(self.ruleRequestCreator.post(parameter: parameter, disposeBag: self.disposeBag))
                } else {
                    self.performSegue(withIdentifier: StoryboardSegue.TermOfService.toSignup.rawValue, sender: nil)
                }
            })
            .disposed(by: disposeBag)
        
        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }
    
    private func changeButtonEnable() {
        allAgreeImage.isHighlighted = nextPageButton.isEnabled
        nextPageButton.changeColor()
    }
}

extension RxStore where AnyStateType == TermOfServiceViewState {
    
    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }
    
    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }.distinctUntilChanged()
    }

    var ruleInfoList: Observable<[RuleInfoEntity]> {
        return stateObservable.map { $0.ruleInfoList ?? [] }.distinctUntilChanged()
    }
    
    var update: Observable<Bool> {
        return stateObservable.map { $0.update }
    }
    
}
