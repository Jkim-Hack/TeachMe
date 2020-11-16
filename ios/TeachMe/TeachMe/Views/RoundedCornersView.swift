//
//  RoundedCornersView.swift
//  TeachMe
//
//  Created by John Kim on 11/15/20.
//

import UIKit

@IBDesignable
class RoundedCornersView: UIView {
  
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
          layer.cornerRadius = cornerRadius
          layer.masksToBounds = cornerRadius > 0
        }
    }
  
}
