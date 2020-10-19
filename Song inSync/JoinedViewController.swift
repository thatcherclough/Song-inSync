//
//  JoinedViewController.swift
//  Song inSync
//
//  Created by Thatcher Clough on 6/29/20.
//  Copyright © 2020 Thatcher Clough. All rights reserved.
//

import Foundation
import UIKit
import MultipeerConnectivity
import AVFoundation
import MediaPlayer
import StoreKit
import UserNotifications
import Keys

class JoinedViewController: UIViewController, MCSessionDelegate {
    
    var peerID: MCPeerID!
    var mcSession: MCSession!
    var connectedHost: MCPeerID!
    
    var countryCode: String!
    
    override func viewDidLoad() {
        mcSession.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationBecameUnlocked), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationBecameLocked), name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        
        getCountryCode()
        
        soundCheck()
    }
    
    @objc func applicationBecameUnlocked(notification: NSNotification) {
        playingDelay = 0.3
    }
    
    @objc func applicationBecameLocked(notification: NSNotification) {
        playingDelay = 0.6
    }
    
    func getCountryCode() {
        DispatchQueue.global(qos: .background).async {
            let controller = SKCloudServiceController()
            controller.requestStorefrontCountryCode { countryCode, error in
                if error != nil {
                    DispatchQueue.main.async {
                        let errorAlert = UIAlertController(title: "Error", message: "Could not get the current country code. Will use \"us\" as default.", preferredStyle: UIAlertController.Style.alert)
                        errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                        self.present(errorAlert, animated: true, completion: nil)
                    }
                } else {
                    self.countryCode = countryCode
                }
            }
        }
    }
    
    var audioPlayer: AVAudioPlayer?
    func soundCheck() {
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
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        mcSession.disconnect()
    }
    
    // MARK: Multipeer connectivity related
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == MCSessionState.connected {
            print("Peer: connected to: \(peerID.displayName)")
        } else if state == MCSessionState.connecting {
            print("Peer: connecting to: \(peerID.displayName)")
        } else if state == MCSessionState.notConnected {
            print("Peer: disconnected from: \(peerID.displayName)")
            
            if (self.peerID == peerID) || (connectedHost == peerID) {
                if MainViewController.canPushNotifications {
                    MainViewController.pushNotification(title: "Disconnect occurred", body: "You have been disconnected from the host.")
                }
                DispatchQueue.main.async {
                    let errorAlert = UIAlertController(title: "Notice", message: "You have been disconnected from the host. Will now return to the main menu.", preferredStyle: UIAlertController.Style.alert)
                    errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: {(action: UIAlertAction!) in
                        errorAlert.dismiss(animated: true, completion: nil)
                        self.navigationController?.popToRootViewController(animated: true)
                    }))
                    self.present(errorAlert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
    
    var currentSongAndArtist: String = ""
    var currentSongIsPlaying: Bool = false
    var playingDelay: Double = 0.3
    var songAvailable: Bool! = true
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            let dataAsString = String(data: data, encoding: .utf8)!
            
            let songName = dataAsString.slice(from: "song name:", to: "\n")!
            let artistName = dataAsString.slice(from: "artist name:", to: "\n")!
            let songAndArtist = songName + " " + artistName
            let songDurationInSec = Double(dataAsString.slice(from: "song duration:", to: "\n")!)!
            let songPositionInMillis = Double(dataAsString.slice(from: "song position:", to: "\n")!)!
            let explicit = Bool(dataAsString.slice(from: "explicit:", to: "\n")!)!
            let songIsPlaying = Bool(dataAsString.slice(from: "playing:", to: "\n")!)!
            let hostTimeInMillis = Double(dataAsString.slice(from: "current time:", to: "\n")!)!
            
            let player = MPMusicPlayerController.applicationQueuePlayer
            
            let currentSongPositionInSec = player.currentPlaybackTime
            let hostSongPositionForCheckInSec = (songPositionInMillis / 1000) + (NSDate().timeIntervalSince1970 - (hostTimeInMillis / 1000))
            
            if !self.songAvailable && (self.currentSongAndArtist == songAndArtist) {
                print("Song not available")
            } else if !self.currentSongAndArtist.isEmpty && (self.currentSongAndArtist == songAndArtist) && (abs(hostSongPositionForCheckInSec - currentSongPositionInSec) < 0.03) {
                print("Everything is on track")
            } else if (!self.currentSongAndArtist.isEmpty) && (self.currentSongAndArtist == songAndArtist) {
                print("Song is the same, but something else has changed")
                self.currentSongIsPlaying = songIsPlaying
                
                if self.currentSongIsPlaying {
                    player.prepareToPlay()
                    player.play()
                    while player.playbackState != .playing {
                        player.play()
                    }
                    
                    let inSyncSongPositionInSec = (songPositionInMillis / 1000) + (NSDate().timeIntervalSince1970 - (hostTimeInMillis / 1000) + 1)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        player.currentPlaybackTime = inSyncSongPositionInSec + self.playingDelay
                    }
                } else {
                    player.pause()
                }
            } else {
                print("Song has changed")
                self.currentSongAndArtist = songAndArtist
                self.currentSongIsPlaying = songIsPlaying
                
                self.getAppleMusicSongID(songName: songName, artistName: artistName, songDurationInSec: songDurationInSec, explicit: explicit, completion: { id in
                    if let id = id {
                        if !self.songAvailable {
                            self.songAvailable = true
                        }
                        
                        let id: [String] = [id]
                        let queue  = MPMusicPlayerStoreQueueDescriptor(storeIDs: id)
                        player.setQueue(with: queue)
                        
                        if self.currentSongIsPlaying {
                            player.prepareToPlay()
                            player.play()
                            while player.playbackState != .playing {
                                player.play()
                            }
                            
                            let inSyncSongPositionInSec = (songPositionInMillis / 1000) + (NSDate().timeIntervalSince1970 - (hostTimeInMillis / 1000) + 1)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                player.currentPlaybackTime = inSyncSongPositionInSec + self.playingDelay
                            }
                        } else {
                            player.pause()
                        }
                    } else {
                        self.songAvailable = false
                        
                        player.pause()
                        
                        if MainViewController.canPushNotifications {
                            MainViewController.pushNotification(title: "Song not available", body: "The host is playing a song that is not available on Apple Music.")
                        }
                        DispatchQueue.main.async {
                            let errorAlert = UIAlertController(title: "Notice", message: "The host is playing a song that is not available on Apple Music.", preferredStyle: UIAlertController.Style.alert)
                            errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                            self.present(errorAlert, animated: true, completion: nil)
                        }
                    }
                })
            }
        }
    }
    
    let keys = SongInSyncKeys()
    func getAppleMusicSongID(songName: String, artistName: String, songDurationInSec: Double, explicit: Bool, completion: @escaping (String?)->()) {
        let searchTerm  = ("\(songName)+\(artistName)").replacingOccurrences(of: " ", with: "+")
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.music.apple.com"
        components.path = "/v1/catalog/\(self.countryCode ?? "us")/search"
        components.queryItems = [
            URLQueryItem(name: "term", value: searchTerm),
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "types", value: "songs"),
        ]
        let url = components.url!
        
        let session = URLSession.shared
        var request = URLRequest(url: url)
        request.setValue("Bearer \(self.keys.appleMusicAPIKey)", forHTTPHeaderField: "Authorization")
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    let errorAlert = UIAlertController(title: "Error", message: "Could not retrieve data from Apple Music: \(error!.localizedDescription)", preferredStyle: UIAlertController.Style.alert)
                    errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    let errorAlert = UIAlertController(title: "Error", message: "Could not retrieve data from Apple Music.", preferredStyle: UIAlertController.Style.alert)
                    errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    if let results = json["results"] as? [String: Any] {
                        if let songs = results["songs"] as? [String: Any] {
                            if let data = songs["data"] as? NSArray {
                                for song in data {
                                    guard let songJson = song as? [String: Any] else {
                                        continue
                                    }
                                    guard let attributes = songJson["attributes"] as? [String: Any] else {
                                        continue
                                    }
                                    
                                    if (attributes["name"] as! String == songName) && (attributes["artistName"] as! String == artistName && ((attributes["durationInMillis"] as! Double) / 1000).truncate(places: 0) == songDurationInSec) {
                                        if ((attributes["contentRating"] != nil) && ((explicit && attributes["contentRating"] as! String == "explicit") || (!explicit && attributes["contentRating"] as! String == "clean"))) || attributes["contentRating"] == nil {
                                            guard let playParams = attributes["playParams"] as? [String: Any] else {
                                                continue
                                            }
                                            let id = playParams["id"] as? String
                                            return completion(id)
                                        }
                                    }
                                }
                                return completion(nil)
                            }
                        }
                    }
                }
            } catch let error {
                DispatchQueue.main.async {
                    let errorAlert = UIAlertController(title: "Error", message: "Could not parse data from Apple Music: \(error.localizedDescription)", preferredStyle: UIAlertController.Style.alert)
                    errorAlert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                }
                return
            }
        })
        task.resume()
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension String {
    func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
                String(self[substringFrom..<substringTo])
            }
        }
    }
}

extension Double{
    func truncate(places: Int)-> Double{
        return Double(floor(pow(10.0, Double(places)) * self)/pow(10.0, Double(places)))
    }
    
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
