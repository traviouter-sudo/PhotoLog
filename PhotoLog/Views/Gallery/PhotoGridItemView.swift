import SwiftUI
import SwiftData

/// 照片网格项 - 单张缩略图卡片
struct PhotoGridItemView: View {
    let photo: Photo
    let isSelected: Bool
    var onDelete: (() -> Void)?

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

                // 收藏角标
                if photo.isFavorite {
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
                    .stroke(isSelected ? Color.accentColor : (isHovered ? Color.accentColor.opacity(0.3) : Color.clear),
                            lineWidth: isSelected ? 3 : 1.5)
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 4)

            // 文件名
            Text(photo.fileName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
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

    // MARK: - 缩略图视图
    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailData = photo.thumbnail,
           let nsImage = ThumbnailCacheService.shared.imageFromData(thumbnailData, photoID: photo.id) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minHeight: 120, maxHeight: 200)
                .clipped()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(height: 150)
                .overlay {
                    Image(systemName: photo.isOffline ? "externaldrive.badge.questionmark" : "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
