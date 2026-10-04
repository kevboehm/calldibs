import SwiftUI
import DibsCore

/// Type any percentage, nudge it, or tap a common one, and choose whether it
/// applies before or after tax.
struct TipControl: View {
    @Binding var percent: Int
    @Binding var base: TipConfig.Base

    private let quickTips = [15, 18, 20, 25]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tip rate")
                Spacer()
                TextField("20", value: $percent, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 52)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 10))
                Text("%")
                    .foregroundStyle(.secondary)
                Stepper("Tip rate", value: $percent, in: 0...100)
                    .labelsHidden()
            }

            HStack(spacing: Theme.Spacing.small) {
                ForEach(quickTips, id: \.self) { tip in
                    Button("\(tip)%") { choose(tip) }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(percent == tip ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            Picker("Tip on", selection: $base) {
                Text("Before tax").tag(TipConfig.Base.preTax)
                Text("After tax").tag(TipConfig.Base.postTax)
            }
            .pickerStyle(.segmented)
        }
        .sensoryFeedback(.selection, trigger: percent)
        .sensoryFeedback(.selection, trigger: base)
    }

    private func choose(_ tip: Int) {
        Keyboard.dismiss()
        withAnimation(.snappy) { percent = tip }
    }
}
