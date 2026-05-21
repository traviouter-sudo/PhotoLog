import SwiftUI
import SwiftData
import MapKit

/// 拍摄参数面板 - 可编辑 + 可配置字段 + 来源信息 + GPS 地图 + 自定义字段
struct ParameterSectionView: View {
    @Bindable var photo: Photo
    @Environment(\.modelContext) private var modelContext
    @State private var showFieldConfig = false
    @State private var newFieldLabel = ""
    @State private var showAddCustomField = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let note = photo.note {
                ParameterNoteEditor(
                    note: note,
                    showFieldConfig: $showFieldConfig,
                    showAddCustomField: $showAddCustomField,
                    newFieldLabel: $newFieldLabel
                )
            } else {
                Button("添加拍摄参数") {
                    let note = PhotoNote()
                    modelContext.insert(note)
                    photo.note = note
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
    }
}

/// 参数编辑子视图 — 直接 @Bindable note + $note.xxx 绑定确保输入持久化
struct ParameterNoteEditor: View {
    @Bindable var note: PhotoNote
    @Binding var showFieldConfig: Bool
    @Binding var showAddCustomField: Bool
    @Binding var newFieldLabel: String
    @State private var isGeocoding = false
    @State private var geocodeError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 可见参数字段（排除 city/district/location，它们单独渲染）
            ForEach(note.visibleParameterKeys.filter { !["city", "district", "location"].contains($0.key) }) { field in
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.label)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    if field.key == "shootDate" {
                        TextField("如 2026-04-22 14:30", text: dateTextBinding)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    } else {
                        noteTextField(for: field.key, placeholder: field.placeholder)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }
                }
            }

            // 城市区县具体位置 — 三栏输入 + 地理编码
            locationTriFieldSection

            // 自定义参数字段
            customFieldsSection

            // 位置与地图区域（有坐标或已填写地址时显示）
            if note.hasGPS || note.hasLocationInfo {
                locationMapSection
            }

            // 字段配置按钮
            fieldConfigButton
        }
    }

    /// 直接使用 @Bindable 投影绑定 $note.xxx
    @ViewBuilder
    private func noteTextField(for key: String, placeholder: String) -> some View {
        switch key {
        case "camera":         TextField(placeholder, text: $note.camera)
        case "lens":           TextField(placeholder, text: $note.lens)
        case "shutterSpeed":   TextField(placeholder, text: $note.shutterSpeed)
        case "aperture":       TextField(placeholder, text: $note.aperture)
        case "iso":            TextField(placeholder, text: $note.iso)
        case "focalLength":    TextField(placeholder, text: $note.focalLength)
        case "exposureComp":   TextField(placeholder, text: $note.exposureComp)
        case "location":       TextField(placeholder, text: $note.location)
        case "city":           TextField(placeholder, text: $note.city)
        case "district":       TextField(placeholder, text: $note.district)
        case "lightCondition": TextField(placeholder, text: $note.lightCondition)
        case "sourceURL":      TextField(placeholder, text: $note.sourceURL)
        case "originalAuthor": TextField(placeholder, text: $note.originalAuthor)
        default:               TextField(placeholder, text: $note.camera)
        }
    }

    /// 日期绑定
    private var dateTextBinding: Binding<String> {
        Binding(
            get: {
                if let date = note.shootDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                    return formatter.string(from: date)
                }
                return ""
            },
            set: { text in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                if let date = formatter.date(from: text) {
                    note.shootDate = date
                } else {
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let date = formatter.date(from: text) {
                        note.shootDate = date
                    }
                }
            }
        )
    }

    // MARK: - 自定义参数字段
    @ViewBuilder
    private var customFieldsSection: some View {
        if !note.customFields.isEmpty || showAddCustomField {
            Divider()
                .padding(.vertical, 2)

            Text("自定义参数")
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)

            ForEach(Array(note.customFields.enumerated()), id: \.element.id) { index, field in
                HStack(spacing: 6) {
                    TextField("参数名", text: customFieldLabelBinding(for: field.id))
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(width: 80)

                    TextField("值", text: customFieldValueBinding(for: field.id))
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            note.removeCustomField(at: index)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }

            if showAddCustomField {
                HStack(spacing: 6) {
                    TextField("参数名", text: $newFieldLabel)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(width: 80)
                        .onSubmit { addCustomField() }

                    Button("添加") { addCustomField() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.caption2)

                    Button("取消") {
                        showAddCustomField = false
                        newFieldLabel = ""
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            } else {
                addCustomFieldButton
            }
        } else {
            addCustomFieldButton
        }
    }

    private var addCustomFieldButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                showAddCustomField = true
            }
        } label: {
            Label("添加自定义参数", systemImage: "plus.circle")
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 位置信息（地图联动）

    /// 三栏位置输入（城市 / 区县 / 具体位置）+ 地理编码按钮
    private var locationTriFieldSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("📍 拍摄地点")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                // 地理编码按钮
                Button { geocodeLocation() } label: {
                    HStack(spacing: 3) {
                        if isGeocoding {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                        }
                        Text("定位")
                            .font(.caption2)
                    }
                    .foregroundStyle(note.hasGPS ? Color.accentColor : (geocodeError ? .red : .secondary))
                }
                .buttonStyle(.plain)
                .disabled(isGeocoding || note.fullAddress.isEmpty)
                .help(note.hasGPS
                      ? "已定位（点击重新解析）"
                      : "将地址转换为 GPS 坐标并同步到地图")
            }

            // 三栏输入
            HStack(spacing: 6) {
                // 城市
                VStack(alignment: .leading, spacing: 2) {
                    Text("市")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TextField("如 北京", text: $note.city)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit { geocodeLocation() }
                }

                // 区县
                VStack(alignment: .leading, spacing: 2) {
                    Text("区")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TextField("如 东城", text: $note.district)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit { geocodeLocation() }
                }

                // 具体位置
                VStack(alignment: .leading, spacing: 2) {
                    Text("地点")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TextField("如 故宫", text: $note.location)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit { geocodeLocation() }
                }

                Spacer(minLength: 0)
            }

            // 已填写的地址预览
            if !note.fullAddress.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble.left")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(note.shortAddress)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    /// 位置与地图区域 — 统一处理 GPS 坐标和手动输入的地址
    private var locationMapSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("位置")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                // 状态指示
                if note.hasGPS {
                    // 有坐标 — 精确定位
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(String(format: "%.4f", note.latitude!)), \(String(format: "%.4f", note.longitude!))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !note.shortAddress.isEmpty && note.shortAddress != "未设置" {
                            Text(note.shortAddress)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                } else if note.hasLocationInfo {
                    // 无坐标但有文字地址
                    Image(systemName: "mappin")
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(note.shortAddress == "未设置" ? note.fullAddress : note.shortAddress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("（未定位到坐标）")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                // 地图按钮
                if note.hasGPS {
                    Button { openMap() } label: {
                        Label("在地图中查看", systemImage: "map")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if note.hasLocationInfo {
                    // 搜索 + 获取坐标 双按钮
                    Button { openMapSearch() } label: {
                        Label("搜索", systemImage: "safari")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button { geocodeLocation() } label: {
                        Label("定位", systemImage: "location")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isGeocoding)
                }
            }

            // 地理编码错误提示
            if geocodeError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("无法解析「\(note.fullAddress)」，请检查地址或尝试更具体的描述")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 定位成功提示
            if note.hasGPS && !isGeocoding && !geocodeError {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("已同步到地图浏览 ✓")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: geocodeError)
        .animation(.easeInOut(duration: 0.2), value: note.hasGPS)
    }

    // MARK: - 字段配置按钮
    private var fieldConfigButton: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                showFieldConfig.toggle()
            } label: {
                Label(
                    showFieldConfig ? "完成配置" : "配置参数字段",
                    systemImage: showFieldConfig ? "checkmark.circle" : "slider.horizontal.3"
                )
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            if showFieldConfig {
                fieldConfigPanel
            }
        }
    }

    // MARK: - 字段配置面板
    private var fieldConfigPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("显示/隐藏参数字段")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            ForEach(PhotoNote.allParameterKeys) { field in
                HStack {
                    Image(systemName: note.hiddenParameterKeys.contains(field.key) ? "square" : "checkmark.square")
                        .font(.caption)
                        .foregroundStyle(note.hiddenParameterKeys.contains(field.key) ? .secondary : Color.accentColor)
                    Text(field.label)
                        .font(.caption)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        note.toggleParameterVisibility(field.key)
                    }
                }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 辅助方法

    /// 地理编码：将城市+区县+具体位置拼接为完整地址，解析为经纬度
    private func geocodeLocation() {
        let address = note.fullAddress
        guard !address.isEmpty else { return }

        isGeocoding = true
        geocodeError = false

        Task { @MainActor in
            let geocoder = CLGeocoder()
            do {
                let placemarks = try await geocoder.geocodeAddressString(address)
                if let placemark = placemarks.first, let location = placemark.location {
                    // 写入坐标 → note.hasGPS 变为 true
                    note.latitude = location.coordinate.latitude
                    note.longitude = location.coordinate.longitude

                    // 智能反填：如果用户留空的字段，用系统返回的数据补充
                    if note.city.isEmpty,
                       let adminArea = placemark.administrativeArea,           // 省/州
                       let locality = placemark.locality,                    // 市
                       !locality.isEmpty {
                        // 中国地址格式：省+市 合并为 city（如 "北京市"）
                        let fullCity = adminArea + locality
                        note.city = fullCity
                    }
                    if note.district.isEmpty,
                       let subLocality = placemark.subLocality,             // 区/县
                       !subLocality.isEmpty {
                        note.district = subLocality
                    }
                    if note.location.isEmpty,
                       let name = placemark.name ?? placemark.thoroughfare,   // 地点名称/道路
                       !name.isEmpty {
                        note.location = name
                    }
                } else {
                    geocodeError = true
                }
                isGeocoding = false
            } catch {
                print("⚠️ 地理编码失败: \(error.localizedDescription)")
                geocodeError = true
                isGeocoding = false
            }
        }
    }

    /// 打开 Apple Maps — 使用坐标精确定位（有 GPS 时）
    private func openMap() {
        guard let lat = note.latitude, let lon = note.longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = note.shortAddress == "未设置" ? "照片位置" : note.shortAddress
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: coordinate,
            MKLaunchOptionsMapSpanKey: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ])
    }

    /// 打开 Apple Maps — 用地址文字搜索（无 GPS 但有地址时）
    private func openMapSearch() {
        let address = note.fullAddress
        guard !address.isEmpty else { return }

        // 将地址 URL 编码后通过 maps:// 协议打开搜索
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        if let url = URL(string: "maps://?q=\(encodedAddress)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func customFieldValueBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { note.customFields.first(where: { $0.id == id })?.value ?? "" },
            set: { newValue in
                note.updateCustomField(id: id, value: newValue)
            }
        )
    }

    private func customFieldLabelBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { note.customFields.first(where: { $0.id == id })?.label ?? "" },
            set: { newValue in
                note.updateCustomFieldLabel(id: id, label: newValue)
            }
        )
    }

    private func addCustomField() {
        let label = newFieldLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            note.addCustomField(label: label)
            newFieldLabel = ""
            showAddCustomField = false
        }
    }
}
