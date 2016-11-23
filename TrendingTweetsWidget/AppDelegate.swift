//
//  AppDelegate.swift
//  TrendingTweetsWidget
//
//  Created by Kevin Aleman on 10/24/16.
//
//

import UIKit
import Fabric
import TwitterKit
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        Fabric.with([Crashlytics.self, Twitter.self])

        return true
    }
}

