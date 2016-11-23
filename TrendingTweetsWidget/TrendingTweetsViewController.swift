//
//  SettingsViewController.swift
//  TrendingTweetsWidget
//
//  Created by Kevin Aleman on 10/26/16.
//
//

import Foundation
import CoreLocation
import UIKit
import TwitterKit


class TrendingTweetsViewController: UIViewController {
    
    var locationManager: CLLocationManager?
    var currentLocation: CLLocation?
    var locationId: Int = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager = CLLocationManager()
        
        // Ask for location Authorization from the User.
        locationManager!.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager!.delegate = self
            locationManager!.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager!.startUpdatingLocation()
        }
    }
}

extension TrendingTweetsViewController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if currentLocation == nil ||
            (locations[0].coordinate.latitude != currentLocation?.coordinate.latitude &&
                locations[0].coordinate.longitude != currentLocation?.coordinate.longitude) {
            currentLocation = locations[0]
            
            updateClosestTweetsLocation()
        }
    }
    
    func updateClosestTweetsLocation() {
        if let location = currentLocation {
            let client = TWTRAPIClient.init(userID: Twitter.sharedInstance().sessionStore.session()?.userID)
            let trendsEndpoint = "https://api.twitter.com/1.1/trends/closest.json"
            
            let params = ["lat" : String(describing: location.coordinate.latitude), "long" : String(describing: location.coordinate.longitude)]
            var clientError : NSError?
            
            let request = client.urlRequest(withMethod: "GET", url: trendsEndpoint, parameters: params, error: &clientError)
            
            client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
                if connectionError != nil {
                    print("Error: \(connectionError)")
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: [])
                    if let locations = json as? [[String: Any]] {
                        if let woeId = locations[0]["woeid"] as? Int {
                            self.locationId = woeId
                            print("New location nearby: \(woeId)")
                            
                            // Write the location ID to disk so it can be accessed by the Widget
                            let defaults = UserDefaults(suiteName: "group.trendingtweets.TrendingTweetsWidget")
                            defaults?.set(woeId, forKey: "locationId")
                            // tell the defaults to write to disk now
                            defaults?.synchronize()
                        }
                    }
                } catch let jsonError as NSError {
                    print("json error: \(jsonError.localizedDescription)")
                }
            }
        }
    }
}
