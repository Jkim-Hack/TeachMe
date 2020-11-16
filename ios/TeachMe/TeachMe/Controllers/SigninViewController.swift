//
//  SigninViewController.swift
//  TeachMe
//
//  Created by John Kim on 11/15/20.
//

import Foundation
import Firebase

class SigninViewController : UIViewController {
    
    @IBOutlet weak var emailTextField : UITextField!
    @IBOutlet weak var passwordTextField : UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signUpButton: UIButton!
    
    var handle: AuthStateDidChangeListenerHandle?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let user = Auth.auth().currentUser {
            Globals.user = User(email: user.email ?? "", uid: user.uid)
            if let nextViewController = self.storyboard?.instantiateViewController(identifier: Constants.MainMenuViewControllerIdentifier) as? MainMenuViewController {
                nextViewController.modalPresentationStyle = .fullScreen
                self.present(nextViewController, animated: true)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        emailTextField.layer.cornerRadius = 25.0
        emailTextField.layer.borderWidth = 0.0
        emailTextField.layer.backgroundColor = UIColor.white.cgColor
        var frameRect = emailTextField.frame
        frameRect.size.height = 50 // <-- Specify the height you want here.
        emailTextField.frame = frameRect
        
        passwordTextField.layer.cornerRadius = 25.0
        passwordTextField.layer.borderWidth = 0.0
        passwordTextField.layer.backgroundColor = UIColor.white.cgColor
        var frameRect1 = passwordTextField.frame
        frameRect1.size.height = 50 // <-- Specify the height you want here.
        passwordTextField.frame = frameRect1
        
        signUpButton.layer.cornerRadius = 10.0
        signInButton.layer.cornerRadius = 10.0

        if let user = Auth.auth().currentUser {
            Globals.user = User(email: user.email ?? "", uid: user.uid)
            if let nextViewController = self.storyboard?.instantiateViewController(identifier: Constants.MainMenuViewControllerIdentifier) as? MainMenuViewController {
                nextViewController.modalPresentationStyle = .fullScreen
                self.present(nextViewController, animated: true)
            }
        }
        handle = Auth.auth().addStateDidChangeListener() { (auth, user) in
            if let user = auth.currentUser  {
                Globals.user = User(email: user.email ?? "", uid: user.uid)
            } else {
                print("User is nil")
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        Auth.auth().removeStateDidChangeListener(handle!)
    }
    
    @IBAction func onSignUpButtonPressed(sender: UIButton) {
        if let nextViewController = storyboard?.instantiateViewController(identifier: Constants.SignupViewControllerIdentifier) as? SignupViewController {
            nextViewController.modalPresentationStyle = .fullScreen
            self.present(nextViewController, animated: true)
        }
    }
    
    @IBAction func onSignInButtonPressed(sender: UIButton) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            print("email/password cannot be empty")
            return
        }
               
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authresult, error in
            guard let strongSelf = self else { return }
            if let error = error {
                print(error.localizedDescription)
                return
            }
        
            if let nextViewController = strongSelf.storyboard?.instantiateViewController(identifier: Constants.MainMenuViewControllerIdentifier) as? MainMenuViewController {
                nextViewController.modalPresentationStyle = .fullScreen
                strongSelf.present(nextViewController, animated: true)
            }
        }
    }
}
