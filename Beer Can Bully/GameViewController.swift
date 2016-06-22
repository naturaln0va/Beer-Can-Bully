//
//  GameViewController.swift
//  Beer Can Bully
//
//  Created by Ryan Ackermann on 6/4/16.
//  Copyright (c) 2016 Ryan Ackermann. All rights reserved.
//

import UIKit
import GameplayKit
import SceneKit

class GameViewController: UIViewController {
    
    let touchCatchingPlaneNode: SCNNode = {
        let node = SCNNode(geometry: SCNPlane(width: 40, height: 40))
        node.opacity = 0.001
        node.castsShadow = false
        return node
    }()
    
    lazy var velocityRecognizer: UIPanGestureRecognizer = {
        return UIPanGestureRecognizer(
            target: self,
            action: #selector(GameViewController.handlePan(_:))
        )
    }()
    
    var currentLevel = 0
    var bashedCanNames = [String]()
    
    var canNodes = [SCNNode]()
    var ballNodes = [SCNNode]()
    
    var mainCameraNode: SCNNode!
    var ballNode: SCNNode!
    var ballShelfNode: SCNNode!
    var canShelfNode: SCNNode!
    
    let startingCameraPosition = SCNVector3(x: -10, y: 5.8, z: 2.75)
    let gameplayCameraPosition = SCNVector3(x: 0, y: 1.25, z: 8)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createScene()
        resetCans()
        resetCamera()
    }
    
    // MARK: - Helpers
    
    func resetCamera() {
        mainCameraNode.position = startingCameraPosition
        
        let waitAction = SCNAction.waitForDuration(3.0)
        let moveAction = SCNAction.moveTo(gameplayCameraPosition, duration: 0.6)
        let groupAction = SCNAction.sequence([waitAction, moveAction])
        mainCameraNode.runAction(groupAction)
    }
    
    func resetCans() {
        guard let scnView = view as? SCNView, levelScene = scnView.scene else { return }
        guard let canScene = SCNScene(named: "resources.scnassets/Can.scn") else { return }
        guard let baseCanNode = canScene.rootNode.childNodeWithName("can", recursively: true) else { return }
        
        for canNode in canNodes {
            canNode.removeFromParentNode()
        }
        canNodes.removeAll()
        
        for idx in 0..<3 {
            let canNode = baseCanNode.copy() as! SCNNode
            canNode.eulerAngles = SCNVector3(
                x: 0,
                y: GKRandomSource.sharedRandom().nextUniform(),
                z: 0
            )
            canNode.name = "Can #\(idx)"
            
            let canPhysicsBody = SCNPhysicsBody(
                type: .Dynamic,
                shape: SCNPhysicsShape(geometry: canNode.geometry!, options: nil)
            )
            canPhysicsBody.mass = 0.75
            canPhysicsBody.contactTestBitMask = 1
            canNode.physicsBody = canPhysicsBody
            
            let xOffset = 1.125 + canShelfNode.position.x - (Float(idx) * 1.125)
            canNode.position = SCNVector3(
                x: xOffset,
                y: canShelfNode.position.y + 0.5,
                z: canShelfNode.position.z
            )
            levelScene.rootNode.addChildNode(canNode)
            
            canNodes.append(canNode)
        }
    }
    
    func createScene() {
        let levelScene = SCNScene(named: "resources.scnassets/Level.scn")!
        levelScene.physicsWorld.contactDelegate = self
        mainCameraNode = levelScene.rootNode.childNodeWithName("main-camera", recursively: true)!
        
        ballNode = levelScene.rootNode.childNodeWithName("ball", recursively: true)!
        let ballPhysicsBody = SCNPhysicsBody(
            type: .Dynamic,
            shape: SCNPhysicsShape(geometry: SCNSphere(radius: 0.25), options: nil)
        )
        ballPhysicsBody.mass = 3
        ballPhysicsBody.friction = 2
        ballNode.physicsBody = ballPhysicsBody
        ballNode.physicsBody?.applyForce(SCNVector3(x: 1.85, y: 0, z: 0), impulse: true)
        
        canShelfNode = levelScene.rootNode.childNodeWithName("can-shelf", recursively: true)!
        let canShelfPhysicsBody = SCNPhysicsBody(
            type: .Static,
            shape: SCNPhysicsShape(geometry: canShelfNode.geometry!, options: nil)
        )
        canShelfPhysicsBody.affectedByGravity = false
        canShelfNode.physicsBody = canShelfPhysicsBody
        
        levelScene.rootNode.addChildNode(touchCatchingPlaneNode)
        touchCatchingPlaneNode.position = SCNVector3(x: 0, y: 0, z: canShelfNode.position.z)
        touchCatchingPlaneNode.eulerAngles = mainCameraNode.eulerAngles
        
        let scnView = view as! SCNView
        scnView.scene = levelScene
        scnView.backgroundColor = UIColor.blackColor()
        scnView.addGestureRecognizer(velocityRecognizer)
    }
    
    func positionBallFromTouch(touch: UITouch) {
        guard let sceneKitView = view as? SCNView else { return }
        let hitTestResult = sceneKitView.hitTest(
            touch.locationInView(view),
            options: nil
        )
        let firstTouchResult = hitTestResult.filter({
            $0.node == touchCatchingPlaneNode
        }).first
        guard let touchResult = firstTouchResult else { return }
        
        ballNode.position = SCNVector3(
            touchResult.localCoordinates.x,
            touchResult.localCoordinates.y,
            4.5
        )
    }
    
    func handlePan(gesture: UIPanGestureRecognizer) {
        if gesture.state == .Ended {
            guard let sceneKitView = view as? SCNView else { return }
            
            let hitTestResult = sceneKitView.hitTest(
                gesture.locationInView(view),
                options: nil
            )
            
            let firstTouchResult = hitTestResult.filter({
                $0.node == touchCatchingPlaneNode
            }).first
            
            guard let touchResult = firstTouchResult else { return }
            
            let velocity = gesture.velocityInView(gesture.view)
            let forwardVelocity = Float(min(abs(velocity.y / 3000), 1.0)) * 3
            print("Forward velocity: \(forwardVelocity)")
            
            let impulseVector = SCNVector3(
                x: touchResult.localCoordinates.x,
                y: touchResult.localCoordinates.y * forwardVelocity,
                z: canShelfNode.position.z * forwardVelocity
            )
            
            ballNode.physicsBody?.applyForce(impulseVector, impulse: true)
        }
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
        if nodeNameA.containsString("Can") && nodeNameB == "floor" {
            canNodeWithContact = contact.nodeA
        }
        else if nodeNameB.containsString("Can") && nodeNameA == "floor" {
            canNodeWithContact = contact.nodeB
        }
        
        if let bashedCan = canNodeWithContact {
            bashedCanNames.append(bashedCan.name!)
        }
        
        if bashedCanNames.count == canNodes.count {
            resetCans()
            bashedCanNames.removeAll()
        }
    }
    
}
