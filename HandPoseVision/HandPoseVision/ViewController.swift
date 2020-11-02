//
//  ViewController.swift
//  HandPoseVision
//
//  Created by LEE HAEUN on 2020/11/02.
//

import UIKit
import AVFoundation
import Vision
import CoreML

class ViewController: UIViewController {

    lazy var cameraView: CameraView = {
        let view = CameraView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var predictionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 32, weight: .heavy)
        label.textColor = .black
        return label
    }()

    lazy var probabilityLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor.gray.withAlphaComponent(0.4)
        label.numberOfLines = 0
        return label
    }()

    lazy var captureButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 30
        button.backgroundColor = #colorLiteral(red: 1, green: 0.8728042245, blue: 0.07454227656, alpha: 1)
        button.addTarget(self, action: #selector(didTapCapture(_:)), for: .touchUpInside)
        return button
    }()

    let sessionHelper = AVCaptureSessionHelper()
    let handPosePrediction = HandPosePrediction()
    let handDetection = HandDetection()

    var latestHandRect: CGRect?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        startCameraSession()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        stopCameraSession()
    }

    func configureLayout() {
        view.addSubview(probabilityLabel)
        view.addSubview(cameraView)
        view.addSubview(predictionLabel)
        view.addSubview(captureButton)

        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            cameraView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cameraView.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.width + (UIScreen.main.bounds.width/3)),

            predictionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            predictionLabel.topAnchor.constraint(equalTo: cameraView.bottomAnchor),
            predictionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            probabilityLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            probabilityLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            probabilityLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            captureButton.centerYAnchor.constraint(equalTo: predictionLabel.centerYAnchor),
            captureButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 60),
            captureButton.heightAnchor.constraint(equalToConstant: 60),
        ])

    }

    func startCameraSession() {
        cameraView.previewLayer.videoGravity = .resizeAspect
        cameraView.previewLayer.session = sessionHelper.captureSession

        sessionHelper.delegate = self
        sessionHelper.start()
    }

    func stopCameraSession() {
        sessionHelper.stop()
    }

    @objc func didTapCapture(_ sender: UIButton) {
        sessionHelper.capturePhoto()
    }
}

extension ViewController: AVCaptureSessionHelperDelegate {
    func convertPointByPreview(_ points: [CGPoint]) -> [CGPoint] {
        let previewLayer = cameraView.previewLayer
        var pointsConverted: [CGPoint] = []
        for point in points {
            pointsConverted.append(previewLayer.layerPointConverted(fromCaptureDevicePoint: point))
        }
        return pointsConverted
    }

    func avCaptureSessionHelperCaptureOutput(_ sampleBuffer: CMSampleBuffer) {
        guard let points = handDetection.getHandRect(outputBuffer: sampleBuffer) else {
            DispatchQueue.main.async {
                self.predictionLabel.text = nil
                self.cameraView.showPoints([])
                self.cameraView.showRect(handRect: .zero)
            }
            return
        }

        DispatchQueue.main.async {
            let pointsConverted = self.convertPointByPreview(points)
            let handRect = self.handDetection.pointsToRect(pointsConverted)

            // for Capture photo 인 경우
            self.latestHandRect = handRect

            self.cameraView.showRect(handRect: handRect)
            self.cameraView.showPoints(pointsConverted)

            self.handPosePrediction.getPrediction(sampleBuffer, handRectArea: handRect) { (predictionString, probDic)  in
                DispatchQueue.main.async {
                    self.predictionLabel.text = predictionString
                }
            }
        }
    }

    func avCaptureSessionHelperCapturePhotoOutput(_ photo: AVCapturePhoto) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData),
              let handRect = latestHandRect else { return }

        handPosePrediction.getPrediction(image, handRectArea: handRect) { (predictionString, probDic) in
            DispatchQueue.main.async {
                self.predictionLabel.text = predictionString
                var probStr: String = ""
                guard let probDic = probDic else {
                    return
                }

                let sortedProbDic =  probDic.sorted { $0.1 > $1.1 }
                for index in 0 ..< sortedProbDic.count {
                    let value = String(round((sortedProbDic[index].value * 100) * 1000) / 1000) + "%"
                    probStr += "\(sortedProbDic[index].key) : \(value)"
                    if index != (sortedProbDic.count - 1) {
                        probStr += "\n"
                    }
                }

                self.probabilityLabel.text = probStr
            }
        }
    }
}
