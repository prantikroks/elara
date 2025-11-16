import UIKit
import ARKit
import SceneKit

class ARViewController: UIViewController, ARSCNViewDelegate {

  var sceneView: ARSCNView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // 1. Create the AR Scene View
    sceneView = ARSCNView(frame: self.view.frame)
    self.view.addSubview(sceneView)
    
    sceneView.delegate = self
    
    // 2. Create a "Done" button to close the AR view
    let doneButton = UIButton(frame: CGRect(x: 20, y: 60, width: 80, height: 40))
    doneButton.setTitle("Done", for: .normal)
    doneButton.backgroundColor = .black.withAlphaComponent(0.5)
    doneButton.layer.cornerRadius = 10
    doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
    self.view.addSubview(doneButton)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // 1. Configure the AR session for plane detection
    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = .horizontal
    
    // 2. Run the session
    sceneView.session.run(configuration)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Pause the session when the view is closed
    sceneView.session.pause()
  }
  
  // This is called when a flat surface (like a desk) is detected
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    // --- FIX IS HERE ---
    // We must cast to ARPlaneAnchor to get its 'center' property.
    guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
    
    // Once a plane is found, add our 3D pet
    // We only want to do this *once* (0 children in the root node)
    if sceneView.scene.rootNode.childNodes.isEmpty {
      DispatchQueue.main.async {
        // Pass the correctly-typed 'planeAnchor'
        self.placePet(at: planeAnchor)
      }
    }
  }
  
  // --- FIX IS HERE ---
  // Changed function to accept 'ARPlaneAnchor'
  func placePet(at anchor: ARPlaneAnchor) {
    // --- THIS IS WHERE YOU LOAD YOUR "pet.usdz" MODEL ---
    // For now, we will create a simple 3D box as a placeholder.
    
    let box = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0.01)
    let material = SCNMaterial()
    material.diffuse.contents = UIColor(red: 0.66, green: 0.82, blue: 0.94, alpha: 1) // Serene Blue
    box.materials = [material]
    
    let node = SCNNode(geometry: box)
    
    // This code now works because 'anchor' is an ARPlaneAnchor
    node.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
    
    // Add the 3D node to the scene
    sceneView.scene.rootNode.addChildNode(node)
    
    // TODO: Replace the box with:
    // let petScene = SCNScene(named: "art.scnassets/pet.usdz")!
    // let petNode = petScene.rootNode.childNodes.first!
    // petNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
    // sceneView.scene.rootNode.addChildNode(petNode)
  }

  @objc func doneButtonTapped() {
    // Dismiss this native view and return to Flutter
    self.dismiss(animated: true, completion: nil)
  }
}