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
    //allows for digital crown control
    @IBOutlet var scroller : WKInterfacePicker!
    
    /* Paddles & Paddle Control */
    //space above paddles; grows/shrinks according to scroller
    @IBOutlet var spacer : WKInterfaceGroup!
    @IBOutlet var enemySpacer : WKInterfaceGroup!
    //user and enemy paddle representations
    @IBOutlet var paddle : WKInterfaceButton!
    @IBOutlet var enemyPaddle : WKInterfaceButton!
    //size of paddle
    let PaddleHeight = 30 as CGFloat
    
    /* Ball & Ball Control */
    //ball representation
    @IBOutlet var ball   : WKInterfaceButton!
    //move ball in x and y directions
    @IBOutlet var verticalBallSpacer : WKInterfaceGroup!
    @IBOutlet var horizontalBallSpacer : WKInterfaceGroup!
    //size of ball
    let BallHeight = 10 as CGFloat
    
    //size of 38mm canvas
    let CanvasBounds = (top : 0 as CGFloat, left : 0 as CGFloat, bottom : 135 as CGFloat, right : 111 as CGFloat)
    
    //is enemy paddle waiting?
    var enemyPlayerWaiting : Bool = false
    
    //whose turn is it?
    var playerTurn = Player.A
    
    //current position of paddles
    var paddlePosition : CGFloat = 0
    var enemyPaddlePosition : CGFloat = 0
    
    //current position of ball
    var ballLocation = (x : 0 as CGFloat, y: 0 as CGFloat)
    
    //current score
    var score = [Player.A : 0, Player.B : 0]
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
                
        //allows for scrolling paddle, 1-100% scrolled
        var pickerItems: [WKPickerItem] = []
        for _ in 1...100 {
            pickerItems.append(WKPickerItem())
        }
        self.scroller.setItems(pickerItems)
        
        //start round with random ball direction
        self.startRound(CGFloat.random(min: 1, max: 3))
        
        //start moving enemy player around
        self.startEnemyPlayer()
    }
    
    //moves paddle when the user scrolls digital crown
    @IBAction func userDidScroll(value : Int) {
        //set paddle position to 1-100% of available space
        self.paddlePosition = (CGFloat(value)/100)*(CanvasBounds.bottom - PaddleHeight)
        self.spacer.setHeight(self.paddlePosition)
    }

    //starts a round of pong
    func startRound(slope : CGFloat = 3) {
        self.enemyPlayerWaiting = true //enemy always goes first, so wait
        self.startEnemyPlayer()        //move enemy around in the meantime

        //move the ball at passed slope
        moveBallAtSlope(slope) {
            //get slope ball should be returned at if it was hit
            if let slope = self.wasBallHit() {
                //move ball at new slope
                self.startRound(slope)
            }
            //ball was missed, start new round or gameover
            else {
                //play sound, reset the board
                WKInterfaceDevice().playHaptic(WKHapticType.Failure)
                self.resetBoard()
                
                //player A wins!
                if self.score[Player.A] == 4 && self.playerTurn == Player.B {
                    //present an alert, ask user to play again
                    self.presentAlertControllerWithTitle("Whoops!", message: "Watch wins!", preferredStyle: WKAlertControllerStyle.ActionSheet, actions: [WKAlertAction(title: "Play Again", style: WKAlertActionStyle.Default, handler: {
                        //reset the score, start new round
                        delay(1) {
                            self.score = [Player.A : 0, Player.B : 0]
                            self.startRound(CGFloat.random(min: 1, max: 3))
                        }
                    })])
                }
                //player B wins!
                else if self.score[Player.B] == 4 && self.playerTurn == Player.A {
                    //present an alert, ask user to play again
                    self.presentAlertControllerWithTitle("Cogratulations!", message: "You win!", preferredStyle: WKAlertControllerStyle.ActionSheet, actions: [WKAlertAction(title: "Play Again", style: WKAlertActionStyle.Default, handler: {
                        //reset the score, start new round
                        delay(1) {
                            self.score = [Player.A : 0, Player.B : 0]
                            self.startRound(CGFloat.random(min: 1, max: 3))
                        }
                    })])
                }
                //no one wins yet, start new round
                else {
                    if self.playerTurn == Player.A {
                        //update score, show user interstitial alert
                        self.score[Player.B] = self.score[Player.B]! + 1
                        self.presentControllerWithName("AlertController", context: ["delegate" : self, "text" : "Point!\n\(self.score[Player.A]!)-\(self.score[Player.B]!)", "positive" : true])
                    } else {
                        //update score, show user interstitial alert
                        self.score[Player.A] = self.score[Player.A]! + 1
                        self.presentControllerWithName("AlertController", context: ["delegate" : self, "text" : "Ouch!\n\(self.score[Player.A]!)-\(self.score[Player.B]!)", "positive" : false])
                    }
                    
                    //computer always starts round
                    self.playerTurn = Player.A
                }
            }
        }
    }
    
    //move ball at slope; recurses until board crossed
    func moveBallAtSlope(slope : CGFloat, completion: (() -> Void)?) {
        //calculate next point
        var nextX = self.playerTurn == Player.A ? CanvasBounds.right : CanvasBounds.left
        var nextY = ballLocation.y - slope*(ballLocation.x - nextX)
        
        //guard against boundaries
        if nextY > CanvasBounds.bottom || nextY < CanvasBounds.top {
            nextY = nextY > CanvasBounds.bottom ? CanvasBounds.bottom : CanvasBounds.top
            nextX = (slope*ballLocation.x - (ballLocation.y - nextY))/slope
        }
        
        //calculate distance and speed
        let pointA = CGPointMake(nextX, nextY)
        let pointB = CGPointMake(ballLocation.x, ballLocation.y)
        let duration = NSTimeInterval(distance(pointA, pointB: pointB)/100)
        
        //if we're headed towards the enemy goal, start to move enemy
        if self.playerTurn == Player.B && (nextX == self.CanvasBounds.right || nextX ==  self.CanvasBounds.left) {
            self.enemyPlayerWaiting = false
            self.moveEnemyToGoal(nextY, time: duration)
        }
        
        //move the ball to our new point
        self.animateWithDuration(duration, animations: { () -> Void in
            self.horizontalBallSpacer.setWidth(nextX)
            self.verticalBallSpacer.setHeight(nextY)
        }) {
            //update the ball location
            self.ballLocation = (x: nextX, y: nextY)
            
            //if we've reached the other side, switch players and complete
            if nextX == self.CanvasBounds.right || nextX ==  self.CanvasBounds.left {
                self.playerTurn = self.playerTurn == Player.A ? Player.B : Player.A
                
                guard completion != nil else {
                    return
                }
                
                //completion handler
                completion?()
            }
                
            //else keep moving ball
            else {
                self.moveBallAtSlope(-slope, completion: completion)
            }
        }
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
        delay(0) {
            //first enemy paddle move to center
            let paddleAtCenter = (self.CanvasBounds.bottom/2) - self.PaddleHeight/2
            self.animateWithDuration(1, animations: {
                self.enemySpacer.setHeight(self.enemyPaddlePosition)
            }) {
                //enemy is moved to center
                self.enemyPaddlePosition = paddleAtCenter
                
                enum Direction {
                    case Up, Down
                }
                
                //helper for shuffling it around the center
                func shuffle(direction : Direction) {
                    if self.enemyPlayerWaiting { //only continue while we're supposed to be waiting, else exit immediately
                        //pick a random destination, either up or down
                        let destination = direction == Direction.Up
                            ? paddleAtCenter - CGFloat.random(min: -10, max: 50)
                            : paddleAtCenter + CGFloat.random(min: -10, max: 50)
                        
                        //pick a random speed
                        let time = Double.random(min: 0.5, max: 1.5)
                        
                        //move to random destination at random speed
                        self.animateWithDuration(time, animations: {
                            self.enemySpacer.setHeight(destination)
                        }) {
                            //update our tracker
                            self.enemyPaddlePosition = destination
                            
                            //shuffle in opposite direction
                            if direction == Direction.Up {
                                shuffle(Direction.Down)
                            } else {
                                shuffle(Direction.Up)
                            }
                        }
                    } else {
                        return
                    }
                }
                
                //begin shuffle
                shuffle(Direction.Up)
            }
        }
    }
    
    //moves enemy paddle towards the goal spot, limited by speed of ball
    func moveEnemyToGoal(destination : CGFloat, time : NSTimeInterval) {
        let pointA = CGPointMake(destination, 0)
        let pointB = CGPointMake(enemyPaddlePosition, 0)
        let duration = NSTimeInterval(distance(pointA, pointB: pointB)/100) //limits to speed of ball
        
        //animate to new point
        self.animateWithDuration(duration, animations: {
            self.enemySpacer.setHeight(destination)
        }) {
            //update our position after animation
            self.enemyPaddlePosition = destination
        }
    }
    
    //reset board state
    func resetBoard() {
        //reset all positions and locations to 0 (except user paddle position)
        self.enemyPlayerWaiting = false
        self.ballLocation = (x: 0, y: 0)
        self.enemyPaddlePosition = 0
        
        self.horizontalBallSpacer.setRelativeWidth(0, withAdjustment: 0)
        self.verticalBallSpacer.setRelativeHeight(0, withAdjustment: 0)
        self.enemySpacer.setRelativeHeight(0, withAdjustment: 0)
    }
    
    //called when alert dismisses, starts new round after 1s delay
    func alertControllerWillDismiss() {
        dispatch_async(dispatch_get_main_queue()) {
            delay(1) {
                self.startRound()
            }
        }
    }
    
    //calculates distance from pointA to pointB
    func distance(pointA : CGPoint, pointB : CGPoint) -> CGFloat {
        return sqrt(pow(pointA.x - pointB.x, 2) + pow(pointA.y - pointB.y, 2))
    }
}

//Two players
enum Player {
    case A, B
}

//helper for GCD delay
func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

//generates random numbers
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

extension WKInterfaceController {
    func animateWithDuration(duration: NSTimeInterval, animations: () -> Void, completion: (() -> Void)?) {
        animateWithDuration(duration, animations: animations)
        let completionDelay = dispatch_time(DISPATCH_TIME_NOW, Int64(duration * Double(NSEC_PER_SEC)))
        dispatch_after(completionDelay, dispatch_get_main_queue()) {
            completion?()
        }
    }
}