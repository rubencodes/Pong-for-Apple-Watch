//
//  AlertViewController.swift
//  InfiniTweet
//
//  Created by Ruben on 2/27/15.
//  Copyright (c) 2015 Ruben. All rights reserved.
//

import Foundation
import WatchKit

protocol AlertControllerDelegate {
    func alertControllerWillDismiss()
}

class AlertController: WKInterfaceController {
    @IBOutlet weak var label: WKInterfaceLabel!
    @IBOutlet weak var group: WKInterfaceGroup!
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        if context != nil {
            self.setTitle("Close")
            
            if let text = context!["text"] as? String {
                label.setText(text)
                let positive = context!["positive"] as? Bool
                
                if positive! {
                    //Emerald - rgb(46, 204, 113)
                    group.setBackgroundColor(UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1))
                } else {
                    //Alizarin - rgb(231, 76, 60)
                    group.setBackgroundColor(UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1))
                }
            }
            
            let duration = context!["duration"] as? Double ?? 2 as Double
            
            delay(duration) {
                let delegate = context!["delegate"] as? AlertControllerDelegate
                if delegate != nil {
                    delegate!.alertControllerWillDismiss()
                }
                
                self.dismissController()
            }
        }
    }
}