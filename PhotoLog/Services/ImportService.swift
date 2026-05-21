import Foundation
import AppKit
import SwiftData

/// 照片导入服务
/// 负责从文件路径创建 Photo 记录，不复制文件（引用式存储）
final class ImportService {
    /// 支持的图片文件扩展名
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif",
        "cr3", "arw", "nef", "dng", "raf", "orf", "rw2", "pef", "srw"
    ]

    /// 从文件路径导入单张照片
    @discardableResult
    static func importPhoto(
        at filePath: String,
        context: ModelContext
    ) -> Photo? {
        let url = URL(fileURLWithPath: filePath)

        // 检查扩展名
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            print("⚠️ 不支持的格式: \(url.pathExtension)")
            return nil
        }

        // 检查文件是否存在
        let isOffline = !FileManager.default.fileExists(atPath: filePath)

        // 创建 Photo 记录
        let photo = Photo(
            filePath: filePath,
            fileName: url.lastPathComponent,
            isOffline: isOffline
        )

        context.insert(photo)
        return photo
    }

    /// 批量导入照片
    static func importPhotos(
        at paths: [String],
        context: ModelContext
    ) -> [Photo] {
        var imported: [Photo] = []
        for path in paths {
            if let photo = importPhoto(at: path, context: context) {
                imported.append(photo)
            }
        }
        return imported
    }

    /// 从文件夹递归导入所有照片
    static func importFromDirectory(
        at directoryPath: String,
        context: ModelContext,
        recursive: Bool = true
    ) -> [Photo] {
        let fileManager = FileManager.default
        var imported: [Photo] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directoryPath),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: recursive ? [] : [.skipsSubdirectoryDescendants]
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                if let photo = importPhoto(at: fileURL.path, context: context) {
                    imported.append(photo)
                }
            }
        }

        return imported
    }

    /// 检查文件路径是否在线
    static func checkOnlineStatus(for photo: Photo) -> Bool {
        let isOnline = FileManager.default.fileExists(atPath: photo.filePath)
        if photo.isOffline != !isOnline {
            photo.isOffline = !isOnline
        }
        return isOnline
    }

    /// 重新扫描所有照片的在线状态
    static func refreshOnlineStatus(photos: [Photo]) -> (online: Int, offline: Int) {
        var online = 0
        var offline = 0
        for photo in photos {
            if checkOnlineStatus(for: photo) {
                online += 1
            } else {
                offline += 1
            }
        }
        return (online, offline)
    }
}
