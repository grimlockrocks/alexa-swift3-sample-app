# alexa-swift3-sample-app
A sample iOS/Swift3 app that brings Alexa Voice Service on your phone. 

Features:
* Login with Amazon, using scope alexa:all
* [Alexa Voice Service (AVS) v20160207 API with HTTP/2](https://developer.amazon.com/public/solutions/alexa/alexa-voice-service/content/avs-api-overview)
* Swift 3 implementation
* TODO: Downchannel

Instructions:
* Check-out the code, modify Bundle Identifier to something you like.
* [Register](https://developer.amazon.com/avs/home.html#/) a new product with Alexa Voice Service, select product type: application. Write down your Application Type ID. 
* Create a Security Profile, create a new API key with your new Bundle Identifier under iOS Settings. Write down your Key. 
* Modify the value of APPLICATION_TYPE_ID under "Settings.swift" to use your Application Type ID. 
* Modify the value of APIKey under "info.plist" to use your API key.
* Modify the entries under "info.plist" -> URL types, replace URL Schemes -> Item 0 and URL identifier with your Bundle Identifier.
* To change parameters such as [ASR Profile](https://developer.amazon.com/public/solutions/alexa/alexa-voice-service/reference/speechrecognizer#profiles), modify the value of AUDIO_EVENT_DATA under "AlexaVoiceServiceClient.swift".

Demo 1 - Weather
* Run the app.
* Click "Push to Talk", then speak: "What's the weather?".
* Click the button again to stop recording.
* Wait for Alexa's response.

Demo 2 - Timer (Downchannel) 
* TODO

See the official AVS GitHub [here](https://github.com/alexa/alexa-avs-sample-app).
