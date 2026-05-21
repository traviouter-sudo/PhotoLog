import Foundation
import SwiftData

/// 题材标签模型
@Model
final class Tag {
    /// 唯一标识
    var id: UUID
    /// 标签名称（如"人像"、"风光"、"街拍"）
    var name: String
    /// 标签颜色（hex 字符串）
    var colorHex: String
    /// 关联的照片
    var photos: [Photo]

    init(name: String, colorHex: String = "#007AFF") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.photos = []
    }
}
