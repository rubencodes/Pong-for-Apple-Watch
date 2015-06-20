//
//  InterfaceController.swift
//  Pong WatchKit Extension
//
//  Created by Ruben on 6/13/15.
//  Copyright © 2015 Ruben. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController, AlertControllerDelegate {
    @IBOutlet var scroller : WKInterfacePicker!
    
    @IBOutlet var spacer : WKInterfaceGroup!
    @IBOutlet var paddle : WKInterfaceButton!
    @IBOutlet var enemyPaddle : WKInterfaceButton!
    @IBOutlet var enemySpacer : WKInterfaceGroup!
    let PaddleSpacer = (center : 0.4 as CGFloat, top : 0 as CGFloat, bottom : 0.8 as CGFloat)
    let PaddleHeight = 30 as CGFloat
    
    @IBOutlet var ball   : WKInterfaceButton!
    @IBOutlet var verticalBallSpacer : WKInterfaceGroup!
    @IBOutlet var horizontalBallSpacer : WKInterfaceGroup!
    let CanvasBounds = (top : 0 as CGFloat, left : 0 as CGFloat, bottom : 135 as CGFloat, right : 111 as CGFloat)
    let BallHeight = 10 as CGFloat
    
    var enemyPlayerWaiting : Bool = false
    
    var ballLocation = (x : 0 as CGFloat, y: 0 as CGFloat)
    var playerTurn = Player.A
    var paddlePosition : CGFloat = 0
    var enemyPaddlePosition : CGFloat = 0
    var score = [Player.A : 0, Player.B : 0]
    
    var goalFound : CGFloat? = nil
    
    @IBAction func userDidScroll(value : Int) {
        delay(0) {
            self.paddlePosition = (CGFloat(value)/100)*115
            self.spacer.setHeight(self.paddlePosition)
        }
    }
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
                
        // Configure interface objects here.
        var pickerItems: [WKPickerItem] = []
        for _ in 1...100 {
            pickerItems.append(WKPickerItem())
        }
        self.scroller.setItems(pickerItems)
        
        self.startRound(CGFloat.random(min: 1, max: 3))
        self.startEnemyPlayer()
    }

    func startRound(slope : CGFloat = 3) {
        self.enemyPlayerWaiting = true
        self.startEnemyPlayer()

        moveBallAtSlope(slope) {
            if let slope = self.wasBallHit() {
                //ball was hit
                
                //move ball at new slope
                self.startRound(slope)
            } else {
                //ball was missed, reset ball
                WKInterfaceDevice().playHaptic(WKHapticType.Failure)
                self.resetBoard()
                
                //Player A wins!
                if self.score[Player.A] == 4 && self.playerTurn == Player.B {
                    self.presentAlertControllerWithTitle("Whoops!", message: "Watch wins!", preferredStyle: WKAlertControllerStyle.ActionSheet, actions: [WKAlertAction(title: "Play Again", style: WKAlertActionStyle.Default, handler: {
                        delay(1) {
                            self.score = [Player.A : 0, Player.B : 0]
                            self.startRound(CGFloat.random(min: 1, max: 3))
                        }
                    })])
                }
                //Player B wins!
                else if self.score[Player.B] == 4 && self.playerTurn == Player.A {
                    self.presentAlertControllerWithTitle("Cogratulations!", message: "You win!", preferredStyle: WKAlertControllerStyle.ActionSheet, actions: [WKAlertAction(title: "Play Again", style: WKAlertActionStyle.Default, handler: {
                        delay(1) {
                            self.score = [Player.A : 0, Player.B : 0]
                            self.startRound(CGFloat.random(min: 1, max: 3))
                        }
                    })])
                }
                //Else keep going
                else {
                    if self.playerTurn == Player.A {
                        self.score[Player.B] = self.score[Player.B]! + 1
                        self.presentControllerWithName("AlertController", context: ["delegate" : self, "text" : "Point!\n\(self.score[Player.A]!)-\(self.score[Player.B]!)", "positive" : true])
                    } else {
                        self.score[Player.A] = self.score[Player.A]! + 1
                        self.presentControllerWithName("AlertController", context: ["delegate" : self, "text" : "Ouch!\n\(self.score[Player.A]!)-\(self.score[Player.B]!)", "positive" : false])
                    }
                    self.playerTurn = Player.A
                }
            }
        }
    }
    
    func moveBallAtSlope(slope : CGFloat, completion: (() -> Void)?) {
        //calculate next point
        var nextX = self.playerTurn == Player.A ? CanvasBounds.right : CanvasBounds.left
        var nextY = ballLocation.y - slope*(ballLocation.x - nextX)
        
        //guard against sides
        if nextY > CanvasBounds.bottom || nextY < CanvasBounds.top {
            nextY = nextY > CanvasBounds.bottom ? CanvasBounds.bottom : CanvasBounds.top
            nextX = (slope*ballLocation.x - (ballLocation.y - nextY))/slope
        }
        
        //calculate distance and speed
        let pointA = CGPointMake(nextX, nextY)
        let pointB = CGPointMake(ballLocation.x, ballLocation.y)
        let duration = NSTimeInterval(distance(pointA, pointB: pointB)/100)
        
        //move the ball to our new point
        self.moveBallToPoint(nextX, y: nextY, time: duration)
        
        //if we're headed towards the enemy goal, move enemy
        if self.playerTurn == Player.B && (nextX == self.CanvasBounds.right || nextX ==  self.CanvasBounds.left) {
            self.enemyPlayerWaiting = false
            self.moveEnemyToGoal(nextY, time: duration)
        }
        
        delay(duration) {
            //update the ball location
            self.ballLocation = (x: nextX, y: nextY)
            
            //if we've reached the other side, switch players and complete
            if nextX == self.CanvasBounds.right || nextX ==  self.CanvasBounds.left {
                self.playerTurn = self.playerTurn == Player.A ? Player.B : Player.A
                
                guard completion != nil else {
                    return
                }

                completion!()
            }
                
            //else keep moving ball
            else {
                self.moveBallAtSlope(-slope, completion: completion)
            }
        }
    }
    
    func moveBallToPoint(x: CGFloat, y: CGFloat, time : NSTimeInterval) {
        self.animateWithDuration(time, animations: { () -> Void in
            self.horizontalBallSpacer.setWidth(x)
            self.verticalBallSpacer.setHeight(y)
        })
    }
    
    //determines if ball was hit; returns angle to fire back if yes, nil if no
    func wasBallHit() -> CGFloat? {
        //Player B just went, check if they hit
        let paddleCenter = playerTurn == Player.B
            ? self.paddlePosition+self.PaddleHeight/2
            : self.enemyPaddlePosition+self.PaddleHeight/2
        let ballCenter   = self.ballLocation.y+self.BallHeight/2
        let offset       = ballCenter - paddleCenter
        
        //ball did not hit, return nil
        if abs(offset) > 25 {
            return nil
        }
        //HIT! return proper slope
        else {
            return playerTurn == Player.B ? -(offset/25 * 6) : (offset/25 * 6)
        }
    }
    
    func startEnemyPlayer() {
        //first enemy paddle move to center
        delay(0) {
            let paddleAtCenter = (self.CanvasBounds.bottom/2) - self.PaddleHeight/2
            self.animateWithDuration(1, animations: {
                self.enemySpacer.setHeight(self.enemyPaddlePosition)
            })
            self.enemyPaddlePosition = paddleAtCenter
            
            //then move it around center
            func shuffle() {
                if self.enemyPlayerWaiting {
                    let time = Double.random(min: 0.5, max: 1.5)
                    delay(time) {
                        if self.enemyPlayerWaiting {
                            let destination = paddleAtCenter - CGFloat.random(min: -10, max: 50)
                            self.animateWithDuration(time, animations: {
                                self.enemySpacer.setHeight(destination)
                            })
                            
                            self.enemyPaddlePosition = destination
                        } else {
                            return
                        }
                        
                        if self.enemyPlayerWaiting {
                            let time = Double.random(min: 0.5, max: 1.5)
                            delay(time) {
                                if self.enemyPlayerWaiting {
                                    let destination = paddleAtCenter + CGFloat.random(min: -10, max: 50)
                                    self.animateWithDuration(time, animations: {
                                        self.enemySpacer.setHeight(destination)
                                    })
                                    
                                    self.enemyPaddlePosition = destination
                                } else {
                                    return
                                }
                                
                                shuffle()
                            }
                        } else {
                            return
                        }
                    }
                } else {
                    return
                }
            }
            
            shuffle()
        }
    }
    
    func moveEnemyToGoal(destination : CGFloat, time : NSTimeInterval) {
        let pointA = CGPointMake(destination, 0)
        let pointB = CGPointMake(enemyPaddlePosition, 0)
        let duration = NSTimeInterval(distance(pointA, pointB: pointB)/100)
        
        self.animateWithDuration(duration, animations: {
            self.enemySpacer.setHeight(destination)
        })
        delay(duration) {
            self.enemyPaddlePosition = destination
        }
    }
    
    func resetBoard() {
        self.enemyPlayerWaiting = false
        self.ballLocation = (x: 0, y: 0)
        self.enemyPaddlePosition = 0
        
        self.horizontalBallSpacer.setRelativeWidth(0, withAdjustment: 0)
        self.verticalBallSpacer.setRelativeHeight(0, withAdjustment: 0)
        self.enemySpacer.setRelativeHeight(0, withAdjustment: 0)
    }
    
    func alertControllerWillDismiss() {
        dispatch_async(dispatch_get_main_queue()) {
            delay(1) {
                self.startRound()
            }
        }
    }
    
    func distance(pointA : CGPoint, pointB : CGPoint) -> CGFloat {
        return sqrt(pow(pointA.x - pointB.x, 2) + pow(pointA.y - pointB.y, 2))
    }
}

enum Player {
    case A, B
}

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

extension CGFloat {
    func isPositive() -> Bool {
        return self >= 0
    }
}

public extension Double {
    public static func random() -> Double {
        return Double(arc4random()) / 0xFFFFFFFF
    }
    
    public static func random(min min: Double, max: Double) -> Double {
        return Double.random() * (max - min) + min
    }
}

public extension CGFloat {
    public static func random() -> CGFloat {
        return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
    }
    
    public static func random(min min: CGFloat, max: CGFloat) -> CGFloat {
        return CGFloat.random() * (max - min) + min
    }
}