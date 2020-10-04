//
//  SplashView.swift
//  AnaMile
//
//  Created by 西村 拓 on 2016/03/03.
//
//

import UIKit

import RxSwift

import ObjectMapper

/// 自動ログイン試行時に使用する、起動画面と同じ見た目のView
//// SplashViewは画面でしかなく、バージョンチェックなどのロジックはViewControllerが行っている模様
class SplashView: UIView {

    @IBOutlet private final weak var logoImageView: UIImageView!

    @IBOutlet private final weak var loadingIconImageView: LoadingImageView!

    @IBOutlet private final weak var backgroundImageView: UIImageView!

    /// Rx
    private var disposeBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()

        loadingIconImageView.isShowing.accept(true)

        // Rx
        bind()
    }

    // MARK: - Rx
    private final func bind() {

        // ログイン演出準備完了
        AppStatusModel.shared.isReadyToLogin
            .asDriver()
            .filter { $0 }
            .drive(onNext: {[weak self] _ in
                self?.dismiss()
            })
            .disposed(by: disposeBag)

        // 自動ログインエラー
        AppStatusModel.shared.userModel.error
            .asDriver()
            .filterNil()
            .drive(onNext: {[weak self] _ in
                self?.dismiss()
            })
            .disposed(by: disposeBag)

    }

    // Close
    private final func dismiss() {

        loadingIconImageView.isShowing.accept(false)

        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            options: .curveEaseOut,
            animations: {
                self.logoImageView.alpha = 0.0
            },
            completion: nil)

        UIView.animate(
            withDuration: 1.5,
            delay: 0.3,
            options: .curveEaseOut,
            animations: {
                self.backgroundImageView.alpha = 1.0
            },
            completion: nil)

        UIView.animate(
            withDuration: 3.0,
            delay: 1.8,
            options: .curveEaseOut,
            animations: {
                self.backgroundImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.alpha = 0.0
            },
            completion: nil)
    }
}
