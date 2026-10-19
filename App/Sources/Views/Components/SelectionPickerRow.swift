import FamilyControls
import SwiftUI
import UnscrollScreenTime

/// A row that opens Apple's FamilyActivityPicker and stores the result as opaque Data.
struct SelectionPickerRow: View {
    let title: String
    @Binding var selectionData: Data
    @State private var isPresented = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        Button {
            selection = SelectionCodec.decode(selectionData)
            isPresented = true
        } label: {
            HStack {
                Text(title)
                Spacer()
                SelectionSummary(data: selectionData)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
        .familyActivityPicker(isPresented: $isPresented, selection: $selection)
        .onChange(of: selection) { _, newValue in selectionData = SelectionCodec.encode(newValue) }
    }
}

/// Shows up to three app icons from a selection, plus a count.
struct SelectionSummary: View {
    let data: Data

    var body: some View {
        let selection = SelectionCodec.decode(data)
        let count = SelectionCodec.itemCount(data)
        HStack(spacing: -6) {
            ForEach(Array(selection.applicationTokens.prefix(3)), id: \.self) { token in
                Label(token).labelStyle(.iconOnly).frame(width: 24, height: 24)
            }
            Text(count == 0 ? "None" : "\(count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, selection.applicationTokens.isEmpty ? 0 : 10)
        }
    }
}
