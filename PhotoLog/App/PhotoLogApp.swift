import SwiftUI
import SwiftData

@main
struct PhotoLogApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Photo.self, Tag.self, PhotoNote.self])
        let config = ModelConfiguration(schema: schema)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema 迁移失败时，删除旧数据库自动重建
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeFiles = try? FileManager.default.contentsOfDirectory(
                at: appSupport, includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent.hasPrefix("default.store") }
            storeFiles?.forEach { try? FileManager.default.removeItem(at: $0) }

            container = try! ModelContainer(for: schema, configurations: config)
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(container)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
        }
    }
}

/// 根视图 — 持有 showDetailPanel / triggerImport 全局状态
struct AppRootView: View {
    @State private var showDetailPanel = true
    @State private var triggerImport = false

    var body: some View {
        ContentView(showDetailPanel: $showDetailPanel, triggerImport: $triggerImport)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        showDetailPanel.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .help(showDetailPanel ? "隐藏详情面板" : "显示详情面板")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        triggerImport = true
                    } label: {
                        Image(systemName: "plus.rectangle.on.folder")
                    }
                    .help("导入照片")
                }
            }
    }
}
