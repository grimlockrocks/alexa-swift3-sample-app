//
//  HomeViewController.swift
//  Alexa iOS App
//
//  Created by Sheng Bi on 2/11/17.
//  Copyright © 2017 Sheng Bi. All rights reserved.
//

import UIKit
import LoginWithAmazon

class HomeViewController: UIViewController, AIAuthenticationDelegate {

    @IBOutlet weak var loginWithAmazonBtn: UIButton!
    @IBOutlet weak var logoutBtn: UIButton!
    
    let lwa = LoginWithAmazonProxy.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func onClickLoginWithAmazonBtn(_ sender: Any) {
        lwa.login(delegate: self)
    }
    
    @IBAction func onClickLogoutBtn(_ sender: Any) {
        lwa.logout(delegate: self)
    }
    
    func requestDidSucceed(_ apiResult: APIResult) {
        switch(apiResult.api) {
        case API.authorizeUser:
            print("Authorized")
            lwa.getAccessToken(delegate: self)
        case API.getAccessToken:
            print("Login successfully!")
            LoginWithAmazonToken.sharedInstance.loginWithAmazonToken = apiResult.result as! String?
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let controller = storyboard.instantiateViewController(withIdentifier: "AlexaViewController")
            self.present(controller, animated: true, completion: nil)
        case API.clearAuthorizationState:
            print("Logout successfully!")
        default:
            return
        }
    }
    
    func requestDidFail(_ errorResponse: APIError) {
        print("Error: \(errorResponse.error.message)")
    }

}

