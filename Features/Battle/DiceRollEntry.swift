import SwiftUI
import MechBuddyDomain

struct DiceRollEntry: View {
    @Binding var mode: DiceMode
    @Binding var die1: Int?
    @Binding var die2: Int?
    var manualPrompt: String
    var autoPrompt: String
    var identifierPrefix: String

    private var clearingMode: Binding<DiceMode> {
        Binding(
            get: { mode },
            set: { newMode in
                guard newMode != mode else { return }
                die1 = nil
                die2 = nil
                mode = newMode
            }
        )
    }

    var body: some View {
        DiceTray(
            mode: clearingMode,
            die1: $die1,
            die2: $die2,
            manualPrompt: manualPrompt,
            autoPrompt: autoPrompt,
            identifierPrefix: identifierPrefix
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
}
