import SwiftUI

struct TNGauge: View {
    var targetNumber: Int
    var rolledTotal: Int?
    var reason: String?
    /// Replaces the numeral when the shot is illegal before a target number exists.
    var blockedTitle: String?
    var previewIdentifier: String? = "as.sator.tnPreview"
    var gaugeIdentifier: String? = "as.sator.tn"

    @ScaledMetric(relativeTo: .largeTitle) private var readoutSize: CGFloat = TMFont.readoutLBase
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isShort: Bool { verticalSizeClass == .compact }
    private var numeralSize: CGFloat { isShort ? readoutSize * 0.62 : readoutSize }
    private var histogramHeight: CGFloat { isShort ? 28 : 44 }
    private var barMax: CGFloat { isShort ? 20 : 36 }
    private var autoMiss: Bool { blockedTitle == nil && targetNumber > 12 }
    private var odds = 0

    init(
        targetNumber: Int,
        rolledTotal: Int? = nil,
        reason: String? = nil,
        blockedTitle: String? = nil,
        previewIdentifier: String? = "as.sator.tnPreview",
        gaugeIdentifier: String? = "as.sator.tn"
    ) {
        self.targetNumber = targetNumber
        self.rolledTotal = rolledTotal
        self.reason = reason
        self.blockedTitle = blockedTitle
        self.previewIdentifier = previewIdentifier
        self.gaugeIdentifier = gaugeIdentifier
        self.odds = TwoD6Display.percent(for: targetNumber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow(blockedTitle == nil ? "Need" : "Shot")
            if let blockedTitle {
                Text(blockedTitle)
                    .font(TMFont.readoutL(size: numeralSize * 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if autoMiss {
                Text("Can’t hit")
                    .font(TMFont.readoutL(size: numeralSize * 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(targetNumber)+")
                        .font(TMFont.readoutL(size: numeralSize))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Spacer(minLength: TMSpace.sm)
                    Text("\(odds)% to hit")
                        .font(TMFont.readoutM)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Text("or higher")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            histogram
            if let reason, !reason.isEmpty, blockedTitle != nil || autoMiss {
                Text(reason)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(isShort ? TMSpace.sm : TMSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TMColor.readout, in: RoundedRectangle(cornerRadius: TMRadius.readout, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifiers(primary: previewIdentifier ?? "as.sator.tnPreview", extra: gaugeIdentifier, label: spoken)
        .onChange(of: targetNumber) { _, newValue in
            postAnnouncement(for: newValue)
        }
        .onChange(of: blockedTitle) { _, _ in
            AccessibilityNotification.Announcement(spoken).post()
        }
    }

    private var spoken: String {
        if let blockedTitle {
            if let reason, !reason.isEmpty { return "\(blockedTitle). \(reason)" }
            return blockedTitle
        }
        if autoMiss {
            return "Can’t hit"
        }
        return "Target number \(targetNumber) or higher, \(odds) percent"
    }

    private var histogram: some View {
        VStack(spacing: TMSpace.xxs) {
            HStack(alignment: .bottom, spacing: TMSpace.xxs) {
                ForEach(2...12, id: \.self) { total in
                    bar(for: total)
                }
            }
            .frame(height: histogramHeight)
            HStack {
                Text("2")
                Spacer()
                Text("7")
                Spacer()
                Text("12")
            }
            .font(TMFont.statLabel)
            .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    private func bar(for total: Int) -> some View {
        let ways = TwoD6Display.ways(for: total)
        let meets = blockedTitle == nil && !autoMiss && total >= targetNumber
        let marked = rolledTotal == total
        return VStack(spacing: TMSpace.xxs) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(meets ? TMColor.signal : TMColor.pipEmpty)
                .frame(height: max(4, CGFloat(ways) / 6 * barMax))
            Circle()
                .fill(marked ? TMColor.onSignal : Color.clear)
                .frame(width: 6, height: 6)
                .background {
                    if marked {
                        Circle().fill(TMColor.signal).frame(width: 8, height: 8)
                    }
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func postAnnouncement(for value: Int) {
        if blockedTitle != nil {
            AccessibilityNotification.Announcement(spoken).post()
            return
        }
        let message = value > 12
            ? "Can’t hit"
            : "Target number \(value) or higher, \(TwoD6Display.percent(for: value)) percent"
        AccessibilityNotification.Announcement(message).post()
    }
}

enum TwoD6Display {
    private static let waysByTotal = [1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1]
    private static let waysAtLeast = [2: 36, 3: 35, 4: 33, 5: 30, 6: 26, 7: 21, 8: 15, 9: 10, 10: 6, 11: 3, 12: 1]

    static func ways(for total: Int) -> Int {
        guard (2...12).contains(total) else { return 0 }
        return waysByTotal[total - 2]
    }

    static func percent(for targetNumber: Int) -> Int {
        if targetNumber <= 2 { return 100 }
        if targetNumber > 12 { return 0 }
        let ways = waysAtLeast[targetNumber] ?? 0
        return Int((Double(ways) / 36.0 * 100.0).rounded())
    }
}

#if DEBUG
#Preview("TN gauge") {
    PreviewPair {
        VStack(spacing: TMSpace.lg) {
            TNGauge(targetNumber: 7, rolledTotal: 9)
            TNGauge(targetNumber: 13, reason: "Need 13 or higher. This shot always misses.")
        }
    }
}
#endif
