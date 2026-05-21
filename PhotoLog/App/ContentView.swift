import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 主视图 - 三栏布局
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var showDetailPanel: Bool
    @Binding var triggerImport: Bool
    @State private var selectedSidebarItem: SidebarItem? = .allPhotos
    @State private var selectedPhoto: Photo?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isImporting = false
    @State private var importProgress: (current: Int, total: Int)?
    @State private var showPhotoPreview = false
    @State private var previewPhotos: [Photo] = []
    @State private var previewStartIndex = 0
    @State private var galleryViewModel = GalleryViewModel()
    @State private var rescanResult: (online: Int, offline: Int)?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 左栏：侧边栏
            SidebarView(selectedSidebarItem: $selectedSidebarItem)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200)
        } content: {
            // 中栏：照片网格 / 地图
            Group {
                if selectedSidebarItem == .map {
                    PhotoMapView(selectedPhoto: $selectedPhoto)
                        .navigationTitle("地图浏览")
                } else {
                    PhotoGridView(
                        selectedPhoto: $selectedPhoto,
                        sidebarItem: selectedSidebarItem,
                        viewModel: galleryViewModel,
                        onDoubleTap: { photos, index in
                            previewPhotos = photos
                            previewStartIndex = index
                            showPhotoPreview = true
                        },
                        onImportRequest: { triggerImport = true }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    SearchFilterView(viewModel: galleryViewModel)
                }
            }
        } detail: {
            // 右栏：详情面板
            Group {
                if showDetailPanel, let photo = selectedPhoto {
                    DetailPanelView(selectedPhoto: photo)
                        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
                } else {
                    EmptyDetailPanelView()
                        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
                }
            }
        }
        // 大图预览（overlay）
        .overlay {
            if showPhotoPreview {
                PhotoPreviewView(
                    photos: previewPhotos,
                    currentIndex: $previewStartIndex,
                    isPresented: $showPhotoPreview
                )
                .transition(.opacity)
            }
        }
        // 导入文件选择器
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.jpeg, .png, .tiff, .rawImage, .init(filenameExtension: "arw")!, .init(filenameExtension: "cr2")!, .init(filenameExtension: "nef")!, .init(filenameExtension: "dng")!],
            allowsMultipleSelection: true,
            onCompletion: handleImportResult
        )
        // 拖拽导入
        .onDrop(of: ["public.file-url"], isTargeted: nil, perform: { providers in
            handleDrop(providers: providers)
            return true
        })
        // 监听导入触发
        .onChange(of: triggerImport) { _, newValue in
            if newValue {
                isImporting = true
                triggerImport = false
            }
        }
        // 导入进度 overlay
        .overlay(alignment: .bottom) {
            if let progress = importProgress {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("导入中 \(progress.current) / \(progress.total)")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 16)
            }
        }
        // 重新扫描状态提示
        .overlay(alignment: .top) {
            if let result = rescanResult {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("扫描完成：\(result.online) 在线，\(result.offline) 离线")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 12)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        rescanResult = nil
                    }
                }
            }
        }
        // 重新扫描菜单命令
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RescanOnlineStatus"),
                object: nil,
                queue: .main
            ) { _ in
                rescanOnlineStatus()
            }
        }
    }

    // MARK: - 辅助方法

    private func rescanOnlineStatus() {
        let result = FileAccessService.rescanAllPhotos(context: modelContext)
        rescanResult = result
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let paths = urls.map { $0.path }
            importPhotosFromPaths(paths)
        case .failure(let error):
            print("导入失败: \(error)")
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        var paths: [String] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    paths.append(url.path)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            importPhotosFromPaths(paths)
        }
    }

    private func importPhotosFromPaths(_ paths: [String]) {
        guard !paths.isEmpty else { return }
        let total = paths.count
        importProgress = (0, total)

        Task { @MainActor in
            let photos = ImportService.importPhotos(at: paths, context: modelContext)

            for (index, photo) in photos.enumerated() {
                importProgress = (index + 1, total)
                _ = await ThumbnailService.generateThumbnail(for: photo)

                if !photo.isOffline {
                    let note = PhotoNote()
                    EXIFService.readEXIF(for: photo, note: note)
                    modelContext.insert(note)
                    photo.note = note
                }
            }

            try? modelContext.save()
            importProgress = nil
        }
    }
}

/// 侧边栏选中项
enum SidebarItem: Hashable {
    case allPhotos
    case favorites
    case recent
    case untagged
    case map
    case tag(Tag)

    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        switch (lhs, rhs) {
        case (.allPhotos, .allPhotos): return true
        case (.favorites, .favorites): return true
        case (.recent, .recent): return true
        case (.untagged, .untagged): return true
        case (.map, .map): return true
        case (.tag(let a), .tag(let b)): return a.id == b.id
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .allPhotos: hasher.combine("allPhotos")
        case .favorites: hasher.combine("favorites")
        case .recent: hasher.combine("recent")
        case .untagged: hasher.combine("untagged")
        case .map: hasher.combine("map")
        case .tag(let tag): hasher.combine(tag.id)
        }
    }
}

#Preview {
    ContentView(showDetailPanel: .constant(true), triggerImport: .constant(false))
        .modelContainer(for: [Photo.self, Tag.self, PhotoNote.self], inMemory: true)
}
