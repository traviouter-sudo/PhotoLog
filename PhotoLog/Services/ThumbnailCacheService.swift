import Foundation
import AppKit
import CoreGraphics
import ImageIO
import os.log
import SwiftData

/// 缩略图内存缓存服务 + 统一图像加载器
///
/// ## 核心问题（已解决）
/// 1. **JFIF DPI 问题**：NSImage(contentsOf:) 解析 JPEG JFIF DPI 头导致 size 异常 → 模糊
///    → 解决：统一走 CGImageSource → CGImage → NSImage 路径，绕过 DPI 解析
///
/// 2. **App Sandbox 权限问题**：重启后 security-scoped access 失效，
///    CGImageSourceCreateWithURL 返回 "Operation not permitted" (-62)
///    → 解决：导入时保存 Security-Scoped Bookmark Data，重启后通过 bookmark 解析恢复访问权限
///
/// ## 加载策略
/// - **缩略图 (loadSafely)**：NSImage.size 限制在 maxDimension=1200，适合小区域显示
/// - **预览大图 (loadFullSize)**：NSImage.size = 真实像素尺寸，1:1 渲染保证最清晰
final class ThumbnailCacheService {
    static let shared = ThumbnailCacheService()
    private static let logger = Logger(subsystem: "com.photolog", category: "ThumbnailCache")

    /// NSCache 自动在内存紧张时清理
    private let imageCache: NSCache<NSString, NSImage>

    private init() {
        imageCache = NSCache()
        imageCache.countLimit = 200      // 最多缓存 200 张
        imageCache.totalCostLimit = 200 * 1024 * 1024  // 200MB 上限（高质量缩略图）
    }

    // MARK: - Sandbox 权限包装器（基于 Security-Scoped Bookmark）

    /// 在 App Sandbox 环境下安全地访问用户文件（基于 bookmark）
    ///
    /// 优先级：
    /// 1. 从 Photo.bookmarkData 解析 security-scoped URL（重启后仍有效）✅
    /// 2. fallback 到纯路径 URL（仅当文件在沙盒可访问范围内）
    ///
    /// - Parameters:
    ///   - photo: 含有 bookmarkData 的 Photo 模型对象
    ///   - operation: 接收有效 URL 执行文件读取的闭包
    /// - Returns: operation 的返回值，如果所有访问方式均失败则返回 nil
    private static func withSecurityScopedAccess<T>(photo: Photo, operation: (URL) -> T?) -> T? {
        // 策略 1: 尝试从 bookmarkData 解析安全范围 URL
        if let bookmarkData = photo.bookmarkData {
            var isStale = false

            if let resolvedURL = ImportService.resolveBookmark(bookmarkData, isStale: &isStale) {
                let didStart = resolvedURL.startAccessingSecurityScopedResource()
                let result = operation(resolvedURL)
                if didStart {
                    resolvedURL.stopAccessingSecurityScopedResource()
                }

                if let result {
                    // 如果 bookmark 过期但访问成功，尝试异步刷新
                    if isStale {
                        logger.info("🔄 Bookmark 过期但访问成功，准备刷新: \(photo.fileName)")
                        DispatchQueue.main.async {
                            _ = ImportService.refreshStaleBookmark(for: photo)
                        }
                    }
                    return result
                }

                // bookmark 存在但解析后无法访问文件
                logger.warning("⚠️ Bookmark URL 访问失败: \(photo.fileName)")
            } else {
                logger.warning("⚠️ Bookmark 解析失败: \(photo.fileName)")
            }
        }

        // 策略 2: fallback 纯路径 URL（适用于沙盒内路径或无 bookmark 的旧数据）
        let fallbackURL = URL(fileURLWithPath: photo.filePath)
        let didStartFallback = fallbackURL.startAccessingSecurityScopedResource()
        let fallbackResult = operation(fallbackURL)
        if didStartFallback {
            fallbackURL.stopAccessingSecurityScopedResource()
        }
        return fallbackResult
    }

    /// 在 App Sandbox 环境下安全地访问用户文件（纯路径版本，用于无 Photo 对象的场景）
    ///
    /// 注意：此方法对纯字符串创建的 URL 调用 startAccessingSecurityScopedResource()，
    /// 仅在文件位于沙盒可访问目录内时才可能成功。对于外部存储的文件，
    /// 应使用 `withSecurityScopedAccess(photo:operation:)` 版本。
    private static func withSecurityScopedAccess<T>(filePath: String, operation: (URL) -> T?) -> T? {
        let url = URL(fileURLWithPath: filePath)
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        let result = operation(url)
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
        }
        return result
    }

    /// 从 Photo 对象安全加载图像（使用 bookmark，推荐入口）
    /// 用于网格缩略图显示，NSImage.size 限制在 maxDimension=1200
    static func loadSafely(for photo: Photo) -> NSImage? {
        withSecurityScopedAccess(photo: photo) { url in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                return nil
            }
            return Self.loadFromSource(source)
        }
    }

    /// 从 Photo 对象安全加载全尺寸图像（使用 bookmark）
    /// NSImage.size 使用真实像素尺寸，专用于预览大图等需要最大清晰度的场景
    static func loadFullSize(for photo: Photo) -> NSImage? {
        withSecurityScopedAccess(photo: photo) { url in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                return nil
            }
            return Self.loadFromSourceFullSize(source)
        }
    }

    /// 从 Data 安全加载图像（绕过 NSImage(data:) 的 JFIF DPI 问题）
    /// 用于从 SwiftData 外部存储加载的缩略图数据
    static func loadSafely(from data: Data, photoID: UUID? = nil) -> NSImage? {
        // 先查缓存
        if let photoID, let cached = shared.get(photoID: photoID) {
            return cached
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let nsImage = Self.loadFromSource(source)

        // 存入缓存
        if let photoID, let nsImage {
            shared.set(nsImage, for: photoID)
        }

        return nsImage
    }

    // MARK: - 核心解码（CGImageSource 路径）

    /// 统一的 CGImageSource 解码方法
    ///
    /// NSImage(cgImage:) 构造器的 `size` 参数决定 SwiftUI 渲染行为：
    /// - 若 size == 像素尺寸（如 2700x2160），SwiftUI 在 ~800px 显示区做 3.4x 下采样 → 模糊
    /// - 若 size == 合理逻辑尺寸（如 900x720），SwiftUI 接近 1:1 渲染 → 清晰
    ///
    /// 策略：将 size 限制在 maxDimension=1200 以内（等比缩放），既保证缩略图清晰，
    /// 又避免预览大图因超大 size 触发过度下采样。CGImage 像素数据不受影响。
    private static func loadFromSource(_ source: CGImageSource) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)

        // 将逻辑尺寸限制在 1200px 以内，保持宽高比
        let maxDimension: CGFloat = 1200
        let logicalSize: NSSize
        if max(pixelWidth, pixelHeight) > maxDimension {
            let scale = maxDimension / max(pixelWidth, pixelHeight)
            logicalSize = NSSize(width: pixelWidth * scale, height: pixelHeight * scale)
        } else {
            logicalSize = NSSize(width: pixelWidth, height: pixelHeight)
        }

        return NSImage(cgImage: cgImage, size: logicalSize)
    }

    /// 全尺寸加载：NSImage.size = 真实像素尺寸，不缩放
    /// 用于预览大图等需要 1:1 像素映射的场景。
    /// 与 loadFromSource 的区别：不限制 logicalSize，让 SwiftUI 在 .fit 模式下精确渲染每个像素。
    private static func loadFromSourceFullSize(_ source: CGImageSource) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        // 使用真实像素尺寸作为 NSImage.size
        let pixelSize = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        return NSImage(cgImage: cgImage, size: pixelSize)
    }

    // MARK: - 缓存操作（供外部直接调用）

    /// 获取缓存中的缩略图
    func get(photoID: UUID) -> NSImage? {
        let key = photoID.uuidString as NSString
        return imageCache.object(forKey: key)
    }

    /// 存入缓存
    func set(_ image: NSImage, for photoID: UUID) {
        let key = photoID.uuidString as NSString
        let estimatedSize = image.size.width * image.size.height * 4
        imageCache.setObject(image, forKey: key, cost: Int(estimatedSize))
    }

    /// 清除所有缓存
    func clearAll() {
        imageCache.removeAllObjects()
    }

    /// 清除单张照片的缓存
    func removeCache(for photoID: UUID) {
        let key = photoID.uuidString as NSString
        imageCache.removeObject(forKey: key)
    }

    /// 从 Data 加载或从缓存获取（向后兼容接口，内部走安全路径）
    func imageFromData(_ data: Data, photoID: UUID) -> NSImage? {
        return Self.loadSafely(from: data, photoID: photoID)
    }
}
