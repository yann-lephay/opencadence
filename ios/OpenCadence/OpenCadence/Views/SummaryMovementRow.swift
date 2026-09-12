import CadenceEngine
import SwiftUI

/// Presentation of confirmed work only. Illustration follows the exact movement manifest.
struct SummaryMovementRow: View {
    let movement: PrescribedMovement
    let results: [CompletedSetRecord]
    let aggregateDose: String
    let dose: (Int) -> String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            DisclosureGroup(isExpanded: $expanded) {
                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.eventID) { index, result in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundStyle(LBSBrand.secondaryText)
                                .accessibilityLabel(String.localizedStringWithFormat(String(localized: "Série %lld"), index + 1))
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(dose(result.repetitions))
                                    Spacer(minLength: 12)
                                    Text(load(result)).fontWeight(.semibold)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dose(result.repetitions))
                                    Text(load(result)).fontWeight(.semibold)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .combine)
                        if index < results.count - 1 { Divider() }
                    }
                }
                .padding(.top, 10)
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    if !dynamicTypeSize.isAccessibilitySize { portrait }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(PresentationCopy.movementTitle(movement.exerciseKey))
                            .font(.archivoBlack(20, relativeTo: .title3))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(aggregate)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(context)
                            .font(.subheadline)
                            .foregroundStyle(LBSBrand.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if !expanded {
                            Text("Détail des séries")
                                .font(.footnote)
                                .underline()
                                .foregroundStyle(LBSBrand.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 20)
            }
            .tint(LBSBrand.brandText)
            .multilineTextAlignment(.leading)
        }
        .foregroundStyle(LBSBrand.brandText)
    }

    private var portrait: some View {
        ZStack {
            LBSBrand.cream
            if let asset = MovementMediaManifest.asset(for: movement.exerciseKey),
               let url = MovementMediaManifest.resourceURL(asset.posterFilename),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .saturation(0)
                    .blendMode(.multiply)
            }
        }
        .frame(width: 66, height: 66)
        .clipShape(Circle())
        .overlay { Circle().stroke(LBSBrand.orange, lineWidth: 1.5) }
        .accessibilityHidden(true)
    }

    private var aggregate: String {
        let sets = results.count == 1
            ? String(localized: "1 série")
            : String.localizedStringWithFormat(String(localized: "%lld séries"), results.count)
        return "\(sets) · \(aggregateDose)"
    }

    private var context: String {
        let equipment = movement.equipment.compactMap { item -> String? in
            switch item.category {
            case "bodyweight": return String(localized: "Poids du corps")
            case "fixed_dumbbell", "adjustable_dumbbell": return String(localized: "Haltères")
            case "kettlebell": return String(localized: "Kettlebell")
            case "resistance_band": return String(localized: "Élastique")
            case "weighted_vest": return String(localized: "Gilet lesté")
            case "pullup_bar": return String(localized: "Barre de traction")
            case "dip_bars": return String(localized: "Barres de dips")
            case "rower": return String(localized: "Rameur")
            default: return nil
            }
        }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: " · ")
        let loads = Array(Set(results.map(load))).filter { !$0.isEmpty }
        if loads.count == 1 { return [equipment, loads[0]].filter { !$0.isEmpty }.joined(separator: " · ") }
        if loads.count > 1 { return equipment + " · " + String(localized: "Charges variables") }
        return equipment
    }

    private func load(_ result: CompletedSetRecord) -> String {
        if let weight = result.perUnitWeightKg {
            return "\(weight.formatted(.number)) \(WorkoutLoadResolver.loadLabel(for: movement))"
        }
        return result.loadOptionID.map { EquipmentConfigurationDraft.bandDisplayName(for: $0) } ?? ""
    }
}
