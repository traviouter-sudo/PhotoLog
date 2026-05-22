# PhotoLog 📸

摄影师的私人照片学习笔记本 — macOS 原生应用

**v1.0.0** — 首个正式发布版本

> 用 SwiftUI + SwiftData 构建，支持照片导入、EXIF 读取、标签管理、地图定位、三栏结构化位置输入等完整功能。

## 环境要求

- **macOS 14.0+** (Sonoma 及以上)
- **Xcode 15+** (完整版，非 Command Line Tools)
- **Apple M 系列芯片** (arm64)

> ⚠️ SwiftData 的 `@Model` 宏需要完整 Xcode，Command Line Tools 不支持

## 快速开始

### 方式一：直接安装（推荐 👆 右侧 Releases 下载）

> 无需 Xcode，无需编译，下载即用

1. 点击页面右侧 **Releases** 区域中的 `PhotoLog-v1.0.0.dmg` 下载
2. 双击 `.dmg` 文件
3. 将 **PhotoLog.app** 拖入 **Applications** 文件夹
4. 从 Launchpad 或 Applications 打开即可使用

### 方式二：XcodeGen 生成项目（开发者）

```bash
# 1. 安装 XcodeGen
brew install xcodegen

# 2. 生成 .xcodeproj
cd PhotoLog
xcodegen generate

# 3. 打开项目
open PhotoLog.xcodeproj
```

### 方式二：手动创建 Xcode 项目

1. 打开 Xcode → File → New → Project → macOS → App
2. Product Name: `PhotoLog`，Interface: `SwiftUI`，Storage: `SwiftData`
3. 将本项目的 `PhotoLog/` 目录下所有文件拖入项目
4. 确保 Deployment Target 设为 macOS 14.0

## 项目结构

```
PhotoLog/
├── Package.swift                    # SPM 配置（需要完整 Xcode）
├── project.yml                      # XcodeGen 配置
├── generate-xcodeproj.sh            # 一键生成项目脚本
├── Scripts/
│   └── build-and-package.sh         # 构建与打包脚本
├── PhotoLog/
│   ├── App/
│   │   ├── PhotoLogApp.swift        # 应用入口 + SwiftData Container + 菜单命令
│   │   └── ContentView.swift        # 主视图（三栏布局 + 拖拽导入）
│   ├── Models/
│   │   ├── Photo.swift              # 照片模型（引用式存储）
│   │   ├── Tag.swift                # 标签模型
│   │   └── PhotoNote.swift          # 笔记模型（参数+分析）
│   ├── Views/
│   │   ├── MainLayout/
│   │   │   ├── SidebarView.swift    # 左侧边栏（快捷入口+标签管理）
│   │   │   └── DetailPanelView.swift # 右侧面板（参数+分析+评分）
│   │   ├── Gallery/
│   │   │   ├── PhotoGridView.swift  # 照片网格（筛选+排序）
│   │   │   ├── PhotoGridItemView.swift # 网格项（缩略图+角标）
│   │   │   ├── OfflineIndicatorView.swift # 离线标识
│   │   │   └── EmptyStateView.swift # 空状态组件
│   │   ├── DetailPanel/
│   │   │   ├── ParameterSectionView.swift # 拍摄参数
│   │   │   ├── AnalysisSectionView.swift  # 个人分析
│   │   │   ├── TagEditorView.swift        # 标签编辑器
│   │   │   └── RatingSectionView.swift    # 评分与收藏
│   │   ├── Preview/
│   │   │   └── PhotoPreviewView.swift # 大图预览（缩放+切换）
│   │   ├── Toolbar/
│   │   │   └── SearchFilterView.swift # 搜索与筛选工具栏
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift       # 设置主页
│   │   │   └── StorageSettingsView.swift # 存储设置
│   │   └── Sidebar/
│   │       └── TagListView.swift        # 标签管理服务
│   ├── Services/
│   │   ├── ImportService.swift       # 导入服务（拖拽+文件选择）
│   │   ├── ThumbnailService.swift    # 缩略图生成（ImageIO）
│   │   ├── ThumbnailCacheService.swift # 缩略图内存缓存（NSCache）
│   │   ├── EXIFService.swift         # EXIF 读取（ImageIO）
│   │   └── FileAccessService.swift   # 文件访问与离线检测
│   ├── ViewModels/
│   │   └── GalleryViewModel.swift    # 照片库视图模型（筛选+排序）
│   ├── Resources/
│   │   └── Assets.xcassets/         # 资源文件
│   └── PhotoLog.entitlements        # 沙箱权限
├── PhotoLogTests/                   # 单元测试
└── PhotoLogUITests/                 # UI 测试
```

## 功能概览

| 功能 | 状态 | 说明 |
|-----|------|------|
| 照片导入 | ✅ | 拖拽 + 文件选择器，引用式存储 |
| 缩略图 | ✅ | ImageIO 异步生成，NSCache 二级缓存 |
| EXIF 读取 | ✅ | 自动读取 8 个拍摄参数 |
| 照片网格 | ✅ | 自适应列数，离线/收藏/评分角标 |
| 大图预览 | ✅ | 缩放、拖拽、左右切换、Esc 退出 |
| 标签管理 | ✅ | 10 色预设，右键编辑/删除 |
| 照片打标签 | ✅ | 芯片式展示，Popover 添加/移除 |
| 星级评分 | ✅ | 1-5 星 + 取消评分 |
| 收藏 | ✅ | 收藏切换 + 侧边栏快捷筛选 |
| 搜索筛选 | ✅ | 关键词 + 评分 + 日期 + 收藏/离线 |
| 外置硬盘 | ✅ | 离线检测 + 重新扫描 + 卷宗识别 |
| 存储设置 | ✅ | 默认导入目录 + 缩略图质量 |
| 键盘快捷键 | ✅ | ⌘I 导入、⌘⇧I 面板、⌘⇧R 扫描 |
| 空状态引导 | ✅ | 欢迎引导 + 分类空状态 |
| 打包分发 | ✅ | 签名+公证+DMG 脚本 |

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| ⌘I | 导入照片 |
| ⌘⇧I | 切换右侧面板 |
| ⌘⇧R | 重新扫描离线状态 |
| ← → | 大图预览中切换照片 |
| Esc | 退出大图预览 |

## 打包发布

```bash
# 构建并打包（无签名）
./Scripts/build-and-package.sh

# 构建并签名+公证
./Scripts/build-and-package.sh PhotoLog "Developer ID Application: Your Name (TEAMID)"
```

## 技术栈

| 层级 | 技术 |
|-----|------|
| 语言 | Swift 5.9+ |
| UI | SwiftUI |
| 数据 | SwiftData |
| EXIF | ImageIO |
| 缓存 | NSCache |
| 构建工具 | Xcode 15+ / XcodeGen |
| 包管理 | SPM |

## 开发进度

- [x] 20/20 任务完成 ✅
- 详见 `ai/memory-bank/tasks/photolog-tasklist.md`

---

## 🤖 关于本项目

> 本项目从 **第一行代码到最后发布**，全程由 AI Agent（WorkBuddy）辅助生成、调试、打包、上传至 GitHub。
>
> - 全部源码（29 个 Swift 文件，约 5000 行）基于 SwiftUI + SwiftData 编写
> - 包含完整的 Xcode 项目配置（XcodeGen / project.yml）
> - Release 构建、DMG 打包、Git 版本管理、SSH 密钥配置、GitHub Releases 发布均通过 Agent 协作完成
