import Foundation
import SwiftData
import CoreLocation

/// 照片笔记模型 - 拍摄参数 + 个人分析 + 来源信息
@Model
final class PhotoNote {
    /// 唯一标识
    var id: UUID

    // MARK: - 拍摄参数
    var camera: String          // 相机型号
    var lens: String            // 镜头
    var filmStock: String       // 胶卷（如 Portra 400, Ektar 100）
    var shutterSpeed: String    // 快门速度 (如 "1/500s")
    var aperture: String        // 光圈 (如 "f/2.8")
    var iso: String             // ISO
    var focalLength: String     // 焦距 (如 "85mm")
    var exposureComp: String    // 曝光补偿 (如 "+0.3EV")
    var shootDate: Date?        // 拍摄时间
    var location: String        // 拍摄地点（具体位置，如"故宫""东京塔"）
    var city: String            // 城市（如"北京""东京"）
    var district: String        // 区县（如"东城区""港区"）
    var lightCondition: String  // 天气/光线条件

    // MARK: - GPS 坐标（从 EXIF 自动读取）
    var latitude: Double?
    var longitude: Double?

    // MARK: - 来源信息
    var sourceURL: String       // 照片来源链接
    var originalAuthor: String  // 原作者/摄影师

    // MARK: - 个人分析
    var overallThought: String  // 整体想法
    var pros: String            // 优点
    var cons: String            // 缺点/遗憾
    var learnings: String       // 学习点
    var postProcess: String     // 后期处理备注

    // MARK: - 可配置参数（用户自定义显示哪些参数字段）
    /// 隐藏的参数字段 key 集合
    var hiddenParameterKeys: [String]

    // MARK: - 自定义参数字段
    /// 用户自定义的参数字段（key-value 对）
    var customFields: [CustomField]

    /// 关联照片
    var photo: Photo?

    init() {
        self.id = UUID()
        self.camera = ""
        self.lens = ""
        self.filmStock = ""
        self.shutterSpeed = ""
        self.aperture = ""
        self.iso = ""
        self.focalLength = ""
        self.exposureComp = ""
        self.shootDate = nil
        self.location = ""
        self.city = ""
        self.district = ""
        self.lightCondition = ""
        self.latitude = nil
        self.longitude = nil
        self.sourceURL = ""
        self.originalAuthor = ""
        self.overallThought = ""
        self.pros = ""
        self.cons = ""
        self.learnings = ""
        self.postProcess = ""
        self.hiddenParameterKeys = []
        self.customFields = []
        self.photo = nil
    }

    // MARK: - GPS 辅助
    /// 是否有 GPS 坐标
    var hasGPS: Bool {
        latitude != nil && longitude != nil
    }

    /// 是否有任何位置信息（GPS 或手动填写的城市/地点）
    var hasLocationInfo: Bool {
        hasGPS || !city.trimmingCharacters(in: .whitespaces).isEmpty
            || !district.trimmingCharacters(in: .whitespaces).isEmpty
            || !location.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 拼接完整地址（用于地理编码）：城市 + 区县 + 具体位置
    var fullAddress: String {
        var parts: [String] = []
        if !city.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(city) }
        if !district.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(district) }
        if !location.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(location) }
        return parts.joined(separator: "")
    }

    /// 简短地址显示（城市 + 具体位置，省略区县）
    var shortAddress: String {
        var parts: [String] = []
        if !city.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(city) }
        if !location.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(location) }
        let result = parts.joined(separator: " ")
        return result.isEmpty ? "未设置" : result
    }

    /// 获取 CLLocation 对象
    var clLocation: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    // MARK: - 参数字段定义
    /// 所有内置可配置的参数字段
    static let allParameterKeys: [ParameterField] = [
        ParameterField(key: "camera", label: "相机", placeholder: "如 Canon R5"),
        ParameterField(key: "lens", label: "镜头", placeholder: "如 RF 85mm f/1.2"),
        ParameterField(key: "filmStock", label: "胶卷", placeholder: "如 Portra 400"),
        ParameterField(key: "shutterSpeed", label: "快门速度", placeholder: "如 1/500s"),
        ParameterField(key: "aperture", label: "光圈", placeholder: "如 f/2.8"),
        ParameterField(key: "iso", label: "ISO", placeholder: "如 400"),
        ParameterField(key: "focalLength", label: "焦距", placeholder: "如 85mm"),
        ParameterField(key: "exposureComp", label: "曝光补偿", placeholder: "如 +0.3EV"),
        ParameterField(key: "shootDate", label: "拍摄时间", placeholder: ""),
        ParameterField(key: "city", label: "城市", placeholder: "如 北京"),
        ParameterField(key: "district", label: "区县", placeholder: "如 东城"),
        ParameterField(key: "location", label: "具体位置", placeholder: "如 故宫"),
        ParameterField(key: "lightCondition", label: "光线条件", placeholder: "如 黄昏逆光"),
        ParameterField(key: "sourceURL", label: "照片链接", placeholder: "如 https://..."),
        ParameterField(key: "originalAuthor", label: "原作者", placeholder: "如 摄影师姓名"),
    ]

    /// 获取可见的参数字段（未隐藏的）
    var visibleParameterKeys: [ParameterField] {
        Self.allParameterKeys.filter { !hiddenParameterKeys.contains($0.key) }
    }

    /// 切换参数字段的显示/隐藏
    func toggleParameterVisibility(_ key: String) {
        if hiddenParameterKeys.contains(key) {
            hiddenParameterKeys.removeAll { $0 == key }
        } else {
            hiddenParameterKeys.append(key)
        }
    }

    // MARK: - 自定义字段操作
    /// 添加自定义字段
    func addCustomField(label: String, value: String = "") {
        let field = CustomField(id: UUID(), label: label, value: value)
        customFields.append(field)
    }

    /// 删除自定义字段
    func removeCustomField(at index: Int) {
        guard customFields.indices.contains(index) else { return }
        customFields.remove(at: index)
    }

    /// 更新自定义字段值
    func updateCustomField(id: UUID, value: String) {
        if let index = customFields.firstIndex(where: { $0.id == id }) {
            customFields[index].value = value
        }
    }

    /// 更新自定义字段标签
    func updateCustomFieldLabel(id: UUID, label: String) {
        if let index = customFields.firstIndex(where: { $0.id == id }) {
            customFields[index].label = label
        }
    }
}

/// 参数字段定义（内置）
struct ParameterField: Hashable, Identifiable {
    let key: String
    let label: String
    let placeholder: String

    var id: String { key }
}

/// 自定义参数字段（用户添加）
struct CustomField: Codable, Identifiable, Hashable {
    let id: UUID
    var label: String
    var value: String
}
