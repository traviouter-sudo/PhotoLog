import Foundation
import SwiftData

/// 照片模型 - 引用式存储，不复制原文件
@Model
final class Photo {
    /// 唯一标识
    var id: UUID
    /// 照片文件绝对路径（可指向外置硬盘）
    var filePath: String
    /// 文件名（用于显示）
    var fileName: String
    /// 导入日期
    var importDate: Date
    /// 缩略图数据
    @Attribute(.externalStorage)
    var thumbnail: Data?
    /// 文件是否离线（外置硬盘未连接）
    var isOffline: Bool
    /// Security-Scoped Bookmark Data（用于 Sandbox 环境下重启后恢复文件访问权限）
    var bookmarkData: Data?
    /// 星级评分 (1-5, 0 = 未评分)
    var rating: Int
    /// 是否收藏
    var isFavorite: Bool
    /// 关联标签
    var tags: [Tag]
    /// 关联笔记
    var note: PhotoNote?

    init(
        filePath: String,
        fileName: String? = nil,
        thumbnail: Data? = nil,
        isOffline: Bool = false,
        bookmarkData: Data? = nil
    ) {
        self.id = UUID()
        self.filePath = filePath
        self.fileName = fileName ?? URL(fileURLWithPath: filePath).lastPathComponent
        self.importDate = Date()
        self.thumbnail = thumbnail
        self.isOffline = isOffline
        self.bookmarkData = bookmarkData
        self.rating = 0
        self.isFavorite = false
        self.tags = []
        self.note = nil
    }
}
