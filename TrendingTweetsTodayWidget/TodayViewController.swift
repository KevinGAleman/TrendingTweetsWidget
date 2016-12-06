//
//  TodayViewController.swift
//  TrendingTweetsTodayWidget
//
//  Created by Kevin Aleman on 10/26/16.
//
//

import UIKit
import NotificationCenter
import Fabric
import TwitterKit
import Crashlytics
import RealmSwift

class Trend: Object {
    dynamic var name: String = ""
    dynamic var query: String = ""
    dynamic var url: String = ""
    dynamic var date: NSDate = NSDate()
    var tweets = List<Tweet>()

    convenience init(name: String, query: String, url: String) {
        self.init()
        self.name = name
        self.query = query
        self.url = url
    }
}

class Tweet: Object {
    dynamic var id: String = ""
    dynamic var text: String = ""
    dynamic var userName: String = ""
    dynamic var userScreenName: String = ""
    dynamic var userImgUrl: String = ""
    dynamic var userImg: Data? = Data()
    dynamic var date: String = ""

    convenience init(id: String, text: String, userName: String, userScreenName: String, userImgUrl: String, date: String) {
        self.init()
        self.id = id
        self.text = text
        self.userName = userName
        self.userScreenName = userScreenName
        self.userImgUrl = userImgUrl
        self.date = date
    }
}

class TodayViewController: UIViewController, NCWidgetProviding {
    
    @IBOutlet weak var trendsView: UICollectionView!
    @IBOutlet weak var loginButton: UIButton!
    
    // Twitter data properties
    var locationId: Int = 1
    var trends: [Trend] = []
    var tweets: [Tweet] = []
    var signedIn = false
    var selectedCell: TrendCell?

    // Layout and View properties
    let trendsViewHeight: CGFloat = 80.0
    let widgetMaxHeight: CGFloat = 200.0
    let numOfRows = 2
    let numOfColumns = 3
    let trendsViewSection = 0
    let tweetsViewSection = 1
    var isExpanded = false
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        Fabric.with([Crashlytics.self, Twitter.self])
        
        // If there's no active session, log the user in.
        if Twitter.sharedInstance().sessionStore.session() == nil {
            Twitter.sharedInstance().logIn { session, error in
                if (session != nil) {
                    self.signedIn = true
                    print("signed in as \(session?.userName)")
                } else {
                    print("error: \(error?.localizedDescription)")
                }
            }
        } else {
            self.signedIn = true
        }

        // Clear Realm DB of any items created earlier than one day ago.
        let realm = try! Realm()
        let yesterday = NSDate(timeIntervalSinceNow:-(24*60*60))
        let predicate = NSPredicate(format: "date < %@", yesterday)
        let itemsToDelete = realm.objects(Trend.self).filter(predicate)

        if itemsToDelete.count > 0 {
            try! realm.write {
                realm.delete(itemsToDelete)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Reload some old data from Realm so there's data in the VC before making web service calls
        let realm = try! Realm()
        trends = realm.objects(Trend.self).map { $0 }
        if let trend = trends.first {
            tweets = Array(trend.tweets)
        }
        
        // Show the login button if we're not signed in.
        loginButton.isHidden = signedIn
        
        trendsView.backgroundColor = UIColor.clear
        trendsView.backgroundView = nil
        
        extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        preferredContentSize = CGSize(width: 0.0, height: trendsViewHeight)
    }
    
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        if activeDisplayMode == .expanded {
            preferredContentSize = CGSize(width: 0.0, height: widgetMaxHeight)
            isExpanded = true
        } else if activeDisplayMode == .compact {
            resetSelectedCell()
            preferredContentSize = CGSize(width: 0.0, height: trendsViewHeight)
            isExpanded = false
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        let defaults = UserDefaults(suiteName: "group.trendingtweets.TrendingTweetsWidget")
        if let location:Int = defaults?.object(forKey: "locationId") as? Int {
            self.locationId = location
        }
        
        getTrendingTweets()
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        completionHandler(NCUpdateResult.newData)
    }
    
    func getTrendingTweets() {
        let client = TWTRAPIClient.init(userID: Twitter.sharedInstance().sessionStore.session()?.userID)
        let trendsEndpoint = "https://api.twitter.com/1.1/trends/place.json"
        
        let params = ["id" : String(describing: locationId)]
        var clientError : NSError?
        
        let request = client.urlRequest(withMethod: "GET", url: trendsEndpoint, parameters: params, error: &clientError)
        
        client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
            if connectionError != nil {
                print("Error: \(connectionError)")
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: []) as! [[String: Any?]]
                let data = json[0] as [String: Any?]
                
                if data.count >= 1, let trendJSON = data["trends"] as? [[String: Any?]] {
                    self.trends.removeAll()

                    let realm = try! Realm()
                    var newTrends: [Trend] = []
                    for trend in trendJSON {
                        if let name = trend["name"] as? String, let query = trend["query"] as? String, let url = trend["url"] as? String {
                            let newTrend = Trend.init(name: name, query: query, url: url)
                            self.trends.append(newTrend)

                            // If we've already saved this trend before, don't save it again.
                            let nameSearch = NSPredicate(format: "name == %@", name)
                            let savedObjects = realm.objects(Trend.self).filter(nameSearch)
                            if savedObjects.count == 0 {
                                newTrends.append(newTrend)
                            }
                        }

                        // Save the new trend data to Realm.
                        try! realm.write {
                            realm.add(newTrends)
                        }
                    }
                }
                
                self.trendsView.reloadSections(IndexSet.init(integer: self.trendsViewSection))
            } catch let jsonError as NSError {
                print("json error: \(jsonError.localizedDescription)")
            }
        }
    }
}

extension TodayViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == trendsViewSection {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "trendCell", for: indexPath) as! TrendCell
            
            cell.label.text = trends[indexPath.row].name
            
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tweetCell", for: indexPath) as! TweetCell
            
            if tweets.count > 0 {
                cell.userName.text = tweets[0].userName
                cell.userScreenName.text = "@\(tweets[0].userScreenName)"
                cell.text.text = tweets[0].text
                if let url = URL.init(string: tweets[0].userImgUrl) {
                    cell.userImage.downloadedFrom(url: url)
                }
            }
            
            return cell
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
        
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == trendsViewSection {
            let totalToShow = numOfRows * numOfColumns
            return trends.count > totalToShow ? totalToShow : trends.count
        } else {
            return tweets.count > 0 ? 1 : 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.5
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == trendsViewSection {
            // Width or Height minus number of separators, divided by number of rows or columns
            let width = (collectionView.bounds.width - CGFloat(numOfColumns)) / CGFloat(numOfColumns)
            let height = (trendsViewHeight - CGFloat(numOfRows)) / CGFloat(numOfRows)
            
            return CGSize(width: width, height: height)
        } else {
            let width = collectionView.bounds.width
            let height =  widgetMaxHeight - trendsViewHeight
            return CGSize(width: width, height: height)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == trendsViewSection {
            if isExpanded {
                // Change the background color for the new selected cell.
                resetSelectedCell()
                if let cell = collectionView.cellForItem(at: indexPath) as? TrendCell {
                    cell.backgroundColor = UIColor.init(white: 1.0, alpha: 0.25)
                    selectedCell = cell
                }

                // Clear the current tweets array to make room for the Realm or web response array.
                self.tweets.removeAll()

                let realm = try! Realm()
                let trend = trends[indexPath.row]
                let nameSearch = NSPredicate(format: "name == %@", trend.name)
                let savedTrends = realm.objects(Trend.self).filter(nameSearch)
                let savedTrend = savedTrends.first

                var needsUpdate = true

                // If we've saved these tweets, then don't query them again.
                if savedTrend != nil {
                    if let trend = savedTrends.first {
                        if trend.tweets.count > 0 {
                            needsUpdate = false
                            tweets = Array(trend.tweets)
                        }
                    }
                }

                if needsUpdate {
                    let client = TWTRAPIClient.init(userID: Twitter.sharedInstance().sessionStore.session()?.userID)
                    let tweetsEndpoint = "https://api.twitter.com/1.1/search/tweets.json"

                    let params = ["q" : trend.query]
                    var clientError : NSError?

                    let request = client.urlRequest(withMethod: "GET", url: tweetsEndpoint, parameters: params, error: &clientError)

                    client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
                        if connectionError != nil {
                            print("Error: \(connectionError)")
                        }

                        do {
                            let json = try JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any?]

                            if  let tweetsJSON = json["statuses"] as? [[String: Any?]] {
                                for tweet in tweetsJSON {
                                    if let user = tweet["user"] as? [String: Any?] {
                                        if let id = tweet["id_str"] as? String,
                                            let text = tweet["text"] as? String,
                                            let userName = user["name"] as? String,
                                            let userScreenName = user["screen_name"] as? String,
                                            let imgUrl = user["profile_image_url_https"] as? String,
                                            let date = tweet["created_at"] as? String {
                                            let newTweet = Tweet(id: id, text: text, userName: userName, userScreenName: userScreenName, userImgUrl: imgUrl, date: date)
                                            self.tweets.append(newTweet)
                                        }
                                    }
                                }

                                // Save the tweets to Realm.
                                if savedTrend != nil {
                                    try! realm.write {
                                        for tweet in self.tweets {
                                            savedTrend!.tweets.append(tweet)
                                        }
                                    }
                                }
                            }
                        } catch let jsonError as NSError {
                            print("json error: \(jsonError.localizedDescription)")
                        }
                    }
                }

                self.trendsView.reloadSections(IndexSet.init(integer: self.tweetsViewSection))
            } else {
                if let url = URL.init(string: trends[indexPath.row].url) {
                    extensionContext?.open(url, completionHandler: nil)
                }
            }
        }
    }
    
    func resetSelectedCell() {
        // Clear the old selected cell
        if let selected = selectedCell {
            selected.backgroundColor = UIColor.clear
        }
    }
}

extension UIImageView {
    func downloadedFrom(url: URL, contentMode mode: UIViewContentMode = .scaleAspectFit) {
        contentMode = mode
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
                else { return }
            DispatchQueue.main.async() { () -> Void in
                self.image = image
            }
            }.resume()
    }
    func downloadedFrom(link: String, contentMode mode: UIViewContentMode = .scaleAspectFit) {
        guard let url = URL(string: link) else { return }
        downloadedFrom(url: url, contentMode: mode)
    }
}
