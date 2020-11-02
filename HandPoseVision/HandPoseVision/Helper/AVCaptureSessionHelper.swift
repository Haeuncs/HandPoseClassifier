//
//  AVCaptureSessionHelper.swift
//  HandPoseVision
//
//  Created by LEE HAEUN on 2020/11/02.
//

import UIKit
import AVFoundation

protocol AVCaptureSessionHelperDelegate: class {
    func avCaptureSessionHelperCaptureOutput(_ sampleBuffer: CMSampleBuffer)
    func avCaptureSessionHelperCapturePhotoOutput(_ photo: AVCapturePhoto)
}

class AVCaptureSessionHelper: NSObject {

    private let videoDataOutputQueue = DispatchQueue(label: "HAEUN.HabdPoseVision.videoDataOutputQueue", qos: .userInteractive)

    weak var delegate: AVCaptureSessionHelperDelegate?

    var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480
        return session
    }()

    private var captureDevice: AVCaptureDevice? = {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            return nil
        }
        return videoDevice
    }()

    private let photoOutput = AVCapturePhotoOutput()

    override init() {
        super.init()
        bindVideoOutput()
        bindPhotoOutput()
        activateCamera()
    }

    func bindVideoOutput() {
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        output.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        output.connection(with: .video)?.videoOrientation = .portrait

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
    }

    func bindPhotoOutput() {
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }

    func activateCamera() {
        guard let captureDevice = captureDevice else {
            return
        }

        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }

        captureSession.beginConfiguration()
        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
        }
        captureSession.commitConfiguration()
    }

    func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [
                kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType,
                kCVPixelBufferWidthKey as String: UIScreen.main.bounds.size.width,
                kCVPixelBufferHeightKey as String: UIScreen.main.bounds.size.height

            ]

            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    func start() {
        guard captureSession.isRunning == false else {
            return
        }
        captureSession.startRunning()
    }

    func stop() {
        guard captureSession.isRunning else {
            return
        }
        captureSession.stopRunning()
    }
}


extension AVCaptureSessionHelper: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.avCaptureSessionHelperCaptureOutput(sampleBuffer)
    }
}

extension AVCaptureSessionHelper: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        delegate?.avCaptureSessionHelperCapturePhotoOutput(photo)
    }
}
