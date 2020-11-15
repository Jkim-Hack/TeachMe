//
//  Photo.swift
//  TeachMe
//
//  Created by John Kim on 11/15/20.
//

import UIKit
import AVKit

class Photo {
  
    class func allPhotos() -> [Photo] {
        var photos = [Photo]()
        guard let data = UserDefaults.standard.object(forKey: "dataKey") as? [String: [String: String]] else {
            return photos
        }
        for (_, dictionary) in data {
            let photo = Photo(dictionary: dictionary as NSDictionary)
            photos.append(photo)
        }
        return photos
    }

    var title: String
    var date: String
    var duration: String
    var uuid: String
    var image: UIImage

    init(title: String, date: String, duration: String, uuid: String, image: UIImage) {
        self.title = title
        self.date = date
        self.duration = duration
        self.uuid = uuid
        self.image = image
    }

    convenience init(dictionary: NSDictionary) {
        let title = dictionary["Title"] as? String
        let date = dictionary["Date"] as? String
        let duration = dictionary["Duration"] as? String
        let uuid = dictionary["UUID"] as? String
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(uuid!).mov")
        let image = Photo.generateThumbnail(path: url)
        self.init(title: title!, date: date!, duration: duration!, uuid: uuid!, image: image!)
    }

    static func generateThumbnail(path: URL) -> UIImage? {
        do {
            let asset = AVURLAsset(url: path, options: nil)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            imgGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            return thumbnail
        } catch let error {
            print("*** Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
    
    /*
    func heightForComment(_ font: UIFont, width: CGFloat) -> CGFloat {
        let rect = NSString(string: comment).boundingRect(with: CGSize(width: width, height: CGFloat(MAXFLOAT)), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        return ceil(rect.height)
    }
 */
  
}
