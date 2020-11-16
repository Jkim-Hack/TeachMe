//
//  RecordButton.swift
//  TeachMe
//
//  Created by John Kim on 11/14/20.
//

import UIKit

@IBDesignable class RecordButton: UIButton {
        
    override func layoutSubviews() {
        super.layoutSubviews()
        self.backgroundColor = .red
        layer.cornerRadius = 0.5 * self.bounds.size.width
        self.clipsToBounds = true
        
    }
    
    func cornerRadiusChangeAnimation(reverse: Bool) {
        UIView.animate(withDuration: 0.5, animations: {
            if !reverse {
                self.bounds.size.width = self.bounds.size.width / 1.5
                self.bounds.size.height = self.bounds.size.height / 1.5
                self.layer.cornerRadius = 0.5 * self.bounds.size.width
            } else {
                self.bounds.size.width = self.bounds.size.width * 1.5
                self.bounds.size.height = self.bounds.size.height * 1.5
                self.layer.cornerRadius = self.bounds.size.height / 2
            }
        }, completion: { _ in
            UIView.animate(withDuration: 0.5, animations: {
                if !reverse {
                    self.layer.cornerRadius = self.bounds.size.height / 5
                } else {
                    self.layer.cornerRadius = self.bounds.size.height / 2
                }
            })
        })
    }
}
