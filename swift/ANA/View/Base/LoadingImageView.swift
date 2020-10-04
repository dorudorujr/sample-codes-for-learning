//
//  LoadingImageView.swift
//  AnaMile
//
//  Created by YANG SHENWEN on 2019/06/18.
//

import UIKit
import RxSwift
import RxCocoa

@IBDesignable       /// カスタムViewがxibなどに反映されるやつ？
final class LoadingImageView: UIImageView {
    
    var isShowing = BehaviorRelay<Bool>(value: false)
    
    private let disposeBag = DisposeBag()
    
    //下記初期化メソッドはViewの生成方法で呼ばれる関数が違ってくる
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    private func setup() {
        animationImages = Loading.animationImages   ///画像をセット
        animationDuration = 3.0
        animationRepeatCount = 0
        alpha = 0.0
        
        bind()
    }
    
    private func bind() {
        isShowing.asDriver()
            .drive(onNext: { [unowned self] isShowing in
                isShowing ? self.startAnimating() : self.stopAnimating()
                UIView.animate(withDuration: 0.4, animations: {
                    self.alpha = isShowing ? 1 : 0
                })
            })
            .disposed(by: disposeBag)
    }
    
    override var intrinsicContentSize: CGSize {
        return Loading.size
    }
    
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        image = UIImage(named: "loading_ani_0000")
    }
}
