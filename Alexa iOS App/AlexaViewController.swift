//
//  AlexaViewController.swift
//  Alexa iOS App
//
//  Created by Sheng Bi on 2/12/17.
//  Copyright © 2017 Sheng Bi. All rights reserved.
//

import UIKit
import AVFoundation

class AlexaViewController: UIViewController, AVAudioPlayerDelegate {
    
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var pingBtn: UIButton!
    @IBOutlet weak var startDownchannelBtn: UIButton!
    @IBOutlet weak var pushToTalkBtn: UIButton!
    
    private var isRecording = false
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder!
    private var audioPlayer: AVAudioPlayer?
    
    private var avsClient = AlexaVoiceServiceClient()
    private var speakToken: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = directory.appendingPathComponent(Settings.Audio.TEMP_FILE_NAME)
            try audioRecorder = AVAudioRecorder(url: fileURL, settings: Settings.Audio.RECORDING_SETTING as [String : AnyObject])
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            audioRecorder.prepareToRecord()
        } catch let ex {
            print("Audio session has an error: \(ex.localizedDescription)")
        }
        
        avsClient.pingHandler = self.pingHandler
        avsClient.syncHandler = self.syncHandler
        avsClient.directiveHandler = self.directiveHandler
        avsClient.downchannelHandler = self.downchannelHandler
    }
    
    @IBAction func onClickPingBtn(_ sender: Any) {
        avsClient.ping()
    }
    
    @IBAction func onClickStartDownchannelBtn(_ sender: Any) {
        avsClient.startDownchannel()
    }
    
    @IBAction func onClickPushToTalkBtn(_ sender: Any) {
        
        if (!self.isRecording) {
            audioRecorder.record()
            
            self.isRecording = true
            pushToTalkBtn.setTitle("Recording, click to stop", for: .normal)
        } else {
            audioRecorder.stop()
            
            self.isRecording = false
            pushToTalkBtn.setTitle("Push to Talk", for: .normal)

            do {
                try avsClient.postRecording(audioData: Data(contentsOf: audioRecorder.url))
            } catch let ex {
                print("AVS Client threw an error: \(ex.localizedDescription)")
            }
        }
    }
    
    func pingHandler(isSuccess: Bool) {
        DispatchQueue.main.async { () -> Void in
            if (isSuccess) {
                self.infoLabel.text = "Ping success!"
            } else {
                self.infoLabel.text = "Ping failure!"
            }
        }
    }
    
    func syncHandler(isSuccess: Bool) {
        DispatchQueue.main.async { () -> Void in
            if (isSuccess) {
                self.infoLabel.text = "Sync success!"
            } else {
                self.infoLabel.text = "Sync failure!"
            }
        }
    }
    
    func directiveHandler(directives: [DirectiveData]) {
        // Store the token for directive "Speak"
        for directive in directives {
            if (directive.contentType == "application/json") {
                do {
                    let jsonData = try JSONSerialization.jsonObject(with: directive.data) as! [String:Any]
                    let directiveJson = jsonData["directive"] as! [String:Any]
                    let header = directiveJson["header"] as! [String:String]
                    if (header["name"] == "Speak") {
                        let payload = directiveJson["payload"] as! [String:String]
                        self.speakToken = payload["token"]!
                    }
                } catch let ex {
                    print("Directive data has an error: \(ex.localizedDescription)")
                }
            }
        }
        
        // Play the audio
        for directive in directives {
            if (directive.contentType == "application/octet-stream") {
                DispatchQueue.main.async { () -> Void in
                    self.infoLabel.text = "Alexa is speaking"
                }
                do {
                    self.avsClient.sendEvent(namespace: "SpeechSynthesizer", name: "SpeechStarted", token: self.speakToken!)
                    
                    try self.audioPlayer = AVAudioPlayer(data: directive.data)
                    self.audioPlayer!.delegate = self
                    self.audioPlayer!.prepareToPlay()
                    self.audioPlayer!.play()
                } catch let ex {
                    print("Audio player has an error: \(ex.localizedDescription)")
                }
            }
        }
    }
    
    func downchannelHandler(directive: String) {
        
        do {
            let jsonData = try JSONSerialization.jsonObject(with: directive.data(using: String.Encoding.utf8)!) as! [String:Any]
            let directiveJson = jsonData["directive"] as! [String:Any]
            let header = directiveJson["header"] as! [String:String]
            if (header["name"] == "StopCapture") {
                // Handle StopCapture
            } else if (header["name"] == "SetAlert") {
                // Handle SetAlert
                let payload = directiveJson["payload"] as! [String:String]
                let scheduledTime = payload["scheduledTime"]
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                dateFormatter.locale = Locale.init(identifier: "en_US")
                let futureDate = dateFormatter.date(from: scheduledTime!)
                
                let numberOfSecondsDiff = Calendar.current.dateComponents([.second], from: Date(), to: futureDate!).second ?? 0
            
                DispatchQueue.main.async { () -> Void in
                    Timer.scheduledTimer(timeInterval: TimeInterval(numberOfSecondsDiff),
                                         target: self,
                                         selector: #selector(self.timerStart),
                                         userInfo: nil,
                                         repeats: false)
                }
                
                print("Downchannel SetAlert scheduledTime: \(scheduledTime!); \(numberOfSecondsDiff) seconds from now.")
            }
        } catch let ex {
            print("Downchannel error: \(ex.localizedDescription)")
        }
    }
    
    func timerStart() {
        print("Timer trigger")
        DispatchQueue.main.async { () -> Void in
            self.infoLabel.text = "Time is up!"
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio player is finished playing")
        self.infoLabel.text = "Alexa iOS Demo"
        
        self.avsClient.sendEvent(namespace: "SpeechSynthesizer", name: "SpeechFinished", token: self.speakToken!)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player has an error: \(error?.localizedDescription)")
    }

}


