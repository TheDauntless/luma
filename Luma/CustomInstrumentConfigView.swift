import LumaCore
import SwiftUI

struct CustomInstrumentConfigView: View {
    let defID: UUID
    @Binding var config: CustomInstrumentConfig
    @ObservedObject var workspace: Workspace
    @Binding var selection: SidebarItemID?

    private var def: CustomInstrumentDef? {
        workspace.engine.customInstruments.def(withId: defID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            GroupBox("Features") {
                Group {
                    if let def, !def.features.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(def.features) { feature in
                                featureRow(feature: feature)
                            }
                        }
                    } else {
                        Text("This custom instrument does not declare any features.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let def {
                InstrumentIconView(icon: def.icon, pointSize: 14)
                Text(def.name).font(.headline)
            } else {
                Text("Custom Instrument").font(.headline)
            }
            Spacer()
            Button("Edit Source\u{2026}") {
                selection = .customInstrumentDef(defID)
            }
            .accessibilityIdentifier("customInstrument.editSource")
        }
    }

    @ViewBuilder
    private func featureRow(feature: CustomInstrumentDef.Feature) -> some View {
        if feature.optional {
            optionalFeatureRow(feature: feature)
        } else {
            requiredFeatureRow(feature: feature)
        }
    }

    @ViewBuilder
    private func optionalFeatureRow(feature: CustomInstrumentDef.Feature) -> some View {
        let enabled = enabledBinding(for: feature)
        VStack(alignment: .leading, spacing: 6) {
            Toggle(feature.name, isOn: enabled)
                .platformCheckboxToggleStyle()
            if case .boolean = feature.schema {
                EmptyView()
            } else {
                FeatureValueEditor(
                    schema: feature.schema,
                    value: valueBinding(for: feature)
                )
                .disabled(!enabled.wrappedValue)
                .opacity(enabled.wrappedValue ? 1 : 0.4)
                .padding(.leading, 20)
            }
        }
    }

    @ViewBuilder
    private func requiredFeatureRow(feature: CustomInstrumentDef.Feature) -> some View {
        if case .boolean = feature.schema {
            Toggle(feature.name, isOn: requiredBoolBinding(for: feature))
                .platformCheckboxToggleStyle()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.name).font(.subheadline)
                FeatureValueEditor(
                    schema: feature.schema,
                    value: valueBinding(for: feature)
                )
                .padding(.leading, 20)
            }
        }
    }

    private func requiredBoolBinding(for feature: CustomInstrumentDef.Feature) -> Binding<Bool> {
        Binding(
            get: {
                if case .boolean(let b) = config.features[feature.id]?.value { return b }
                if case .boolean(let b) = feature.schema.defaultValue { return b }
                return false
            },
            set: { newValue in
                var updated = config
                let existingEnabled = updated.features[feature.id]?.enabled ?? feature.enabledByDefault
                updated.features[feature.id] = FeatureState(enabled: existingEnabled, value: .boolean(newValue))
                config = updated
            }
        )
    }

    private func enabledBinding(for feature: CustomInstrumentDef.Feature) -> Binding<Bool> {
        Binding(
            get: { config.features[feature.id]?.enabled ?? feature.enabledByDefault },
            set: { newValue in
                var updated = config
                let existingValue = updated.features[feature.id]?.value ?? feature.schema.defaultValue
                updated.features[feature.id] = FeatureState(enabled: newValue, value: existingValue)
                config = updated
            }
        )
    }

    private func valueBinding(for feature: CustomInstrumentDef.Feature) -> Binding<FeatureValue> {
        Binding(
            get: {
                config.features[feature.id]?.value ?? feature.schema.defaultValue
            },
            set: { newValue in
                var updated = config
                let existingEnabled = updated.features[feature.id]?.enabled ?? feature.enabledByDefault
                updated.features[feature.id] = FeatureState(enabled: existingEnabled, value: newValue)
                config = updated
            }
        )
    }
}
