import SwiftUI
import SwiftData

/// 评分与收藏区 - 独立组件
/// 支持星级评分（1-5）和收藏切换
struct RatingSectionView: View {
    @Bindable var photo: Photo
    @State private var hoverStar: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("评分")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                // 星级评分
                ForEach(1...5, id: \.self) { star in
                    starButton(star: star)
                }

                Spacer()

                // 收藏按钮
                favoriteButton
            }
        }
    }

    // MARK: - 星级按钮
    @ViewBuilder
    private func starButton(star: Int) -> some View {
        let isFilled = star <= (hoverStar ?? photo.rating)
        let isActive = star <= photo.rating

        Button {
            // 点击同一颗星取消评分
            photo.rating = (photo.rating == star) ? 0 : star
        } label: {
            Image(systemName: isFilled ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundStyle(
                    isActive ? .yellow : (hoverStar != nil && isFilled ? .yellow.opacity(0.6) : .secondary.opacity(0.3))
                )
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(star == 1 ? "1 星" : "\(star) 星")
        .onHover { hovering in
            if hovering {
                hoverStar = star
            } else {
                hoverStar = nil
            }
        }
    }

    // MARK: - 收藏按钮
    private var favoriteButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                photo.isFavorite.toggle()
            }
        } label: {
            Image(systemName: photo.isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 16))
                .foregroundStyle(photo.isFavorite ? .red : .secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(photo.isFavorite ? "取消收藏" : "收藏")
    }
}
