import SwiftUI
import SwiftData

/// 左侧边栏 - 快捷入口 + 题材标签列表
struct SidebarView: View {
    @Binding var selectedSidebarItem: SidebarItem?
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#007AFF"
    @State private var editingTag: Tag?
    @State private var editTagName = ""
    @State private var editTagColor = ""

    var body: some View {
        List(selection: $selectedSidebarItem) {
            // 快捷入口
            Section("照片库") {
                Label("全部照片", systemImage: "photo.on.rectangle.angled")
                    .tag(SidebarItem.allPhotos)

                Label("最近导入", systemImage: "clock")
                    .tag(SidebarItem.recent)

                Label("收藏", systemImage: "heart.fill")
                    .foregroundStyle(.red)
                    .tag(SidebarItem.favorites)

                Label("地图浏览", systemImage: "map")
                    .tag(SidebarItem.map)

                Label("未分类", systemImage: "questionmark.folder")
                    .tag(SidebarItem.untagged)
            }

            // 题材标签
            Section {
                ForEach(tags) { tag in
                    tagRow(tag)
                }
                .onDelete(perform: deleteTags)
            } header: {
                HStack {
                    Text("题材标签")
                    Spacer()
                    Button {
                        isAddingTag = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("新建标签")
                }
            }
        }
        .listStyle(.sidebar)
        // 新建标签弹窗
        .alert("新建标签", isPresented: $isAddingTag) {
            TextField("标签名称", text: $newTagName)
            Button("取消", role: .cancel) { newTagName = "" }
            Button("创建") {
                createTag()
            }
            .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            VStack {
                Text("输入题材标签名称")
                // 颜色选择
                colorPickerGrid(selectedColor: $newTagColor)
            }
        }
        // 编辑标签弹窗
        .alert("编辑标签", isPresented: Binding(
            get: { editingTag != nil },
            set: { if !$0 { editingTag = nil } }
        )) {
            TextField("标签名称", text: $editTagName)
            Button("取消", role: .cancel) {
                editingTag = nil
            }
            Button("保存") {
                saveTagEdit()
            }
            .disabled(editTagName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            VStack {
                Text("修改标签名称和颜色")
                colorPickerGrid(selectedColor: $editTagColor)
            }
        }
    }

    // MARK: - 标签行视图
    @ViewBuilder
    private func tagRow(_ tag: Tag) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: tag.colorHex) ?? .accentColor)
                .frame(width: 10, height: 10)
            Text(tag.name)
            Spacer()
            if !tag.photos.isEmpty {
                Text("\(tag.photos.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .tag(SidebarItem.tag(tag))
        .contextMenu {
            Button {
                editTagName = tag.name
                editTagColor = tag.colorHex
                editingTag = tag
            } label: {
                Label("重命名", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                TagService.deleteTag(tag, context: modelContext)
            } label: {
                Label("删除标签", systemImage: "trash")
            }
        }
    }

    // MARK: - 颜色选择器
    @ViewBuilder
    private func colorPickerGrid(selectedColor: Binding<String>) -> some View {
        HStack(spacing: 6) {
            ForEach(TagService.presetColors, id: \.hex) { color in
                Circle()
                    .fill(Color(hex: color.hex) ?? .accentColor)
                    .frame(width: 18, height: 18)
                    .overlay {
                        if selectedColor.wrappedValue == color.hex {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .onTapGesture {
                        selectedColor.wrappedValue = color.hex
                    }
            }
        }
    }

    // MARK: - 标签操作
    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        _ = TagService.createTag(name: name, colorHex: newTagColor, context: modelContext)
        newTagName = ""
        newTagColor = "#007AFF"
    }

    private func saveTagEdit() {
        guard let tag = editingTag else { return }
        TagService.renameTag(tag, newName: editTagName)
        tag.colorHex = editTagColor
        editingTag = nil
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            TagService.deleteTag(tags[index], context: modelContext)
        }
    }
}
