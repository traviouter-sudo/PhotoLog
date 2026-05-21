import Foundation
import ImageIO
import AppKit

/// 缩略图生成服务
/// 使用 ImageIO 高效生成缩略图，支持 RAW 格式
final class ThumbnailService {
    /// 目标缩略图尺寸（足够清晰，用于预览和学习）
    static let thumbnailSize: CGFloat = 1200

    /// 为照片异步生成缩略图
    @MainActor
    static func generateThumbnail(for photo: Photo) async -> Bool {
        // 文件不在线，无法生成
        guard !photo.isOffline else { return false }

        let filePath = photo.filePath
        let size = thumbnailSize

        // 在后台线程生成
        let thumbnailData = await Task.detached(priority: .utility) {
            Self.createThumbnailData(filePath: filePath, size: size)
        }.value

        if let data = thumbnailData {
            photo.thumbnail = data
            return true
        }
        return false
    }

    /// 批量生成缩略图
    @MainActor
    static func generateThumbnails(for photos: [Photo], onProgress: ((Int, Int) -> Void)? = nil) async {
        let total = photos.count
        for (index, photo) in photos.enumerated() {
            if photo.thumbnail == nil {
                _ = await generateThumbnail(for: photo)
            }
            onProgress?(index + 1, total)
        }
    }

    // MARK: - 私有方法

    /// 使用 ImageIO 创建缩略图数据
    private static func createThumbnailData(filePath: String, size: CGFloat) -> Data? {
        let url = URL(fileURLWithPath: filePath)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        // 尝试使用 ImageIO 内置缩略图（RAW 文件更高效）
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: size,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        bitmapRep.size = NSSize(width: cgImage.width, height: cgImage.height)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
    }
}
