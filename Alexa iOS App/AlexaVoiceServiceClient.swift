//
//  AlexaVoiceServiceClient.swift
//  Alexa iOS App
//
//  Created by Sheng Bi on 2/18/17.
//  Copyright © 2017 Sheng Bi. All rights reserved.
//
//  This client uses HTTP/2 and API v20160207
//  Ref: https://developer.amazon.com/public/solutions/alexa/alexa-voice-service/content/avs-api-overview
//

import Foundation

struct DirectiveData {
    var contentType: String
    var data: Data
}

class AlexaVoiceServiceClient : NSObject, URLSessionDelegate, URLSessionDataDelegate {
    
    let PING_ENDPOINT: String = "https://avs-alexa-na.amazon.com/ping"
    let DIRECTIVES_ENDPOINT = "https://avs-alexa-na.amazon.com/v20160207/directives"
    let EVENTS_ENDPOINT: String = "https://avs-alexa-na.amazon.com/v20160207/events"
    
    let TIMEOUT = 3600 // 60 minutes per AVS recommendation
    let BOUNDARY_TERM = "CUSTOM_BOUNDARY_TERM"
    let SYNC_EVENT_DATA = "{ \"event\" : { \"header\" : { \"namespace\" : \"System\", \"name\" : \"SynchronizeState\", \"messageId\" : \"1\" }, \"payload\" : { } }, \"context\" : [ { \"header\" : { \"namespace\" : \"AudioPlayer\", \"name\" : \"PlaybackState\" }, \"payload\" : { \"token\" : \"\", \"offsetInMilliseconds\" : 0, \"playerActivity\" : \"IDLE\" } }, { \"header\" : { \"namespace\" : \"SpeechSynthesizer\", \"name\" : \"SpeechState\" }, \"payload\" : { \"token\" : \"\", \"offsetInMilliseconds\" : 0, \"playerActivity\" : \"FINISHED\" } }, { \"header\" : { \"namespace\" : \"Alerts\", \"name\" : \"AlertsState\" }, \"payload\" : { \"allAlerts\" : [ ], \"activeAlerts\" : [ ] } }, { \"header\" : { \"namespace\" : \"Speaker\", \"name\" : \"VolumeState\" }, \"payload\" : { \"volume\" : 50, \"muted\" : false } } ] }"
    let AUDIO_EVENT_DATA = "{\"event\": {\"header\": {\"namespace\": \"SpeechRecognizer\",\"name\": \"Recognize\",\"messageId\": \"$messageId\",\"dialogRequestId\": \"$dialogRequestId\"},\"payload\": {\"profile\": \"NEAR_FIELD\", \"format\": \"AUDIO_L16_RATE_16000_CHANNELS_1\"}},\"context\": [{\"header\": {\"namespace\": \"AudioPlayer\",\"name\": \"PlaybackState\"},\"payload\": {\"token\": \"\",\"offsetInMilliseconds\": 0,\"playerActivity\": \"FINISHED\"}}, {\"header\": {\"namespace\": \"SpeechSynthesizer\",\"name\": \"SpeechState\"},\"payload\": {\"token\": \"\",\"offsetInMilliseconds\": 0,\"playerActivity\": \"FINISHED\"}}, { \"header\" : { \"namespace\" : \"Alerts\", \"name\" : \"AlertsState\" }, \"payload\" : { \"allAlerts\" : [ ], \"activeAlerts\" : [ ] } }, {\"header\": {\"namespace\": \"Speaker\",\"name\": \"VolumeState\"},\"payload\": {\"volume\": 25,\"muted\": false}}]}"
    let EVENT_DATA_TEMPLATE = "{\"event\": {\"header\": {\"namespace\": \"$namespace\",\"name\": \"$name\",\"messageId\": \"$messageId\"},\"payload\": {\"token\": \"$token\"}}}"
    
    var session: URLSession!
    
    var pingHandler: ((_ isSuccess:Bool) -> Void)?
    var syncHandler: ((_ isSuccess:Bool) -> Void)?
    var directiveHandler: ((_ directives:[DirectiveData]) -> Void)?
    var downchannelHandler: ((_ directive:String) -> Void)?
    
    override init() {
        super.init()
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpMaximumConnectionsPerHost = 1
        sessionConfig.timeoutIntervalForRequest = 30.0
        session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        print("Session created")
    }
    
    func ping() {
        
        var request = URLRequest(url: URL(string: PING_ENDPOINT)!)
        request.httpMethod = "GET"
        addAuthHeader(request: &request)
        
        session.dataTask(with: request, completionHandler: { (data:Data?, response:URLResponse?, error:Error?) -> Void in
            if (error != nil) {
                print("Ping failure: \(error?.localizedDescription)")
                self.pingHandler?(false)
            } else {
                let res = response as! HTTPURLResponse
                print("Ping status code: \(res.statusCode)")
                if (res.statusCode == 204) {
                    self.pingHandler?(true)
                } else {
                    self.pingHandler?(false)
                }
            }
        }).resume()
    }
    
    func startDownchannel() {
        
        // 1. Establish a downchannel stream
        var request = URLRequest(url: URL(string: DIRECTIVES_ENDPOINT)!)
        request.httpMethod = "GET"
        request.timeoutInterval = TimeInterval(TIMEOUT)
        addAuthHeader(request: &request)
        session.dataTask(with: request).resume()
        
        // 2. Sychronize states
        sync(jsonData: SYNC_EVENT_DATA)
        
        // 3. Send a Ping every 5 minutes
        Timer.scheduledTimer(timeInterval: 300,
                             target: self,
                             selector: #selector(ping),
                             userInfo: nil,
                             repeats: true)
    }
    
    func postRecording(audioData: Data) {

        var eventData = AUDIO_EVENT_DATA
        // Create unique message id and dialog id
        eventData = eventData.replacingOccurrences(of: "$messageId", with: UUID().uuidString)
        eventData = eventData.replacingOccurrences(of: "$dialogRequestId", with: UUID().uuidString)
        
        sendAudio(jsonData: eventData, audioData: audioData)
    }
    
    func sync(jsonData: String) {
        
        var request = URLRequest(url: URL(string: EVENTS_ENDPOINT)!)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(TIMEOUT)
        addAuthHeader(request: &request)
        addContentTypeHeader(request: &request)
        
        var bodyData = Data()
        bodyData.append(getBoundaryTermBegin())
        bodyData.append(addEventData(jsonData: jsonData))
        bodyData.append(getBoundaryTermEnd())
        
        session.uploadTask(with: request, from: bodyData, completionHandler: { (data:Data?, response:URLResponse?, error:Error?) -> Void in
            if (error != nil) {
                print("Send data error: \(error?.localizedDescription)")
                self.syncHandler?(false)
            } else {
                let res = response as! HTTPURLResponse
                print("Sync status code: \(res.statusCode)")
                if (res.statusCode != 204) {
                    let resJsonData = try! JSONSerialization.jsonObject(with: data!, options: [.allowFragments])
                    print("Sync response: \(resJsonData)")
                    self.syncHandler?(false)
                } else {
                    self.syncHandler?(true)
                }
            }
        }).resume()
    }
    
    func sendAudio(jsonData: String, audioData: Data) {

        var request = URLRequest(url: URL(string: EVENTS_ENDPOINT)!)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(TIMEOUT)
        addAuthHeader(request: &request)
        addContentTypeHeader(request: &request)
        
        var bodyData = Data()
        bodyData.append(getBoundaryTermBegin())
        bodyData.append(addEventData(jsonData: jsonData))
        bodyData.append(getBoundaryTermBegin())
        bodyData.append(addAudioData(audioData: audioData))
        bodyData.append(getBoundaryTermEnd())

        session.uploadTask(with: request, from: bodyData, completionHandler: { (data:Data?, response:URLResponse?, error:Error?) -> Void in
            if (error != nil) {
                print("Send audio error: \(error?.localizedDescription)")
            } else {
                let res = response as! HTTPURLResponse
                print("Send audio status code: \(res.statusCode)")

                if (res.statusCode >= 200 && res.statusCode <= 299) {
                    
                    if let contentTypeHeader = res.allHeaderFields["Content-Type"] {
                        let boundary = self.extractBoundary(contentTypeHeader: contentTypeHeader as! String)
                        let directives = self.extractDirectives(data: data!, boundary: boundary)
                        self.directiveHandler?(directives)
                    } else {
                        print("Content type in response is empty")
                    }
                }
            }
        }).resume()
    }
    
    func sendEvent(namespace: String, name: String, token: String) {
        
        var request = URLRequest(url: URL(string: EVENTS_ENDPOINT)!)
        request.httpMethod = "POST"
        addAuthHeader(request: &request)
        addContentTypeHeader(request: &request)

        var eventData = EVENT_DATA_TEMPLATE
        eventData = eventData.replacingOccurrences(of: "$messageId", with: UUID().uuidString)
        eventData = eventData.replacingOccurrences(of: "$namespace", with: namespace)
        eventData = eventData.replacingOccurrences(of: "$name", with: name)
        eventData = eventData.replacingOccurrences(of: "$token", with: token)

        var bodyData = Data()
        bodyData.append(getBoundaryTermBegin())
        bodyData.append(addEventData(jsonData: eventData))
        bodyData.append(getBoundaryTermEnd())
        
        session.uploadTask(with: request, from: bodyData, completionHandler: { (data:Data?, response:URLResponse?, error:Error?) -> Void in
            if (error != nil) {
                print("Send event \(namespace).\(name) error: \(error?.localizedDescription)")
            } else {
                let res = response as! HTTPURLResponse
                print("Send event \(namespace).\(name) status code: \(res.statusCode)")
            }
        }).resume()
    }
    
    fileprivate func addAuthHeader(request: inout URLRequest) {
        request.addValue("Bearer \(LoginWithAmazonToken.sharedInstance.loginWithAmazonToken!)", forHTTPHeaderField: "Authorization")
    }
    
    fileprivate func addContentTypeHeader(request: inout URLRequest) {
        request.addValue("multipart/form-data; boundary=\(BOUNDARY_TERM)", forHTTPHeaderField: "Content-Type")
    }
    
    fileprivate func addEventData(jsonData: String) -> Data {
        var bodyData = Data()
        bodyData.append("Content-Disposition: form-data; name=\"metadata\"\r\n".data(using: String.Encoding.utf8)!)
        bodyData.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: String.Encoding.utf8)!)
        bodyData.append(jsonData.data(using: String.Encoding.utf8)!)
        bodyData.append("\r\n".data(using: String.Encoding.utf8)!)
        return bodyData
    }
    
    fileprivate func addAudioData(audioData: Data) -> Data {
        var bodyData = Data()
        bodyData.append("Content-Disposition: form-data; name=\"audio\"\r\n".data(using: String.Encoding.utf8)!)
        bodyData.append("Content-Type: application/octet-stream\r\n\r\n".data(using: String.Encoding.utf8)!)
        bodyData.append(audioData)
        bodyData.append("\r\n".data(using: String.Encoding.utf8)!)
        return bodyData
    }
    
    fileprivate func getBoundaryTermBegin() -> Data {
        return "--\(BOUNDARY_TERM)\r\n".data(using: String.Encoding.utf8)!
    }
    
    fileprivate func getBoundaryTermEnd() -> Data {
        return "--\(BOUNDARY_TERM)--\r\n".data(using: String.Encoding.utf8)!
    }
    
    fileprivate func extractBoundary(contentTypeHeader: String) -> String {
        var boundary: String?
        let ctbRange = (contentTypeHeader as AnyObject).range(of: "boundary=.*?;", options: .regularExpression)
        if ctbRange.location != NSNotFound {
            let boundryNSS = (contentTypeHeader as AnyObject).substring(with: ctbRange) as NSString
            boundary = boundryNSS.substring(with: NSRange(location: 9, length: boundryNSS.length - 10))
        }
        return boundary!
    }
    
    fileprivate func extractDirectives(data: Data, boundary: String) -> [DirectiveData] {
        
        var directives = [DirectiveData]()
        
        let innerBoundry = "--\(boundary)".data(using: String.Encoding.utf8)!
        let endBoundry = "--\(boundary)--".data(using: String.Encoding.utf8)!
        let contentTypeApplicationJson = "Content-Type: application/json; charset=UTF-8".data(using: String.Encoding.utf8)!
        let contentTypeAudio = "Content-Type: application/octet-stream".data(using: String.Encoding.utf8)!
        let headerEnd = "\r\n\r\n".data(using: String.Encoding.utf8)!
        
        var startIndex = 0
        while (true) {
            let firstAppearance = data.range(of: innerBoundry, in: startIndex..<(data.count))
            if (firstAppearance == nil) {
                break
            }
            var secondAppearance = data.range(of: innerBoundry, in: (firstAppearance?.upperBound)!..<(data.count))
            if (secondAppearance == nil) {
                secondAppearance = data.range(of: endBoundry, in: (firstAppearance?.upperBound)!..<(data.count))
                if (secondAppearance == nil) {
                    break
                }
            } else {
                startIndex = (secondAppearance?.lowerBound)!
            }
            let subdata = data.subdata(in: (firstAppearance?.upperBound)!..<(secondAppearance?.lowerBound)!)
            var contentType = subdata.range(of: contentTypeApplicationJson)
            if (contentType != nil) {
                let headerRange = subdata.range(of: headerEnd)
                var directiveData = String(data: subdata.subdata(in: (headerRange?.upperBound)!..<subdata.count), encoding: String.Encoding.utf8) ?? "Directive data is not String"
                directiveData = directiveData.replacingOccurrences(of: "\r\n", with: "")
                directives.append(DirectiveData(contentType: "application/json", data: directiveData.data(using: String.Encoding.utf8)!))
                print("Directive: \(directiveData)")
            }
            contentType = subdata.range(of: contentTypeAudio)
            if (contentType != nil) {
                let headerRange = subdata.range(of: headerEnd)
                let audioData = subdata.subdata(in: (headerRange?.upperBound)!..<subdata.count)
                directives.append(DirectiveData(contentType: "application/octet-stream", data: audioData))
                print("Audio data")
            }
        }
        
        return directives
    }

    // Downchannel directives are processed here
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let dataString = String(data: data, encoding: String.Encoding.utf8) ?? "Downchannel directives data is not String"
        let firstBracket = dataString.range(of: "{")!
        let lastBracket = dataString.range(of: "}", options: .backwards)!
        let jsonString = dataString[firstBracket.lowerBound...lastBracket.upperBound]
        self.downchannelHandler?(jsonString)
    }
}
