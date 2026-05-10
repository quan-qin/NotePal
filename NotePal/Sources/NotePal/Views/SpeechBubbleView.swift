import SwiftUI

struct SpeechBubbleView: View {
    let message: String

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text(message)
                .font(.system(size: 11.8, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(bubbleBackground)

            BubbleTail()
                .fill(bubbleFill)
                .overlay(
                    BubbleTail()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
                )
                .frame(width: 17, height: 9)
                .offset(y: -1)
        }
        .background(Color.clear)
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(bubbleFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
    }

    private var bubbleFill: Color {
        Color(nsColor: .windowBackgroundColor).opacity(0.98)
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
