/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A `Pose` is a collection of "landmarks" and connections between select landmarks.
 Each `Pose` can draw itself as a wireframe to a Core Graphics context.
*/

import UIKit
import Vision

typealias Observation = VNHumanBodyPoseObservation
/// Stores the landmarks and connections of a human body pose and draws them as
/// a wireframe.
/// - Tag: Pose
struct Pose {
    /// 人体上重要点的名称和位置。
    let landmarks: [Landmark]

    /// 用于绘制线框的地标之间的线的列表。
    var connections: [Connection]!

    /// 姿势的地标的位置作为一个多重数组。
    /// - Tag: multiArray
    let multiArray: MLMultiArray?

    /// 对地标面积的粗略估计。
    let area: CGFloat

    /// 为数组中的每个人体姿势观察创建一个“Pose”。
    /// - Parameter observations: An array of human body pose observations.
    /// - Returns: A `Pose` array.
    static func fromObservations(_ observations: [Observation]?) -> [Pose]? {
        // Convert each observations to a `Pose`.
        observations?.compactMap { observation in Pose(observation) }
    }

    /// Creates a wireframe from a human pose observation.
    /// - Parameter observation: A human body pose observation.
    init?(_ observation: Observation) {
        // Create a landmark for each joint in the observation.
        landmarks = observation.availableJointNames.compactMap { jointName in
            guard jointName != JointName.root else {
                return nil
            }

            guard let point = try? observation.recognizedPoint(jointName) else {
                return nil
            }

            return Landmark(point)
        }

        guard !landmarks.isEmpty else { return nil }

        //
        area = Pose.areaEstimateOfLandmarks(landmarks)

        // Save the multiarray from the observation.
        multiArray = try? observation.keypointsMultiArray()

        // Build a list of connections from the pose's landmarks.
        buildConnections()
    }

    /// 绘制线框的所有有效连接和地标。
    /// - Parameters:
    ///   - context: 方法用于绘制线框的上下文
    ///   - transform: 修改点位置的变换。
    /// - Tag: drawWireframeToContext
    func drawWireframeToContext(_ context: CGContext,
                                applying transform: CGAffineTransform? = nil) {
        let scale = drawingScale

        // 先画连接线。
        connections.forEach {
            line in line.drawToContext(context,
                                       applying: transform,
                                       at: scale)

        }

        // 在直线端点的顶部绘制地标。
        landmarks.forEach { landmark in
            landmark.drawToContext(context,
                                   applying: transform,
                                   at: scale)
        }
    }

    /// Adjusts the landmarks radius and connection thickness when the pose draws
    /// itself as a wireframe.
    private var drawingScale: CGFloat {
        /// The typical size of a dominant pose.
        ///
        /// The sample's author empirically derived this value.
        let typicalLargePoseArea: CGFloat = 0.35

        /// The largest scale is 100%.
        let max: CGFloat = 1.0

        /// The smallest scale is 60%.
        let min: CGFloat = 0.6

        /// The area's ratio relative to the typically large pose area.
        let ratio = area / typicalLargePoseArea

        let scale = ratio >= max ? max : (ratio * (max - min)) + min
        return scale
    }
}

// MARK: - Helper methods
extension Pose {
    /// Creates an array of connections from the available landmarks.
    mutating func buildConnections() {
        // Only build the connections once.
        guard connections == nil else {
            return
        }

        connections = [Connection]()

        // Get the joint name for each landmark.
        let joints = landmarks.map { $0.name }

        // Get the location for each landmark.
        let locations = landmarks.map { $0.location }

        // Create a lookup dictionary of landmark locations.
        let zippedPairs = zip(joints, locations)
        let jointLocations = Dictionary(uniqueKeysWithValues: zippedPairs)

        // Add a connection if both of its endpoints have valid landmarks.
        for jointPair in Pose.jointPairs {
            guard let one = jointLocations[jointPair.joint1] else { continue }
            guard let two = jointLocations[jointPair.joint2] else { continue }

            connections.append(Connection(one, two))
        }
    }

    /// Returns a rough estimate of the landmarks' collective area.
    /// - Parameter landmarks: A `Landmark` array.
    /// - Returns: A `CGFloat` that is greater than or equal to `0.0`.
    static func areaEstimateOfLandmarks(_ landmarks: [Landmark]) -> CGFloat {
        let xCoordinates = landmarks.map { $0.location.x }
        let yCoordinates = landmarks.map { $0.location.y }

        guard let minX = xCoordinates.min() else { return 0.0 }
        guard let maxX = xCoordinates.max() else { return 0.0 }

        guard let minY = yCoordinates.min() else { return 0.0 }
        guard let maxY = yCoordinates.max() else { return 0.0 }

        let deltaX = maxX - minX
        let deltaY = maxY - minY

        return deltaX * deltaY
    }
}
