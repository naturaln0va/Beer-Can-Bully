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
  
  // Audio sources
  lazy var whooshAudioSource: SCNAudioSource = {
    let source = SCNAudioSource(fileNamed: "sounds/whoosh.aiff")!
    
    source.positional = false
    source.volume = 0.15
    
    return source
  }()
  lazy var ballCanAudioSource: SCNAudioSource = {
    let source = SCNAudioSource(fileNamed: "sounds/ball_can.aiff")!
    
    source.positional = true
    source.volume = 0.6
    
    return source
  }()
  lazy var ballFloorAudioSource: SCNAudioSource = {
    let source = SCNAudioSource(fileNamed: "sounds/ball_floor.aiff")!
    
    source.positional = true
    source.volume = 0.6
    
    return source
  }()
  lazy var canFloorAudioSource: SCNAudioSource = {
    let source = SCNAudioSource(fileNamed: "sounds/can_floor.aiff")!
    
    source.positional = true
    source.volume = 0.6
    
    return source
  }()
  
  var scnView: SCNView {
    let scnView = view as! SCNView
    
    if scnView.scene == nil {
      scnView.scene = menuScene
    }
    
    scnView.backgroundColor = UIColor.blackColor()
    
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
  
  var isThrowing: Bool {
    return startTouch != nil
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
  let ballCanCollisionAudioKey = "ball_hit_can"
  let ballFloorCollisionAudioKey = "ball_hit_floor"
  
  var currentLevel = 0
  var levels = [GameLevel]()
  var state = GameStateType.TapToPlay
  
  var canNodes = [SCNNode]()
  var ballNodes = [SCNNode]()
  var bashedCanNames = [String]()
  
  // Ball throwing mechanics
  var startTouchTime: NSTimeInterval!
  var endTouchTime: NSTimeInterval!
  var startTouch: UITouch?
  var endTouch: UITouch?
  
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
    loadAudio()
    createScene()
    createHud()
  }
  
  // MARK: - Helpers
  
  func loadAudio() {
    let sources = [
      whooshAudioSource,
      ballCanAudioSource,
      ballFloorAudioSource, 
      canFloorAudioSource
    ]
    
    for source in sources {
      source.load()
    }
  }
  
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
    ballPhysicsBody.contactTestBitMask = 1
    ballNode.physicsBody = ballPhysicsBody
    ballNode.physicsBody?.applyForce(SCNVector3(x: 0.8, y: 0, z: 0), impulse: true)
    
    // Keep track of the current ball
    currentBallNode = ballNode
    levelScene.rootNode.addChildNode(ballNode)
  }
  
  func throwBall() {
    guard let ballNode = currentBallNode else { return }
    guard let sceneKitView = view as? SCNView else { return }
    guard let endingTouch = endTouch else { return }
    
    let firstTouchResult = sceneKitView.hitTest(
      endingTouch.locationInView(view),
      options: nil
    ).filter({
      $0.node == touchCatchingPlaneNode
    }).first
    
    guard let touchResult = firstTouchResult else { return }
    
    levelScene.rootNode.runAction(SCNAction.playAudioSource(whooshAudioSource, waitForCompletion: false))
    
    // Calculate the velocity of the flick
    let timeDifference = endTouchTime - startTouchTime
    let velocityComponent = Float(min(max(1 - timeDifference, 0.1), 1.0))
    
    // Create the impulse to push the ball
    let impulseVector = SCNVector3(
      x: touchResult.localCoordinates.x,
      y: touchResult.localCoordinates.y * velocityComponent * 3,
      z: canShelfNode.position.z * velocityComponent * 15
    )
    
    ballNode.physicsBody?.applyForce(impulseVector, impulse: true)
    ballNodes.append(ballNode)
    
    currentBallNode = nil
    startTouchTime = nil
    endTouchTime = nil
    startTouch = nil
    endTouch = nil
    
    refreshLabel()
    
    if ballNodes.count == maxBallNodes {
      // Wait a little to see if the last throw completed the level
      let waitAction = SCNAction.waitForDuration(3)
      let blockAction = SCNAction.runBlock({ _ in
        self.resetLevel()
        self.ballNodes.removeAll()
        self.currentLevel = 0
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
    super.touchesBegan(touches, withEvent: event)
    if state == .TapToPlay {
      loadLevel()
    }
    else {
      guard let firstTouch = touches.first else { return }
      
      // Location of the touch in the view
      let point = firstTouch.locationInView(scnView)
      let hitResults = scnView.hitTest(point, options: nil)

      // If the touch is on the ball then hold onto that touch
      if let ball = hitResults.first?.node where ball == currentBallNode {
        startTouch = touches.first
        startTouchTime = NSDate().timeIntervalSince1970
      }
    }
  }
  
  override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
    super.touchesEnded(touches, withEvent: event)
    guard isThrowing else { return }
    
    endTouch = touches.first
    endTouchTime = NSDate().timeIntervalSince1970
    throwBall()
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
    
    // Check if the ball collided with the floor
    var ballFloorContactNode: SCNNode?
    if nodeNameA == "ball" && nodeNameB == "floor" {
      ballFloorContactNode = contact.nodeA
    } else if nodeNameB == "ball" && nodeNameA == "floor" {
      ballFloorContactNode = contact.nodeB
    }
    
    if let ballNode = ballFloorContactNode {
      // Limit the number of ball floor collision sounds
      guard ballNode.actionForKey(ballFloorCollisionAudioKey) == nil else { return }
      
      ballNode.runAction(
        SCNAction.playAudioSource(ballFloorAudioSource, waitForCompletion: true),
        forKey: ballFloorCollisionAudioKey
      )
      return
    }
    
    // Check if the ball collided with a can
    var ballCanContactNode: SCNNode?
    if nodeNameA.containsString("Can") && nodeNameB == "ball" {
      ballCanContactNode = contact.nodeA
    } else if nodeNameB.containsString("Can") && nodeNameA == "ball" {
      ballCanContactNode = contact.nodeB
    }
    
    if let canNode = ballCanContactNode {
      // Limit the number of ball can collision sounds
      guard canNode.actionForKey(ballCanCollisionAudioKey) == nil else { return }
      
      canNode.runAction(
        SCNAction.playAudioSource(ballCanAudioSource, waitForCompletion: true),
        forKey: ballCanCollisionAudioKey
      )
      return
    }
    
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
      bashedCan.runAction(SCNAction.playAudioSource(canFloorAudioSource, waitForCompletion: false))
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
