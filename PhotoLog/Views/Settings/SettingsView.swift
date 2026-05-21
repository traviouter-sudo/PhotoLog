import SwiftUI
import SwiftData

/// 设置页面 - 通用设置 + 存储设置
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }
            
            StorageSettingsView()
                .tabItem {
                    Label("存储", systemImage: "externaldrive")
                }
        }
        .frame(width: 500, height: 400)
    }
}

/// 通用设置视图
struct GeneralSettingsView: View {
    @AppStorage("autoReadEXIF") private var autoReadEXIF: Bool = true
    @AppStorage("autoGenerateThumbnail") private var autoGenerateThumbnail: Bool = true
    @AppStorage("defaultRating") private var defaultRating: Int = 0

    /// 从 Bundle 动态读取版本号（与 project.yml MARKETING_VERSION 同步）
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (build \(build))"
    }
    
    var body: some View {
        Form {
            Section("导入行为") {
                Toggle("自动读取 EXIF 信息", isOn: $autoReadEXIF)
                    .help("导入照片时自动从文件读取拍摄参数")
                
                Toggle("自动生成缩略图", isOn: $autoGenerateThumbnail)
                    .help("导入照片时自动生成缩略图以加速显示")
            }
            
            Section("关于") {
                HStack {
                    Text("PhotoLog")
                        .font(.headline)
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }

                Text("摄影师照片学习笔记本")
                    .foregroundStyle(.secondary)

                Text("照片以路径引用方式存储，不复制原文件")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}
