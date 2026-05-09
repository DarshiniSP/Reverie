import SwiftUI

struct DSColors {
    // MARK: - Canvas & Surfaces (Adaptive)
    // Warm parchment in light, deep midnight in dark — feels intentional, not stock iOS
    static let canvasPrimary = Color(
        light: Color(hex: "F4F1EC"),        // Light: Warm linen
        dark: Color(hex: "0F1210")          // Dark: Deep forest night
    )

    static let canvasSecondary = Color(
        light: Color(hex: "FFFFFF"),        // Light: Pure white cards
        dark: Color(hex: "181E14")          // Dark: Deep sage card surface
    )

    static let canvasTertiary = Color(
        light: Color(hex: "EAE6DF"),        // Light: Warm section background
        dark: Color(hex: "1E2719")          // Dark: Higher elevation sage
    )

    // MARK: - Text Hierarchy (Adaptive)
    static let textPrimary = Color(
        light: Color(hex: "2A2A1E"),        // Light: Warm near-black
        dark: Color(hex: "F0EDE6")          // Dark: Soft warm white
    )

    static let textSecondary = Color(
        light: Color(hex: "6B7060"),        // Light: Warm sage-gray
        dark: Color(hex: "9EA88E")          // Dark: Muted sage-gray
    )

    static let textTertiary = Color(
        light: Color(hex: "6B7060").opacity(0.45),
        dark: Color(hex: "9EA88E").opacity(0.45)
    )

    // MARK: - Accent Colors (Always vibrant)
    // Warm sage — organic, calm, growth-oriented
    static let accentPrimary = Color(hex: "5C8A6E")      // Warm sage green
    static let accentPrimaryHex = "5C8A6E"
    static let accentSecondary = Color(hex: "C4714A")    // Terracotta
    static let onAccent = Color.white

    // MARK: - Semantic Colors
    static let success = Color(hex: "4A9E6B")            // Forest green
    static let warning = Color(hex: "D4945A")            // Warm terracotta-amber
    static let error = Color(hex: "C4514A")              // Muted clay red

    // MARK: - Contextual Colors
    static let journey = Color(hex: "7A8A5C")            // Olive for long-term goals
    static let focus = Color(hex: "C4714A")              // Terracotta for deep work
    static let plan = Color(hex: "5C8A6E")               // Sage for organisation

    // MARK: - Interactive Elements
    static let divider = Color(
        light: Color(hex: "2A2A1E").opacity(0.1),
        dark: Color(hex: "F0EDE6").opacity(0.12)
    )

    static let shadow = Color(
        light: Color(hex: "5C8A6E").opacity(0.08),
        dark: Color.black.opacity(0.4)
    )
}

struct DSFonts {
    static func title(_ size: CGFloat = 28) -> Font { 
        .system(size: size, weight: .bold, design: .rounded) 
    }
    
    static func headline(_ size: CGFloat = 20) -> Font { 
        .system(size: size, weight: .semibold, design: .rounded) 
    }
    
    static func body(_ size: CGFloat = 17) -> Font { 
        .system(size: size, weight: .regular, design: .default) 
    }
    
    static func label(_ size: CGFloat = 15) -> Font { 
        .system(size: size, weight: .medium, design: .rounded) 
    }
    
    static func caption(_ size: CGFloat = 13) -> Font { 
        .system(size: size, weight: .regular, design: .default) 
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFonts.label(16))
            .fontWeight(.semibold)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .foregroundColor(DSColors.onAccent)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [DSColors.accentPrimary, DSColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: DSColors.accentPrimary.opacity(configuration.isPressed ? 0.15 : 0.35),
                    radius: configuration.isPressed ? 4 : 12,
                    x: 0,
                    y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFonts.label(16))
            .fontWeight(.medium)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .foregroundColor(DSColors.accentPrimary)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DSColors.canvasSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DSColors.accentPrimary.opacity(0.3), lineWidth: 1.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFonts.label(16))
            .fontWeight(.semibold)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DSColors.error)
            )
            .shadow(color: DSColors.error.opacity(configuration.isPressed ? 0.2 : 0.3), 
                    radius: configuration.isPressed ? 4 : 8, 
                    x: 0, 
                    y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct CloseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFonts.label(15))
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(DSColors.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(DSColors.canvasSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DSColors.divider, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct NavBarModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .toolbarBackground(DSColors.canvasPrimary, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Reverie")
                            .font(DSFonts.title(24))
                            .foregroundColor(DSColors.textPrimary)
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [DSColors.accentPrimary, DSColors.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 48, height: 3)
                            .cornerRadius(1.5)
                    }
                    .accessibilityIdentifier("navTitle")
                }
            }
    }
}

extension View {
    func navBarStyled() -> some View { self.modifier(NavBarModifier()) }
}

struct GlassActionBar<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: DSColors.shadow, radius: 16, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DSColors.divider, lineWidth: 0.5)
            )
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
        }
    }
}

struct Card<Content: View>: View {
    var content: Content
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 16

    init(cornerRadius: CGFloat = 16, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(padding)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: DSColors.shadow, radius: 12, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(DSColors.divider, lineWidth: 0.5)
        )
    }
}

struct RoundedBorderTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(DSFonts.body(16))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DSColors.canvasSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DSColors.divider, lineWidth: 1)
            )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct DesignSystemPreview: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Primary Action")
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                Button("Continue") {}
                    .buttonStyle(PrimaryButtonStyle())
                Button("Secondary") {}
                    .buttonStyle(SecondaryButtonStyle())
                Button("Delete") {}
                    .buttonStyle(DestructiveButtonStyle())
                Button("Close") {}
                    .buttonStyle(CloseButtonStyle())
                RoundedRectangle(cornerRadius: 12)
                    .fill(DSColors.canvasSecondary)
                    .frame(height: 80)
                    .overlay(Text("Card").foregroundColor(DSColors.textSecondary))
                Spacer()
                GlassActionBar {
                    Button("Add") {}.buttonStyle(PrimaryButtonStyle())
                    Button("Edit") {}.buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding()
            .background(DSColors.canvasPrimary.ignoresSafeArea())
            .navBarStyled()
        }
    }
}

#Preview {
    DesignSystemPreview()
}
