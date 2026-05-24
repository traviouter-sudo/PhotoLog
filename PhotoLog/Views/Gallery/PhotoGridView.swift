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

    // 批量操作
    @State private var isEditMode = false
    @State private var multiSelectedIDs: Set<UUID> = []
    @State private var showBatchDeleteConfirm = false

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
        .toolbar {
            // 多选按钮 — 独立放置
            ToolbarItem(placement: .automatic) {
                if isEditMode {
                    HStack(spacing: 8) {
                        Button(multiSelectedIDs.count == filteredPhotos.count ? "取消全选" : "全选") {
                            if multiSelectedIDs.count == filteredPhotos.count {
                                multiSelectedIDs.removeAll()
                            } else {
                                multiSelectedIDs = Set(filteredPhotos.map(\.id))
                            }
                        }
                        .disabled(filteredPhotos.isEmpty)

                        Button("删除选中 (\(multiSelectedIDs.count))") {
                            showBatchDeleteConfirm = true
                        }
                        .disabled(multiSelectedIDs.isEmpty)
                        .tint(.red)

                        Button("完成") {
                            exitEditMode()
                        }
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                } else {
                    Button {
                        isEditMode = true
                    } label: {
                        Label("多选", systemImage: "checklist")
                    }
                    .help("批量选择照片")
                }
            }

            // 搜索 + 筛选
            ToolbarItem(placement: .automatic) {
                SearchFilterView(viewModel: viewModel)
            }
        }
        .onChange(of: sidebarItem) { _, _ in
            // 切换侧边栏时退出编辑模式
            exitEditMode()
        }
        .onDeleteCommand {
            if isEditMode {
                if !multiSelectedIDs.isEmpty {
                    showBatchDeleteConfirm = true
                }
            } else if let photo = selectedPhoto {
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
        .alert("批量删除确认", isPresented: $showBatchDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("删除 \(multiSelectedIDs.count) 张照片", role: .destructive) {
                batchDeleteSelected()
            }
        } message: {
            Text("将 \(multiSelectedIDs.count) 张照片从照片库中移除？原文件不会被删除。")
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
                        isSelected: selectedPhoto?.id == photo.id && !isEditMode,
                        onDelete: {
                            photoToDelete = photo
                            showDeleteConfirm = true
                        },
                        isMultiSelectMode: isEditMode,
                        isMultiSelected: multiSelectedIDs.contains(photo.id)
                    )
                    .onTapGesture {
                        if isEditMode {
                            toggleMultiSelect(photo)
                        } else {
                            selectedPhoto = photo
                        }
                    }
                    .onTapGesture(count: 2) {
                        if !isEditMode {
                            onDoubleTap?(filteredPhotos, index)
                        }
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

    // MARK: - 批量操作

    private func toggleMultiSelect(_ photo: Photo) {
        if multiSelectedIDs.contains(photo.id) {
            multiSelectedIDs.remove(photo.id)
        } else {
            multiSelectedIDs.insert(photo.id)
        }
    }

    private func batchDeleteSelected() {
        let photosToDelete = filteredPhotos.filter { multiSelectedIDs.contains($0.id) }
        for photo in photosToDelete {
            // 清除选中状态
            if selectedPhoto?.id == photo.id {
                selectedPhoto = nil
            }
            photo.tags.removeAll()
            if let note = photo.note {
                modelContext.delete(note)
            }
            ThumbnailCacheService.shared.removeCache(for: photo.id)
            modelContext.delete(photo)
        }
        try? modelContext.save()
        multiSelectedIDs.removeAll()
        exitEditMode()
    }

    private func exitEditMode() {
        isEditMode = false
        multiSelectedIDs.removeAll()
    }
}
