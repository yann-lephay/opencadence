import CoreText
import SwiftUI
import UIKit

enum LBSBrand {
    static let ink = Color(red: 1 / 255, green: 47 / 255, blue: 43 / 255)
    static let secondaryGreen = Color(red: 13 / 255, green: 90 / 255, blue: 80 / 255)
    static let orange = Color(red: 233 / 255, green: 138 / 255, blue: 21 / 255)
    static let plum = Color(red: 89 / 255, green: 17 / 255, blue: 77 / 255)
    static let cream = Color(red: 244 / 255, green: 238 / 255, blue: 228 / 255)
    static let paper = Color(red: 244 / 255, green: 238 / 255, blue: 228 / 255)

    // In dark mode, functional text and controls use native semantic colors.
    // This preserves legibility without inventing a second brand palette.
    static let brandText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .label
            : UIColor(red: 1 / 255, green: 47 / 255, blue: 43 / 255, alpha: 1)
    })
    static let brandAccentText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .label
            : UIColor(red: 13 / 255, green: 90 / 255, blue: 80 / 255, alpha: 1)
    })
    static let controlTint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .label
            : UIColor(red: 1 / 255, green: 47 / 255, blue: 43 / 255, alpha: 1)
    })
    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .secondaryLabel
            : UIColor(red: 74 / 255, green: 104 / 255, blue: 99 / 255, alpha: 1)
    })
    static let destructiveText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemRed
            : UIColor(red: 179 / 255, green: 38 / 255, blue: 30 / 255, alpha: 1)
    })
    static let border = Color(uiColor: .separator)

    // Light mode carries the paper system. Dark mode deliberately falls back to
    // native functional surfaces until a dedicated dark art direction exists.
    static let screenBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemGroupedBackground
            : UIColor(red: 244 / 255, green: 238 / 255, blue: 228 / 255, alpha: 1)
    })
    static let cardBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .secondarySystemGroupedBackground
            : UIColor(red: 244 / 255, green: 238 / 255, blue: 228 / 255, alpha: 1)
    })
}

@MainActor
enum BrandFontRegistry {
    nonisolated static let regularName = "Archivo-Regular"
    nonisolated static let blackName = "Archivo-Black"

    static func register() {
        ["archivo-400", "archivo-900"].forEach { filename in
            guard let url = Bundle.main.url(forResource: filename, withExtension: "ttf")
                ?? Bundle.main.url(forResource: filename, withExtension: "ttf", subdirectory: "Fonts")
            else { return }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        assert(isAvailable, "Archivo must be bundled and registered; do not silently fall back.")
    }

    static var isAvailable: Bool {
        UIFont(name: regularName, size: 16) != nil
            && UIFont(name: blackName, size: 16) != nil
    }
}

extension Font {
    static func archivoBlack(_ size: CGFloat, relativeTo style: TextStyle) -> Font {
        .custom(BrandFontRegistry.blackName, size: size, relativeTo: style)
    }

    static func archivoRegular(_ size: CGFloat, relativeTo style: TextStyle) -> Font {
        .custom(BrandFontRegistry.regularName, size: size, relativeTo: style)
    }
}

enum LBSMarkStyle: Equatable {
    case color
    case twoColor
    case monochrome
    case onDark
}

struct LBSMark: View {
    let style: LBSMarkStyle

    init(style: LBSMarkStyle = .color) {
        self.style = style
    }

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 284, size.height / 296)
            let transform = CGAffineTransform(
                translationX: (size.width - 284 * scale) / 2,
                y: (size.height - 296 * scale) / 2
            ).scaledBy(x: scale, y: scale)

            if style == .color {
                context.fill(prunePath.applying(transform), with: .color(LBSBrand.plum))
            }
            context.fill(topPath.applying(transform), with: .color(topColor))
            context.fill(basePath.applying(transform), with: .color(baseColor))
        }
        .aspectRatio(284 / 296, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var topColor: Color {
        switch style {
        case .monochrome: LBSBrand.ink
        default: LBSBrand.orange
        }
    }

    private var baseColor: Color {
        switch style {
        case .onDark: LBSBrand.cream
        default: LBSBrand.ink
        }
    }

    private var topPath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 37, y: 0))
        path.addLine(to: CGPoint(x: 232, y: 0))
        path.addLine(to: CGPoint(x: 256, y: 24))
        path.addLine(to: CGPoint(x: 256, y: 167))
        path.addLine(to: CGPoint(x: 177, y: 167))
        path.addLine(to: CGPoint(x: 161, y: 192))
        path.addLine(to: CGPoint(x: 104, y: 192))
        path.addLine(to: CGPoint(x: 93, y: 210))
        path.addLine(to: CGPoint(x: 13, y: 210))
        path.addLine(to: CGPoint(x: 13, y: 24))
        path.closeSubpath()
        return path
    }

    private var prunePath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 256, y: 40))
        path.addLine(to: CGPoint(x: 284, y: 68))
        path.addLine(to: CGPoint(x: 284, y: 190))
        path.addLine(to: CGPoint(x: 256, y: 167))
        path.closeSubpath()
        return path
    }

    private var basePath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 236))
        path.addLine(to: CGPoint(x: 13, y: 223))
        path.addLine(to: CGPoint(x: 99, y: 223))
        path.addLine(to: CGPoint(x: 111, y: 204))
        path.addLine(to: CGPoint(x: 167, y: 204))
        path.addLine(to: CGPoint(x: 183, y: 179))
        path.addLine(to: CGPoint(x: 256, y: 179))
        path.addLine(to: CGPoint(x: 284, y: 207))
        path.addLine(to: CGPoint(x: 284, y: 273))
        path.addLine(to: CGPoint(x: 262, y: 296))
        path.addLine(to: CGPoint(x: 23, y: 296))
        path.addLine(to: CGPoint(x: 0, y: 273))
        path.closeSubpath()
        return path
    }
}

struct LBSWordmark: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .headline) private var markSize = 34.0

    var body: some View {
        HStack(spacing: 10) {
            LBSMark(style: colorScheme == .dark ? .onDark : (effectiveMarkSize < 24 ? .twoColor : .color))
                .frame(width: effectiveMarkSize, height: effectiveMarkSize)
            Text("La Bonne\nSéance")
                .font(.archivoBlack(18, relativeTo: .headline))
                .foregroundStyle(LBSBrand.brandText)
                .lineSpacing(-5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("La Bonne Séance")
    }

    private var effectiveMarkSize: CGFloat { min(markSize, 48) }
}

struct LBSChamferedRectangle: Shape {
    var cut: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let cut = min(cut, min(rect.width, rect.height) / 3)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.closeSubpath()
        return path
    }
}

struct LBSBrandPoster: View {
    let label: String?

    init(label: String? = nil) {
        self.label = label
    }

    var body: some View {
        Image("BrandPoster")
            .resizable()
            .scaledToFill()
            .overlay(alignment: .bottomLeading) {
                if let label {
                    Text(label.uppercased())
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(LBSBrand.cream)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(LBSBrand.ink)
                        .padding(12)
                }
            }
            .clipShape(LBSChamferedRectangle(cut: 18))
            .accessibilityHidden(true)
    }
}

#if DEBUG
struct BrandLogoSizeProofView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Logo — contrôle petites tailles")
                .font(.archivoBlack(30, relativeTo: .title))
            HStack(alignment: .bottom, spacing: 28) {
                proof(size: 48)
                proof(size: 32)
                proof(size: 24)
                proof(size: 16)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LBSBrand.paper)
        .foregroundStyle(LBSBrand.ink)
    }

    private func proof(size: CGFloat) -> some View {
        VStack(spacing: 8) {
            LBSMark(style: size < 24 ? .twoColor : .color)
                .frame(width: size, height: size)
            Text("\(Int(size)) pt")
                .font(.caption.monospacedDigit())
        }
    }
}
#endif
