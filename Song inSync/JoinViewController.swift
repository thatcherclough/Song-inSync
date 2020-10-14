//
//  JoinViewController.swift
//  Song inSync
//
//  Created by Thatcher Clough on 6/25/20.
//  Copyright © 2020 Thatcher Clough. All rights reserved.
//

import Foundation
import UIKit
import MultipeerConnectivity
import AVFoundation
import MediaPlayer
import StoreKit

class JoinViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate {
    
    static var peerID: MCPeerID!
    static var mcSession: MCSession!
    static var mcBrowser: MCNearbyServiceBrowser!
    
    var hosts: [MCPeerID] = []
    var requestedHost: MCPeerID = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
    var declinedHost: MCPeerID = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
    var connectingHost: MCPeerID = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
    
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
        JoinViewController.mcBrowser.stopBrowsingForPeers()
        hosts.removeAll()
        
        tableView.reloadData()
    }
    
    @objc func appCameToForeground() {
        JoinViewController.mcBrowser.startBrowsingForPeers()
        
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !alreadySetUpMC {
            setUpMC()
            alreadySetUpMC = true
        }
        JoinViewController.mcBrowser.startBrowsingForPeers()
    }
    
    func setUpMC() {
        JoinViewController.peerID = MCPeerID(displayName: UIDevice.current.name)
        JoinViewController.mcSession = MCSession(peer: JoinViewController.peerID, securityIdentity: nil, encryptionPreference: .required)
        JoinViewController.mcSession.delegate = self
        
        JoinViewController.mcBrowser = MCNearbyServiceBrowser(peer: JoinViewController.peerID, serviceType: "Song-inSync")
        JoinViewController.mcBrowser.delegate = self
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        JoinViewController.mcBrowser.stopBrowsingForPeers()
        hosts.removeAll()
        declinedHost = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
        requestedHost = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
        connectingHost = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
        
        tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let joined = segue.destination as! JoinedViewController
        joined.peerID = JoinViewController.peerID
        joined.mcSession = JoinViewController.mcSession
        joined.connectedHost = self.connectingHost
        
        declinedHost = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
        requestedHost = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
        connectingHost = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
    }
    
    // MARK: Table related
    
    @IBOutlet weak var tableView: UITableView!
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return hosts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (requestedHost == hosts[indexPath.row]) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "StatusCell", for: indexPath) as! StatusCell
            cell.label.text = hosts[indexPath.row].displayName
            cell.statusLabel.text = "Requested"
            
            cell.layoutMargins = UIEdgeInsets.zero
            
            return cell
        }  else if (declinedHost == hosts[indexPath.row]) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "StatusCell", for: indexPath) as! StatusCell
            cell.label.text = hosts[indexPath.row].displayName
            cell.statusLabel.text = "Declined"
            
            cell.layoutMargins = UIEdgeInsets.zero
            
            return cell
        } else if (connectingHost == hosts[indexPath.row]) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConnectingCell", for: indexPath) as! ConnectingCell
            cell.label.text = hosts[indexPath.row].displayName
            
            cell.layoutMargins = UIEdgeInsets.zero
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath) as! DefaultCell
            cell.label.text = hosts[indexPath.row].displayName
            
            cell.layoutMargins = UIEdgeInsets.zero
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        DispatchQueue.main.async {
            self.tableView.cellForRow(at: indexPath)?.setSelected(false, animated: true)
            if self.requestedHost.displayName == "Song-inSyncDefaultPeerID" && self.connectingHost.displayName == "Song-inSyncDefaultPeerID" {
                self.declinedHost = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
                self.requestedHost = self.hosts[indexPath.row]
                self.tableView.reloadData()
                JoinViewController.mcBrowser.invitePeer(self.hosts[indexPath.row], to: JoinViewController.mcSession, withContext: nil, timeout: 300.0)
            }
        }
    }
    
    // MARK: Multipeer connectivity related
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == MCSessionState.connected {
            print("Peer: connected to: \(peerID.displayName)")
            
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "ToJoinedView", sender: nil)
            }
        } else if state == MCSessionState.connecting {
            print("Peer: connecting to: \(peerID.displayName)")
            
            requestedHost = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
            connectingHost = peerID
        } else if state == MCSessionState.notConnected {
            print("Peer: disconnected from: \(peerID.displayName)")
            
            requestedHost = MCPeerID(displayName: "Song-inSyncDefaultPeerID")
            declinedHost = peerID
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        if !hosts.contains(peerID) && !(JoinViewController.peerID == peerID) {
            hosts.append(peerID)
        }
        tableView.reloadData()
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        hosts.remove(at: hosts.firstIndex(of: peerID)!)
        tableView.reloadData()
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

public class DefaultCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
}

public class StatusCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
}

public class ConnectingCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
}
