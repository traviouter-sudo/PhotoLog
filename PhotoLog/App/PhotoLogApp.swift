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
            // 文件菜单
            CommandGroup(replacing: .newItem) {
                Button("导入照片...") {
                    NotificationCenter.default.post(name: NSNotification.Name("TriggerImport"), object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            // 应用菜单（苹果 logo）中的关于和设置
            CommandGroup(replacing: .appInfo) {
                Button("关于 PhotoLog") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
                Divider()
                Button("设置...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            // 编辑菜单
            CommandGroup(replacing: .textEditing) {
                Button("撤销") { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
                    .keyboardShortcut("z", modifiers: .command)
                Button("重做") { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                Divider()
                Button("剪切") { NSApp.sendAction(Selector(("cut:")), to: nil, from: nil) }
                    .keyboardShortcut("x", modifiers: .command)
                Button("拷贝") { NSApp.sendAction(Selector(("copy:")), to: nil, from: nil) }
                    .keyboardShortcut("c", modifiers: .command)
                Button("粘贴") { NSApp.sendAction(Selector(("paste:")), to: nil, from: nil) }
                    .keyboardShortcut("v", modifiers: .command)
                Button("全选") { NSApp.sendAction(Selector(("selectAll:")), to: nil, from: nil) }
                    .keyboardShortcut("a", modifiers: .command)
                Button("删除") { NSApp.sendAction(Selector(("delete:")), to: nil, from: nil) }
                    .keyboardShortcut(.delete, modifiers: [])
            }
            // 显示菜单
            CommandGroup(replacing: .toolbar) {
                Button("显示详情面板") {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleDetailPanel"), object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
            }
            // 窗口菜单
            CommandGroup(replacing: .windowSize) {
                Button("最小化") { NSApp.keyWindow?.miniaturize(nil) }
                    .keyboardShortcut("m", modifiers: .command)
                Button("缩放") { NSApp.keyWindow?.zoom(nil) }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

/// 根视图 — 持有全局状态
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
            .onAppear {
                NotificationCenter.default.addObserver(forName: NSNotification.Name("TriggerImport"), object: nil, queue: .main) { _ in
                    triggerImport = true
                }
                NotificationCenter.default.addObserver(forName: NSNotification.Name("ToggleDetailPanel"), object: nil, queue: .main) { _ in
                    showDetailPanel.toggle()
                }
            }
    }
}
