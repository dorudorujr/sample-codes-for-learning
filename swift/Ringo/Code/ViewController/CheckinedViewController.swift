//
//  CheckinedViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/03/04.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import ApplicationConfig

final class CheckinedViewController: UIViewController {
    
    @IBOutlet private weak var closeButton: UIButton!
    
    var isSuicaEntry = false

    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.isHidden = true
        navigationItem.hidesBackButton = true
        
        bind()
    }

    func bind() {
        
        closeButton.rx.tap
            .subscribe({ [weak self] _ in
                TransitionHelper.shared.transitionOut(false)
                if (self?.isSuicaEntry)! {
                    self?.navigationController?.dismiss(animated: true, completion: nil)
                } else {
                    UIView.beginAnimations("toHome", context: nil)
                    UIView.setAnimationDuration(Animation.duration)
                    UIView.setAnimationTransition(.flipFromLeft, for: (self?.navigationController?.view)!, cache: false)
                    UIView.commitAnimations()
                    self?.navigationController?.popToRootViewController(animated: true)
                }
            })
            .disposed(by: disposeBag)
    }
    
}
