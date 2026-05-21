import SwiftUI
import SwiftData

/// 照片大图预览视图
/// 使用全屏覆盖 + 直接绑定 showPhotoPreview 来关闭
struct PhotoPreviewView: View {
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
            // 深色背景，点击可关闭
            Color.black.ignoresSafeArea()
                .onTapGesture { close() }

            // 图片始终居中（占满全屏）
            imageArea

            // 顶部工具栏 — 浮在图片上方
            VStack {
                previewToolbar
                    .padding(.top, 8)
                Spacer()
            }

            // 底部信息栏 — 浮在图片上方
            VStack {
                Spacer()
                bottomBar
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
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
            let filePath = photo.filePath
            let photoID = photo.id

            let image = await Task.detached(priority: .userInitiated) {
                let url = URL(fileURLWithPath: filePath)
                return NSImage(contentsOf: url)
            }.value

            // 确保还在当前照片上
            if let image, currentPhoto?.id == photoID {
                self.fullImage = image
            }
            self.isLoadingImage = false
        }
    }

    // MARK: - 顶部工具栏
    private var previewToolbar: some View {
        HStack {
            // 关闭按钮
            Button {
                close()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("关闭预览 (Esc)")

            Spacer()

            // 缩放控制
            HStack(spacing: 12) {
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

            Spacer()

            // 占位保持居中
            Color.clear.frame(width: 28)
        }
        .padding(.horizontal, 16)
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
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
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
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            Text("无法加载图片")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - 底部信息栏
    private var bottomBar: some View {
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
        .padding(.horizontal, 32)
        .frame(maxWidth: 400)
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
