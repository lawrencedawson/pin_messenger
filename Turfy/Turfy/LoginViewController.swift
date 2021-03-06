//
//  LoginViewController.swift
//  Turfy
//
//  Created by James Stonehill on 26/10/2016.
//  Copyright © 2016 Lawrence Dawson. All rights reserved.
//
import UIKit
import Firebase
import FirebaseAuth
import FBSDKCoreKit
import FBSDKLoginKit
import FBSDKShareKit

class LoginViewController: UIViewController, FBSDKLoginButtonDelegate {
    var emptyArrayOfDictionary = [[String : String]]()
    var name: String = "", email: String = "", uid: String = "";
    let ref = FIRDatabase.database().reference().child("user")
    
    @IBOutlet weak var loginButton: FBSDKLoginButton!
    var login = FBSDKLoginManager()
    
    let fireCurrentUser = FIRAuth.auth()?.currentUser
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if FIRAuth.auth()?.currentUser != nil {
            retrieveData()
            DispatchQueue.main.async(){
                self.performSegue(withIdentifier: "loginSegue", sender: self)
                
            }
        } else {
            loginButton!.delegate = self
            view.addSubview(loginButton!)
            loginButton!.center = view.center
            loginButton.readPermissions = ["public_profile", "email", "user_friends"]
            // Do any additional setup after loading the view.
        }
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) { //should be triggered by event in settings view
        // required by the class delegate
    }
    
    func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!) {
        if error != nil {
            print(error.localizedDescription)
            return
        }
        else if result.isCancelled {
            let alert = UIAlertController(title: "Login cancelled", message: "You must login or sign up to use the app.", preferredStyle: UIAlertControllerStyle.alert)
            let button = UIAlertAction(title: "Ok", style: UIAlertActionStyle.cancel, handler: nil)
            alert.addAction(button)
            
            present(alert, animated: false, completion: nil)
        }
        else {
            let credential = FIRFacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
            firebaseSignInIfNotAlready(credential: credential)
            loginButton.isHidden = true
        }
    }
    
    func firebaseSignInIfNotAlready(credential: FIRAuthCredential){
        if FIRAuth.auth()?.currentUser != nil {
            self.performSegue(withIdentifier: "loginSegue", sender: self)
        } else {
            FIRAuth.auth()?.signIn(with: credential) { (user, error) in
                if (user != nil) {
                    self.getUserProfile()
                    self.saveData(uid: self.uid, name: self.name, email: self.email)
                    self.performSegue(withIdentifier: "loginSegue", sender: self)
                    
                }
                else if (error != nil) {
                    print(error?.localizedDescription)
                }
            }
        }
    }
    
    
    func getUserProfile() {
        if (FIRAuth.auth()?.currentUser != nil) {
            self.uid = (FIRAuth.auth()?.currentUser?.uid)!;
            self.name = (FIRAuth.auth()?.currentUser?.displayName)!;
            self.email = (FIRAuth.auth()?.currentUser?.email)!;
        }
    }
    
    func saveData(uid: String, name: String, email: String) {
        let user = User(uid: uid, name: name, email: email)
        let itemRef = self.ref.child(uid)
        itemRef.setValue(user.toAnyObject())
    }
    
    func retrieveData() {
        ref.observe(.value, with: { snapshot in
            for child in snapshot.children {
                let data = (child as! FIRDataSnapshot).value! as! [String:String]
                let uid = (data["uid"])!
                let name = (data["name"])!
                let email = (data["email"])!
                self.emptyArrayOfDictionary.append(["uid": uid , "name": name, "email": email])
            }
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
