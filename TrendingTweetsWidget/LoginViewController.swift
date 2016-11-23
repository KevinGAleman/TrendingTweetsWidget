//
//  ViewController.swift
//  TrendingTweetsWidget
//
//  Created by Kevin Aleman on 10/24/16.
//
//

import UIKit
import TwitterKit
import CoreLocation

class LoginViewController: UIViewController {
    
    @IBOutlet weak var loginButton: UIButton!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Configure the button.
        loginButton.layer.cornerRadius = 10.0
        
        // If the user is already logged in, move on to the next screen.
        if Twitter.sharedInstance().sessionStore.session() != nil {
            self.performSegue(withIdentifier: "loggedIn", sender: nil)
        }
    }
    
    @IBAction func loginPressed() {
        Twitter.sharedInstance().logIn(completion: { (session, error) in
            if session != nil {
                self.performSegue(withIdentifier: "loggedIn", sender: nil)
            } else if let error = error {
                NSLog("Login error: %@", error.localizedDescription);
            }
        })
    }
}
