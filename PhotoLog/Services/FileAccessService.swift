import Foundation
import SwiftData

/// 文件访问服务 - 处理外置硬盘挂载/卸载时的文件访问状态
/// 监控卷宗变化，自动更新离线状态
final class FileAccessService {
    /// 启动时检测所有照片路径是否可访问
    @MainActor
    static func checkAllPhotosOnStartup(context: ModelContext) {
        let descriptor = FetchDescriptor<Photo>()
        guard let photos = try? context.fetch(descriptor) else { return }
        
        var offlineCount = 0
        for photo in photos {
            let isOnline = FileManager.default.fileExists(atPath: photo.filePath)
            if photo.isOffline == isOnline {
                photo.isOffline = !isOnline
            }
            if photo.isOffline { offlineCount += 1 }
        }
        
        if offlineCount > 0 {
            print("📱 启动检测：\(offlineCount)/\(photos.count) 张照片离线")
        }
    }
    
    /// 重新扫描所有照片的在线状态
    @MainActor
    static func rescanAllPhotos(context: ModelContext) -> (online: Int, offline: Int) {
        let descriptor = FetchDescriptor<Photo>()
        guard let photos = try? context.fetch(descriptor) else { return (0, 0) }
        
        return ImportService.refreshOnlineStatus(photos: photos)
    }
    
    /// 检查单张照片是否在线
    static func isPhotoOnline(_ photo: Photo) -> Bool {
        return FileManager.default.fileExists(atPath: photo.filePath)
    }
    
    /// 检测文件所在卷宗是否为外置硬盘
    static func isExternalVolume(_ path: String) -> Bool {
        // /Volumes/ 下的路径通常是外置硬盘
        return path.hasPrefix("/Volumes/")
    }
    
    /// 获取文件所在卷宗名称
    static func volumeName(for path: String) -> String? {
        guard path.hasPrefix("/Volumes/") else { return nil }
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        return components.count >= 2 ? String(components[1]) : nil
    }
}
