//
//  HostViewController.swift
//  Song inSync
//
//  Created by Thatcher Clough on 6/25/20.
//  Copyright © 2020 Thatcher Clough. All rights reserved.
//

import Foundation
import UIKit
import MultipeerConnectivity
import MediaPlayer
import AVFoundation
import StoreKit

class HostViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {
    
    static var peerID: MCPeerID!
    static var mcSession: MCSession!
    static var mcAdvertiser: MCNearbyServiceAdvertiser!
    
    var peers: [MCPeerID] = []
    var connectingPeers: [MCPeerID] = []
    var toBeAccepted: [MCPeerID] = []
    var toBeDeclined: [MCPeerID] = []
    
    var alreadySetUpMC: Bool! = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpTable()
        
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    func setUpTable() {
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.rowHeight = 70
        tableView.layoutMargins = UIEdgeInsets.zero
        tableView.separatorInset = UIEdgeInsets.zero
        tableView.reloadData()
    }
    
    @objc func appMovedToBackground() {
        HostViewController.mcAdvertiser.stopAdvertisingPeer()
    }
    
    @objc func appCameToForeground() {
        HostViewController.mcAdvertiser.startAdvertisingPeer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !alreadySetUpMC {
            setUpMC()
            alreadySetUpMC = true
        }
        HostViewController.mcAdvertiser.stopAdvertisingPeer()
        HostViewController.mcAdvertiser.startAdvertisingPeer()
        
        startSendingMusicData()
    }
    
    func setUpMC() {
        HostViewController.peerID = MCPeerID(displayName: UIDevice.current.name)
        HostViewController.mcSession = MCSession(peer: HostViewController.peerID, securityIdentity: nil, encryptionPreference: .required)
        HostViewController.mcSession.delegate = self
        
        HostViewController.mcAdvertiser = MCNearbyServiceAdvertiser(peer: HostViewController.peerID, discoveryInfo: nil, serviceType: "Song-inSync")
        HostViewController.mcAdvertiser.delegate = self
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if timer != nil {
            timer.invalidate()
        }
        
        HostViewController.mcAdvertiser.stopAdvertisingPeer()
        HostViewController.mcSession.disconnect()
        peers.removeAll()
        connectingPeers.removeAll()
        toBeAccepted.removeAll()
        toBeDeclined.removeAll()
        
        tableView.reloadData()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        HostViewController.mcAdvertiser.stopAdvertisingPeer()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        tableView.reloadData()
    }
    
    // MARK: Table related
    
    @IBOutlet weak var tableView: UITableView!
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if HostViewController.mcSession.connectedPeers.contains(peers[indexPath.row]) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AcceptedCell", for: indexPath) as! AcceptedCell
            cell.label.text = peers[indexPath.row].displayName
            cell.connectionStatusLabel.text = "Connected"
            
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            cell.layoutMargins = UIEdgeInsets.zero
            
            return cell
        } else if connectingPeers.contains(peers[indexPath.row]) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AcceptedCell", for: indexPath) as! AcceptedCell
            cell.label.text = peers[indexPath.row].displayName
            cell.connectionStatusLabel.text = "Connecting"
            
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            cell.layoutMargins = UIEdgeInsets.zero
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "RequestedCell", for: indexPath) as! RequestedCell
            cell.label.text = peers[indexPath.row].displayName
            
            cell.acceptButton.layer.cornerRadius = 6
            cell.acceptButton.addTarget(self, action: #selector(accept(sender:)), for: .touchUpInside)
            cell.acceptButton.tag = indexPath.row
            
            cell.declineButton.layer.cornerRadius = 6
            cell.declineButton.addTarget(self, action: #selector(decline(sender:)), for: .touchUpInside)
            cell.declineButton.tag = indexPath.row
            
            if self.traitCollection.userInterfaceStyle == .dark {
                cell.declineButton.setTitleColor(UIColor.white, for: .normal)
                cell.declineButton.layer.borderColor = UIColor.lightGray.cgColor
            } else {
                cell.declineButton.setTitleColor(UIColor.black, for: .normal)
                cell.declineButton.layer.borderColor = UIColor.darkGray.cgColor
            }
            
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            cell.layoutMargins = UIEdgeInsets.zero
            
            return cell
        }
    }
    
    @objc func accept(sender: UIButton) {
        let index = sender.tag
        connectingPeers.append(peers[index])
        toBeAccepted.append(peers[index])
        tableView.reloadData()
    }
    
    @objc func decline(sender: UIButton){
        let index = sender.tag
        toBeDeclined.append(peers[index])
        peers.remove(at: index)
        tableView.reloadData()
    }
    
    // MARK: Multipeer connectivity related
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == MCSessionState.connected {
            print("Host: connected to: \(peerID.displayName)")
        } else if state == MCSessionState.connecting {
            print("Host: connecting to: \(peerID.displayName)")
            
            connectingPeers.append(peerID)
        } else if state == MCSessionState.notConnected {
            print("Host: disconnected from: \(peerID.displayName)")
            if MainViewController.canPushNotifications {
                MainViewController.pushNotification(title: "Disconnect occurred", body: "\(peerID.displayName) has been disconnected.")
            }
            
            if peers.contains(peerID) {
                peers.remove(at: peers.firstIndex(of: peerID)!)
            }
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        if !peers.contains(peerID) {
            peers.append(peerID)
        }
        tableView.reloadData()
        
        DispatchQueue.global(qos: .background).async {
            while true {
                if self.toBeAccepted.count > 0 && self.toBeAccepted.contains(peerID) {
                    self.toBeAccepted.remove(at: self.toBeAccepted.firstIndex(of: peerID)!)
                    invitationHandler(true, HostViewController.mcSession)
                    break;
                } else if self.toBeDeclined.count > 0 && self.toBeDeclined.contains(peerID) {
                    self.toBeDeclined.remove(at: self.toBeDeclined.firstIndex(of: peerID)!)
                    invitationHandler(false, HostViewController.mcSession)
                    break;
                }
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    var audioPlayer: AVAudioPlayer?
    var timer: Timer!
    func startSendingMusicData() {
        do {
            let audioCheck = URL(fileURLWithPath: Bundle.main.path(forResource: "audioCheck", ofType: "mp3")!)
            audioPlayer = try AVAudioPlayer(contentsOf: audioCheck)
            audioPlayer!.numberOfLoops = -1
            audioPlayer!.prepareToPlay()
            audioPlayer!.play()
        } catch {
            DispatchQueue.main.async {
                let errorAlert = UIAlertController(title: "Notice", message: "Could not perform audio check: \(error.localizedDescription)", preferredStyle: UIAlertController.Style.alert)
                errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                self.present(errorAlert, animated: true, completion: nil)
            }
        }
        
        var backgroundTask = UIBackgroundTaskIdentifier(rawValue: 0)
        backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            UIApplication.shared.endBackgroundTask(backgroundTask)
        })
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { (t) in
            let player = MPMusicPlayerController.systemMusicPlayer
            let nowPlaying = player.nowPlayingItem
            
            if (nowPlaying != nil && nowPlaying!.title != nil && nowPlaying!.artist != nil) {
                let songName: String = nowPlaying!.value(forProperty: MPMediaItemPropertyTitle) as! String
                let artistName: String = nowPlaying!.value(forProperty: MPMediaItemPropertyArtist) as! String
                let songDurationInSec: Double = (nowPlaying!.value(forKey: MPMediaItemPropertyPlaybackDuration) as! Double).truncate(places: 0)
                var songPositionInMillis = player.currentPlaybackTime
                var currentTimeMillis = NSDate().timeIntervalSince1970
                songPositionInMillis = songPositionInMillis * 1000
                currentTimeMillis = currentTimeMillis * 1000
                let explicit: Bool = nowPlaying!.isExplicitItem
                let songIsPlaying = !(player.playbackState == .paused)
                
                self.sendData((String(
                    "song name:\(songName)\n" +
                        "artist name:\(artistName)\n" +
                        "song duration:\(songDurationInSec)\n" +
                        "song position:\(songPositionInMillis)\n" +
                        "playing:\(songIsPlaying)\n" +
                        "explicit:\(explicit)\n" +
                    "current time:\(currentTimeMillis)\n")
                    ).data(using: .utf8)!)
            }
        }
        RunLoop.current.add(timer, forMode: RunLoop.Mode.default)
    }
    
    func sendData(_ data:Data) {
        if HostViewController.mcSession.connectedPeers.count > 0 {
            do {
                try HostViewController.mcSession.send(data, toPeers: HostViewController.mcSession.connectedPeers, with: .reliable)
            } catch let error {
                DispatchQueue.main.async {
                    let errorAlert = UIAlertController(title: "Error", message: "Could not send music data to peers: \(error.localizedDescription)", preferredStyle: UIAlertController.Style.alert)
                    errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

public class RequestedCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var declineButton: UIButton!
}

public class AcceptedCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var connectionStatusLabel: UILabel!
}
