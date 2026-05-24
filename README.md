# PhotoLog 📸

摄影师的私人照片学习笔记本 — macOS 原生应用

**v1.1.0** — [📥 点击下载安装包](https://github.com/traviouter-sudo/PhotoLog/releases/tag/v1.1.0)

> 用 SwiftUI + SwiftData 构建，支持照片导入、EXIF 读取、标签管理、地图定位、三栏结构化位置输入等完整功能。

## 快速开始

### 方式一：直接安装（推荐 👆 或右侧 Releases 下载）

> 无需 Xcode，无需编译，下载即用

1. 下载 [`PhotoLog-v1.1.0.dmg`](https://github.com/traviouter-sudo/PhotoLog/releases/tag/v1.1.0)
2. 双击 `.dmg` 文件
3. 将 **PhotoLog.app** 拖入 **Applications** 文件夹
4. 从 Launchpad 或 Applications 打开即可使用

> ⚠️ 首次打开可能需要在「系统设置 → 隐私与安全性」中允许运行（未签名应用）

### 方式二：从源码构建（开发者）

```bash
# 1. 克隆仓库
git clone https://github.com/traviouter-sudo/PhotoLog.git
cd PhotoLog

# 2. 安装 XcodeGen 并生成项目
brew install xcodegen
xcodegen generate

# 3. 打开并编译
open PhotoLog.xcodeproj
```

**环境要求**：macOS 14.0+ / Xcode 15+（完整版）/ Apple M 系列芯片

## 功能概览

| 功能 | 说明 |
|-----|------|
| 📥 照片导入 | 拖拽 + 文件选择器，引用式存储（不复制文件） |
| 🖼️ 缩略图 | ImageIO 异步生成，NSCache 二级缓存，流畅滚动 |
| 📊 EXIF 读取 | 自动读取光圈/快门/ISO/焦距/镜头等 8 项参数 |
| 🗺️ 地图定位 | GPS 自动读取 + 三栏地址输入（市/区/具体位置）+ 地图同步 |
| 🏷️ 标签管理 | 10 色预设标签，芯片式展示，右键编辑删除 |
| ⭐ 星级评分 | 1-5 星评分 + 收藏切换 + 侧边栏快捷筛选 |
| 🔍 搜索筛选 | 关键词 + 评分 + 日期 + 收藏/离线 多维筛选 |
| 💾 外置硬盘 | 离线检测 + 重新扫描 + 卷宗识别，支持外置存储 |
| ⌨️ 快捷键 | ⌘I 导入 · ⌘⇧I 面板 · ⌘⇧R 扫描 · ←→ 切换 · Esc 退出 |

## 项目结构

```
PhotoLog/
├── PhotoLog/App/              # 应用入口 & 主视图
├── PhotoLog/Models/           # 数据模型（Photo / Tag / PhotoNote）
├── PhotoLog/Views/            # 全部 UI 视图（29 个 Swift 文件）
│   ├── MainLayout/            #   三栏布局：侧边栏 / 网格 / 详情面板
│   ├── Gallery/               #   照片网格 + 缩略图 + 空状态
│   ├── DetailPanel/           #   拍摄参数 / 个人分析 / 评分 / 标签
│   ├── Preview/               #   大图预览（缩放/拖拽/切换）
│   ├── Toolbar/               #   搜索与筛选工具栏
│   ├── Settings/              #   设置页面 & 存储配置
│   └── Sidebar/               #   标签管理列表
├── PhotoLog/Services/         # 核心服务（导入/缩略图/EXIF/文件访问）
├── PhotoLog/ViewModels/       # 视图模型（筛选/排序逻辑）
├── project.yml                # XcodeGen 配置
├── generate-xcodeproj.sh      # 一键生成项目脚本
└── Scripts/build-and-package.sh # Release 构建与 DMG 打包
```

## 技术栈

Swift 5.9+ · SwiftUI · SwiftData · ImageIO · MapKit · NSCache · XcodeGen · SPM

## 更新日志

### v1.1.0 (2026-05-24)

#### 🖼️ 修复
- 修复重启后照片缩略图模糊问题 — 通过 Security-Scoped Bookmark 持久化沙箱权限

#### ✨ 新增功能
- **多选批量删除** — 工具栏多选模式，支持一次性选中并删除多张照片
- **搜索与筛选** — 照片网格工具栏集成搜索/筛选功能
- **胶卷参数字段** — 拍摄参数面板新增「胶卷」字段（如 Portra 400、Ektar 100）
- **来源链接编辑器** — 参数面板新增 URL 输入框，一键在浏览器中打开

#### 🎨 界面优化
- 完整菜单栏支持（文件/编辑/显示/窗口），含快捷键（⌘O 导入、⌥⌘D 切换详情面板等）
- 分析面板精简：4 个区块 → 1 个备注区
- 新增简体中文本地化

---

### v1.0.0 (2026-05-22)

#### 🎉 首个正式发布
- 照片导入（引用式存储，不复制文件）
- EXIF 自动读取（光圈/快门/ISO/焦距等）
- 三栏结构化位置输入 + 地图定位同步
- 标签管理（10 色预设）+ 星级评分
- 搜索筛选 + 外置硬盘离线检测
- 大图预览（缩放/拖拽/切换）

---

## 开发进度

V1.1.0 已发布 ✅

---

## 🤖 关于本项目

本项目从 **第一行代码到最后发布**，全程由 AI Agent 辅助生成、调试、打包、上传至 GitHub。

包括：完整 SwiftUI + SwiftData 源码编写、Xcode 项目配置、Release 构建、DMG 打包、Git 版本管理、SSH 密钥配置、GitHub Releases 发布。
