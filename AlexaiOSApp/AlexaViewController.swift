//
//  AlexaViewController.swift
//  Alexa iOS App
//
//  Created by Sheng Bi on 2/12/17.
//  Copyright © 2017 Sheng Bi. All rights reserved.
//

import UIKit
import AVFoundation

class AlexaViewController: UIViewController, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var pingBtn: UIButton!
    @IBOutlet weak var startDownchannelBtn: UIButton!
    @IBOutlet weak var pushToTalkBtn: UIButton!
    @IBOutlet weak var wakeWordBtn: UIButton!
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder!
    private var audioPlayer: AVAudioPlayer!
    private var isRecording = false
    
    private var avsClient = AlexaVoiceServiceClient()
    private var speakToken: String?
    
    private var snowboy: SnowboyWrapper!
    private var snowboyTimer: Timer!
    private var snowboyTempSoundFileURL: URL!
    private var stopCaptureTimer: Timer!
    private var isListening = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        snowboy = SnowboyWrapper(resources: Settings.WakeWord.RESOURCE, modelStr: Settings.WakeWord.MODEL)
        snowboy.setSensitivity(Settings.WakeWord.SENSITIVITY)
        snowboy.setAudioGain(Settings.WakeWord.AUDIO_GAIN)
        
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
        
        if (self.isRecording) {
            audioRecorder.stop()
            
            self.isRecording = false
            pushToTalkBtn.setTitle("Push to Talk", for: .normal)
            
            do {
                try avsClient.postRecording(audioData: Data(contentsOf: audioRecorder.url))
            } catch let ex {
                print("AVS Client threw an error: \(ex.localizedDescription)")
            }
        } else {
            prepareAudioSession()
            
            audioRecorder.prepareToRecord()
            audioRecorder.record()
            
            self.isRecording = true
            pushToTalkBtn.setTitle("Recording, click to stop", for: .normal)
        }
    }
    
    @IBAction func onClickWakeWordBtn(_ sender: Any) {
        
        if (self.isListening) {
            self.isListening = false
            wakeWordBtn.setTitle("Start Wake Word", for: .normal)

            snowboyTimer.invalidate()
        } else {
            self.isListening = true
            wakeWordBtn.setTitle("Listening, click to stop", for: .normal)
            
            prepareAudioSessionForWakeWord()
            
            snowboyTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(startListening), userInfo: nil, repeats: true)
        }

    }
    
    func prepareAudioSession() {
        
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = directory.appendingPathComponent(Settings.Audio.TEMP_FILE_NAME)
            try audioRecorder = AVAudioRecorder(url: fileURL, settings: Settings.Audio.RECORDING_SETTING as [String : AnyObject])
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:[AVAudioSessionCategoryOptions.allowBluetooth, AVAudioSessionCategoryOptions.allowBluetoothA2DP])
        } catch let ex {
            print("Audio session has an error: \(ex.localizedDescription)")
        }
    }
    
    func prepareAudioSessionForWakeWord() {
        
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            snowboyTempSoundFileURL = directory.appendingPathComponent(Settings.WakeWord.TEMP_FILE_NAME)
            try audioRecorder = AVAudioRecorder(url: snowboyTempSoundFileURL, settings: Settings.Audio.RECORDING_SETTING as [String : AnyObject])
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            audioRecorder.delegate = self
        } catch let ex {
            print("Audio session for wake word has an error: \(ex.localizedDescription)")
        }
    }
    
    @objc func startListening() {
        
        audioRecorder.record(forDuration: 1.0)
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
                    
                    try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:[AVAudioSessionCategoryOptions.allowBluetooth, AVAudioSessionCategoryOptions.allowBluetoothA2DP])
                    do {
                        try audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
                    } catch let error as NSError {
                        print("audioSession error: \(error.localizedDescription)")
                    }
                    try self.audioPlayer = AVAudioPlayer(data: directive.data)
                    self.audioPlayer.delegate = self
                    self.audioPlayer.prepareToPlay()
                    self.audioPlayer.play()
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
    
    @objc func timerStart() {
        print("Timer is triggered")
        DispatchQueue.main.async { () -> Void in
            self.infoLabel.text = "Time is up!"
        }
    }
    
    func runSnowboy() {
        
        let file = try! AVAudioFile(forReading: snowboyTempSoundFileURL)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000.0, channels: 1, interleaved: false)
        let buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(file.length))
        try! file.read(into: buffer!)
        let array = Array(UnsafeBufferPointer(start: buffer?.floatChannelData![0], count:Int(buffer!.frameLength)))
        
        let result = snowboy.runDetection(array, length: Int32(buffer!.frameLength))
        print("Snowboy result: \(result)")
        
        // Wake word matches
        if (result == 1) {
            DispatchQueue.main.async { () -> Void in
                self.infoLabel.text = "Alexa is listening"
            }
            
            prepareAudioSession()
            
            audioRecorder.isMeteringEnabled = true
            audioRecorder.record()
            stopCaptureTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(checkAudioMetering), userInfo: nil, repeats: true)
        } else {
            DispatchQueue.main.async { () -> Void in
                self.infoLabel.text = "Say Alexa"
            }
        }
    }
    
    @objc func checkAudioMetering() {
        
        audioRecorder.updateMeters()
        let power = audioRecorder.averagePower(forChannel: 0)
        print("Average power: \(power)")
        if (power < Settings.Audio.SILENCE_THRESHOLD) {
            
            DispatchQueue.main.async { () -> Void in
                self.infoLabel.text = "Waiting for Alexa to respond..."
            }
            
            stopCaptureTimer.invalidate()
            snowboyTimer.invalidate()
            audioRecorder.stop()
            
            do {
                try avsClient.postRecording(audioData: Data(contentsOf: audioRecorder.url))
            } catch let ex {
                print("AVS Client threw an error: \(ex.localizedDescription)")
            }
            
            prepareAudioSessionForWakeWord()
            snowboyTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(startListening), userInfo: nil, repeats: true)
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio player is finished playing")
        self.infoLabel.text = "Alexa iOS Demo"
        
        self.avsClient.sendEvent(namespace: "SpeechSynthesizer", name: "SpeechFinished", token: self.speakToken!)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player has an error: \(String(describing: error?.localizedDescription))")
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("Audio recorder is finished recording")
        runSnowboy()
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio recorder has an error: \(String(describing: error?.localizedDescription))")
    }
}


