//
//  GameViewController.swift
//  CookieCrunch
//
//  Created by Anton Novoselov on 29/06/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

import UIKit
import SpriteKit
import AVFoundation
import GoogleMobileAds
import StoreKit

class GameViewController: UIViewController, GADBannerViewDelegate, GADInterstitialDelegate {
    
    // MARK: - OUTLETS
    
    @IBOutlet weak var targetLabel: UILabel!
    @IBOutlet weak var movesLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var gameOverPanel: UIImageView!
    @IBOutlet weak var shuffleButton: UIButton!
    
    @IBOutlet weak var removeAdsButton: UIButton!
    @IBOutlet weak var restorePurchasesButton: UIButton!
    
    // MARK: - PROPERTIES
    
    var scene: GameScene!
    
    var level: Level!
    var currentLevelNum = 1
    
    var movesLeft = 0
    var score = 0
    
    var tapGestureRecognizer: UITapGestureRecognizer!
    
    lazy var backgroundMusic: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "Mining by Moonlight", withExtension: "mp3") else {
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            return player
        } catch {
            return nil
        }
    }()
    
    var bannerView: GADBannerView?
    var interstitial: GADInterstitial?
    var adCount = 0
    
    var adsRemoved = false
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait, .portraitUpsideDown]
    }

    
    // MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup view with level 1
        setupLevel(currentLevelNum)
        
        // Start the background music.
        //        backgroundMusic?.play()
        
        
        adsRemoved = UserDefaults.standard.bool(forKey: "removeAds")
        
        if !adsRemoved {
            
            if USE_INTERSTITIAL {
                self.createInterstitial()
            }
            
            if USE_BANNER {
                self.createBanner()
            }
        }
        
        adjustAlpha()
        
        toggleAdsButtons()
        
    }
    
    // MARK: - HELPER METHODS
    
    func toggleAdsButtons() {
        removeAdsButton.isHidden = adsRemoved
        restorePurchasesButton.isHidden = adsRemoved
    }
    
    func adjustAlpha() {
        
        let targetAlpha: CGFloat = 0.8
        
        targetLabel.alpha = targetAlpha
        movesLabel.alpha = targetAlpha
        scoreLabel.alpha = targetAlpha
        removeAdsButton.alpha = targetAlpha
        restorePurchasesButton.alpha = targetAlpha
        shuffleButton.alpha = targetAlpha
        
    }
    
    // MARK: - GOOGLE ADMOB
    func createBanner() {
        self.bannerView = GADBannerView(frame: CGRect(x: 0, y: self.view.frame.size.height - kGADAdSizeBanner.size.height, width: kGADAdSizeBanner.size.width, height: kGADAdSizeBanner.size.height))
        
        self.bannerView?.adUnitID = ADMOB_AD_UNIT_BANNER_ID
        self.bannerView?.rootViewController = self
        self.bannerView?.delegate = self
        
        let request = GADRequest()
        request.testDevices = [kGADSimulatorID, ADMOB_TEST_DEVICE_ID]
        self.bannerView?.load(request)
        
        self.bannerView?.center = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.maxY - (self.bannerView?.bounds.midY)!)
        
        self.view.addSubview(bannerView!)
    }
    
    func createInterstitial() {
        
        self.interstitial = GADInterstitial(adUnitID: ADMOB_AD_UNIT_INTERSTITIAL_ID)
        
        self.interstitial?.delegate = self
        
        let request = GADRequest()
        request.testDevices = [kGADSimulatorID, ADMOB_TEST_DEVICE_ID]
        
        self.interstitial?.load(request)
    }
    
    func presentInterstitial() {
        if !adsRemoved && (self.interstitial?.isReady)! && USE_INTERSTITIAL {
            self.interstitial?.present(fromRootViewController: self)
        } else {
            print("Not ready/ads disabled")
        }
    }
    
    
    // MARK: - GAME METHODS
    
    func setupLevel(_ levelNum: Int) {
        let skView = view as! SKView
        skView.isMultipleTouchEnabled = false
        
        // Create and configure the scene.
        scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .aspectFill
        
        // Setup the level.
        level = Level(filename: "Level_\(levelNum)")
        scene.level = level
        
        scene.addTiles()
        scene.swipeHandler = handleSwipe
        
        gameOverPanel.isHidden = true
        shuffleButton.isHidden = true
        
        // Present the scene.
        skView.presentScene(scene)
        
        // Start the game.
        beginGame()
    }
    
    func beginGame() {
        movesLeft = level.maximumMoves
        score = 0
        updateLabels()
        
        level.resetComboMultiplier()
        
        scene.animateBeginGame() {
            self.shuffleButton.isHidden = false
        }
        
        shuffle()
    }
    
    func shuffle() {
        scene.removeAllCookieSprites()
        
        // Fill up the level with new cookies, and create sprites for them.
        let newCookies = level.shuffle()
        scene.addSprites(for: newCookies)
    }
    
    // This is the swipe handler. MyScene invokes this function whenever it
    // detects that the player performs a swipe.
    func handleSwipe(_ swap: Swap) {
        // While cookies are being matched and new cookies fall down to fill up
        // the holes, we don't want the player to tap on anything.
        view.isUserInteractionEnabled = false
        
        if level.isPossibleSwap(swap) {
            level.performSwap(swap)
            scene.animate(swap: swap, completion: handleMatches)
        } else {
            scene.animateInvalidSwap(swap) {
                self.view.isUserInteractionEnabled = true
            }
        }
    }
    
    func beginNextTurn() {
        level.resetComboMultiplier()
        level.detectPossibleSwaps()
        view.isUserInteractionEnabled = true
        
        decrementMoves()
    }
    
    func handleMatches() {
        // Detect if there are any matches left.
        let chains = level.removeMatches()
        
        // If there are no more matches, then the player gets to move again.
        if chains.count == 0 {
            beginNextTurn()
            return
        }
        
        scene.animateMatchedCookies(for: chains) {
            
            // Add the new scores to the total.
            for chain in chains {
                self.score += chain.score
            }
            self.updateLabels()
            
            // ...then shift down any cookies that have a hole below them...
            let columns = self.level.fillHoles()
            self.scene.animateFallingCookiesFor(columns: columns) {
                
                // ...and finally, add new cookies at the top.
                let columns = self.level.topUpCookies()
                self.scene.animateNewCookies(columns) {
                    
                    // Keep repeating this cycle until there are no more matches.
                    self.handleMatches()
                }
            }
        }
    }
    
    func updateLabels() {
        targetLabel.text = String(format: "%ld", level.targetScore)
        movesLabel.text = String(format: "%ld", movesLeft)
        scoreLabel.text = String(format: "%ld", score)
    }
    
    func decrementMoves() {
        movesLeft -= 1
        updateLabels()
        
        if score >= level.targetScore {
            gameOverPanel.image = UIImage(named: "LevelComplete")
            // Increment the current level, go back to level 1 if the current level
            // is the last one.
            currentLevelNum = currentLevelNum < NumLevels ? currentLevelNum+1 : 1
            showGameOver()
        } else if movesLeft == 0 {
            gameOverPanel.image = UIImage(named: "GameOver")
            showGameOver()
        }
    }
    
    func showGameOver() {
        gameOverPanel.isHidden = false
        shuffleButton.isHidden = true
        scene.isUserInteractionEnabled = false
        
        scene.animateGameOver() {
            self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.hideGameOver))
            self.view.addGestureRecognizer(self.tapGestureRecognizer)
        }
    }
    
    @objc func hideGameOver() {
        view.removeGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer = nil
        
        gameOverPanel.isHidden = true
        scene.isUserInteractionEnabled = true
        
        if !adsRemoved {
            adCount += 1
            if adCount == ADMOB_INTERSTITIAL_RATE {
                adCount = 0
                self.presentInterstitial()
            }
        }
        
        setupLevel(currentLevelNum)
    }
    
    // MARK: - ACTIONS
    @IBAction func shuffleButtonPressed(_: AnyObject) {
        shuffle()
        
        decrementMoves()
    }
    
    @IBAction func removeAdsButtonPressed(_ sender: UIButton) {
        //Requesting purchase
        if SKPaymentQueue.canMakePayments() {
            let productsRequest = SKProductsRequest(productIdentifiers: [REMOVE_ADS_ID])
            productsRequest.delegate = self
            
            productsRequest.start()
        } else {
            self.showAlert("Error purchasing", isError: true)
        }
    }
    
    @IBAction func restorePurchasesButtonPressed(_ sender: UIButton) {
        //When restore is initiated
        SKPaymentQueue.default().add(self)
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
}


extension GameViewController: SKPaymentTransactionObserver, SKProductsRequestDelegate {
    
    func showAlert(_ message: String, isError: Bool) {
        //Show info/error alert
        let alert = UIAlertController(title: isError ? "Error" : "Info", message: message, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    func removeAds() {
        self.showAlert("Thanks for your purchase! Ads are now removed", isError: false)
        
        UserDefaults.standard.set(true, forKey: "removeAds")
        UserDefaults.standard.synchronize()
        
        adsRemoved = true
        
        toggleAdsButtons()
        
        self.bannerView?.removeFromSuperview()
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                self.removeAds()
                SKPaymentQueue.default().finishTransaction(transaction)
                break
                
            case .restored:
                self.removeAds()
                SKPaymentQueue.default().finishTransaction(transaction)
                break
                
            case .failed:
                guard let error = transaction.error as? SKError else {return}
                
                if error.code == .paymentCancelled {
                    self.showAlert("Purchase was cancelled", isError: false)
                }
                SKPaymentQueue.default().finishTransaction(transaction)
                break
            default: break
            }
        }
    }
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        //Find the product requested
        var validProduct: SKProduct? = nil
        let count = Int(response.products.count)
        
        if count > 0 {
            validProduct = response.products[0]
            self.purchase(validProduct!)
        } else if validProduct == nil {
            self.showAlert("An error with purchasing the bottle occurred", isError: true)
            print("No products available!")
        }
        
    }
    
    func purchase(_ product: SKProduct) {
        //Start payment transaction
        let payment = SKPayment(product: product)
        
        SKPaymentQueue.default().add(self)
        SKPaymentQueue.default().add(payment)
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        //Restore
        
        for transaction in queue.transactions {
            if transaction.transactionState == .restored {
                self.removeAds()
                SKPaymentQueue.default().finishTransaction(transaction)
                break
            }
        }
    }

}

