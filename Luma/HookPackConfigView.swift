import SwiftUI
import LumaCore

struct HookPackConfigView: View {
    let manifest: HookPackManifest
    @Binding var config: HookPackConfig

    var body: some View {
        HStack(spacing: 0) {
            GroupBox("Features") {
                if manifest.features.isEmpty {
                    Text("This hook-pack does not define any configurable features.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(manifest.features) { feature in
                            HStack(alignment: .top, spacing: 8) {
                                Text(feature.name)
                                    .frame(width: 200, alignment: .leading)
                                FeatureValueEditor(
                                    schema: .boolean,
                                    value: featureValueBinding(for: feature)
                                )
                            }
                        }
                    }
                }
            }

            Spacer()
        }
    }

    private func featureValueBinding(for feature: HookPackManifest.Feature) -> Binding<FeatureValue> {
        Binding(
            get: { .boolean(config.features[feature.id] != nil) },
            set: { newValue in
                if case .boolean(let enabled) = newValue {
                    if enabled {
                        config.features[feature.id] = FeatureConfig()
                    } else {
                        config.features.removeValue(forKey: feature.id)
                    }
                }
            }
        )
    }
}
