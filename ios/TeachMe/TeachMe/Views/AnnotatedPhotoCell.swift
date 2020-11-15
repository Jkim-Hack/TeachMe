//
//  AnnotatedPhotoCell.swift
//  TeachMe
//
//  Created by John Kim on 11/15/20.
//

import UIKit

class AnnotatedPhotoCell: UICollectionViewCell {
  
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!

    var photo: Photo? {
        didSet {
          if let photo = photo {
            imageView.image = photo.image
            titleLabel.text = photo.title
            dateLabel.text = photo.date
            timeLabel.text = photo.duration
          }
        }
    }
}

