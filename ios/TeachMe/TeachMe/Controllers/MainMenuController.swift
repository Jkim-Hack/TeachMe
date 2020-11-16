//
//  MainMenuController.swift
//  TeachMe
//
//  Created by John Kim on 11/15/20.
//

import Foundation
import Firebase
import AVFoundation
import UIKit
import CoreMotion

class MainMenuViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
  
    @IBOutlet weak var newLesson: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var photos = Photo.allPhotos()
  
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        view.backgroundColor = UIColor.white
        collectionView!.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)

        let layout = self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        
        layout.sectionInset = UIEdgeInsets(top: 20, left: 50, bottom: 20, right: 50)
        layout.itemSize = CGSize(width: self.collectionView.frame.size.width - 20, height: self.collectionView.frame.size.height/3)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        createCaptureButton()
    }
    
    func createCaptureButton() {
        let circleDiameter = self.view.frame.size.height/12
        let x = self.view.frame.size.width - circleDiameter
        let y = (self.view.frame.size.height * 0.85)
        let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: circleDiameter, height: circleDiameter))
        
        let capButton = UIButton(frame: CGRect(x: x - circleDiameter/2, y: y - circleDiameter/2, width: circleDiameter, height: circleDiameter))
        capButton.backgroundColor = UIColor.clear
        
        let circleLayer = CAShapeLayer()
        circleLayer.strokeColor = UIColor.red.cgColor
        circleLayer.path = path.cgPath
        circleLayer.lineWidth = 4.0
        circleLayer.fillColor = UIColor.red.cgColor
        
        capButton.layer.addSublayer(circleLayer)
        
        capButton.addTarget(self, action: #selector(onNewLessonClick(sender:)), for: UIControl.Event.touchUpInside)
        self.view.addSubview(capButton)
        
    }
    
    @IBAction func onNewLessonClick(sender: UIButton) {
        if let nextViewController = storyboard?.instantiateViewController(identifier: Constants.CameraViewControllerIdentifier) as? CameraViewController {
            nextViewController.modalPresentationStyle = .fullScreen
            self.present(nextViewController, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
      return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AnnotatedPhotoCell", for: indexPath) as! AnnotatedPhotoCell
        cell.photo = photos[indexPath.item]
        cell.imageView.backgroundColor = UIColor.black
        return cell
    }
    
}
