//
//  GameViewController.swift
//  Beer Can Bully
//
//  Created by Ryan Ackermann on 6/4/16.
//  Copyright (c) 2016 Ryan Ackermann. All rights reserved.
//

import UIKit
import SceneKit

class GameViewController: UIViewController {
    
    let touchCatchingPlaneNode: SCNNode = {
        let node = SCNNode(geometry: SCNPlane(width: 40, height: 40))
        node.opacity = 0.001
        node.castsShadow = false
        return node
    }()
    
    var bashedCans = 0
    var bashedCanNames = [String]()
    var currentLevel = 1
    var canNodes = [SCNNode]()
    var mainCameraNode: SCNNode!
    var ballNode: SCNNode!
    var tableTopNode: SCNNode!
    
    var firstTouchTime: NSTimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createScene()
        resetCans()
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesEnded(touches, withEvent: event)
        
        ballNode.physicsBody = nil
        firstTouchTime = NSDate().timeIntervalSince1970
        
        guard let firstTouch = touches.first else { return }
        positionBallFromTouch(firstTouch)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesMoved(touches, withEvent: event)
        
        guard let firstTouch = touches.first else { return }
        positionBallFromTouch(firstTouch)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesEnded(touches, withEvent: event)
        
        let ballPhysicsBody = SCNPhysicsBody(
            type: .Dynamic,
            shape: SCNPhysicsShape(geometry: SCNSphere(radius: 0.25), options: nil)
        )
        ballPhysicsBody.mass = 3
        ballNode.physicsBody = ballPhysicsBody
        
        let timeDiff = Float(NSDate().timeIntervalSince1970 - firstTouchTime)
        
        let impulseVector = SCNVector3(x: 0, y: 1/(timeDiff * Float(M_PI)), z: -3 / timeDiff)
        ballNode.physicsBody?.applyForce(impulseVector, impulse: true)
        
        firstTouchTime = 0
    }
    
    // MARK: - Helpers
    
    func resetCans() {
        guard let scnView = view as? SCNView, levelScene = scnView.scene else { return }
        
        for canNode in canNodes {
            canNode.removeFromParentNode()
        }
        canNodes.removeAll()
        
        for idx in 0..<3 {
            let canShape = SCNCylinder(radius: 0.15, height: 0.45)
            let canNode = SCNNode(geometry: canShape)
            canNode.name = "Can #\(idx)"
            
            let canPhysicsBody = SCNPhysicsBody(
                type: .Dynamic,
                shape: SCNPhysicsShape(geometry: canShape, options: nil)
            )
            canPhysicsBody.mass = 0.75
            canPhysicsBody.contactTestBitMask = 1
            canNode.physicsBody = canPhysicsBody
            
            let xOffset = 1.125 + tableTopNode.position.x - (Float(idx) * 1.125)
            canNode.position = SCNVector3(x: xOffset, y: tableTopNode.position.y + 0.5, z: 2)
            levelScene.rootNode.addChildNode(canNode)
            
            canNodes.append(canNode)
        }
    }
    
    func createScene() {
        let levelScene = SCNScene(named: "resources.scnassets/Level.scn")!
        levelScene.physicsWorld.contactDelegate = self
        mainCameraNode = levelScene.rootNode.childNodeWithName("Main Camera", recursively: true)!
        
        ballNode = levelScene.rootNode.childNodeWithName("Ball reference", recursively: true)!
        levelScene.rootNode.addChildNode(touchCatchingPlaneNode)
        touchCatchingPlaneNode.position = SCNVector3(x: 0, y: 0, z: ballNode.position.z)
        touchCatchingPlaneNode.eulerAngles = mainCameraNode.eulerAngles
        
        let table = levelScene.rootNode.childNodeWithName("Table", recursively: true)!
        tableTopNode = table.childNodeWithName("Top", recursively: true)!
        let tableTopPhysicsShape = SCNPhysicsShape(node: tableTopNode, options: [SCNPhysicsShapeTypeKey: SCNPhysicsShapeTypeBoundingBox])
        let tableTopPhysicsBody = SCNPhysicsBody(type: .Static, shape: tableTopPhysicsShape)
        tableTopPhysicsBody.affectedByGravity = false
        tableTopNode.physicsBody = tableTopPhysicsBody
        
        let scnView = view as! SCNView
        scnView.scene = levelScene
        scnView.backgroundColor = UIColor.blackColor()
    }
    
    func positionBallFromTouch(touch: UITouch) {
        guard let sceneKitView = view as? SCNView else { return }
        let hitTestResult = sceneKitView.hitTest(touch.locationInView(view), options: nil)
        guard let touchResult = hitTestResult.filter({ $0.node == touchCatchingPlaneNode }).first else {
            return
        }
        
        ballNode.position = SCNVector3(
            touchResult.localCoordinates.x,
            touchResult.localCoordinates.y,
            7.0
        )
    }
    
    // MARK: - ViewController Overrides
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIDevice.currentDevice().userInterfaceIdiom == .Phone ? .Portrait : .All
    }

}

// MARK: SCNPhysicsContactDelegate

extension GameViewController: SCNPhysicsContactDelegate {
    
    func physicsWorld(world: SCNPhysicsWorld, didBeginContact contact: SCNPhysicsContact) {
        guard let nodeNameA = contact.nodeA.name, let nodeNameB = contact.nodeB.name else { return }
        if bashedCanNames.contains(nodeNameA) || bashedCanNames.contains(nodeNameB) { return }
        print("Node A: \(contact.nodeA.name). Node B: \(contact.nodeB.name)")
        
        var canNodeWithContact: SCNNode?
        if nodeNameA.containsString("Can") && nodeNameB == "Floor" {
            canNodeWithContact = contact.nodeA
        }
        else if nodeNameB.containsString("Can") && nodeNameA == "Floor" {
            canNodeWithContact = contact.nodeB
        }
        
        if let bashedCan = canNodeWithContact {
            bashedCanNames.append(bashedCan.name!)
            bashedCans += 1
        }
        
        if bashedCans == canNodes.count {
            resetCans()
            bashedCans = 0
            bashedCanNames.removeAll()
        }
    }
    
}
