//
//  HandPosePrediction.swift
//  HandPoseVision
//
//  Created by LEE HAEUN on 2020/11/02.
//

import UIKit
import Vision

class HandPosePrediction {
    let model = rps_imageProcessed_flip_rotate()
    private let visionQueue = DispatchQueue(label: "HAEUN.HabdPoseVision.visionQueue")

    private func convertSampleBufferToUIImage(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer,
                                     CVPixelBufferLockFlags.readOnly)

        let image = UIImage(ciImage: CIImage(cvPixelBuffer: pixelBuffer))

        CVPixelBufferUnlockBaseAddress(pixelBuffer,
                                       CVPixelBufferLockFlags.readOnly)
        return  image
    }

    private func getProcessedPixelBuffer(
        _ image: UIImage,
        handRectArea: CGRect
    ) -> CVPixelBuffer? {
        let handRectPath = UIBezierPath(roundedRect: handRectArea, cornerRadius: 0)
        handRectPath.close()


        guard let croppedImage = image.imageByApplyingMaskingBezierPath(handRectPath), let blackAndWhiteImage = croppedImage.toBlackAndWhite() else {
            return nil
        }

        let inputImageSize: CGFloat = 299.0
        let minLen = min(blackAndWhiteImage.size.width, blackAndWhiteImage.size.height)
        let resizedImage = blackAndWhiteImage.resize(
            to: CGSize(
                width: inputImageSize * blackAndWhiteImage.size.width / minLen,
                height: inputImageSize * blackAndWhiteImage.size.height / minLen
            )
        )

        guard let processedPixelBuffer = resizedImage.pixelBuffer() else {
            return nil
        }

        return processedPixelBuffer
    }

    func getPrediction(
        _ sampleBuffer: CMSampleBuffer,
        handRectArea: CGRect,
        completion: @escaping ((String?, [String : Double]?) -> Void)
    ) {
        guard let image = convertSampleBufferToUIImage(sampleBuffer) else {
            return completion(nil, nil)
        }
        guard let pixelBuffer = getProcessedPixelBuffer(image, handRectArea: handRectArea) else {
            return completion(nil, nil)
        }
        visionQueue.async {
            guard let output = try? self.model.prediction(image: pixelBuffer) else {
                return
            }
            completion(output.classLabel, output.classLabelProbs)
        }
    }

    func getPrediction(
        _ image: UIImage,
        handRectArea: CGRect,
        completion: @escaping ((String?, [String : Double]?) -> Void)
    ) {
        guard let pixelBuffer = getProcessedPixelBuffer(image, handRectArea: handRectArea) else {
            return completion(nil, nil)
        }
        visionQueue.async {
            guard let output = try? self.model.prediction(image: pixelBuffer) else {
                return
            }
            completion(output.classLabel, output.classLabelProbs)
        }
    }
}
