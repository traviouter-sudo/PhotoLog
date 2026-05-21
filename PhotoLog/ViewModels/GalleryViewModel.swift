import SwiftUI
import SwiftData
import Combine

/// 照片库视图模型 - 管理搜索和筛选逻辑
/// 集中管理筛选状态，支持多条件组合
@Observable
final class GalleryViewModel {
    /// 搜索关键词
    var searchText: String = ""
    
    /// 评分范围筛选
    var minRating: Int = 0
    var maxRating: Int = 5
    
    /// 日期范围筛选
    var startDate: Date?
    var endDate: Date?
    
    /// 标签筛选（在侧边栏标签点击时触发）
    var selectedTagID: UUID?
    
    /// 仅显示收藏
    var showFavoritesOnly: Bool = false
    
    /// 仅显示离线照片
    var showOfflineOnly: Bool = false
    
    /// 排序方式
    var sortOption: PhotoSortOption = .importDateDesc
    
    /// 是否有激活的筛选条件（不含搜索）
    var hasActiveFilters: Bool {
        minRating > 0 || maxRating < 5 ||
        startDate != nil || endDate != nil ||
        showFavoritesOnly || showOfflineOnly
    }
    
    /// 清除所有筛选条件
    func clearFilters() {
        minRating = 0
        maxRating = 5
        startDate = nil
        endDate = nil
        showFavoritesOnly = false
        showOfflineOnly = false
    }
    
    /// 对照片列表应用所有筛选条件
    func filter(_ photos: [Photo]) -> [Photo] {
        var result = photos
        
        // 搜索关键词
        if !searchText.isEmpty {
            result = result.filter { photo in
                photo.fileName.localizedCaseInsensitiveContains(searchText) ||
                (photo.note?.camera.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (photo.note?.lens.localizedCaseInsensitiveContains(searchText) ?? false) ||
                photo.tags.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })
            }
        }
        
        // 评分范围
        if minRating > 0 {
            result = result.filter { $0.rating >= minRating }
        }
        if maxRating < 5 {
            result = result.filter { $0.rating <= maxRating }
        }
        
        // 日期范围
        if let startDate = startDate {
            result = result.filter { $0.importDate >= startDate }
        }
        if let endDate = endDate {
            result = result.filter { $0.importDate <= endDate }
        }
        
        // 收藏
        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        
        // 离线
        if showOfflineOnly {
            result = result.filter { $0.isOffline }
        }
        
        // 排序
        result = sort(result)
        
        return result
    }
    
    /// 排序照片
    private func sort(_ photos: [Photo]) -> [Photo] {
        switch sortOption {
        case .importDateDesc:
            return photos.sorted { $0.importDate > $1.importDate }
        case .importDateAsc:
            return photos.sorted { $0.importDate < $1.importDate }
        case .fileNameAsc:
            return photos.sorted { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
        case .ratingDesc:
            return photos.sorted { $0.rating > $1.rating }
        case .ratingAsc:
            return photos.sorted { $0.rating < $1.rating }
        }
    }
}

/// 照片排序选项
enum PhotoSortOption: String, CaseIterable {
    case importDateDesc = "导入时间（新→旧）"
    case importDateAsc = "导入时间（旧→新）"
    case fileNameAsc = "文件名（A→Z）"
    case ratingDesc = "评分（高→低）"
    case ratingAsc = "评分（低→高）"
}
