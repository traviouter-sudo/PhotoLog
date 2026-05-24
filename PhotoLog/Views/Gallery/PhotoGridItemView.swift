import SwiftUI
import SwiftData

/// 照片网格项 - 单张缩略图卡片
struct PhotoGridItemView: View {
    let photo: Photo
    let isSelected: Bool
    var onDelete: (() -> Void)?
    var isMultiSelectMode: Bool = false
    var isMultiSelected: Bool = false
    var onToggleMultiSelect: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // 缩略图
                thumbnailView

                // 离线遮罩
                if photo.isOffline {
                    OfflineOverlay()
                }

                // 多选勾选框（编辑模式）
                if isMultiSelectMode {
                    ZStack {
                        Circle()
                            .fill(isMultiSelected ? Color.accentColor : Color.white.opacity(0.8))
                            .frame(width: 22, height: 22)
                        if isMultiSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(isMultiSelected ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: 1.5)
                    )
                    .padding(6)
                }

                // 收藏角标
                if photo.isFavorite && !isMultiSelectMode {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(4)
                }

                // 评分显示
                if photo.rating > 0 {
                    HStack(spacing: 1) {
                        ForEach(1...photo.rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isMultiSelectMode
                            ? (isMultiSelected ? Color.accentColor : Color.gray.opacity(0.3))
                            : (isSelected ? Color.accentColor : (isHovered ? Color.accentColor.opacity(0.3) : Color.clear)),
                            lineWidth: isMultiSelectMode ? 2 : (isSelected ? 3 : 1.5))
            )
            .overlay(
                // 多选模式下未选中的照片加半透明遮罩
                isMultiSelectMode && !isMultiSelected ?
                RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.3)) : nil
            )
            .shadow(color: (isMultiSelectMode ? isMultiSelected : isSelected) ? Color.accentColor.opacity(0.3) : .clear, radius: 4)

            // 文件名
            Text(photo.fileName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .onAppear {
            loadImage()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .contextMenu {
            Button {
                // 在 Finder 中显示
                NSWorkspace.shared.selectFile(photo.filePath, inFileViewerRootedAtPath: "")
            } label: {
                Label("在 Finder 中显示", systemImage: "folder")
            }
            .disabled(photo.isOffline)

            Divider()

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("从照片库移除", systemImage: "trash")
            }
        }
    }

    /// 缩略图状态：加载中 / 已加载 / 无图（占位符）
    @State private var displayImage: NSImage?
    @State private var isLoading = false

    // MARK: - 缩略图视图
    ///
    /// 渲染策略（优先级从高到低）：
    /// 1. 源文件存在 → 用 CGImageSource 安全加载源文件（最高质量）
    /// 2. 源文件不存在 + 有缩略图数据 → 用 CGImageSource 安全加载缩略图 Data
    /// 3. 都没有 → 显示占位符
    @ViewBuilder
    private var thumbnailView: some View {
        if let image = displayImage {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(minHeight: 120, maxHeight: 200)
                .clipped()
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(height: 150)
                .overlay {
                    if isLoading && !photo.isOffline {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Image(systemName: photo.isOffline ? "externaldrive.badge.questionmark" : "photo")
                        .font(.title2)
                        .foregroundStyle(photo.isOffline ? .secondary : .tertiary)
                }
        }
    }

    /// 加载图像：统一走 ThumbnailCacheService.loadSafely(for:) 路径（基于 bookmark）
    private func loadImage() {
        guard !photo.isOffline else {
            // 离线照片：从数据库缩略图 Data 加载
            loadThumbnailData()
            return
        }

        // 在线照片：异步从源文件加载（CGImageSource + bookmark 安全路径）
        isLoading = true
        let photoID = photo.id

        Task { @MainActor in
            let image = await Task.detached(priority: .userInitiated) {
                return ThumbnailCacheService.loadSafely(for: photo)
            }.value

            guard self.photo.id == photoID else { return }

            if let image {
                self.displayImage = image
            } else {
                // 源文件加载失败，fallback 到数据库缩略图
                self.loadThumbnailData()
            }
            self.isLoading = false
        }
    }

    /// 从数据库缩略图 Data 加载（离线或源文件不可用时的 fallback）
    private func loadThumbnailData() {
        guard let thumbnailData = photo.thumbnail else { return }

        // 同步加载缩略图 Data（已在内存中或本地磁盘，很快）
        let image = ThumbnailCacheService.loadSafely(from: thumbnailData, photoID: photo.id)
        if let image {
            self.displayImage = image
        }
    }
}
