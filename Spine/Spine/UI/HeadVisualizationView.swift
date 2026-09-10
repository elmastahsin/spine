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
///
/// The head shape is three overlapping ellipsoids (cranium, jaw, chin)
/// rather than a single sphere or a hand-tuned lathe profile: a lathe
/// silhouette is very sensitive to its control points and previously came
/// out looking like a lightbulb, while stacked ellipsoids stay predictably
/// round at every size and still read as a head once the jaw narrows
/// below the cranium.
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

    // MARK: - Ellipsoid surface math

    /// A sphere's base radius plus a non-uniform scale, both in the same
    /// local space as the nodes built from it. Lets facial features be
    /// placed by sampling the actual surface instead of guessing
    /// coordinates that risk floating or clipping.
    private struct Ellipsoid {
        let center: SCNVector3
        let radius: Double
        let scale: SCNVector3
    }

    private static func surfaceExtent(_ e: Ellipsoid, atWorldY y: Double) -> (x: Double, z: Double) {
        let localY = (y - Double(e.center.y)) / Double(e.scale.y)
        let clamped = max(-1, min(1, localY))
        let factor = (1 - clamped * clamped).squareRoot()
        return (Double(e.scale.x) * e.radius * factor, Double(e.scale.z) * e.radius * factor)
    }

    // MARK: - Scene

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        let headGroup = SCNNode()
        headGroup.name = "headGroup"
        headGroup.position = SCNVector3(0, -0.1, 0)
        scene.rootNode.addChildNode(headGroup)

        let skinTone = NSColor(calibratedRed: 0.93, green: 0.92, blue: 0.94, alpha: 1)
        let skinMaterial = matteMaterial(skinTone, roughness: 0.55)
        skinMaterial.specular.contents = NSColor.white.withAlphaComponent(0.25)

        let cranium = Ellipsoid(center: SCNVector3(0, 0.08, 0), radius: 1.0, scale: SCNVector3(0.80, 0.95, 0.85))
        let jaw = Ellipsoid(center: SCNVector3(0, -0.55, 0.05), radius: 0.55, scale: SCNVector3(0.75, 0.58, 0.8))
        let chin = Ellipsoid(center: SCNVector3(0, -0.97, 0.18), radius: 0.18, scale: SCNVector3(0.9, 0.75, 1.0))

        for e in [cranium, jaw, chin] {
            let sphere = SCNSphere(radius: e.radius)
            sphere.segmentCount = 48
            sphere.materials = [skinMaterial]
            let node = SCNNode(geometry: sphere)
            node.scale = e.scale
            node.position = e.center
            headGroup.addChildNode(node)
        }

        // Neck: matches the jaw's width where it meets the bottom of the head.
        let neckY = -0.85
        let neckWidth = surfaceExtent(jaw, atWorldY: neckY).x
        let neck = SCNCylinder(radius: max(neckWidth * 0.85, 0.18), height: 0.6)
        neck.radialSegmentCount = 32
        neck.materials = [skinMaterial]
        let neckNode = SCNNode(geometry: neck)
        neckNode.position = SCNVector3(0, -1.15, 0.04)
        headGroup.addChildNode(neckNode)

        let eyelidMaterial = matteMaterial(NSColor(calibratedRed: 0.82, green: 0.78, blue: 0.78, alpha: 1), roughness: 0.5)
        let mouthMaterial = matteMaterial(NSColor(calibratedRed: 0.80, green: 0.62, blue: 0.62, alpha: 1), roughness: 0.6)
        let airPodsMaterial = matteMaterial(.white, roughness: 0.2)

        // Eyes: closed, almond-shaped lids sitting flush on the cranium's
        // brow line, colored a soft shadow tone rather than solid dark
        // "eye holes".
        let eyeY = 0.30
        let eyeZ = surfaceExtent(cranium, atWorldY: eyeY).z + 0.02
        for side: CGFloat in [-1, 1] {
            let eyelid = SCNCapsule(capRadius: 0.028, height: 0.16)
            eyelid.materials = [eyelidMaterial]
            let eyelidNode = SCNNode(geometry: eyelid)
            eyelidNode.eulerAngles.z = .pi / 2
            eyelidNode.scale = SCNVector3(1, 0.55, 1)
            eyelidNode.position = SCNVector3(side * 0.26, CGFloat(eyeY), CGFloat(eyeZ))
            headGroup.addChildNode(eyelidNode)
        }

        // Nose: soft bridge + rounded tip rather than a sharp cone.
        let noseBridgeY = 0.05
        let noseTipY = -0.14
        let bridgeZ = surfaceExtent(cranium, atWorldY: noseBridgeY).z - 0.01
        let tipZ = surfaceExtent(cranium, atWorldY: noseTipY).z + 0.14
        let bridge = SCNCapsule(capRadius: 0.045, height: 0.2)
        bridge.materials = [skinMaterial]
        let bridgeNode = SCNNode(geometry: bridge)
        bridgeNode.eulerAngles.x = .pi / 2.5
        bridgeNode.position = SCNVector3(0, CGFloat((noseBridgeY + noseTipY) / 2), CGFloat((bridgeZ + tipZ) / 2))
        headGroup.addChildNode(bridgeNode)

        let tip = SCNSphere(radius: 0.06)
        tip.materials = [skinMaterial]
        let tipNode = SCNNode(geometry: tip)
        tipNode.position = SCNVector3(0, CGFloat(noseTipY), CGFloat(tipZ))
        headGroup.addChildNode(tipNode)

        // Mouth: sits on the jaw ellipsoid, not the cranium.
        let mouthY = -0.42
        let mouthZ = surfaceExtent(jaw, atWorldY: mouthY).z + 0.02
        let mouth = SCNCapsule(capRadius: 0.022, height: 0.28)
        mouth.materials = [mouthMaterial]
        let mouthNode = SCNNode(geometry: mouth)
        mouthNode.eulerAngles.z = .pi / 2
        mouthNode.scale = SCNVector3(1, 0.6, 1)
        mouthNode.position = SCNVector3(0, CGFloat(mouthY), CGFloat(mouthZ))
        headGroup.addChildNode(mouthNode)

        // Ears + AirPods, at the widest part of the cranium.
        let earY = 0.12
        let earX = surfaceExtent(cranium, atWorldY: earY).x + 0.02
        for side: CGFloat in [-1, 1] {
            let ear = SCNSphere(radius: 0.13)
            ear.materials = [skinMaterial]
            let earNode = SCNNode(geometry: ear)
            earNode.scale = SCNVector3(0.45, 1.0, 0.75)
            earNode.position = SCNVector3(side * CGFloat(earX), CGFloat(earY), 0.02)
            headGroup.addChildNode(earNode)

            let bud = SCNSphere(radius: 0.07)
            bud.materials = [airPodsMaterial]
            let budNode = SCNNode(geometry: bud)
            budNode.position = SCNVector3(side * CGFloat(earX + 0.05), CGFloat(earY) + 0.01, 0.09)
            headGroup.addChildNode(budNode)

            let stem = SCNCapsule(capRadius: 0.026, height: 0.4)
            stem.materials = [airPodsMaterial]
            let stemNode = SCNNode(geometry: stem)
            stemNode.position = SCNVector3(side * CGFloat(earX + 0.07), CGFloat(earY) - 0.28, 0.13)
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
        cameraNode.position = SCNVector3(0, 0.05, 4.6)
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
