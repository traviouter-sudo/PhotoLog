import Foundation
import ImageIO
import CoreLocation

/// EXIF 读取服务
/// 从照片文件自动读取拍摄参数和 GPS，填充到 PhotoNote
final class EXIFService {
    /// 从照片文件读取 EXIF 数据并填充到 PhotoNote
    @MainActor
    static func readEXIF(for photo: Photo, note: PhotoNote) {
        guard !photo.isOffline else { return }

        let filePath = photo.filePath
        let url = URL(fileURLWithPath: filePath)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return }

        // 读取 TIFF/EXIF 字典
        let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]

        // 相机型号
        if let camera = tiffDict?[kCGImagePropertyTIFFMake as String] as? String {
            let model = tiffDict?[kCGImagePropertyTIFFModel as String] as? String ?? ""
            note.camera = [camera, model].filter { !$0.isEmpty }.joined(separator: " ")
        }

        // 镜头
        if let lens = exifDict?[kCGImagePropertyExifLensModel as String] as? String {
            note.lens = lens
        }

        // 快门速度
        if let exposureTime = exifDict?[kCGImagePropertyExifExposureTime as String] as? Double {
            if exposureTime < 1 {
                note.shutterSpeed = "1/\(Int(round(1 / exposureTime)))s"
            } else {
                note.shutterSpeed = "\(String(format: "%.1f", exposureTime))s"
            }
        }

        // 光圈
        if let fNumber = exifDict?[kCGImagePropertyExifFNumber as String] as? Double {
            note.aperture = "f/\(String(format: "%.1f", fNumber))"
        }

        // ISO
        if let iso = exifDict?[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let first = iso.first {
            note.iso = "\(first)"
        } else if let iso = exifDict?[kCGImagePropertyExifISOSpeedRatings as String] as? Int {
            note.iso = "\(iso)"
        }

        // 焦距
        if let focalLength = exifDict?[kCGImagePropertyExifFocalLength as String] as? Double {
            note.focalLength = "\(Int(focalLength))mm"
        }

        // 曝光补偿
        if let ev = exifDict?[kCGImagePropertyExifExposureBiasValue as String] as? Double {
            note.exposureComp = ev >= 0 ? "+\(String(format: "%.1f", ev))EV" : "\(String(format: "%.1f", ev))EV"
        }

        // 拍摄时间
        if let dateStr = exifDict?[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            note.shootDate = formatter.date(from: dateStr)
        }

        // GPS 坐标
        readGPS(properties: properties, note: note)
    }

    // MARK: - GPS 读取
    private static func readGPS(properties: [String: Any], note: PhotoNote) {
        guard let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else { return }

        guard let latStr = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
              let latRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let lonStr = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double,
              let lonRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String else { return }

        var lat = latStr
        if latRef == "S" { lat = -lat }

        var lon = lonStr
        if lonRef == "W" { lon = -lon }

        // 验证坐标合理性
        guard abs(lat) <= 90, abs(lon) <= 180 else { return }

        note.latitude = lat
        note.longitude = lon
    }
}
