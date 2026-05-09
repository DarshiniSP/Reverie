import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct LogoPalette {
    let primaryAccent: Color
    let secondaryAccent: Color
    let neutralDark: Color
    let neutralLight: Color
}

enum PaletteExtractor {
    /// Singleton cache for the extracted palette
    private static var cachedPalette: LogoPalette?
    
    /// Get the current logo-derived palette (cached after first extraction)
    static var current: LogoPalette {
        if let cached = cachedPalette {
            return cached
        }
        let palette = extractFresh()
        cachedPalette = palette
        return palette
    }
    
    /// Force re-extraction from AppIcon (useful if asset changes)
    static func refresh() -> LogoPalette {
        let palette = extractFresh()
        cachedPalette = palette
        return palette
    }
    
    private static func extractFresh() -> LogoPalette {
        guard let uiImage = UIImage(named: "AppIcon") else {
            // Fallback palette if no AppIcon found
            return LogoPalette(
                primaryAccent: Color(red: 0.0, green: 0.48, blue: 1.0),
                secondaryAccent: Color(red: 0.35, green: 0.34, blue: 0.84),
                neutralDark: Color(white: 0.10),
                neutralLight: Color(white: 0.96)
            )
        }
        let avg = averageColor(image: uiImage) ?? UIColor.systemBlue
        let primary = Color(avg)
        let secondary = Color(hueRotate(color: avg, degrees: 30))
        let neutralDark = Color(white: 0.10)
        let neutralLight = Color(white: 0.96)
        return LogoPalette(primaryAccent: primary, secondaryAccent: secondary, neutralDark: neutralDark, neutralLight: neutralLight)
    }

    private static func averageColor(image: UIImage) -> UIColor? {
        guard let inputImage = CIImage(image: image) else { return nil }
        let extent = inputImage.extent
        let filter = CIFilter.areaAverage()
        filter.inputImage = inputImage
        filter.extent = extent
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        guard let outputImage = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0
        let a = CGFloat(bitmap[3]) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func hueRotate(color: UIColor, degrees: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let newH = fmod(h + (degrees/360.0), 1.0)
        return UIColor(hue: newH, saturation: s, brightness: b, alpha: a)
    }
}

struct PalettePreview: View {
    private var palette: LogoPalette {
        PaletteExtractor.current
    }
    var body: some View {
        VStack(spacing: 12) {
            Text("Logo-derived Palette")
                .font(.headline)
            HStack(spacing: 12) {
                swatch(palette.primaryAccent, title: "Primary Accent")
                swatch(palette.secondaryAccent, title: "Secondary Accent")
            }
            HStack(spacing: 12) {
                swatch(palette.neutralLight, title: "Neutral Light")
                swatch(palette.neutralDark, title: "Neutral Dark")
            }
        }
        .padding()
    }
    private func swatch(_ color: Color, title: String) -> some View {
        VStack {
            RoundedRectangle(cornerRadius: 8).fill(color).frame(width: 120, height: 60)
            Text(title).font(.caption)
        }
    }
}

#Preview {
    PalettePreview()
}
