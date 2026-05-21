import SwiftUI
import SwiftData

/// 搜索与筛选工具栏视图
/// 提供搜索框 + 多条件筛选面板
struct SearchFilterView: View {
    @Bindable var viewModel: GalleryViewModel
    @State private var showFilterPanel = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 搜索框
            searchField
            
            // 筛选按钮
            filterButton
            
            // 清除筛选
            if viewModel.hasActiveFilters {
                clearButton
            }
        }
    }
    
    // MARK: - 搜索框
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextField("搜索文件名、相机、镜头、标签...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.caption)
                .frame(width: 200)
            
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator, lineWidth: 0.5)
        )
    }
    
    // MARK: - 筛选按钮
    private var filterButton: some View {
        Button {
            showFilterPanel.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                Text("筛选")
                    .font(.caption)
                if viewModel.hasActiveFilters {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .popover(isPresented: $showFilterPanel) {
            filterPanel
        }
    }
    
    // MARK: - 筛选面板
    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 排序
            VStack(alignment: .leading, spacing: 6) {
                Text("排序")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Picker("排序方式", selection: $viewModel.sortOption) {
                    ForEach(PhotoSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            // 评分范围
            VStack(alignment: .leading, spacing: 6) {
                Text("评分范围")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("最低")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Picker("", selection: $viewModel.minRating) {
                            Text("不限").tag(0)
                            ForEach(1...5, id: \.self) { i in
                                Text("\(i)★").tag(i)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("最高")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Picker("", selection: $viewModel.maxRating) {
                            ForEach(0...5, id: \.self) { i in
                                if i == 0 {
                                    Text("不限").tag(5)
                                } else {
                                    Text("\(i)★").tag(i)
                                }
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            }
            
            Divider()
            
            // 日期范围
            VStack(alignment: .leading, spacing: 6) {
                Text("导入日期")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    DatePicker("开始", selection: Binding(
                        get: { viewModel.startDate ?? Date.distantPast },
                        set: { viewModel.startDate = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    
                    DatePicker("结束", selection: Binding(
                        get: { viewModel.endDate ?? Date.distantFuture },
                        set: { viewModel.endDate = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }
                
                if viewModel.startDate != nil || viewModel.endDate != nil {
                    Button("清除日期") {
                        viewModel.startDate = nil
                        viewModel.endDate = nil
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
            
            Divider()
            
            // 快捷筛选
            VStack(alignment: .leading, spacing: 6) {
                Text("快捷筛选")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Toggle("仅收藏", isOn: $viewModel.showFavoritesOnly)
                    .font(.caption)
                    .toggleStyle(.checkbox)
                
                Toggle("仅离线", isOn: $viewModel.showOfflineOnly)
                    .font(.caption)
                    .toggleStyle(.checkbox)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
    
    // MARK: - 清除筛选按钮
    private var clearButton: some View {
        Button {
            viewModel.clearFilters()
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                Text("清除筛选")
                    .font(.caption2)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
