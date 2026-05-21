import Foundation
import AppKit

/// 缩略图内存缓存服务
/// 使用 NSCache 作为二级缓存，减少频繁从 SwiftData Data 反序列化的开销
final class ThumbnailCacheService {
    static let shared = ThumbnailCacheService()
    
    /// NSCache 自动在内存紧张时清理
    private let cache: NSCache<NSString, NSImage>
    
    private init() {
        cache = NSCache()
        cache.countLimit = 200      // 最多缓存 200 张
        cache.totalCostLimit = 100 * 1024 * 1024  // 100MB 上限
    }
    
    /// 获取缓存中的缩略图
    func get(photoID: UUID) -> NSImage? {
        let key = photoID.uuidString as NSString
        return cache.object(forKey: key)
    }
    
    /// 存入缓存
    func set(_ image: NSImage, for photoID: UUID) {
        let key = photoID.uuidString as NSString
        // 估算图片大小
        let estimatedSize = image.size.width * image.size.height * 4
        cache.setObject(image, forKey: key, cost: Int(estimatedSize))
    }
    
    /// 清除所有缓存
    func clearAll() {
        cache.removeAllObjects()
    }

    /// 清除单张照片的缓存
    func removeCache(for photoID: UUID) {
        let key = photoID.uuidString as NSString
        cache.removeObject(forKey: key)
    }
    
    /// 从 Data 加载或从缓存获取
    func imageFromData(_ data: Data, photoID: UUID) -> NSImage? {
        // 先查缓存
        if let cached = get(photoID: photoID) {
            return cached
        }
        
        // 从 Data 创建
        guard let image = NSImage(data: data) else { return nil }
        set(image, for: photoID)
        return image
    }
}
