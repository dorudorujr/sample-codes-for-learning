//
//  UserInfoViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/02/21.
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

// g-001
final class UserInfoViewController: UITableViewController {
    
    var sideUserInfoKeeper: UserInfoKeepable!
    
    private var selectedIndex = -1
    private var mailAddress = ""

    private let disposeBag = DisposeBag()
  
    override var preferredStatusBarStyle: UIStatusBarStyle {
      return .lightContent
    }
  
    override func viewDidLoad() {
        super.viewDidLoad()
        sendTrackingScreen(name: GoogleAnalyticsScreen.userInfo)
        
        navigationBarSetup(titleText: L10n.g001UserInfoTitle, fontSize: 14, modal: true, dispose: disposeBag)
        navigationController?.navigationBar.ringoGreen()
        tableView.estimatedRowHeight = 50.0
        navigationController?.navigationBar.addShadow()

        selectedIndex = -1

        bind()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
        self.setNeedsStatusBarAppearanceUpdate()        //statusbarの更新
    }
  
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch StoryboardSegue.UserInfo(rawValue: segue.identifier!)! {
        case .toChangeUserName:
            let next = segue.destination as! ChangeUserNameViewController
            next.firstName = sideUserInfoKeeper.firstName
            next.lastName = sideUserInfoKeeper.lastName
        case .toChangeInfo:
            let next = segue.destination as! SendMailViewController
            next.mailAddress = sideUserInfoKeeper.mailAddress
            next.changeTarget = (selectedIndex == 1) ? ChangeTarget.mailAddress : ChangeTarget.password
        default:
            break
        }
    }

    private func bind() {
        //tableviewのitemを選択した時のイベントハンドリング
        tableView.rx.itemSelected
            .subscribe({ [unowned self] in
                self.selectedIndex = ($0.element?.row)!
                let cell = self.tableView.cellForRow(at: IndexPath(row: self.selectedIndex, section: 0)) as? SegueCell  //指定されたインデックスパスにあるテーブルセルを返します。
                if cell == nil {
                    Alert.show(to: self, title: L10n.g001UserInfoLogoutAlert, style: .custom(buttons: [(.cancel, .cancel), (.ok, .default)]))
                        .subscribe {
                            guard let result = $0.element else { return }
                            if result == .ok {
                                KeyChainUtil.shared.remove(key: KeyChainKey.mailAddress)
                                KeyChainUtil.shared.remove(key: KeyChainKey.password)
                                ApplicationStore.instance.dispatch(LoginResetAction())
                                self.dismiss(animated: true, completion: nil)
                                TransitionHelper.shared.navigationPopToRoot()
                            }
                        }
                        .disposed(by: self.disposeBag)
                } else {
                    guard let segue = cell?.segue else { return }
                    if segue.isEmpty { return }
                    self.performSegue(withIdentifier: segue, sender: nil)
                }
            })
            .disposed(by: disposeBag)
    }
    
    // --- MARK: TableViewDelegate ---
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // docomoのindex
        //セルの高さを0にすることによってセルをなくす
        //docomoがcellがない場合がある
        if indexPath.row == 3 && sideUserInfoKeeper.userData[indexPath.row].isEmpty {
            return 0
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        //docomo以降のindex
        if indexPath.row <= 3 {
          cell.detailTextLabel?.text = sideUserInfoKeeper.userData[indexPath.row]   //userDataのString配列に表示する値が入っている
          //パスワードは空白
        }
    }
}
