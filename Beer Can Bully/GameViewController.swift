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
import SpriteKit

class GameViewController: UIViewController {
  
  // Defaults key for persisting the highscore
  static let kHighscoreKey = "highscore"
  
  // Node that intercept touches in the scene
  lazy var touchCatchingPlaneNode: SCNNode = {
    let node = SCNNode(geometry: SCNPlane(width: 40, height: 40))
    node.opacity = 0.001
    node.castsShadow = false
    return node
  }()
  // Gesture to calculate the velocity of a swipe
  lazy var velocityRecognizer: UIPanGestureRecognizer = {
    return UIPanGestureRecognizer(
      target: self,
      action: #selector(GameViewController.handlePan(_:))
    )
  }()
  
  var scnView: SCNView {
    let scnView = view as! SCNView
    
    if scnView.scene == nil {
      scnView.scene = menuScene
    }
    
    scnView.backgroundColor = UIColor.blackColor()
    scnView.addGestureRecognizer(self.velocityRecognizer)
    
    return scnView
  }
  
  var score = 0 {
    didSet {
      if score > highScore {
        highScore = score
      }
      refreshLabel()
    }
  }
  var highScore: Int {
    get {
      return NSUserDefaults.standardUserDefaults().integerForKey(GameViewController.kHighscoreKey)
    }
    set {
      NSUserDefaults.standardUserDefaults().setInteger(newValue, forKey: GameViewController.kHighscoreKey)
      NSUserDefaults.standardUserDefaults().synchronize()
    }
  }
  
  // Game state
  enum GameStateType {
    case TapToPlay
    case Playing
  }
  
  // Information about a level
  struct GameLevel {
    let canPositions: [SCNVector3]
  }
  
  // Maximum number of ball attempts
  let maxBallNodes = 5
  let gameEndActionKey = "game_end"
  
  var currentLevel = 0
  var levels = [GameLevel]()
  var state = GameStateType.TapToPlay
  
  var canNodes = [SCNNode]()
  var ballNodes = [SCNNode]()
  var bashedCanNames = [String]()
  
  // Scene references
  var menuScene = SCNScene(named: "resources.scnassets/Menu.scn")!
  var levelScene = SCNScene(named: "resources.scnassets/Level.scn")!
  
  // Node references
  var currentBallNode: SCNNode?
  var mainCameraNode: SCNNode!
  var ballShelfNode: SCNNode!
  var canShelfNode: SCNNode!
  var hudNode: SCNNode!
  var labelNode: SKLabelNode!
  var baseBallNode: SCNNode!
  var baseCanNode: SCNNode!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    loadMenu()
    createScene()
    createHud()
  }
  
  // MARK: - Helpers
  
  func loadMenu() {
    let scoreNode = menuScene.rootNode.childNodeWithName("score", recursively: true)!
    
    if let text = scoreNode.geometry as? SCNText {
      text.string = "Highscore: \(highScore)"
    }
    
    state = .TapToPlay
    
    levelScene.paused = true
    let transition = SKTransition.crossFadeWithDuration(1.0)
    scnView.presentScene(
      menuScene,
      withTransition: transition,
      incomingPointOfView: nil,
      completionHandler: {
        self.menuScene.paused = false
      }
    )
  }
  
  func loadLevel() {
    resetLevel()
    setupNextLevel()
    refreshLabel()
    
    state = .Playing
    
    menuScene.paused = true
    let transition = SKTransition.crossFadeWithDuration(1.0)
    scnView.presentScene(
      levelScene,
      withTransition: transition,
      incomingPointOfView: nil,
      completionHandler: {
        self.levelScene.paused = false
      }
    )
  }
  
  func createLevelsFromBaseNode(node: SCNNode) {
    // Level 1
    let levelOneCanOne = SCNVector3(
      x: node.position.x - 0.5,
      y: node.position.y + 0.62,
      z: node.position.z
    )
    let levelOneCanTwo = SCNVector3(
      x: node.position.x + 0.5,
      y: node.position.y + 0.62,
      z: node.position.z
    )
    let levelOneCanThree = SCNVector3(
      x: node.position.x,
      y: node.position.y + 1.75,
      z: node.position.z
    )
    let levelOne = GameLevel(
      canPositions: [
        levelOneCanOne,
        levelOneCanTwo,
        levelOneCanThree
      ]
    )
    
    // Level 2
    let levelTwoCanOne = SCNVector3(
      x: node.position.x - 0.65,
      y: node.position.y + 0.62,
      z: node.position.z
    )
    let levelTwoCanTwo = SCNVector3(
      x: node.position.x - 0.65,
      y: node.position.y + 1.75,
      z: node.position.z
    )
    let levelTwoCanThree = SCNVector3(
      x: node.position.x + 0.65,
      y: node.position.y + 0.62,
      z: node.position.z
    )
    let levelTwoCanFour = SCNVector3(
      x: node.position.x + 0.65,
      y: node.position.y + 1.75,
      z: node.position.z
    )
    let levelTwo = GameLevel(
      canPositions: [
        levelTwoCanOne,
        levelTwoCanTwo,
        levelTwoCanThree,
        levelTwoCanFour
      ]
    )
    
    levels = [levelOne, levelTwo]
  }
  
  func resetLevel() {
    // Remove the current ball if needed
    currentBallNode?.removeFromParentNode()
    
    // Remove all the bashed cans
    bashedCanNames.removeAll()
    
    // Remove the can nodes and clear the reference array
    for canNode in canNodes {
      canNode.removeFromParentNode()
    }
    canNodes.removeAll()
    
    // Remove the ball nodes from the scene
    for ballNode in ballNodes {
      ballNode.removeFromParentNode()
    }
    
    refreshLabel()
  }
  
  func setupNextLevel() {
    // Give player a ball if they complete a level
    if ballNodes.count > 0 {
      ballNodes.removeLast()
    }
    
    // Position the cans based on the level model
    let level = levels[currentLevel]
    for idx in 0..<level.canPositions.count {
      let canNode = baseCanNode.flattenedClone()
      // Randomly rotate the can
      canNode.eulerAngles = SCNVector3(
        x: 0,
        y: GKRandomSource.sharedRandom().nextUniform(),
        z: 0
      )
      // Give the can a unique name
      canNode.name = "Can #\(idx)"
      
      let canPhysicsBody = SCNPhysicsBody(
        type: .Dynamic,
        shape: SCNPhysicsShape(geometry: SCNCylinder(radius: 0.33, height: 1.125), options: nil)
      )
      canPhysicsBody.mass = 0.75
      canPhysicsBody.contactTestBitMask = 1
      canNode.physicsBody = canPhysicsBody
      // Position the can based on the level
      canNode.position = level.canPositions[idx]
      
      levelScene.rootNode.addChildNode(canNode)
      canNodes.append(canNode)
    }
    
    // Delay the ball creation on level change
    let waitAction = SCNAction.waitForDuration(1.0)
    let blockAction = SCNAction.runBlock({ _ in
      self.dispenseNewBall()
      self.refreshLabel()
    })
    let sequenceAction = SCNAction.sequence([waitAction, blockAction])
    levelScene.rootNode.runAction(sequenceAction)
  }
  
  // MARK: - Creation
  
  func createHud() {
    // Create a HUD label node in SpriteKit
    let skScene = SKScene(size: CGSize(width: view.frame.width, height: 100))
    skScene.backgroundColor = UIColor(white: 0.0, alpha: 0.0)
    
    labelNode = SKLabelNode(fontNamed: "Menlo-Bold")
    labelNode.fontSize = 35
    labelNode.position.y = 50
    labelNode.position.x = view.frame.width / 2
    
    skScene.addChild(labelNode)
    
    // Add the SKScene to a plane node
    let plane = SCNPlane(width: 5, height: 1)
    let material = SCNMaterial()
    material.lightingModelName = SCNLightingModelConstant
    material.doubleSided = true
    material.diffuse.contents = skScene
    plane.materials = [material]
    
    // Add the hud to the level
    hudNode = SCNNode(geometry: plane)
    hudNode.name = "hud"
    hudNode.position = SCNVector3(x: 0.0, y: 6.0, z: -4.5)
    hudNode.rotation = SCNVector4(x: 1, y: 0, z: 0, w: Float(M_PI))
    levelScene.rootNode.addChildNode(hudNode)
  }
  
  func createScene() {
    levelScene.physicsWorld.contactDelegate = self
    
    // Store references to the nodes from the scene
    mainCameraNode = levelScene.rootNode.childNodeWithName("main-camera", recursively: true)!
    baseBallNode = levelScene.rootNode.childNodeWithName("ball", recursively: true)!
    canShelfNode = levelScene.rootNode.childNodeWithName("can-shelf", recursively: true)!
    
    // Load the base can node from it's scene
    guard let canScene = SCNScene(named: "resources.scnassets/Can.scn") else { return }
    baseCanNode = canScene.rootNode.childNodeWithName("can", recursively: true)!
    
    // Define the physics body of the shelf
    let canShelfPhysicsBody = SCNPhysicsBody(
      type: .Static,
      shape: SCNPhysicsShape(geometry: canShelfNode.geometry!, options: nil)
    )
    canShelfPhysicsBody.affectedByGravity = false
    canShelfNode.physicsBody = canShelfPhysicsBody
    
    // Create levels based on the shelf node
    createLevelsFromBaseNode(canShelfNode)
    
    // Add a node to handle touches
    levelScene.rootNode.addChildNode(touchCatchingPlaneNode)
    touchCatchingPlaneNode.position = SCNVector3(x: 0, y: 0, z: canShelfNode.position.z)
    touchCatchingPlaneNode.eulerAngles = mainCameraNode.eulerAngles
  }
  
  // MARK: - Helpers
  
  func refreshLabel() {
    guard let labelNode = labelNode else { return }
    labelNode.text = "⚾️: \(maxBallNodes - ballNodes.count) | 🍺: \(score)"
  }
  
  func dispenseNewBall() {
    // Clone the ball node from the scene
    let ballNode = baseBallNode.flattenedClone()
    let ballPhysicsBody = SCNPhysicsBody(
      type: .Dynamic,
      shape: SCNPhysicsShape(geometry: SCNSphere(radius: 0.25), options: nil)
    )
    ballPhysicsBody.mass = 3
    ballPhysicsBody.friction = 2
    ballNode.physicsBody = ballPhysicsBody
    ballNode.physicsBody?.applyForce(SCNVector3(x: 1.75, y: 0, z: 0), impulse: true)
    
    // Keep track of the current ball
    currentBallNode = ballNode
    levelScene.rootNode.addChildNode(ballNode)
  }
  
  func handlePan(gesture: UIPanGestureRecognizer) {
    guard gesture.state == .Ended else { return }
    
    guard let ballNode = currentBallNode else { return }
    guard let sceneKitView = view as? SCNView else { return }
    
    let hitTestResult = sceneKitView.hitTest(
      gesture.locationInView(view),
      options: nil
    )
    
    // Get the touch catching node
    let firstTouchResult = hitTestResult.filter({
      $0.node == touchCatchingPlaneNode
    }).first
    
    guard let touchResult = firstTouchResult else { return }
    
    // Calculate the velocity of the flick
    let velocity = gesture.velocityInView(gesture.view)
    let forwardVelocity = Float(min(max(abs(velocity.y), 900) / 1500, 1.0))
    
    // Create the impulse to push the ball
    let impulseVector = SCNVector3(
      x: touchResult.localCoordinates.x,
      y: touchResult.localCoordinates.y * (forwardVelocity * 2.5),
      z: canShelfNode.position.z * (forwardVelocity * 6)
    )
    
    ballNode.physicsBody?.applyForce(impulseVector, impulse: true)
    ballNodes.append(ballNode)
    currentBallNode = nil
    refreshLabel()
    
    if ballNodes.count == maxBallNodes {
      // Wait a little to see if the last throw completed the level
      let waitAction = SCNAction.waitForDuration(3)
      let blockAction = SCNAction.runBlock({ _ in
        self.resetLevel()
        self.ballNodes.removeAll()
        self.score = 0
        self.refreshLabel()
        self.loadMenu()
      })
      let sequenceAction = SCNAction.sequence([waitAction, blockAction])
      levelScene.rootNode.runAction(sequenceAction, forKey: gameEndActionKey)
    } else {
      // Load next ball
      let waitAction = SCNAction.waitForDuration(0.5)
      let blockAction = SCNAction.runBlock({ _ in
        self.dispenseNewBall()
      })
      let sequenceAction = SCNAction.sequence([waitAction, blockAction])
      levelScene.rootNode.runAction(sequenceAction)
    }
  }
  
  // MARK: - Touches
  
  override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
    if state == .TapToPlay {
      loadLevel()
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

extension GameViewController: SCNPhysicsContactDelegate {
  
  // MARK: SCNPhysicsContactDelegate
  
  func physicsWorld(world: SCNPhysicsWorld, didBeginContact contact: SCNPhysicsContact) {
    guard let nodeNameA = contact.nodeA.name else { return }
    guard let nodeNameB = contact.nodeB.name else { return }
    if bashedCanNames.contains(nodeNameA) || bashedCanNames.contains(nodeNameB) { return }
    
    // Attempt to get a reference to a can node
    var canNodeWithContact: SCNNode?
    if nodeNameA.containsString("Can") && nodeNameB == "floor" {
      canNodeWithContact = contact.nodeA
    } else if nodeNameB.containsString("Can") && nodeNameA == "floor" {
      canNodeWithContact = contact.nodeB
    }
    
    // Keep track of the can's name and add to the score
    if let bashedCan = canNodeWithContact {
      bashedCanNames.append(bashedCan.name!)
      score += 1
    }
    
    // Handle the advancement scenario
    if bashedCanNames.count == canNodes.count {
      // If the player is out of balls but completes the level on the last throw
      if levelScene.rootNode.actionForKey(gameEndActionKey) != nil {
        levelScene.rootNode.removeActionForKey(gameEndActionKey)
      }
      
      let maxLevelIndex = levels.count - 1
      
      // Loop the levels
      if currentLevel == maxLevelIndex {
        currentLevel = 0
      } else {
        currentLevel += 1
      }
      
      // Load the next level with a delay
      let waitAction = SCNAction.waitForDuration(1.0)
      let blockAction = SCNAction.runBlock({ _ in
        self.resetLevel()
        self.setupNextLevel()
      })
      let sequenceAction = SCNAction.sequence([waitAction, blockAction])
      levelScene.rootNode.runAction(sequenceAction)
    }
  }
  
}
