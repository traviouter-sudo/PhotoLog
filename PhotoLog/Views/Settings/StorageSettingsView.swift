import SwiftUI
import SwiftData

/// 存储位置设置视图
/// 允许用户设置默认导入根目录（如外置硬盘路径）
/// 提供缓存管理功能
struct StorageSettingsView: View {
    @AppStorage("defaultImportDirectory") private var defaultImportDirectory: String = ""
    @AppStorage("showOfflineBadge") private var showOfflineBadge: Bool = true
    @AppStorage("thumbnailSize") private var thumbnailSize: Int = 1200
    @AppStorage("thumbnailQuality") private var thumbnailQuality: Double = 0.92

    @State private var isSelectingDirectory = false
    @State private var showClearCacheConfirm = false
    @State private var cacheCleared = false

    @Query private var allPhotos: [Photo]
    @Environment(\.modelContext) private var modelContext

    /// 缩略图缓存大小估算
    private var thumbnailCacheSize: String {
        let totalBytes = allPhotos.compactMap { $0.thumbnail?.count }.reduce(0, +)
        return ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }

    /// 有缩略图的照片数量
    private var thumbnailCount: Int {
        allPhotos.filter { $0.thumbnail != nil }.count
    }

    var body: some View {
        Form {
            // 默认导入目录
            Section("导入设置") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("默认导入目录")
                            .font(.body)
                        if defaultImportDirectory.isEmpty {
                            Text("未设置 - 使用文件选择器手动选择")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(defaultImportDirectory)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            if FileAccessService.isExternalVolume(defaultImportDirectory) {
                                Label("外置硬盘路径", systemImage: "externaldrive")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Spacer()

                    Button("选择...") {
                        isSelectingDirectory = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if !defaultImportDirectory.isEmpty {
                        Button {
                            defaultImportDirectory = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("清除默认目录")
                    }
                }

                if !defaultImportDirectory.isEmpty {
                    HStack {
                        Text("目录状态")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if FileManager.default.fileExists(atPath: defaultImportDirectory) {
                            Label("在线", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("离线", systemImage: "externaldrive.badge.questionmark")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            // 缩略图设置
            Section("缩略图") {
                Picker("缩略图尺寸", selection: $thumbnailSize) {
                    Text("小 (600px)").tag(600)
                    Text("中 (1200px)").tag(1200)
                    Text("大 (2000px)").tag(2000)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("缩略图质量")
                        Spacer()
                        Text("\(Int(thumbnailQuality * 100))%")
                            .monospacedDigit()
                    }
                    Slider(value: $thumbnailQuality, in: 0.5...1.0, step: 0.1) {
                        Text("质量")
                    }
                }
            }

            // 缓存管理
            Section("缓存管理") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("缩略图缓存")
                            .font(.body)
                        HStack(spacing: 12) {
                            Label("\(thumbnailCount) 张缩略图", systemImage: "photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Label(thumbnailCacheSize, systemImage: "internaldrive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        showClearCacheConfirm = true
                    } label: {
                        Label("清理缓存", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(thumbnailCount == 0)
                }

                if cacheCleared {
                    Label("缓存已清理", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }

            // 显示设置
            Section("显示") {
                Toggle("显示离线标识", isOn: $showOfflineBadge)
                    .help("在网格视图中为离线照片显示特殊标识")
            }

            // 提示
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("照片以路径引用方式存储，不会复制到本地")
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption)

                    Label {
                        Text("外置硬盘断开时，缩略图和笔记仍可正常访问")
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption)

                    Label {
                        Text("清理缓存后，下次浏览照片时会自动重新生成缩略图")
                    } icon: {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.yellow)
                    }
                    .font(.caption)

                    Label {
                        Text("将默认目录设为外置硬盘路径，可方便批量导入")
                    } icon: {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.yellow)
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $isSelectingDirectory,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    defaultImportDirectory = url.path
                }
            case .failure(let error):
                print("选择目录失败: \(error)")
            }
        }
        .alert("清理缩略图缓存", isPresented: $showClearCacheConfirm) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) {
                clearThumbnailCache()
            }
        } message: {
            Text("将清除所有 \(thumbnailCount) 张缩略图缓存（约 \(thumbnailCacheSize)）。原文件不受影响，浏览时会自动重新生成。")
        }
    }

    // MARK: - 清理缓存
    private func clearThumbnailCache() {
        // 清除内存缓存
        ThumbnailCacheService.shared.clearAll()

        // 清除 SwiftData 中的缩略图数据
        for photo in allPhotos {
            photo.thumbnail = nil
        }

        try? modelContext.save()

        withAnimation {
            cacheCleared = true
        }

        // 3 秒后隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                cacheCleared = false
            }
        }
    }
}
