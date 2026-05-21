import SwiftUI
import SwiftData

/// 标签管理服务 - 集中处理标签增删改
struct TagService {
    /// 创建标签
    @discardableResult
    static func createTag(name: String, colorHex: String = "#007AFF", context: ModelContext) -> Tag {
        let tag = Tag(name: name, colorHex: colorHex)
        context.insert(tag)
        return tag
    }

    /// 重命名标签
    static func renameTag(_ tag: Tag, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tag.name = trimmed
    }

    /// 删除标签（只解除关联，不删除照片）
    static func deleteTag(_ tag: Tag, context: ModelContext) {
        // 清除关联
        tag.photos.removeAll()
        context.delete(tag)
    }

    /// 预设颜色列表
    static let presetColors: [(name: String, hex: String)] = [
        ("蓝色", "#007AFF"),
        ("红色", "#FF3B30"),
        ("橙色", "#FF9500"),
        ("黄色", "#FFCC00"),
        ("绿色", "#34C759"),
        ("紫色", "#AF52DE"),
        ("粉色", "#FF2D55"),
        ("青色", "#5AC8FA"),
        ("灰色", "#8E8E93"),
        ("棕色", "#A2845E"),
    ]

    /// 推荐标签名称（首次创建时提示）
    static let suggestedTagNames = [
        "人像", "风光", "街拍", "建筑", "生态",
        "旅行", "黑白", "长曝光", "夜景", "美食",
        "纪实", "运动", "静物", "微距", "航拍"
    ]
}
