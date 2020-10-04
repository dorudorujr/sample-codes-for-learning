//
//  UsageQRViewController.swift
//  RingoPass
//
//  Created by 溝口 健 on 2018/03/04.
//  Copyright © 2018年 Team Lab. All rights reserved.
//

import Foundation
import ApplicationLib
import UIKit
import RxSwift
import ReSwift
import RxCocoa
import AVFoundation
import ApplicationConfig
import ApplicationModel
import GoogleMaps

final class UsageQRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    @IBOutlet private weak var cameraPreview: UIView!       //カメラ画面

    var isDestinationChanged = false
    var nowPositionKeeper: NowPositionKeepable!

    private let captureSession = AVCaptureSession()         //カメラを使用するためのセッションを生成
    private let metadataOutput = AVCaptureMetadataOutput()  //QRコードの出力?

    private let disposeBag = DisposeBag()

    private let store = RxStore(store: Store<UsageQRViewState>(reducer: UsageQRViewReducer.handleAction, state: nil))
    private var requestCreator: QRInfoActionCreatable! {
        willSet {
            if requestCreator != nil {
                fatalError()
            }
        }
    }

    //taxiでのチェックイン情報をサーバに送る
    private var taxiCheckInRequestCreator: TaxiCheckInActionCreatable! {
        willSet {
            if taxiCheckInRequestCreator != nil {
                fatalError()
            }
        }
    }

    func inject(requestCreator: QRInfoActionCreatable, taxiCheckInActionCreatable: TaxiCheckInActionCreatable) {
        self.requestCreator = requestCreator
        self.taxiCheckInRequestCreator = taxiCheckInActionCreatable
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.barClear()                  //navigationを消している
        navigationController?.navigationBar.tintColor = UIColor.white   //戻るボタンの色を白にしている
        //戻るボタンの設定?
        navigationBarSetup(dispose: disposeBag, visibleHome: false, backRxCallBack: {
            TransitionHelper.shared.transitionOut(false)
            UIView.beginAnimations("toHome", context: nil)
            UIView.setAnimationDuration(Animation.duration)
            UIView.setAnimationTransition(.flipFromRight, for: self.navigationController!.view, cache: false)
            UIView.commitAnimations()
        })
        //透過にしている
        navigationController?.navigationBar.isTranslucent = true
        bind()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        //QRを読み取るためのカメラを設定
        cameraSetup(pos: AVCaptureDevice.Position.back)
        navigationController?.setNavigationBarHidden(false, animated: true)

        //ライト灯火
        lightOn()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.setBackgroundImage(UIImage.imageWithFill(color: UIColor.ringoGreen, size: (navigationController?.navigationBar.bounds.size)!), for: .default)
        navigationController?.navigationBar.barTintColor = UIColor.ringoGreen
        captureSession.stopRunning()
        lightOff()
    }

    func bind() {

        //carNumberとproviderCodeの値が変更されたら実行
        //変更とは無から有への変更も伴う
        Observable.combineLatest(store.carNumber, store.providerCode)
            .filter { $0.0.isNotEmpty && $0.1 != nil }
            .subscribe({ [unowned self] in

                let nowPosition = self.nowPositionKeeper.read()     //現在地取得
                let longitude = nowPosition.longitude               //現在地の経度
                let latitude = nowPosition.latitude                 //現在地の緯度
                //クレジットカードのスロット
                let cardSlot = ApplicationStore.instance.state.taxiPaymentCardSlot == -1 ? ApplicationStore.instance.state.defaultCardSlot : ApplicationStore.instance.state.taxiPaymentCardSlot
                let param = TaxiCheckInParameter(cardSlot: cardSlot, providerCode: ($0.element?.1)!, carNumber: ($0.element?.0)!, currentLongitude: longitude, currentLatitude: latitude)
                self.store.dispatch(self.taxiCheckInRequestCreator.post(parameter: param, disposeBag: self.disposeBag))

                if self.isDestinationChanged {
                    //TODO:行き先が設定されていれば行き先送信APIを叩く
                }
            })
            .disposed(by: disposeBag)

        //チェックインしたら画面を遷移
        store.isCheckIn
            .filter { $0 }
            .subscribe({ [unowned self] _ in
                self.performSegue(withIdentifier: StoryboardSegue.UsageQR.toComplete.rawValue, sender: nil)
            })
            .disposed(by: disposeBag)

        commonBind(isLoading: store.isLoading, error: store.error, disposeBag: disposeBag)
    }

    func cameraSetup(pos: AVCaptureDevice.Position) {
        if captureSession.isRunning {
            captureSession.stopRunning()
            captureSession.beginConfiguration()
            captureSession.removeInput(captureSession.inputs.first!)
        }
        let camera = AVCaptureDevice.devices(for: .video).first(where: { $0.position == pos })
        guard let videoInput = try? AVCaptureDeviceInput(device: camera!) else {
            Alert.show(to: self, message: L10n.error005CantUseCameraMessage, style: .custom(buttons: [(.setting, .default), (.cancel, .cancel)]))
                .subscribe({ [unowned self] in
                    guard let result = $0.element else { return }
                    if result == .setting {
                        guard let url = URL(string: UIApplicationOpenSettingsURLString) else { return }
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    } else {
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                }).disposed(by: disposeBag)
            return
        }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)

            if captureSession.outputs.isEmpty {
                let metadataOutput = AVCaptureMetadataOutput()
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            }

            let videoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoLayer.frame = cameraPreview.bounds
            videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            cameraPreview.layer.addSublayer(videoLayer)

            captureSession.commitConfiguration()
            captureSession.startRunning()
        }
    }

    //QRコードが検出されたら呼び出される
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        //最前面のUIViewControllerを取得
        var topView = UIApplication.shared.keyWindow?.rootViewController
        while (topView!.presentedViewController) != nil {
            topView = topView!.presentedViewController
        }
        //エラー時のアラート？
        let alert = topView as? UIAlertController
        //エラーではなくロードもしていない
        if alert == nil && !self.store.state.isLoading {
            self.captureSession.stopRunning()       //カメラ停止
            let qrValue = (metadataObjects as! [AVMetadataMachineReadableCodeObject]).filter { $0.type == AVMetadataObject.ObjectType.qr }
            let param = QRInfoParameter(qrCode: (qrValue.first?.stringValue)!)      //QRコードの値を取得。この時はまだcarNumberなどは取得していない
            store.dispatch(requestCreator.get(parameter: param, disposeBag: disposeBag))
            captureSession.startRunning()
            lightOn()//一度sessionを止めると lightが自動でoffになるため
        }
        
    }

    private func lightOn() {
        let device = AVCaptureDevice.default(for: .video)!
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                do {
                    try device.setTorchModeOn(level: 1.0)
                } catch {
                    print(error)
                }
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }

    private func lightOff() {
        let device = AVCaptureDevice.default(for: .video)!
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                device.torchMode = .off
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }

}

extension RxStore where AnyStateType == UsageQRViewState {

    var isLoading: Observable<Bool> {
        return stateObservable.map { $0.isLoading }.distinctUntilChanged()
    }

    var error: Observable<Error?> {
        return stateObservable.map { $0.error }.filter { $0 != nil }
    }

    //distinctUntilChanged:変化がない間はスキップ
    var carNumber: Observable<String> {
        return stateObservable.map { $0.carNumber }.distinctUntilChanged()
    }

    var providerCode: Observable<Int?> {
        return stateObservable.map { $0.providerCode }.distinctUntilChanged()
    }

    var isCheckIn: Observable<Bool> {
        return stateObservable.map { $0.isCheckIn }.distinctUntilChanged()
    }

}

extension Alert.ActionType {
    static var setting: Alert.ActionType {
        return .custom(title: "設定")
    }
}
