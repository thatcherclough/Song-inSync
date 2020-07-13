//
//  MainViewController.swift
//  Song inSync
//
//  Created by Thatcher Clough on 6/24/20.
//  Copyright © 2020 Thatcher Clough. All rights reserved.
//

import UIKit
import StoreKit
import UserNotifications

class MainViewController: UIViewController {
    
    var hasPermissions: Bool! = false
    static var canPushNotifications: Bool! = true
    
    @IBOutlet weak var hostButtonOutlet: UIButton!
    @IBOutlet weak var joinButtonOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hostButtonOutlet.layer.cornerRadius = 6
        joinButtonOutlet.layer.cornerRadius = 6
        
        checkPermissions()
    }
    
    func checkPermissions() {
        let controller = SKCloudServiceController()
        SKCloudServiceController.requestAuthorization { status in
            if SKCloudServiceController.authorizationStatus() == .authorized {
                controller.requestCapabilities { capabilities, error in
                    if capabilities.contains(.musicCatalogPlayback) {
                        self.hasPermissions = true
                        UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound, .badge]) {
                                granted, error in
                                MainViewController.canPushNotifications = granted
                        }
                    } else {
                        DispatchQueue.main.async {
                            let errorAlert = UIAlertController(title: "Notice", message: "Song inSync will not work on this deivce beucase this device does not have Apple Music.", preferredStyle: UIAlertController.Style.alert)
                            errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                            self.present(errorAlert, animated: true, completion: nil)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    let errorAlert = UIAlertController(title: "Notice", message: "Song inSync will not work on this deivce beucase it does not have access to Apple Music. Please enable access to \"Media and Apple Music\" in settings.", preferredStyle: UIAlertController.Style.alert)
                    errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                }
            }
        }
    }
    
    @IBAction func hostButtonAction(_ sender: Any) {
        checkPermissions()
        if hasPermissions {
            let host = self.storyboard!.instantiateViewController(withIdentifier: "HostViewController") as! HostViewController
            self.navigationController!.pushViewController(host, animated: true)
        }
    }
    
    @IBAction func joinButtonAction(_ sender: Any) {
        checkPermissions()
        if hasPermissions {
            let join = self.storyboard!.instantiateViewController(withIdentifier: "JoinViewController") as! JoinViewController
            self.navigationController!.pushViewController(join, animated: true)
        }
    }
    
    static func pushNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
