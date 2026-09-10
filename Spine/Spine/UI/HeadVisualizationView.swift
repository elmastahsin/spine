import AppKit
import SceneKit
import SwiftUI

/// Live 3D head that tilts with the wearer's real head orientation.
///
/// The model is built procedurally from SceneKit primitives — no bundled
/// asset file — to stay in keeping with the project's no-third-party-
/// dependency rule. Pitch reflects the same signed baseline deviation used
/// for posture detection (`PostureEvaluation.signedDeviationDegrees`); yaw
/// and roll are the raw live device attitude, so turning your head visibly
/// turns the model rather than only tracking the posture-relevant axis.
///
/// Sign/axis mapping here is a best-effort guess (no physical AirPods were
/// available to verify against real hardware) — flip `pitchSign` below if
/// the model tilts opposite to the real motion once tested.
struct HeadVisualizationView: NSViewRepresentable {
    var pitchDegrees: Double
    var yawDegrees: Double
    var rollDegrees: Double

    private static let pitchSign: Double = -1

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = Self.makeScene()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        guard let headGroup = view.scene?.rootNode.childNode(withName: "headGroup", recursively: false) else { return }
        let pitch = Self.pitchSign * pitchDegrees * .pi / 180
        let yaw = yawDegrees * .pi / 180
        let roll = rollDegrees * .pi / 180
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.15
        headGroup.eulerAngles = SCNVector3(CGFloat(pitch), CGFloat(yaw), CGFloat(roll))
        SCNTransaction.commit()
    }

    // MARK: - Materials

    private static func matteMaterial(_ color: NSColor, roughness: CGFloat = 0.85) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .physicallyBased
        material.roughness.contents = roughness
        return material
    }

    // MARK: - Head silhouette

    /// Radius (before the node's xz scale is applied) at each sampled
    /// height, from crown (y = 1) to chin (y = -1). Revolving this around
    /// the Y axis is what actually gives the model a jaw and a chin instead
    /// of the plain scaled sphere the first version used.
    private static let headProfile: [(y: Double, r: Double)] = [
        (1.00, 0.00),
        (0.90, 0.30),
        (0.75, 0.48),
        (0.55, 0.56),
        (0.35, 0.57),
        (0.15, 0.54),
        (-0.05, 0.48),
        (-0.25, 0.40),
        (-0.45, 0.30),
        (-0.65, 0.20),
        (-0.85, 0.10),
        (-1.00, 0.00),
    ]

    /// Linear interpolation of `headProfile`, used to place facial features
    /// flush against the actual silhouette instead of guessing coordinates
    /// that risk floating off the surface or clipping into it.
    private static func profileRadius(atY y: Double) -> Double {
        let points = headProfile
        for i in 0..<(points.count - 1) {
            let (y0, r0) = points[i]
            let (y1, r1) = points[i + 1]
            if y <= y0 && y >= y1 {
                let t = (y0 - y) / (y0 - y1)
                return r0 + t * (r1 - r0)
            }
        }
        return points.last?.r ?? 0
    }

    /// Builds a lathe (surface of revolution) mesh from `headProfile`,
    /// smooth-shaded, with degenerate-but-valid triangle fans at the crown
    /// and chin poles.
    private static func makeHeadGeometry(material: SCNMaterial, radialSegments: Int = 40) -> SCNGeometry {
        let profile = headProfile
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []

        for (y, r) in profile {
            for seg in 0..<radialSegments {
                let theta = Double(seg) / Double(radialSegments) * 2 * .pi
                let x = r * cos(theta)
                let z = r * sin(theta)
                vertices.append(SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z)))
                let len = (x * x + z * z).squareRoot()
                if len > 0.0001 {
                    normals.append(SCNVector3(CGFloat(x / len), 0, CGFloat(z / len)))
                } else {
                    normals.append(SCNVector3(0, y > 0 ? 1 : -1, 0))
                }
            }
        }

        var indices: [Int32] = []
        for ring in 0..<(profile.count - 1) {
            for seg in 0..<radialSegments {
                let next = (seg + 1) % radialSegments
                let a = Int32(ring * radialSegments + seg)
                let b = Int32(ring * radialSegments + next)
                let c = Int32((ring + 1) * radialSegments + seg)
                let d = Int32((ring + 1) * radialSegments + next)
                indices.append(contentsOf: [a, b, c])
                indices.append(contentsOf: [b, d, c])
            }
        }

        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.materials = [material]
        return geometry
    }

    // MARK: - Scene

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        let headGroup = SCNNode()
        headGroup.name = "headGroup"
        headGroup.position = SCNVector3(0, -0.05, 0)
        scene.rootNode.addChildNode(headGroup)

        // Flattens the revolved (circular) cross-section slightly
        // front-to-back, the way a real head is narrower depth-wise than
        // it is across the temples.
        let headScale = SCNVector3(1.0, 1.05, 0.82)

        let skinTone = NSColor(calibratedRed: 0.93, green: 0.92, blue: 0.94, alpha: 1)
        let skinMaterial = matteMaterial(skinTone, roughness: 0.55)
        skinMaterial.specular.contents = NSColor.white.withAlphaComponent(0.25)

        let headNode = SCNNode(geometry: makeHeadGeometry(material: skinMaterial))
        headNode.scale = headScale
        headGroup.addChildNode(headNode)

        // Neck: tapers from roughly the jaw width down to the shoulders,
        // instead of a mismatched cylinder butting into a round skull.
        let jawWidth = profileRadius(atY: -0.55) * headScale.x
        let neck = SCNCylinder(radius: jawWidth * 0.85, height: 0.62)
        neck.radialSegmentCount = 32
        neck.materials = [skinMaterial]
        let neckNode = SCNNode(geometry: neck)
        neckNode.position = SCNVector3(0, -1.02 * headScale.y, 0.02 * headScale.z)
        headGroup.addChildNode(neckNode)

        let eyelidMaterial = matteMaterial(NSColor(calibratedRed: 0.82, green: 0.78, blue: 0.78, alpha: 1), roughness: 0.5)
        let mouthMaterial = matteMaterial(NSColor(calibratedRed: 0.80, green: 0.62, blue: 0.62, alpha: 1), roughness: 0.6)
        let airPodsMaterial = matteMaterial(.white, roughness: 0.2)

        // Eyes: closed, almond-shaped lids sitting flush on the brow line,
        // colored a soft shadow tone rather than solid dark "eye holes".
        let eyeY = 0.27
        let eyeZ = (profileRadius(atY: eyeY) + 0.015) * headScale.z
        for side: CGFloat in [-1, 1] {
            let eyelid = SCNCapsule(capRadius: 0.028, height: 0.16)
            eyelid.materials = [eyelidMaterial]
            let eyelidNode = SCNNode(geometry: eyelid)
            eyelidNode.eulerAngles.z = .pi / 2
            eyelidNode.scale = SCNVector3(1, 0.55, 1)
            eyelidNode.position = SCNVector3(side * 0.27 * headScale.x, eyeY * headScale.y, eyeZ)
            headGroup.addChildNode(eyelidNode)
        }

        // Nose: soft bridge + rounded tip rather than a sharp cone.
        let noseBridgeY = 0.05
        let noseTipY = -0.12
        let bridgeZ = (profileRadius(atY: noseBridgeY) - 0.01) * headScale.z
        let tipZ = (profileRadius(atY: noseTipY) + 0.14) * headScale.z
        let bridge = SCNCapsule(capRadius: 0.045, height: 0.22)
        bridge.materials = [skinMaterial]
        let bridgeNode = SCNNode(geometry: bridge)
        bridgeNode.eulerAngles.x = .pi / 2.55
        bridgeNode.position = SCNVector3(0, (noseBridgeY + noseTipY) / 2 * headScale.y, (bridgeZ + tipZ) / 2)
        headGroup.addChildNode(bridgeNode)

        let tip = SCNSphere(radius: 0.06)
        tip.materials = [skinMaterial]
        let tipNode = SCNNode(geometry: tip)
        tipNode.position = SCNVector3(0, noseTipY * headScale.y, tipZ)
        headGroup.addChildNode(tipNode)

        // Mouth: thin, gently rounded lip line.
        let mouthY = -0.42
        let mouthZ = (profileRadius(atY: mouthY) + 0.03) * headScale.z
        let mouth = SCNCapsule(capRadius: 0.022, height: 0.3)
        mouth.materials = [mouthMaterial]
        let mouthNode = SCNNode(geometry: mouth)
        mouthNode.eulerAngles.z = .pi / 2
        mouthNode.scale = SCNVector3(1, 0.6, 1)
        mouthNode.position = SCNVector3(0, mouthY * headScale.y, mouthZ)
        headGroup.addChildNode(mouthNode)

        // Ears + AirPods, at the widest (temple) part of the head.
        let earY = 0.18
        let earX = (profileRadius(atY: earY) + 0.02) * headScale.x
        for side: CGFloat in [-1, 1] {
            let ear = SCNSphere(radius: 0.13)
            ear.materials = [skinMaterial]
            let earNode = SCNNode(geometry: ear)
            earNode.scale = SCNVector3(0.45, 1.0, 0.75)
            earNode.position = SCNVector3(side * earX, earY * headScale.y, 0.02)
            headGroup.addChildNode(earNode)

            let bud = SCNSphere(radius: 0.07)
            bud.materials = [airPodsMaterial]
            let budNode = SCNNode(geometry: bud)
            budNode.position = SCNVector3(side * (earX + 0.05), earY * headScale.y + 0.01, 0.09)
            headGroup.addChildNode(budNode)

            let stem = SCNCapsule(capRadius: 0.026, height: 0.4)
            stem.materials = [airPodsMaterial]
            let stemNode = SCNNode(geometry: stem)
            stemNode.position = SCNVector3(side * (earX + 0.07), earY * headScale.y - 0.28, 0.13)
            stemNode.eulerAngles.z = side * (.pi / 11)
            headGroup.addChildNode(stemNode)
        }

        // MARK: Camera & lights

        let cameraNode = SCNNode()
        cameraNode.camera = {
            let camera = SCNCamera()
            camera.fieldOfView = 30
            return camera
        }()
        cameraNode.position = SCNVector3(0, 0.1, 4.6)
        scene.rootNode.addChildNode(cameraNode)

        let keyLightNode = SCNNode()
        keyLightNode.light = {
            let light = SCNLight()
            light.type = .directional
            light.intensity = 950
            light.color = NSColor.white
            return light
        }()
        keyLightNode.eulerAngles = SCNVector3(-CGFloat.pi / 4.2, CGFloat.pi / 6, 0)
        scene.rootNode.addChildNode(keyLightNode)

        let fillLightNode = SCNNode()
        fillLightNode.light = {
            let light = SCNLight()
            light.type = .directional
            light.intensity = 250
            light.color = NSColor(calibratedRed: 0.6, green: 0.7, blue: 1.0, alpha: 1)
            return light
        }()
        fillLightNode.eulerAngles = SCNVector3(CGFloat.pi / 6, -CGFloat.pi / 3, 0)
        scene.rootNode.addChildNode(fillLightNode)

        let ambientLightNode = SCNNode()
        ambientLightNode.light = {
            let light = SCNLight()
            light.type = .ambient
            light.intensity = 350
            light.color = NSColor(calibratedWhite: 0.65, alpha: 1)
            return light
        }()
        scene.rootNode.addChildNode(ambientLightNode)

        return scene
    }
}
