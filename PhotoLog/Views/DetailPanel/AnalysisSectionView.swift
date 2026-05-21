import SwiftUI
import SwiftData

/// 个人分析面板 - 可编辑的 5 个文本块
struct AnalysisSectionView: View {
    @Bindable var photo: Photo
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let note = photo.note {
                AnalysisNoteEditor(note: note)
            } else {
                Button("添加个人分析") {
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

/// 分析编辑子视图 — 直接 @Bindable note + $note.xxx 绑定
struct AnalysisNoteEditor: View {
    @Bindable var note: PhotoNote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            analysisBlock(
                title: "整体想法",
                icon: "lightbulb",
                text: $note.overallThought,
                placeholder: "你对这张照片的第一感受...",
                accentColor: .blue
            )

            analysisBlock(
                title: "优点",
                icon: "hand.thumbsup",
                text: $note.pros,
                placeholder: "这张照片做得好的地方...",
                accentColor: .green
            )

            analysisBlock(
                title: "缺点 / 遗憾",
                icon: "hand.thumbsdown",
                text: $note.cons,
                placeholder: "不满意或拍摄失误的地方...",
                accentColor: .orange
            )

            analysisBlock(
                title: "学习点",
                icon: "book",
                text: $note.learnings,
                placeholder: "下次可以改进或借鉴的...",
                accentColor: .purple
            )

            analysisBlock(
                title: "后期处理备注",
                icon: "slider.horizontal.3",
                text: $note.postProcess,
                placeholder: "记录后期处理流程（可选）...",
                accentColor: .secondary
            )
        }
    }

    @ViewBuilder
    private func analysisBlock(
        title: String,
        icon: String,
        text: Binding<String>,
        placeholder: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
            }

            TextEditor(text: text)
                .font(.caption)
                .frame(minHeight: 60, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.background.secondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(text.wrappedValue.isEmpty ? Color.secondary.opacity(0.2) : accentColor.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}
