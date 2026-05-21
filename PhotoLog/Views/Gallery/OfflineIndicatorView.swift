import SwiftUI

/// 离线照片标识视图 - 用于网格项和详情中显示
/// 外置硬盘未连接时，照片显示灰色遮罩 + 插头图标
struct OfflineIndicatorView: View {
    let isCompact: Bool
    
    init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }
    
    var body: some View {
        if isCompact {
            compactView
        } else {
            fullView
        }
    }
    
    // MARK: - 紧凑版（网格项使用）
    private var compactView: some View {
        HStack(spacing: 2) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 8))
            Text("离线")
                .font(.system(size: 7, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(.red.opacity(0.8), in: Capsule())
    }
    
    // MARK: - 完整版（详情面板使用）
    private var fullView: some View {
        VStack(spacing: 8) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("文件离线")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("请连接外置硬盘后重试")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            if let volume = volumeName {
                Text("卷宗: \(volume)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
    
    /// 卷宗名称（外置硬盘时显示）
    var volumeName: String?
}

/// 网格中的离线遮罩层
struct OfflineOverlay: View {
    var body: some View {
        ZStack {
            // 灰色遮罩
            Color.black.opacity(0.3)
            
            // 离线标识
            VStack(spacing: 4) {
                Image(systemName: "externaldrive.badge.questionmark")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                Text("离线")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
