# alexa-swift3-sample-app
A sample iOS/Swift3 app that brings Alexa Voice Service to your phone. 

Disclaimer: This repository is not affiliated with, maintained, authorized, endorsed or sponsored by Amazon or any of its affiliates. Please use it as an example to learn Alexa Voice Service. The code is not production level, rather, a prototype that demonstrates the capability of Alexa. Please refer to the official instructions from the [website](https://developer.amazon.com/alexa-voice-service). 

Features:
* Login with Amazon, using scope alexa:all
* [Alexa Voice Service (AVS) v20160207 API with HTTP/2](https://developer.amazon.com/public/solutions/alexa/alexa-voice-service/content/avs-api-overview)
* Downchannel implementation on Timer (only SetAlert)
* Swift 3 implementation
* [Snowboy](https://github.com/grimlockrocks/kitt-snowboy-swift3-sample-app) wake word
* Bluetooth audio input/output through hands-free profile

Instructions:
* Check-out the code, modify Bundle Identifier to something you like.
* [Register](https://developer.amazon.com/avs/home.html#/) a new product with Alexa Voice Service, select product type: application. Write down your Application Type ID. 
* Create a Security Profile, create a new API key with your new Bundle Identifier under iOS Settings. Write down your Key. 
* Modify the value of APPLICATION_TYPE_ID under "Settings.swift" to use your Application Type ID. 
* Modify the value of APIKey under "info.plist" to use your API key.
* Modify the entries under "info.plist" -> URL types, replace URL Schemes -> Item 0 and URL identifier with your Bundle Identifier. Note that CFBundleURLSchemes needs to have prefix "amzn-".
* To change parameters such as [ASR Profile](https://developer.amazon.com/public/solutions/alexa/alexa-voice-service/reference/speechrecognizer#profiles), modify the value of AUDIO_EVENT_DATA under "AlexaVoiceServiceClient.swift".

Demo 1 - Ping
* Run the app.
* Click "Ping", then you will see "Ping Success!".

Demo 2 - Weather (or any question)
* Run the app.
* Click "Push to Talk", then speak: "What's the weather?".
* Click the button again to stop recording.
* Wait for Alexa's response.

Demo 3 - Timer (Downchannel) 
* Run the app.
* Click "Start Downchannel & Synchronize State, wait for "Sync Success!".
* Click "Push to Talk", then speak: "Set a timer for 10 seconds".
* Wait for 10 seconds, then you will see "Time is up!".

Demo 4 - Wake Word "Alexa"
* Run the app.
* Click "Start Wake Word".
* Say "Alexa", once the wake word is succesfully detected, you will see "Alexa is listening". Then say "What day is it today?".
* You will see "Waiting for Alexa to respond...". 
* Finetune the values in Settings.swift, namely: SENSITIVITY for wake word detection; SILENCE_THRESHOLD for when to stop recording and send the audio to Alexa. 
* There are several improvements you can do to improve wake word accuracy, e.g. audio buffer size. This demo is more or less a proof of concept. 

See the official AVS GitHub [here](https://github.com/alexa/alexa-avs-sample-app).
