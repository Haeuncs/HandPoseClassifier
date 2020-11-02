//
//  HandDetection.swift
//  HandPoseVision
//
//  Created by LEE HAEUN on 2020/11/02.
//

import Vision

class HandDetection {
    lazy var handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()

    func getHandRect(outputBuffer: CMSampleBuffer) -> [CGPoint]? {
        let requestHandler = VNImageRequestHandler(
            cmSampleBuffer: outputBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try requestHandler.perform([handPoseRequest])
            guard let handPoseObservation = handPoseRequest.results?.first else {
                return nil
            }

            // get finger
            let thumbPoints = try handPoseObservation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyThumb)
            let indexFingerPoints = try handPoseObservation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyIndexFinger)
            let middleFingerPoints = try handPoseObservation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyMiddleFinger)
            let ringFingerPoints = try handPoseObservation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyRingFinger)
            let littleFingerPoints = try handPoseObservation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyLittleFinger)
            let wristPoints = try handPoseObservation.recognizedPoints(forGroupKey: .all)

            // get point
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
                return nil
            }

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
                return nil
            }

            let handPoints: [CGPoint] = [
                getCGPoint(thumbTipPoint),
                getCGPoint(thumbIpPoint),
                getCGPoint(thumbMpPoint),
                getCGPoint(thumbCmcPoint),

                getCGPoint(indexTipPoint),
                getCGPoint(indexDipPoint),
                getCGPoint(indexPipPoint),
                getCGPoint(indexMcpPoint),

                getCGPoint(middleTipPoint),
                getCGPoint(middleDipPoint),
                getCGPoint(middlePipPoint),
                getCGPoint(middleMcpPoint),

                getCGPoint(ringTipPoint),
                getCGPoint(ringDipPoint),
                getCGPoint(ringPipPoint),
                getCGPoint(ringMcpPoint),

                getCGPoint(littleTipPoint),
                getCGPoint(littleDipPoint),
                getCGPoint(littlePipPoint),
                getCGPoint(littleMcpPoint),

                getCGPoint(wristPoint)
            ]

            return handPoints

        } catch {
            return nil
        }
    }

    func pointsToRect(_ points: [CGPoint]) -> CGRect {
        let maxX = points.max { (point1, point2) -> Bool in
            point1.x < point2.x
        }?.x

        let maxY = points.max { (point1, point2) -> Bool in
            point1.y < point2.y
        }?.y

        let minX = points.min { (point1, point2) -> Bool in
            point1.x < point2.x
        }?.x

        let minY = points.min { (point1, point2) -> Bool in
            point1.y < point2.y
        }?.y

        guard let minX_ = minX,
              let minY_ = minY,
              let maxX_ = maxX,
              let maxY_ = maxY else {
            return .zero
        }

        let number: CGFloat = 20

        return CGRect(
            x: (minX_ - number),
            y: (minY_ - number),
            width: (maxX_ - minX_) + (2 * number),
            height: (maxY_ - minY_) + (2 * number)
        )
    }

    private func getCGPoint(_ point: VNRecognizedPoint) -> CGPoint {
        CGPoint(x: point.location.x, y: 1 - point.location.y)
    }
}
