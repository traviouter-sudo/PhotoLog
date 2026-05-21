import SwiftUI
import SwiftData
import MapKit

/// 地图浏览视图 - 显示所有有 GPS 坐标的照片位置
struct PhotoMapView: View {
    @Query(sort: \Photo.importDate, order: .reverse) private var allPhotos: [Photo]
    @Binding var selectedPhoto: Photo?

    /// 有 GPS 坐标的照片
    private var geoPhotos: [(photo: Photo, coordinate: CLLocationCoordinate2D)] {
        allPhotos.compactMap { photo in
            guard let note = photo.note,
                  let lat = note.latitude,
                  let lon = note.longitude else { return nil }
            return (photo, CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }

    /// 地图区域
    @State private var cameraPosition: MapCameraPosition = .automatic

    /// 选中的标注
    @State private var selectedAnnotation: PhotoAnnotation?

    var body: some View {
        Group {
            if geoPhotos.isEmpty {
                // 没有 GPS 数据
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                    Text("没有带位置信息的照片")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("导入包含 GPS 数据的照片后，这里会显示它们的地理位置")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mapContent
            }
        }
        .navigationTitle("地图浏览")
    }

    // MARK: - 地图内容
    @ViewBuilder
    private var mapContent: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, selection: $selectedAnnotation) {
                ForEach(geoPhotos.map { PhotoAnnotation(photo: $0.photo, coordinate: $0.coordinate) }) { annotation in
                    Annotation(
                        annotation.photo.fileName,
                        coordinate: annotation.coordinate
                    ) {
                        photoMapPin(annotation.photo)
                    }
                    .tag(annotation)
                }
            }
            .mapStyle(.standard)

            // 底部统计栏
            HStack {
                Label("\(geoPhotos.count) 张照片有位置信息", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("\(allPhotos.count - geoPhotos.count) 张无位置", systemImage: "questionmark.mappin")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(12)
        }

        // 选中标注时显示照片信息
        .onChange(of: selectedAnnotation) { _, newValue in
            if let annotation = newValue {
                selectedPhoto = annotation.photo
            }
        }
        .sheet(item: $selectedAnnotation) { annotation in
            photoDetailSheet(annotation.photo)
        }
    }

    // MARK: - 照片地图标注
    @ViewBuilder
    private func photoMapPin(_ photo: Photo) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 32, height: 32)

            if let thumbnailData = photo.thumbnail,
               let nsImage = ThumbnailCacheService.shared.imageFromData(thumbnailData, photoID: photo.id) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
        }
        .shadow(radius: 3)
    }

    // MARK: - 照片详情弹窗
    @ViewBuilder
    private func photoDetailSheet(_ photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 缩略图
            if let thumbnailData = photo.thumbnail,
               let nsImage = ThumbnailCacheService.shared.imageFromData(thumbnailData, photoID: photo.id) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(photo.fileName)
                    .font(.headline)
                if let note = photo.note {
                    if !note.camera.isEmpty {
                        Text(note.camera)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !note.location.isEmpty || !note.city.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !note.city.isEmpty && note.shortAddress != "未设置" {
                                Text(note.shortAddress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if !note.location.isEmpty {
                                Text(note.location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            HStack {
                // 在 Finder 中显示
                Button {
                    NSWorkspace.shared.selectFile(photo.filePath, inFileViewerRootedAtPath: "")
                } label: {
                    Label("在 Finder 中显示", systemImage: "folder")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(photo.isOffline)

                Spacer()

                Button("关闭") {
                    selectedAnnotation = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

// MARK: - 照片标注模型
struct PhotoAnnotation: Identifiable, Hashable {
    let photo: Photo
    let coordinate: CLLocationCoordinate2D

    var id: UUID { photo.id }

    func hash(into hasher: inout Hasher) {
        hasher.combine(photo.id)
    }

    static func == (lhs: PhotoAnnotation, rhs: PhotoAnnotation) -> Bool {
        lhs.photo.id == rhs.photo.id
    }
}
