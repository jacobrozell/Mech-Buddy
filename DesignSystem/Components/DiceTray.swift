import SwiftUI
import MechBuddyDomain

/// Manual faces are the primary control. "Let the app roll" switches the session dice mode.
struct DiceTray: View {
    @Binding var mode: DiceMode
    @Binding var die1: Int?
    @Binding var die2: Int?
    var manualPrompt: String
    var autoPrompt: String
    var identifierPrefix: String

    private var pairToken: String {
        if let die1, let die2 {
            "\(die1)-\(die2)"
        } else {
            ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            if mode == .manual {
                Text(manualPrompt)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                DieFacePicker(title: "First die", value: $die1, accessibilityIdentifier: "\(identifierPrefix).die1")
                DieFacePicker(title: "Second die", value: $die2, accessibilityIdentifier: "\(identifierPrefix).die2")
            } else {
                Text(autoPrompt)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Button {
                    die1 = Int.random(in: 1...6)
                    die2 = Int.random(in: 1...6)
                } label: {
                    Text(die1 == nil || die2 == nil ? "Roll" : "Roll again")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("\(identifierPrefix).autoRoll")
            }
            if let die1, let die2 {
                DiceReadout(die1: die1, die2: die2)
            }
            DiceModeLink(mode: $mode, accessibilityIdentifier: "\(identifierPrefix).diceMode")
        }
        .padding(TMSpace.md)
        .background(TMColor.readout, in: RoundedRectangle(cornerRadius: TMRadius.readout, style: .continuous))
        .tmHaptic(.diceLanded, trigger: pairToken, when: { !$0.isEmpty })
    }
}

struct DiceModeLink: View {
    @Binding var mode: DiceMode
    var accessibilityIdentifier: String

    var body: some View {
        Button(mode == .manual ? "Let the app roll" : "Use real dice") {
            mode = mode == .manual ? .auto : .manual
        }
        .font(TMFont.detail)
        .foregroundStyle(.secondary)
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityHint("Real dice on the table, or the app rolls")
    }
}

/// Segmented dice-mode control kept for Settings. Battle screens use `DiceModeLink`.
struct DiceModePicker: View {
    @Binding var mode: DiceMode
    var identifier: String

    var body: some View {
        Picker("How to roll", selection: $mode) {
            Text("Real dice").tag(DiceMode.manual)
            Text("In the app").tag(DiceMode.auto)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("How to roll")
        .accessibilityHint("Real dice on the table, or the app rolls")
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview("Dice tray") {
    PreviewPair {
        DiceTrayPreviewHost()
    }
}

private struct DiceTrayPreviewHost: View {
    @State private var mode: DiceMode = .manual
    @State private var die1: Int?
    @State private var die2: Int?

    var body: some View {
        DiceTray(
            mode: $mode,
            die1: $die1,
            die2: $die2,
            manualPrompt: "Tap the faces you rolled.",
            autoPrompt: "The app rolls.",
            identifierPrefix: "preview.dice"
        )
    }
}

#Preview("Dice mode picker") {
    DiceModePickerPreview()
        .padding()
}

private struct DiceModePickerPreview: View {
    @State private var mode: DiceMode = .manual

    var body: some View {
        DiceModePicker(mode: $mode, identifier: "preview.diceMode")
    }
}
#endif
