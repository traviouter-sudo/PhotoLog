import Foundation
import AppKit
import SwiftData
import os.log

/// 照片导入服务
/// 负责从 URL 创建 Photo 记录，不复制文件（引用式存储）
/// 导入时自动生成 Security-Scoped Bookmark Data 用于 Sandbox 重启后恢复访问权限
final class ImportService {
    private static let logger = Logger(subsystem: "com.photolog", category: "Import")

    /// 支持的图片文件扩展名
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif",
        "cr3", "arw", "nef", "dng", "raf", "orf", "rw2", "pef", "srw"
    ]

    /// 从 Security-Scoped URL 导入单张照片（推荐入口）
    /// 自动创建 bookmark data 并持久化到 Photo 模型
    @discardableResult
    static func importPhoto(from url: URL, context: ModelContext) -> Photo? {
        // 检查扩展名
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            logger.warning("不支持的格式: \(url.pathExtension)")
            return nil
        }

        let filePath = url.path
        let fileName = url.lastPathComponent

        // 检查文件是否存在
        let isOffline = !FileManager.default.fileExists(atPath: filePath)

        // 生成 Security-Scoped Bookmark Data
        let bookmarkData = createBookmark(for: url)

        // 创建 Photo 记录（含 bookmark data）
        let photo = Photo(
            filePath: filePath,
            fileName: fileName,
            isOffline: isOffline,
            bookmarkData: bookmarkData
        )

        context.insert(photo)

        if let bookmarkData {
            logger.info("✅ Bookmark 已保存: \(fileName) (\(bookmarkData.count) bytes)")
        } else {
            logger.warning("⚠️ Bookmark 创建失败（非 security-scoped URL）: \(fileName)")
        }

        return photo
    }

    /// 从文件路径导入单张照片（向后兼容，无 bookmark）
    @discardableResult
    static func importPhoto(at filePath: String, context: ModelContext) -> Photo? {
        return importPhoto(from: URL(fileURLWithPath: filePath), context: context)
    }

    /// 从 URL 数组批量导入照片（推荐入口）
    static func importPhotos(from urls: [URL], context: ModelContext) -> [Photo] {
        var imported: [Photo] = []
        for url in urls {
            if let photo = importPhoto(from: url, context: context) {
                imported.append(photo)
            }
        }
        return imported
    }

    /// 从路径数组批量导入照片（向后兼容）
    static func importPhotos(at paths: [String], context: ModelContext) -> [Photo] {
        return importPhotos(from: paths.map { URL(fileURLWithPath: $0) }, context: context)
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

    // MARK: - Security-Scoped Bookmark 工具

    /// 从 URL 创建 Security-Scoped Bookmark Data
    /// 仅当 URL 本身携带安全范围权限时（如 .fileImporter / NSOpenPanel 返回的 URL）才能成功创建
    static func createBookmark(for url: URL) -> Data? {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmarkData
        } catch {
            logger.warning("Bookmark 创建失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 从 Bookmark Data 解析出带安全范围的 URL
    /// - Parameters:
    ///   - bookmarkData: 持久化的 bookmark 数据
    ///   - isStale: 输出参数，标记 bookmark 是否过期（文件被移动/重命名等）
    /// - Returns: 可用的 security-scoped URL，调用方需自行 startAccessingSecurityScopedResource()
    static func resolveBookmark(_ bookmarkData: Data, isStale: inout Bool) -> URL? {
        do {
            let resolvedUrl = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return resolvedUrl
        } catch {
            logger.warning("Bookmark 解析失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 刷新过期的 bookmark：用新 URL 重新生成 bookmark data 并更新到 Photo 模型
    @discardableResult
    static func refreshStaleBookmark(for photo: Photo) -> Bool {
        guard let oldData = photo.bookmarkData else { return false }
        var isStale = false

        // 先尝试解析旧 bookmark（即使 stale 也可能返回有效 URL）
        guard let resolvedURL = resolveBookmark(oldData, isStale: &isStale),
              resolvedURL.startAccessingSecurityScopedResource() else {
            return false
        }

        // 用解析出的有效 URL 创建新 bookmark
        if let newBookmark = createBookmark(for: resolvedURL) {
            photo.bookmarkData = newBookmark
            resolvedURL.stopAccessingSecurityScopedResource()
            logger.info("🔄 Bookmark 已刷新: \(photo.fileName)")
            return true
        }

        resolvedURL.stopAccessingSecurityScopedResource()
        return false
    }
}
