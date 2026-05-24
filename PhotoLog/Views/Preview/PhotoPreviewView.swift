import SwiftUI
import SwiftData
import os.log

/// 照片大图预览视图
/// 在软件界面内居中显示，背景半透明变暗，点击背景关闭
struct PhotoPreviewView: View {
    private static let logger = Logger(subsystem: "com.photolog", category: "Preview")
    let photos: [Photo]
    @Binding var currentIndex: Int
    @Binding var isPresented: Bool

    // 缩放状态
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isDragging = false

    // 异步图片加载
    @State private var fullImage: NSImage?
    @State private var isLoadingImage = false

    var body: some View {
        ZStack {
            // 半透明深色背景，点击可关闭
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { close() }

            // 图片区域（居中，限制最大尺寸，不占满全屏）
            VStack(spacing: 0) {
                // 顶部：关闭按钮（右上角）
                HStack {
                    Spacer()
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("关闭预览 (Esc)")
                    .padding(.trailing, 12)
                    .padding(.top, 12)
                }

                // 图片居中显示
                ZStack {
                    imageArea
                }
                .frame(
                    maxWidth: min(NSApp.mainWindow?.frame.width ?? 800, 900) - 40,
                    maxHeight: (NSApp.mainWindow?.frame.height ?? 600) - 140
                )
                .padding(.horizontal, 20)

                // 底部：缩放控制 + 翻页
                bottomBar
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onKeyPress(.escape) {
            close()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            navigateToPrevious()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateToNext()
            return .handled
        }
        .onChange(of: currentIndex) { _, _ in
            loadFullImage()
        }
        .onAppear {
            loadFullImage()
        }
    }

    var currentPhoto: Photo? {
        guard indicesValid else { return nil }
        return photos[currentIndex]
    }

    var indicesValid: Bool {
        !photos.isEmpty && currentIndex >= 0 && currentIndex < photos.count
    }

    // MARK: - 关闭
    private func close() {
        fullImage = nil
        isPresented = false
    }

    // MARK: - 异步加载高清图
    private func loadFullImage() {
        guard let photo = currentPhoto, !photo.isOffline else {
            fullImage = nil
            return
        }
        isLoadingImage = true
        fullImage = nil

        Task { @MainActor in
            let photoID = photo.id

            let image = await Task.detached(priority: .userInitiated) {
                // 预览大图使用全像素尺寸加载（基于 bookmark 安全路径）
                // NSImage.size = 真实像素，保证 SwiftUI 在 .fit 模式下 1:1 渲染
                return ThumbnailCacheService.loadFullSize(for: photo)
            }.value

            // 确保还在当前照片上
            if let image, currentPhoto?.id == photoID {
                self.fullImage = image
            }
            self.isLoadingImage = false
        }
    }

    // MARK: - 大图区域
    @ViewBuilder
    private var imageArea: some View {
        if let photo = currentPhoto {
            if photo.isOffline {
                offlineView
            } else if let fullImage {
                interactiveImage(Image(nsImage: fullImage))
            } else if let thumbnailData = photo.thumbnail,
                      let nsImage = ThumbnailCacheService.shared.imageFromData(thumbnailData, photoID: photo.id) {
                ZStack {
                    interactiveImage(Image(nsImage: nsImage))
                        .blur(radius: 2)

                    if isLoadingImage {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white.opacity(0.7))
                            .scaleEffect(1.5)
                    }
                }
            } else if isLoadingImage {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white.opacity(0.7))
                    .scaleEffect(1.5)
            } else {
                unavailableView
            }
        } else {
            unavailableView
        }
    }

    /// 可交互的图片（缩放 + 拖拽），居中显示
    private func interactiveImage(_ image: Image) -> some View {
        image
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .scaleEffect(zoomScale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                        isDragging = false
                    }
            )
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newScale = zoomScale * value.magnification
                        zoomScale = min(max(newScale, 0.5), 5.0)
                    }
            )
            .animation(.easeInOut(duration: isDragging ? 0 : 0.2), value: zoomScale)
    }

    /// 离线状态提示
    private var offlineView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.4))
            Text("文件离线")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.5))
            Text("请连接外置硬盘后重试")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    /// 无图可用
    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            Text("无法加载图片")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - 底部工具栏（缩放 + 翻页 + 文件名）
    private var bottomBar: some View {
        VStack(spacing: 8) {
            // 缩放控制
            HStack(spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomScale = max(0.5, zoomScale - 0.25)
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("缩小")

                Text("\(Int(zoomScale * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 44)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomScale = min(5.0, zoomScale + 0.25)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("放大")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right.magnifyingglass")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("重置缩放")
            }

            // 翻页 + 文件名
            HStack {
                Button {
                    navigateToPrevious()
                } label: {
                    Image(systemName: "chevron.left.circle")
                        .font(.title2)
                        .foregroundStyle(currentIndex > 0 ? .white.opacity(0.7) : .white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(currentIndex <= 0)
                .help("上一张 (←)")

                Spacer()

                if let photo = currentPhoto {
                    VStack(spacing: 2) {
                        Text(photo.fileName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                        Text("\(currentIndex + 1) / \(photos.count)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                Button {
                    navigateToNext()
                } label: {
                    Image(systemName: "chevron.right.circle")
                        .font(.title2)
                        .foregroundStyle(currentIndex < photos.count - 1 ? .white.opacity(0.7) : .white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(currentIndex >= photos.count - 1)
                .help("下一张 (→)")
            }
            .frame(maxWidth: 400)
        }
    }

    // MARK: - 导航
    private func navigateToPrevious() {
        guard currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex -= 1
            resetZoom()
        }
    }

    private func navigateToNext() {
        guard currentIndex < photos.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex += 1
            resetZoom()
        }
    }

    private func resetZoom() {
        zoomScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}
