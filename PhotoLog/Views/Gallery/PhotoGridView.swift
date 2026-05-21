import SwiftUI
import SwiftData

/// 照片网格视图 - 中间主区域
/// 支持按标签、收藏、搜索、多条件筛选、删除
struct PhotoGridView: View {
    @Binding var selectedPhoto: Photo?
    let sidebarItem: SidebarItem?
    @Bindable var viewModel: GalleryViewModel
    var onDoubleTap: (([Photo], Int) -> Void)?

    /// 导入触发（从欢迎页按钮）
    var onImportRequest: (() -> Void)?

    @Query(sort: \Photo.importDate, order: .reverse)
    private var allPhotos: [Photo]

    @Environment(\.modelContext) private var modelContext
    @State private var photoToDelete: Photo?
    @State private var showDeleteConfirm = false

    /// 根据侧边栏选择和 GalleryViewModel 筛选条件过滤照片
    private var filteredPhotos: [Photo] {
        var result = allPhotos

        // 侧边栏筛选
        switch sidebarItem {
        case .allPhotos:
            break // 显示全部
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .recent:
            // 最近 7 天
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            result = result.filter { $0.importDate >= weekAgo }
        case .untagged:
            result = result.filter { $0.tags.isEmpty }
        case .map:
            // 地图视图在 ContentView 中单独处理，这里显示全部
            break
        case .tag(let tag):
            result = result.filter { photo in
                photo.tags.contains(where: { $0.id == tag.id })
            }
        case .none:
            break
        }

        // ViewModel 多条件筛选
        result = viewModel.filter(result)

        return result
    }

    var body: some View {
        Group {
            if allPhotos.isEmpty {
                // 完全没有照片 - 欢迎引导
                WelcomeGuideView {
                    onImportRequest?()
                }
            } else if filteredPhotos.isEmpty {
                // 有照片但筛选为空
                noResultsView
            } else {
                photoGrid
            }
        }
        .navigationTitle(navigationTitle)
        .onDeleteCommand {
            // Delete 键删除选中照片
            if let photo = selectedPhoto {
                photoToDelete = photo
                showDeleteConfirm = true
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {
                photoToDelete = nil
            }
            Button("从照片库移除", role: .destructive) {
                if let photo = photoToDelete {
                    deletePhoto(photo)
                }
                photoToDelete = nil
            }
        } message: {
            if let photo = photoToDelete {
                Text("将「\(photo.fileName)」从照片库中移除？原文件不会被删除。")
            } else {
                Text("确认移除此照片？")
            }
        }
    }

    // MARK: - 导航标题
    private var navigationTitle: String {
        switch sidebarItem {
        case .allPhotos: return "全部照片"
        case .favorites: return "收藏"
        case .recent: return "最近导入"
        case .untagged: return "未分类"
        case .map: return "地图浏览"
        case .tag(let tag): return tag.name
        case .none: return "PhotoLog"
        }
    }

    // MARK: - 无结果
    @ViewBuilder
    private var noResultsView: some View {
        switch sidebarItem {
        case .tag(let tag):
            TagEmptyStateView(tagName: tag.name)
        case .favorites:
            EmptyStateView(
                icon: "heart",
                title: "没有收藏照片",
                message: "点击照片详情面板中的心形按钮添加收藏"
            )
        case .recent:
            EmptyStateView(
                icon: "clock",
                title: "最近没有导入",
                message: "最近 7 天内没有导入新照片"
            )
        case .untagged:
            EmptyStateView(
                icon: "tag",
                title: "没有未分类照片",
                message: "所有照片都已添加标签"
            )
        default:
            EmptyStateView(
                icon: "photo.on.rectangle.angled",
                title: "没有匹配的照片",
                message: "尝试调整搜索条件或清除筛选",
                actionLabel: viewModel.hasActiveFilters ? "清除筛选" : nil,
                action: viewModel.hasActiveFilters ? {
                    viewModel.searchText = ""
                    viewModel.clearFilters()
                } : nil
            )
        }
    }

    // MARK: - 照片网格
    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 140, maximum: 240), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(Array(filteredPhotos.enumerated()), id: \.element.id) { index, photo in
                    PhotoGridItemView(
                        photo: photo,
                        isSelected: selectedPhoto?.id == photo.id,
                        onDelete: {
                            photoToDelete = photo
                            showDeleteConfirm = true
                        }
                    )
                    .onTapGesture {
                        selectedPhoto = photo
                    }
                    .onTapGesture(count: 2) {
                        // 双击打开大图预览
                        onDoubleTap?(filteredPhotos, index)
                    }
                }
            }
            .padding(12)
        }
    }

    // MARK: - 删除照片
    private func deletePhoto(_ photo: Photo) {
        // 清除选中状态
        if selectedPhoto?.id == photo.id {
            selectedPhoto = nil
        }

        // 从标签中移除
        photo.tags.removeAll()

        // 删除关联笔记
        if let note = photo.note {
            modelContext.delete(note)
        }

        // 清除缓存
        ThumbnailCacheService.shared.removeCache(for: photo.id)

        // 删除照片记录
        modelContext.delete(photo)

        try? modelContext.save()
    }
}
