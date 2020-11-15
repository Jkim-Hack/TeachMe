//
//  JoinViewClassController.swift
//  TeachMe
//
//  Created by John Kim on 11/15/20.
//

import UIKit
import Firebase

class JoinViewController: UIViewController {

    @IBOutlet weak var codeField : UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var joinButton: UIButton!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        AppUtility.lockOrientation(.portrait)
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        codeField.layer.cornerRadius = 25.0
        codeField.layer.borderWidth = 0.0
        codeField.layer.backgroundColor = UIColor.white.cgColor
        var frameRect = codeField.frame
        frameRect.size.height = 50 // <-- Specify the height you want here.
        codeField.frame = frameRect
        
        joinButton.layer.cornerRadius = 10.0
        signInButton.layer.cornerRadius = 10.0
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    @IBAction func onJoinPressed(sender: UIButton) {
        if let nextViewController = storyboard?.instantiateViewController(identifier: Constants.MainMenuViewControllerIdentifier) as? MainMenuViewController {
            nextViewController.modalPresentationStyle = .fullScreen
            self.present(nextViewController, animated: true)
        }
    }
    
    @IBAction func onSignInButtonPressed(sender: UIButton) {
        if let nextViewController = storyboard?.instantiateViewController(identifier: Constants.SigninViewControllerIdentifier) as? SigninViewController {
            nextViewController.modalPresentationStyle = .fullScreen
            self.present(nextViewController, animated: true)
        }
    }
    
}
