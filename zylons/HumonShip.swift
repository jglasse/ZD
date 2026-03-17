//
//  HumonShip.swift
//  Zylon Defenders
//
//  Created by Jeff Glasse on 6/18/17.
//  Copyright © 2023 Jeffery Glasse. All rights reserved.
//

import Foundation
import SceneKit
import UIKit

enum ShipType: Int {
    case scout
    case fighter
    case destroyer
}

class HumonShip: SectorObject {

    enum ManeuverType {
        case zig
        case zag
        case fullstop
    }

    var shiptype: ShipType = .scout
	var currentSpeed = 0.0
	var shieldStrength = 100
	var weaponType = 0
    var currentManeuverType: ManeuverType = .fullstop

    var inCurrentManeuver  = false
    var cyclesUntilNextImpulseTurn = 1
    var speedVector =  vector3(0.0, 0.0, 0.0)
    var targetspeedVector = vector3(0.0, 0.0, 1.0)

    var currentlyShooting = false
    var cyclesUntilFireTorpedo: Float = 130.0

	var zylonTargetPosition = vector3(0.0, 0.0, 0.0)

	var range = [Float]()

    func fireTorpedo() {
        let torpedoNode = Torpedo(designatedTorpType: .humon)
        guard let parentNode = self.parent else {
            print("attempted to add torpedo to parent but there's no parent!")
            fatalError()
        }
        let driftAmount: Float = 2
        let forceAmount: Float = 175
        parentNode.addChildNode(torpedoNode)
        torpedoNode.worldPosition = self.worldPosition
        torpedoNode.physicsBody?.applyForce(SCNVector3Make(-driftAmount, 1.7, forceAmount), asImpulse: true)

    }
    func maneuver() {

        // MOVE SHIP LOGIC
        // if not currently maneuvering, begin executing maneuver. When maneuver is complete, create new maneuver with a random duration between minManeuverInterval and maxManeuverInterval
        if currentManeuverType == .fullstop {
         let maneuverDuration = TimeInterval(randRange(lower: 1, upper: 4))
         var currentManeuver: SCNAction
         let yDelta: Float = randRange(lower: -30, upper: 30)
         var xDelta: Float
         var zDelta: Float = 0
        if self.worldPosition.z  < -20 {
//            print("maneuvering! ship: \(self.description) worldposition: \(self.worldPosition)")
          zDelta = randRange(lower: 5, upper: 10)
            } else {
            zDelta = randRange(lower: -25, upper: -10)
            }
         xDelta = 0
         if self.worldPosition.x < 0 {
            self.currentManeuverType = .zig
            xDelta = randRange(lower: 20, upper: 40)
         } else {
            self.currentManeuverType = .zag
            xDelta = randRange(lower: -40, upper: -20)

        }
            let fullStop = { () -> Void in
                self.currentManeuverType = .fullstop
                self.inCurrentManeuver = false
            }
            let targetWorldVector = SCNVector3(x: self.worldPosition.x+xDelta, y: self.worldPosition.y+yDelta, z: self.worldPosition.z+zDelta)
            let targetObjectsNodeVector = self.parent?.convertPosition(targetWorldVector, from: self.parent?.parent)

            currentManeuver = SCNAction.move(to: targetObjectsNodeVector!, duration: maneuverDuration)
            self.inCurrentManeuver = true
            currentManeuver.timingMode = .easeInEaseOut
            self.runAction(currentManeuver, completionHandler: fullStop)

        }

        // FIRE TORPEDO LOGIC
        // if I'm not currently counting down to fire, start a new counter, with a random value between minShootInterval and maxShootInterval
        if cyclesUntilFireTorpedo  == 0 {
            self.fireTorpedo()
            cyclesUntilFireTorpedo = randRange(lower: Constants.minHumanShootInterval, upper: Constants.maxHumanShootInterval)
        } else {
            cyclesUntilFireTorpedo  -= 1
        }

    }

    init(shipType: ShipType) {
        super.init()
        let humonshipScene: SCNScene!
        self.sectorObjectType = .humonShip //
        self.shiptype = shipType
        switch shipType {
        case .scout:
            print("ship type: Scout")
            humonshipScene = SCNScene(named: "HumonScout.scn")
        case .fighter:
            print("ship type: Fighter (but really Scout)")
            // humonshipScene = SCNScene(named: "HumonFighter.scn")
            humonshipScene = SCNScene(named: "HumonScout.scn")

        case .destroyer:
            print("ship type: Destroyer")
            humonshipScene = SCNScene(named: "HumonHunter.scn")

        }
        let humonShip = humonshipScene?.rootNode.childNodes[0]
        let droneShape = SCNBox(width: 10, height: 5, length: 5, chamferRadius: 0)
        let dronePhysicsShape = SCNPhysicsShape(geometry: droneShape, options: nil)
        self.addChildNode(humonShip!)
        if shipType == .destroyer {
            if let ballRot = humonShip?.childNode(withName: "BallRot", recursively: true) {
                let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y:0, z:  CGFloat.pi * 2, duration: 3.0))
                ballRot.runAction(spin)
            }
            // Animate the BaseStar emission between green and blue to make the orbs glow
            if let baseStar = humonShip?.childNode(withName: "BallRot", recursively: true),
               let originalMaterial = baseStar.geometry?.materials.first {
                let orbMaterial = originalMaterial.copy() as! SCNMaterial
                orbMaterial.emission.contents = UIColor.green
                baseStar.geometry?.materials = [orbMaterial]

                let glowToBlue = SCNAction.customAction(duration: 1.5) { _, elapsed in
                    let t = CGFloat(elapsed / 1.5)
                    orbMaterial.emission.contents = UIColor(red: 0, green: 1.0 - t, blue: t, alpha: 1)
                }
                let glowToGreen = SCNAction.customAction(duration: 1.5) { _, elapsed in
                    let t = CGFloat(elapsed / 1.5)
                    orbMaterial.emission.contents = UIColor(red: 0, green: t, blue: 1.0 - t, alpha: 1)
                }
                baseStar.runAction(.repeatForever(.sequence([glowToBlue, glowToGreen])))
            }
        }
        self.physicsBody = SCNPhysicsBody(type: .kinematic, shape: dronePhysicsShape)
        self.physicsBody?.isAffectedByGravity = false
        self.physicsBody?.friction = 0
        self.physicsBody?.categoryBitMask = ObjectCategories.enemyShip
        self.physicsBody?.contactTestBitMask = ObjectCategories.zylonFire
        self.name = "humonShip"
        self.worldOrientation = SCNVector4(0, 0, 1, Float.pi)
        self.pivot = SCNMatrix4MakeTranslation(0.5, 0.5, 0.5)
        self.worldPosition = SCNVector3Make(randRange(lower: -10, upper: 10), randRange(lower: -12, upper: 12), randRange(lower: -90, upper: -60))
        self.scale = SCNVector3Make(1, 1, 1)
        self.cyclesUntilFireTorpedo = randRange(lower: 30, upper: 340)

    }

   override init() {
          super.init()
          self.sectorObjectType = .humonShip //
          let humonshipScene = SCNScene(named: "HumonScout.scn")
          let humonShip = humonshipScene?.rootNode.childNodes[0]
          let droneShape = SCNBox(width: 10, height: 5, length: 5, chamferRadius: 0)
          let dronePhysicsShape = SCNPhysicsShape(geometry: droneShape, options: nil)
          self.addChildNode(humonShip!)
          self.physicsBody = SCNPhysicsBody(type: .kinematic, shape: dronePhysicsShape)
          self.physicsBody?.isAffectedByGravity = false
          self.physicsBody?.friction = 0
          self.physicsBody?.categoryBitMask = ObjectCategories.enemyShip
          self.physicsBody?.contactTestBitMask = ObjectCategories.zylonFire
          self.name = "humonShip"
          self.worldOrientation = SCNVector4(0, 0, 1, Float.pi)
          self.pivot = SCNMatrix4MakeTranslation(0.5, 0.5, 0.5)
          self.worldPosition = SCNVector3Make(randRange(lower: -10, upper: 10), randRange(lower: -12, upper: 12), randRange(lower: -80, upper: -60))
          self.scale = SCNVector3Make(1, 1, 1)
          self.cyclesUntilFireTorpedo = randRange(lower: 30, upper: 340)

      }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
