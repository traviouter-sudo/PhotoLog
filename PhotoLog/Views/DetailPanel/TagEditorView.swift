import SwiftUI
import SwiftData

/// 标签编辑器 - 为照片添加/移除标签
struct TagEditorView: View {
    @Bindable var photo: Photo
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Environment(\.modelContext) private var modelContext
    @State private var showTagPicker = false

    /// 照片尚未关联的标签
    private var availableTags: [Tag] {
        let photoTagIDs = Set(photo.tags.map { $0.id })
        return allTags.filter { !photoTagIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 已有标签
            if photo.tags.isEmpty {
                HStack {
                    Text("未添加标签")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    addTagButton
                }
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(photo.tags) { tag in
                        tagChip(tag, isRemovable: true)
                    }
                    addTagButton
                }
            }
        }

        // 标签选择弹窗
        .popover(isPresented: $showTagPicker) {
            tagPickerPopover
        }
    }

    // MARK: - 添加标签按钮
    private var addTagButton: some View {
        Button {
            showTagPicker = true
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.caption2)
                Text("标签")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    // MARK: - 标签芯片
    @ViewBuilder
    private func tagChip(_ tag: Tag, isRemovable: Bool = false) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: tag.colorHex) ?? .accentColor)
                .frame(width: 6, height: 6)

            Text(tag.name)
                .font(.caption2)

            if isRemovable {
                Button {
                    removeTag(tag)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (Color(hex: tag.colorHex) ?? .accentColor).opacity(0.15),
            in: Capsule()
        )
    }

    // MARK: - 标签选择弹窗
    private var tagPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("添加标签")
                .font(.headline)

            if availableTags.isEmpty {
                if allTags.isEmpty {
                    Text("还没有标签，请在左侧边栏创建")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("所有标签已添加")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(availableTags) { tag in
                            Button {
                                addTag(tag)
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: tag.colorHex) ?? .accentColor)
                                        .frame(width: 8, height: 8)
                                    Text(tag.name)
                                        .font(.caption)
                                    Spacer()
                                    Text("\(tag.photos.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 200)
        .frame(maxHeight: 300)
    }

    // MARK: - 操作
    private func addTag(_ tag: Tag) {
        if !photo.tags.contains(where: { $0.id == tag.id }) {
            photo.tags.append(tag)
        }
        showTagPicker = false
    }

    private func removeTag(_ tag: Tag) {
        photo.tags.removeAll { $0.id == tag.id }
    }
}
