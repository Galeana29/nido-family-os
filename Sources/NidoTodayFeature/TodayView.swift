#if canImport(SwiftUI)
import SwiftUI
import NidoDomain

// Guarded so the package still builds on Linux CI, where the presentation layer below SwiftUI is what
// gets tested. These views hold no schedule logic: everything they show comes from `TodayScreen`.

/// Scandinavian warm clinical: calm, adult, precise. Tokens from `docs/design/design-system.md`,
/// with the terracotta kept decorative because its contrast on light surfaces is insufficient for text.
public enum NidoTheme {
    public static let forest = Color(red: 0.259, green: 0.416, blue: 0.353)
    public static let soft = Color(red: 0.898, green: 0.937, blue: 0.914)
    public static let canvas = Color(red: 0.973, green: 0.965, blue: 0.945)
    public static let surface = Color.white
    public static let textPrimary = Color(red: 0.125, green: 0.145, blue: 0.133)
    public static let textSecondary = Color(red: 0.353, green: 0.384, blue: 0.365)
    public static let terracotta = Color(red: 0.788, green: 0.522, blue: 0.404)

    public enum Radius {
        public static let control: CGFloat = 10
        public static let button: CGFloat = 14
        public static let card: CGFloat = 18
        public static let hero: CGFloat = 24
    }
}

public struct TodayView: View {
    private let screen: TodayScreen
    private let onAction: (TodayAction) -> Void

    public init(screen: TodayScreen, onAction: @escaping (TodayAction) -> Void) {
        self.screen = screen
        self.onAction = onAction
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let now = screen.now {
                    NowCardView(card: now, onAction: onAction)
                }
                if !screen.next.isEmpty {
                    nextStrip
                }
                if !screen.notices.isEmpty {
                    noticesSection
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(NidoTheme.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(screen.greeting)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(NidoTheme.textPrimary)
            Text(screen.dateLine)
                .font(.system(size: 15))
                .foregroundStyle(NidoTheme.textSecondary)
            Text(screen.dayState)
                .font(.system(size: 17))
                .foregroundStyle(NidoTheme.textPrimary)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var nextStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(screen.next, id: \.ruleID) { item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(item.time)
                        .font(.system(size: 15, weight: .medium).monospacedDigit())
                        .foregroundStyle(NidoTheme.textSecondary)
                        .frame(width: 52, alignment: .leading)
                    Text(item.title)
                        .font(.system(size: 17))
                        .foregroundStyle(NidoTheme.textPrimary)
                    Spacer(minLength: 8)
                    if item.wasAdjusted {
                        // An indicator, never a badge of failure.
                        Circle()
                            .fill(NidoTheme.terracotta)
                            .frame(width: 6, height: 6)
                            .accessibilityLabel(Text("adjusted"))
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(NidoTheme.surface, in: RoundedRectangle(cornerRadius: NidoTheme.Radius.card))
            }
        }
    }

    private var noticesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(screen.notices, id: \.self) { notice in
                Text(notice)
                    .font(.system(size: 15))
                    .foregroundStyle(NidoTheme.textPrimary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NidoTheme.soft, in: RoundedRectangle(cornerRadius: NidoTheme.Radius.card))
            }
        }
    }
}

/// The hero. Large target, low on the screen, reachable with a child on one arm.
public struct NowCardView: View {
    private let card: NowCard
    private let onAction: (TodayAction) -> Void

    public init(card: NowCard, onAction: @escaping (TodayAction) -> Void) {
        self.card = card
        self.onAction = onAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.eyebrow)
                .font(.system(size: 13, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(NidoTheme.forest)

            Text(card.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(NidoTheme.textPrimary)

            Text(card.timeRange)
                .font(.system(size: 17).monospacedDigit())
                .foregroundStyle(NidoTheme.textSecondary)

            if let explanation = card.explanation {
                Text(explanation)
                    .font(.system(size: 15))
                    .foregroundStyle(NidoTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                onAction(card.primaryAction)
            } label: {
                Text(card.primaryActionLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(NidoTheme.forest, in: RoundedRectangle(cornerRadius: NidoTheme.Radius.button))
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NidoTheme.surface, in: RoundedRectangle(cornerRadius: NidoTheme.Radius.hero))
    }
}
#endif
