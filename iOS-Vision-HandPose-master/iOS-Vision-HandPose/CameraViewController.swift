/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main view controller object.
*/

import UIKit
import AVFoundation
import Vision
import CoreML

class CameraViewController: UIViewController {

    private var cameraView: CameraView = {
        let view = CameraView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var captureButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("캡쳐", for: .normal)
        button.addTarget(self, action: #selector(handleCapture), for: .touchUpInside)
        return button
    }()

    let model = rps_imageProcessed_flip_rotate()

    private var handRect: CGRect?

    private let photoOutput = AVCapturePhotoOutput()

    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    private var cameraFeedSession: AVCaptureSession?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(cameraView)
        view.addSubview(captureButton)

        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            cameraView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cameraView.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.width + (UIScreen.main.bounds.width/3)),

            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
        ])

        // This sample app detects one hand only.
        handPoseRequest.maximumHandCount = 1
        
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraFeedSession == nil {
                cameraView.previewLayer.videoGravity = .resizeAspect
                try setupAVSession()
                cameraView.previewLayer.session = cameraFeedSession

                if cameraFeedSession!.canAddOutput(photoOutput) {
                    cameraFeedSession?.addOutput(photoOutput)
                }
            }

            cameraFeedSession?.startRunning()
        } catch {
            AppError.display(error, inViewController: self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewWillDisappear(animated)
    }
    
    func setupAVSession() throws {
        // Select a front facing camera, make an input.
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Add a video input.
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output.
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
        session.commitConfiguration()
        cameraFeedSession = session
}
    
    func processPoints(_ points: [CGPoint?]) {
        
        // Convert points from AVFoundation coordinates to UIKit coordinates.
        let previewLayer = cameraView.previewLayer
        var pointsConverted: [CGPoint] = []
        for point in points {
            pointsConverted.append(previewLayer.layerPointConverted(fromCaptureDevicePoint: point!))
        }
        let maxX = pointsConverted.max { (point1, point2) -> Bool in
            point1.x < point2.x
        }?.x

        let maxY = pointsConverted.max { (point1, point2) -> Bool in
            point1.y < point2.y
        }?.y

        let minX = pointsConverted.min { (point1, point2) -> Bool in
            point1.x < point2.x
        }?.x

        let minY = pointsConverted.min { (point1, point2) -> Bool in
            point1.y < point2.y
        }?.y

        guard let minX_ = minX,
              let minY_ = minY,
              let maxX_ = maxX,
              let maxY_ = maxY else {
            return
        }

        let number: CGFloat = 20

        handRect = CGRect(
            x: (minX_ - number),
            y: (minY_ - number),
            width: (maxX_ - minX_) + (2 * number),
            height: (maxY_ - minY_) + (2 * number)
        )

        cameraView.showRect(handRect: handRect!)
        cameraView.showPoints(pointsConverted)
    }

    @objc func handleCapture() {
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
}

extension UIImage {
    func scaleImage(toSize newSize: CGSize) -> UIImage? {
        var newImage: UIImage?
        let newRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height).integral
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        if let context = UIGraphicsGetCurrentContext(), let cgImage = self.cgImage {
            context.interpolationQuality = .high
            let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: newSize.height)
            context.concatenate(flipVertical)
            context.draw(cgImage, in: newRect)
            if let img = context.makeImage() {
                newImage = UIImage(cgImage: img)
            }
            UIGraphicsEndImageContext()
        }
        return newImage
    }
}

extension UIImage
{
    /// Given a required height, returns a (rasterised) copy
    /// of the image, aspect-fitted to that height.

    func aspectFittedToHeight(_ newHeight: CGFloat) -> UIImage
    {
        let scale = newHeight / self.size.height
        let newWidth = self.size.width * scale
        let newSize = CGSize(width: newWidth, height: newHeight)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}


extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        let previewImage = UIImage(data: imageData)

        guard let hand = handRect else {
            return
        }
        let testPath = UIBezierPath(roundedRect: hand, cornerRadius: 0)
        testPath.close()

        guard let filteredImage = previewImage else {
            return
        }

        let flipImage =  filteredImage.flipHorizontally()!

        let aspectImage = flipImage.aspectFittedToHeight(UIScreen.main.bounds.width + (UIScreen.main.bounds.width/3))

        let processedImage = aspectImage.imageByApplyingMaskingBezierPath(testPath).toBlackAndWhite()!

//        UIImageWriteToSavedPhotosAlbum(processedImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
//
//        UIImageWriteToSavedPhotosAlbum(flipImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)

        DispatchQueue.global(qos: .userInitiated).async {

        let inputImageSize: CGFloat = 299.0
        let minLen = min(processedImage.size.width, processedImage.size.height)
        let resizedImage = processedImage.resize(to: CGSize(width: inputImageSize * processedImage.size.width / minLen, height: inputImageSize * processedImage.size.height / minLen))

        guard let pixelBuffer = resizedImage.pixelBuffer() else {
            fatalError()
        }

            guard let output = try? self.model.prediction(image: pixelBuffer) else {
            return
        }
            DispatchQueue.main.async {
                self.captureButton.setTitle(output.classLabel, for: .normal)
            }
        }
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
//        if let error = error {
//            let ac = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
//            ac.addAction(UIAlertAction(title: "OK", style: .default))
//            present(ac, animated: true)
//        } else {
//            let ac = UIAlertController(title: "Saved!", message: "Your altered image has been saved to your photos.", preferredStyle: .alert)
//            ac.addAction(UIAlertAction(title: "OK", style: .default))
//            present(ac, animated: true)
//        }
    }

}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var thumbTip: CGPoint?
        var thumbIp: CGPoint?
        var thumbMp: CGPoint?
        var thumbCmc: CGPoint?
        var indexTip: CGPoint?
        var indexDip: CGPoint?
        var indexPip: CGPoint?
        var indexMcp: CGPoint?
        var middleTip: CGPoint?
        var middleDip: CGPoint?
        var middlePip: CGPoint?
        var middleMcp: CGPoint?
        var ringTip: CGPoint?
        var ringDip: CGPoint?
        var ringPip: CGPoint?
        var ringMcp: CGPoint?
        var littleTip: CGPoint?
        var littleDip: CGPoint?
        var littlePip: CGPoint?
        var littleMcp: CGPoint?
        var wrist: CGPoint?


        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("Time: \(timeElapsed) s. FPS: \(1/timeElapsed)")
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observation = handPoseRequest.results?.first as? VNRecognizedPointsObservation else {
                cameraView.showPoints([])
                return
            }
            // Get points for all fingers
            let thumbPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyThumb)
            let indexFingerPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyIndexFinger)
            let middleFingerPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyMiddleFinger)
            let ringFingerPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyRingFinger)
            let littleFingerPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyLittleFinger)
            let wristPoints = try observation.recognizedPoints(forGroupKey: .all)
            
            // Extract individual points from Point groups.
            guard let thumbTipPoint = thumbPoints[.handLandmarkKeyThumbTIP],
                  let thumbIpPoint = thumbPoints[.handLandmarkKeyThumbIP],
                  let thumbMpPoint = thumbPoints[.handLandmarkKeyThumbMP],
                  let thumbCmcPoint = thumbPoints[.handLandmarkKeyThumbCMC],
                  let indexTipPoint = indexFingerPoints[.handLandmarkKeyIndexTIP],
                  let indexDipPoint = indexFingerPoints[.handLandmarkKeyIndexDIP],
                  let indexPipPoint = indexFingerPoints[.handLandmarkKeyIndexPIP],
                  let indexMcpPoint = indexFingerPoints[.handLandmarkKeyIndexMCP],
                  let middleTipPoint = middleFingerPoints[.handLandmarkKeyMiddleTIP],
                  let middleDipPoint = middleFingerPoints[.handLandmarkKeyMiddleDIP],
                  let middlePipPoint = middleFingerPoints[.handLandmarkKeyMiddlePIP],
                  let middleMcpPoint = middleFingerPoints[.handLandmarkKeyMiddleMCP],
                  let ringTipPoint = ringFingerPoints[.handLandmarkKeyRingTIP],
                  let ringDipPoint = ringFingerPoints[.handLandmarkKeyRingDIP],
                  let ringPipPoint = ringFingerPoints[.handLandmarkKeyRingPIP],
                  let ringMcpPoint = ringFingerPoints[.handLandmarkKeyRingMCP],
                  let littleTipPoint = littleFingerPoints[.handLandmarkKeyLittleTIP],
                  let littleDipPoint = littleFingerPoints[.handLandmarkKeyLittleDIP],
                  let littlePipPoint = littleFingerPoints[.handLandmarkKeyLittlePIP],
                  let littleMcpPoint = littleFingerPoints[.handLandmarkKeyLittleMCP],
                  let wristPoint = wristPoints[.handLandmarkKeyWrist] else {
                cameraView.showPoints([])
                return
            }
            // Ignore low confidence points.
            let confidenceThreshold: Float = 0.3
            guard thumbTipPoint.confidence > confidenceThreshold &&
                    thumbIpPoint.confidence > confidenceThreshold &&
                    thumbMpPoint.confidence > confidenceThreshold &&
                    thumbCmcPoint.confidence > confidenceThreshold &&
                    indexTipPoint.confidence > confidenceThreshold &&
                    indexDipPoint.confidence > confidenceThreshold &&
                    indexPipPoint.confidence > confidenceThreshold &&
                    indexMcpPoint.confidence > confidenceThreshold &&
                    middleTipPoint.confidence > confidenceThreshold &&
                    middleDipPoint.confidence > confidenceThreshold &&
                    middlePipPoint.confidence > confidenceThreshold &&
                    middleMcpPoint.confidence > confidenceThreshold &&
                    ringTipPoint.confidence > confidenceThreshold &&
                    ringDipPoint.confidence > confidenceThreshold &&
                    ringPipPoint.confidence > confidenceThreshold &&
                    ringMcpPoint.confidence > confidenceThreshold &&
                    littleTipPoint.confidence > confidenceThreshold &&
                    littleDipPoint.confidence > confidenceThreshold &&
                    littlePipPoint.confidence > confidenceThreshold &&
                    littleMcpPoint.confidence > confidenceThreshold &&
                    wristPoint.confidence > confidenceThreshold else {
                cameraView.showPoints([])
                return
            }
            
            // Convert points from Vision coordinates to AVFoundation coordinates.
            thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
            thumbIp = CGPoint(x: thumbIpPoint.location.x, y: 1 - thumbIpPoint.location.y)
            thumbMp = CGPoint(x: thumbMpPoint.location.x, y: 1 - thumbMpPoint.location.y)
            thumbCmc = CGPoint(x: thumbCmcPoint.location.x, y: 1 - thumbCmcPoint.location.y)
            indexTip = CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y)
            indexDip = CGPoint(x: indexDipPoint.location.x, y: 1 - indexDipPoint.location.y)
            indexPip = CGPoint(x: indexPipPoint.location.x, y: 1 - indexPipPoint.location.y)
            indexMcp = CGPoint(x: indexMcpPoint.location.x, y: 1 - indexMcpPoint.location.y)
            middleTip = CGPoint(x: middleTipPoint.location.x, y: 1 - middleTipPoint.location.y)
            middleDip = CGPoint(x: middleDipPoint.location.x, y: 1 - middleDipPoint.location.y)
            middlePip = CGPoint(x: middlePipPoint.location.x, y: 1 - middlePipPoint.location.y)
            middleMcp = CGPoint(x: middleMcpPoint.location.x, y: 1 - middleMcpPoint.location.y)
            ringTip = CGPoint(x: ringTipPoint.location.x, y: 1 - ringTipPoint.location.y)
            ringDip = CGPoint(x: ringDipPoint.location.x, y: 1 - ringDipPoint.location.y)
            ringPip = CGPoint(x: ringPipPoint.location.x, y: 1 - ringPipPoint.location.y)
            ringMcp = CGPoint(x: ringMcpPoint.location.x, y: 1 - ringMcpPoint.location.y)
            littleTip = CGPoint(x: littleTipPoint.location.x, y: 1 - littleTipPoint.location.y)
            littleDip = CGPoint(x: littleDipPoint.location.x, y: 1 - littleDipPoint.location.y)
            littlePip = CGPoint(x: littlePipPoint.location.x, y: 1 - littlePipPoint.location.y)
            littleMcp = CGPoint(x: littleMcpPoint.location.x, y: 1 - littleMcpPoint.location.y)
            wrist = CGPoint(x: wristPoint.location.x, y: 1-wristPoint.location.y)
            
            DispatchQueue.main.async {
                self.processPoints([thumbTip, thumbIp, thumbMp, thumbCmc,
                                    indexTip, indexDip, indexPip, indexMcp,
                                    middleTip, middleDip, middlePip, middleMcp,
                                    ringTip, ringDip, ringPip, ringMcp,
                                    littleTip, littleDip, littlePip, littleMcp,
                                    wrist])
            }
        } catch {
            cameraFeedSession?.stopRunning()
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
            }
        }
    }
}

// MARK: - CGPoint helpers

extension CGPoint {

    static func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }
    
    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
}

