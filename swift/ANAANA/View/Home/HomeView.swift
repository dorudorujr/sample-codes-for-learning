//
//  HomeView.swift
//  AnaMile
//
//  Created by 西村 拓 on 2015/11/04.
//  Copyright © 2015年 TakuNishimura. All rights reserved.
//

import UIKit

import RxSwift

import ObjectMapper

import SwiftDate

import Firebase
import FirebasePerformance

/// ホーム画面
class HomeView: BaseContentsView {

    /// 過去のダイヤ履歴アイコン
    @IBOutlet private final weak var diamondIconView: HomeDiamondIconView!

    /// 最終更新時間
    @IBOutlet private final weak var lastUpdateTimeLabel: UILabel!

    /// スクロール領域高さFixed制約
    @IBOutlet private final weak var heightContentsConstraint: NSLayoutConstraint!

    /// ダイヤモンド履歴View
    @IBOutlet private final weak var diamondView: UIView!

    /// ダイヤ非表示時の罫線
    @IBOutlet private final weak var noDiamondBar: BaseView!

    /// ポイントView
    @IBOutlet private final weak var pointContainer: MileStatusView!

    /// エラーView
    @IBOutlet private final weak var errorContainer: UIView!
    @IBOutlet private final weak var errorContainerVerticalCenterConstraint: NSLayoutConstraint!
    
    @IBOutlet private final weak  var retryButton: BaseButton!
    
    private final var trace: Trace?

    override func awakeFromNib() {
        super.awakeFromNib()

        defaultSetting()

        diamondSetting()

        bind()
    }

    /**
     4インチ系以下はスクロール領域高さFixに
     */
    private final func defaultSetting() {
        ////4インチ系以下かどうかの確認
        if AppInfoUtil.isSmallDevice() {
            heightContentsConstraint.isActive = false               ////制約を無効(「=Height」Viewの高さ)
            errorContainerVerticalCenterConstraint.constant = -6
        }
    }

    private final func bind() {
        // ログイン演出準備完了
        AppStatusModel.shared.isReadyToLogin
            .asObservable()
            .filter { ($0) }
            .subscribe(onNext: { [weak self] _ in
                self?.trace = Performance.startTrace(name: "Top Screen Login Effects")
                self?.diamondSetting()
                self?.startLoginEffect()
            })
            .disposed(by: disposeBag)

        AppStatusModel.shared.cocosViewStatus
            .asObservable()
            .filter { $0 == .replace }
            .subscribe(onNext: { [weak self] _ in
                self?.diamondSetting()
            })
            .disposed(by: disposeBag)

        // ログイン状態変化
        AppStatusModel.shared.loginState
            .asObservable()
            .scan(.isNotLogin, accumulator: { [weak self] (b, a) -> AppStatusModel.LoginState in
                if (b == .isTryUpdate && a == .isLogin) ||
                    (b == .isTryFetch && a == .isLogin) {
                    self?.diamondSetting()
                }

                return a
            })
            .subscribe()
            .disposed(by: disposeBag)

        // 最終更新時刻更新
        AppStatusModel.shared.lastUpdateTime
            .asObservable()
            .filterNil()
            .map {
                return $0.toString("yyyy.MM.dd HH:mm")
            }
            .bind(to: lastUpdateTimeLabel.rx.text)
            .disposed(by: disposeBag)
        
        AppStatusModel.shared.loginState
            .asDriver()
            .drive(onNext: { [weak self] state in
                switch state {
                case .isTryFetch, .isTryLogin, .isTryUpdate, .isTryAutoLogin:
                    self?.startLoadingAnimation()
                default:
                    self?.stopLoadingAnimation()
                }
            })
            .disposed(by: disposeBag)
        
        // ErrorView管理
        // Offlineエラー表示条件はユーザー情報がcacheから
        // 起動後一度サーバーから取得したら通信エラーしても表示しない
        AppStatusModel.shared.loginState
            .asDriver()
            .drive(onNext: { [weak self] state in
                let isShowError = state == .isOfflineMode && AppStatusModel.shared.userModel.user.value?.isCaching == true
                if isShowError {
                    self?.showErrorView()
                } else {
                    self?.dismissErrorContainer()
                }
            })
            .disposed(by: disposeBag)
    }

    /**
     ダイヤモンド履歴エリアの表示状態管理
     */
    private final func diamondSetting() {
        guard let user = AppStatusModel.shared.userModel.user.value else {
            diamondView.isHidden = true
            noDiamondBar.isHidden = false
            return
        }

        if user.diamondCount == 0 {
            diamondView.isHidden = true
            noDiamondBar.isHidden = false
            return
        }

        let isDiamont = AppStatusModel.shared.userModel.savedCardFaceType == .diamond
        diamondView.isHidden = !isDiamont
        noDiamondBar.isHidden = isDiamont
    }

    /**
     ログイン演出開始
     */
    private final func startLoginEffect() {
        AppStatusModel.shared.animateContentsAlpha(to: 1.0)

        // 通常ログインかオートログインか
        let isNewLogin = AppStatusModel.shared.loginState.value == .isLogin

        alpha = 0.0
        transform = CGAffineTransform(scaleX: 0.3, y: 0.3)

        // スケールを1.0に
        UIView.animate(withDuration: isNewLogin ? 4.0 : 3.5,
                       delay: isNewLogin ? 2.5 : 0.8,
                       options: .curveEaseOut,
                       animations: {
                        self.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        },
                       completion: { [weak self] _ in
                        self?.showHint()
                        // Top表示のtracking
                        self?.sendAnalytics()
                        AppStatusModel.shared.didFinishNativeLoginAnimation.value = true
                        self?.trace?.stop()
        })
        // アルファ
        UIView.animate(withDuration: isNewLogin ? 4.0 : 3.5,
                       delay: isNewLogin ? 2.5 : 0.8,
                       options: .curveEaseOut,
                       animations: {
                        self.alpha = 1.0
        },
                       completion: nil)
    }
    
    override func showHint() {
        hintView = HomeHintView.create(AppInfoUtil.classNameString(type(of: self)))
        hintView?.show()
    }

    /**
     アプリ遷移ボタン
     */
    @IBAction private func anaAppButtonTapped() {
        // Analytics
        sendActionAnalytics(actionName: "Common_ANAapp_From_Top")
        AppLink.openAnaApp()
    }

    /**
     リロードボタンタップ時
     */
    @IBAction private final func retryButtonTapped() {
        guard let userParameter = AppStatusModel.shared.userModel.savedLoginParameter else { return }
        
        // 更新中無効
        switch AppStatusModel.shared.loginState.value {
        case .isTryFetch, .isTryLogin, .isTryUpdate, .isTryAutoLogin:
            return
        default:
            break
        }
        
        // 前回更新から一定の間隔内再更新できない
        let lastUpdateAt = AppStatusModel.shared.lastUpdateTime.value ?? Date(timeIntervalSince1970: 0)
        guard lastUpdateAt.timeIntervalSinceNow < -3 else { return }

        sendActionAnalytics(actionName: "Common_LastUpdate_From_Top")
        
        // Offline mode更新する時だけloadingを表示
        if AppStatusModel.shared.userModel.user.value?.isCaching == true {
            LoadingView.show()
        }
        
        AppStatusModel.shared.loginState.value = .isTryUpdate
        AppStatusModel.shared.login(parameter: userParameter)
            .filter { $0 != nil && $1 != nil && $2 != nil && $3 != nil}
            .take(1)
            .subscribe(onNext: { _ in
                LoadingView.dismiss()
            }).disposed(by: disposeBag)
    }
    
    private func startLoadingAnimation() {
        retryButton.imageView?.layer.removeAllAnimations()
        let ani = CABasicAnimation(keyPath: "transform.rotation.z")
        ani.toValue = CGFloat.pi * 2
        ani.duration = 0.8
        ani.repeatCount = Float.greatestFiniteMagnitude
        retryButton.imageView?.layer.add(ani, forKey: "rotate")
    }
    
    private func stopLoadingAnimation() {
        retryButton.imageView?.layer.removeAllAnimations()
    }
    
    /**
     エラーリトライ画面
     */
    final override func showErrorView() {
        pointContainer.alpha = 0.2
        errorContainer.alpha = 1
        errorContainer.isHidden = false
    }

    /**
     エラーViewを非表示に
     */
    private final func dismissErrorContainer() {
        UIView.animate(withDuration: 0.4, animations: {
            self.pointContainer.alpha = 1.0
            self.errorContainer.alpha = 0.0
        })
    }
}
