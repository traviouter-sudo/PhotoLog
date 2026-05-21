import SwiftUI
import SwiftData

/// 右侧面板 - 拍摄参数 + 个人分析
/// 选中照片时显示详情，未选中时显示提示
struct DetailPanelView: View {
    @Bindable var selectedPhoto: Photo
    @State private var collapsedSections: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 照片预览小图
                photoPreview(selectedPhoto)

                Divider()

                // 标签区
                VStack(alignment: .leading, spacing: 6) {
                    Text("标签")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TagEditorView(photo: selectedPhoto)
                }

                Divider()

                // 评分与收藏
                RatingSectionView(photo: selectedPhoto)

                Divider()

                // 拍摄参数
                collapsibleSection("拍摄参数", icon: "camera", id: "params") {
                    ParameterSectionView(photo: selectedPhoto)
                }

                Divider()

                // 个人分析
                collapsibleSection("个人分析", icon: "text.bubble", id: "analysis") {
                    AnalysisSectionView(photo: selectedPhoto)
                }
            }
            .padding()
        }
    }

    // MARK: - 照片预览
    @ViewBuilder
    private func photoPreview(_ photo: Photo) -> some View {
        Group {
            if let thumbnailData = photo.thumbnail,
               let nsImage = ThumbnailCacheService.shared.imageFromData(thumbnailData, photoID: photo.id) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 可折叠区域
    @ViewBuilder
    private func collapsibleSection<Content: View>(
        _ title: String,
        icon: String,
        id: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if collapsedSections.contains(id) {
                        collapsedSections.remove(id)
                    } else {
                        collapsedSections.insert(id)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.caption)
                    Text(title)
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: collapsedSections.contains(id) ? "chevron.right" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            if !collapsedSections.contains(id) {
                content()
            }
        }
    }
}

/// 空状态面板（未选中照片时）
struct EmptyDetailPanelView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("选择一张照片查看详情")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 简易 Flow Layout（水平自动换行）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
