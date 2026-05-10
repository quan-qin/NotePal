import AppKit
import SwiftUI

struct PetView: View {
    @ObservedObject var todoStore: TodoStore
    @ObservedObject var interactionManager: PetInteractionManager
    @ObservedObject var settingsStore: SettingsStore

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private let canvasSize = CGSize(width: 117, height: 117)

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let theme = settingsStore.selectedPetTheme
            let motionEnabled = settingsStore.animationsEnabled
                && !settingsStore.reducedMotionMode
                && !systemReduceMotion

            ZStack(alignment: .topTrailing) {
                shadow(motionEnabled: motionEnabled, time: time)

                petArtwork(
                    for: theme,
                    displaySize: min(canvasSize.width, settingsStore.petSize * 1.185)
                )
                .scaleEffect(scale(for: interactionManager.state, motionEnabled: motionEnabled, time: time))
                .rotationEffect(.degrees(rotation(for: interactionManager.state, motionEnabled: motionEnabled, time: time)))
                .offset(
                    x: interactionManager.isHovering ? 1.2 : 0,
                    y: verticalOffset(for: interactionManager.state, motionEnabled: motionEnabled, time: time)
                )
                .animation(.spring(response: 0.26, dampingFraction: 0.72), value: interactionManager.bounceToken)
                .accessibilityLabel(theme.accessibilityLabel)

                PetExpressionView(
                    state: interactionManager.state,
                    isHovering: interactionManager.isHovering,
                    blink: blinkValue(time: time),
                    motionEnabled: motionEnabled,
                    time: time
                )

                if todoStore.incompleteCount > 0 {
                    CountBadge(count: todoStore.incompleteCount)
                        .offset(x: -6, y: 6)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .contentShape(Rectangle())
            .onHover { hovering in
                interactionManager.setHovering(hovering)
            }
        }
    }

    @ViewBuilder
    private func petArtwork(for theme: PetTheme, displaySize: CGFloat) -> some View {
        if let petImage = PetAssetLoader.image(for: theme) {
            Image(nsImage: petImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: displaySize, height: displaySize)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .frame(width: displaySize, height: displaySize)
        }
    }

    private func shadow(motionEnabled: Bool, time: TimeInterval) -> some View {
        let width = motionEnabled ? 31.5 + sin(time * 2) * 1.5 : 31.5

        return Ellipse()
            .fill(Color.black.opacity(0.16))
            .frame(width: width + 18, height: 7)
            .blur(radius: 3)
            .offset(x: -13.5, y: 102)
    }

    private func verticalOffset(
        for state: PetState,
        motionEnabled: Bool,
        time: TimeInterval
    ) -> CGFloat {
        guard motionEnabled else { return 5 }

        switch state {
        case .idle:
            return 5 + sin(time * 2.0) * 1.4
        case .happy:
            return 3 + abs(sin(time * 8.0)) * -3
        case .thinking:
            return 5 + sin(time * 1.4) * 0.8
        case .sleeping:
            return 7 + sin(time * 0.9) * 0.6
        case .surprised:
            return 3
        case .reminding:
            return 4 + sin(time * 7.0) * 1.6
        case .focused:
            return 4
        case .celebrating:
            return 2 + abs(sin(time * 9.0)) * -4
        }
    }

    private func scale(
        for state: PetState,
        motionEnabled: Bool,
        time: TimeInterval
    ) -> CGFloat {
        guard motionEnabled else { return 1 }

        switch state {
        case .happy, .celebrating:
            return 1.02 + abs(sin(time * 6.0)) * 0.03
        case .surprised:
            return 1.06
        case .sleeping:
            return 0.98
        default:
            return 1
        }
    }

    private func rotation(
        for state: PetState,
        motionEnabled: Bool,
        time: TimeInterval
    ) -> Double {
        guard motionEnabled else { return 0 }

        switch state {
        case .happy:
            return sin(time * 7.0) * 2.5
        case .celebrating:
            return sin(time * 10.0) * 4.0
        case .focused:
            return -1.5
        default:
            return 0
        }
    }

    private func blinkValue(time: TimeInterval) -> Bool {
        Int(time * 3.0).isMultiple(of: 17)
    }
}

struct PetExpressionView: View {
    let state: PetState
    let isHovering: Bool
    let blink: Bool
    let motionEnabled: Bool
    let time: TimeInterval

    var body: some View {
        ZStack {
            switch state {
            case .idle:
                idleCue
            case .happy:
                happyCue
            case .thinking:
                thinkingCue
            case .sleeping:
                sleepingCue
            case .surprised:
                surprisedCue
            case .reminding:
                remindingCue
            case .focused:
                focusedCue
            case .celebrating:
                celebratingCue
            }

            if isHovering && state != .sleeping {
                hoverCue
            }
        }
        .frame(width: 117, height: 117)
        .allowsHitTesting(false)
    }

    private var idleCue: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Color(red: 0.42, green: 0.95, blue: 0.66).opacity(blink ? 0.25 : 0.95))
            .frame(width: 4, height: 8)
            .offset(x: 32, y: 37)
    }

    private var happyCue: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.34, blue: 0.48))
            .offset(x: -41, y: 15 + bounce(1.5))
    }

    private var thinkingCue: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.primary.opacity(0.55))
                    .frame(width: 3, height: 3)
                    .offset(y: motionEnabled ? sin(time * 4 + Double(index)) * 1.35 : 0)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Capsule().fill(.regularMaterial))
        .offset(x: -38, y: 12)
    }

    private var sleepingCue: some View {
        Text("Zz")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.62))
            .offset(x: 38, y: 12 + bounce(0.9))
    }

    private var surprisedCue: some View {
        Text("!")
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(red: 1.0, green: 0.67, blue: 0.20))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Circle().fill(.regularMaterial))
            .offset(x: 38, y: 15)
    }

    private var remindingCue: some View {
        ZStack {
            Circle()
                .stroke(Color.red.opacity(0.32), lineWidth: 2)
                .frame(width: motionEnabled ? 20 + abs(sin(time * 5)) * 6 : 21)

            Image(systemName: "bell.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.red)
        }
        .offset(x: 39, y: 20)
    }

    private var focusedCue: some View {
        HStack(spacing: 2) {
            Text(">")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 9, height: 2)
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 2, height: 7)
                .opacity(blink ? 0.25 : 1)
        }
        .foregroundStyle(Color(red: 0.42, green: 0.95, blue: 0.66))
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.black.opacity(0.78)))
        .offset(x: 29, y: 74)
    }

    private var celebratingCue: some View {
        ZStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.24, green: 0.78, blue: 0.38))
                .offset(x: 39, y: 18)

            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.76, blue: 0.20))
                .offset(x: -41, y: 21 + bounce(1.05))
        }
    }

    private var hoverCue: some View {
        Circle()
            .fill(Color.white.opacity(0.32))
            .frame(width: 5, height: 5)
            .offset(x: 32, y: 32)
    }

    private func bounce(_ amount: CGFloat) -> CGFloat {
        motionEnabled ? CGFloat(sin(time * 4.2)) * amount : 0
    }
}

private struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: count > 9 ? 9 : 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.65)
            .lineLimit(1)
            .frame(width: count > 9 ? 24 : 18, height: 18)
            .background(Capsule().fill(Color(red: 0.48, green: 0.73, blue: 1.0)))
            .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            .accessibilityLabel("\(count) incomplete todos")
    }
}
