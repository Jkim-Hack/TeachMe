//
//  SignupViewController.swift
//  TeachMe
//
//  Created by John Kim on 11/15/20.
//

import UIKit
import Firebase

class SignupViewController: UIViewController {

    @IBOutlet weak var emailTextField : UITextField!
    @IBOutlet weak var passwordTextField : UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signUpButton: UIButton!
    
    var handle: AuthStateDidChangeListenerHandle?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            print("email/password cannot be empty")
            return
        }
                      
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authresult, error in
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
    @IBAction func onSignInButtonPressed(sender: UIButton) {
        if let nextViewController = storyboard?.instantiateViewController(identifier: Constants.SigninViewControllerIdentifier) as? SigninViewController {
            nextViewController.modalPresentationStyle = .fullScreen
            self.present(nextViewController, animated: true)
        }
    }
    
}
