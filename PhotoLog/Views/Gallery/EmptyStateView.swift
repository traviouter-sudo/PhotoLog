import SwiftUI

/// 空状态视图组件 - 可复用的空状态提示
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.secondary.opacity(0.5))
            
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            if let actionLabel = actionLabel, let action = action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 欢迎引导视图 - 首次启动时显示
struct WelcomeGuideView: View {
    var onImport: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 32) {
            // 大图标
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor)
            }
            
            VStack(spacing: 8) {
                Text("欢迎使用 PhotoLog")
                    .font(.title.bold())
                
                Text("摄影师的照片学习笔记本")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // 功能提示
            VStack(spacing: 12) {
                featureRow(icon: "photo.badge.plus", title: "导入照片", description: "拖拽或点击 + 按钮导入照片")
                featureRow(icon: "tag", title: "标签分类", description: "用题材标签快速归类照片")
                featureRow(icon: "pencil.and.list.clipboard", title: "分析撰写", description: "记录参数和心得，提升摄影水平")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            
            // 开始按钮
            Button {
                onImport?()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("导入第一张照片")
                }
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

/// 标签空状态 - 点击标签但无照片
struct TagEmptyStateView: View {
    let tagName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("「\(tagName)」下没有照片")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("在右侧面板为照片添加此标签")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
