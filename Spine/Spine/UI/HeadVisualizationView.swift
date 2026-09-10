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

    private static func matteMaterial(_ color: NSColor, roughness: CGFloat = 0.85) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .physicallyBased
        material.roughness.contents = roughness
        return material
    }

    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        let headGroup = SCNNode()
        headGroup.name = "headGroup"
        headGroup.position = SCNVector3(0, -0.15, 0)
        scene.rootNode.addChildNode(headGroup)

        let skinTone = NSColor(calibratedRed: 0.95, green: 0.90, blue: 0.87, alpha: 1)
        let skinMaterial = matteMaterial(skinTone)

        let skull = SCNSphere(radius: 1.0)
        skull.segmentCount = 48
        skull.materials = [skinMaterial]
        let skullNode = SCNNode(geometry: skull)
        skullNode.scale = SCNVector3(0.78, 1.0, 0.85)
        headGroup.addChildNode(skullNode)

        let neck = SCNCylinder(radius: 0.32, height: 0.7)
        neck.materials = [skinMaterial]
        let neckNode = SCNNode(geometry: neck)
        neckNode.position = SCNVector3(0, -1.05, 0.05)
        headGroup.addChildNode(neckNode)

        let eyeMaterial = matteMaterial(NSColor(calibratedWhite: 0.32, alpha: 1), roughness: 0.6)
        let earAndNoseMaterial = skinMaterial
        let mouthMaterial = matteMaterial(NSColor(calibratedRed: 0.72, green: 0.52, blue: 0.52, alpha: 1), roughness: 0.7)
        let airPodsMaterial = matteMaterial(.white, roughness: 0.25)

        for side: CGFloat in [-1, 1] {
            let eye = SCNSphere(radius: 0.09)
            eye.segmentCount = 16
            eye.materials = [eyeMaterial]
            let eyeNode = SCNNode(geometry: eye)
            eyeNode.scale = SCNVector3(1.4, 0.5, 0.5)
            eyeNode.position = SCNVector3(side * 0.28, 0.1, 0.82)
            headGroup.addChildNode(eyeNode)

            let ear = SCNSphere(radius: 0.14)
            ear.materials = [earAndNoseMaterial]
            let earNode = SCNNode(geometry: ear)
            earNode.scale = SCNVector3(0.5, 1.0, 0.8)
            earNode.position = SCNVector3(side * 0.78, -0.05, 0.05)
            headGroup.addChildNode(earNode)

            let bud = SCNSphere(radius: 0.075)
            bud.materials = [airPodsMaterial]
            let budNode = SCNNode(geometry: bud)
            budNode.position = SCNVector3(side * 0.86, -0.02, 0.12)
            headGroup.addChildNode(budNode)

            let stem = SCNCapsule(capRadius: 0.028, height: 0.42)
            stem.materials = [airPodsMaterial]
            let stemNode = SCNNode(geometry: stem)
            stemNode.position = SCNVector3(side * 0.9, -0.32, 0.17)
            stemNode.eulerAngles.z = side * (.pi / 11)
            headGroup.addChildNode(stemNode)
        }

        let nose = SCNCone(topRadius: 0.02, bottomRadius: 0.1, height: 0.26)
        nose.materials = [earAndNoseMaterial]
        let noseNode = SCNNode(geometry: nose)
        noseNode.eulerAngles.x = .pi / 2.3
        noseNode.position = SCNVector3(0, -0.12, 0.92)
        headGroup.addChildNode(noseNode)

        let mouth = SCNBox(width: 0.34, height: 0.06, length: 0.05, chamferRadius: 0.03)
        mouth.materials = [mouthMaterial]
        let mouthNode = SCNNode(geometry: mouth)
        mouthNode.position = SCNVector3(0, -0.42, 0.82)
        headGroup.addChildNode(mouthNode)

        let cameraNode = SCNNode()
        cameraNode.camera = {
            let camera = SCNCamera()
            camera.fieldOfView = 32
            return camera
        }()
        cameraNode.position = SCNVector3(0, 0.1, 4.4)
        scene.rootNode.addChildNode(cameraNode)

        let keyLightNode = SCNNode()
        keyLightNode.light = {
            let light = SCNLight()
            light.type = .directional
            light.intensity = 900
            light.color = NSColor.white
            return light
        }()
        keyLightNode.eulerAngles = SCNVector3(-CGFloat.pi / 4, CGFloat.pi / 6, 0)
        scene.rootNode.addChildNode(keyLightNode)

        let ambientLightNode = SCNNode()
        ambientLightNode.light = {
            let light = SCNLight()
            light.type = .ambient
            light.intensity = 400
            light.color = NSColor(calibratedWhite: 0.65, alpha: 1)
            return light
        }()
        scene.rootNode.addChildNode(ambientLightNode)

        return scene
    }
}
