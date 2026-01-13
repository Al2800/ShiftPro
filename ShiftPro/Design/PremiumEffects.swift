import SwiftUI

// MARK: - Premium Gradients

enum ShiftProGradients {
    /// Primary brand gradient - sophisticated blue to purple
    static let hero = LinearGradient(
        colors: [
            Color(red: 0.25, green: 0.45, blue: 0.95),
            Color(red: 0.55, green: 0.35, blue: 0.90)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Success gradient for positive states
    static let success = LinearGradient(
        colors: [
            Color(red: 0.20, green: 0.78, blue: 0.55),
            Color(red: 0.15, green: 0.65, blue: 0.65)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Premium mesh gradient for backgrounds (iOS 18+)
    @available(iOS 18.0, *)
    static var mesh: MeshGradient {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                .init(0, 1), .init(0.5, 1), .init(1, 1)
            ],
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.14),
                Color(red: 0.12, green: 0.10, blue: 0.18),
                Color(red: 0.08, green: 0.09, blue: 0.14),
                Color(red: 0.10, green: 0.12, blue: 0.18),
                Color(red: 0.15, green: 0.13, blue: 0.22),
                Color(red: 0.10, green: 0.12, blue: 0.18),
                Color(red: 0.08, green: 0.09, blue: 0.14),
                Color(red: 0.12, green: 0.10, blue: 0.18),
                Color(red: 0.08, green: 0.09, blue: 0.14)
            ]
        )
    }

    /// Fallback gradient for iOS 17 and earlier
    static let meshFallback = LinearGradient(
        colors: [
            Color(red: 0.03, green: 0.04, blue: 0.06),
            Color(red: 0.08, green: 0.07, blue: 0.12),
            Color(red: 0.03, green: 0.04, blue: 0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle ambient glow gradient
    static let ambientGlow = RadialGradient(
        colors: [
            Color(red: 0.35, green: 0.50, blue: 0.95).opacity(0.15),
            Color.clear
        ],
        center: .center,
        startRadius: 0,
        endRadius: 200
    )

    /// Card highlight gradient (top edge shine)
    static let cardHighlight = LinearGradient(
        colors: [
            Color.white.opacity(0.08),
            Color.white.opacity(0.02),
            Color.clear
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Shimmer gradient for loading/premium effects
    static func shimmer(phase: CGFloat) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.15),
                Color.white.opacity(0)
            ],
            startPoint: UnitPoint(x: phase - 0.5, y: phase - 0.5),
            endPoint: UnitPoint(x: phase + 0.5, y: phase + 0.5)
        )
    }
}

// MARK: - Premium Shadows

enum ShiftProShadows {
    /// Soft diffused shadow for elevated cards
    static func soft(_ color: Color = .black) -> some View {
        Color.clear
            .shadow(color: color.opacity(0.08), radius: 8, x: 0, y: 4)
            .shadow(color: color.opacity(0.05), radius: 24, x: 0, y: 12)
    }

    /// Glow shadow for accent elements
    static func glow(_ color: Color) -> some View {
        Color.clear
            .shadow(color: color.opacity(0.25), radius: 12, x: 0, y: 4)
            .shadow(color: color.opacity(0.15), radius: 32, x: 0, y: 8)
    }

    /// Inner shadow effect
    static func inner(_ color: Color = .black, radius: CGFloat = 4) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(color.opacity(0.1), lineWidth: 1)
            .blur(radius: radius)
    }
}

// MARK: - Glass Morphism Modifier

struct GlassMorphismModifier: ViewModifier {
    var intensity: Double
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Frosted glass base
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12 * intensity),
                                    Color.white.opacity(0.05 * intensity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Edge highlight
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2 * intensity),
                                    Color.white.opacity(0.05 * intensity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
    }
}

extension View {
    func glassMorphism(intensity: Double = 1.0, cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassMorphismModifier(intensity: intensity, cornerRadius: cornerRadius))
    }
}

// MARK: - Shimmer Effect Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    var duration: Double = 2.0

    func body(content: Content) -> some View {
        content
            .overlay(
                ShiftProGradients.shimmer(phase: phase)
                    .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmerEffect(duration: Double = 2.0) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
}

// MARK: - Floating Animation Modifier

struct FloatingModifier: ViewModifier {
    @State private var isFloating = false
    var amplitude: CGFloat = 4
    var duration: Double = 3.0

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -amplitude : amplitude)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear {
                isFloating = true
            }
    }
}

extension View {
    func floatingAnimation(amplitude: CGFloat = 4, duration: Double = 3.0) -> some View {
        modifier(FloatingModifier(amplitude: amplitude, duration: duration))
    }
}

// MARK: - Glow Border Modifier

struct GlowBorderModifier: ViewModifier {
    var color: Color
    var lineWidth: CGFloat
    var cornerRadius: CGFloat
    @State private var isGlowing = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color, lineWidth: lineWidth)
                    .blur(radius: isGlowing ? 4 : 2)
                    .opacity(isGlowing ? 0.8 : 0.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color, lineWidth: lineWidth * 0.5)
            )
            .animation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true),
                value: isGlowing
            )
            .onAppear {
                isGlowing = true
            }
    }
}

extension View {
    func glowBorder(color: Color, lineWidth: CGFloat = 2, cornerRadius: CGFloat = 24) -> some View {
        modifier(GlowBorderModifier(color: color, lineWidth: lineWidth, cornerRadius: cornerRadius))
    }
}

// MARK: - Depth Card Modifier

struct DepthCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var elevation: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ShiftProColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ShiftProGradients.cardHighlight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: elevation * 0.5, x: 0, y: elevation * 0.25)
            .shadow(color: Color.black.opacity(0.1), radius: elevation, x: 0, y: elevation * 0.5)
            .shadow(color: ShiftProColors.accent.opacity(0.05), radius: elevation * 2, x: 0, y: elevation)
    }
}

extension View {
    func depthCard(cornerRadius: CGFloat = 24, elevation: CGFloat = 12) -> some View {
        modifier(DepthCardModifier(cornerRadius: cornerRadius, elevation: elevation))
    }
}

// MARK: - Scale Press Modifier

struct ScalePressModifier: ViewModifier {
    @GestureState private var isPressed = false
    var scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

extension View {
    func scalePress(_ scale: CGFloat = 0.96) -> some View {
        modifier(ScalePressModifier(scale: scale))
    }
}

// MARK: - Noise Texture Overlay

struct NoiseTextureView: View {
    var opacity: Double = 0.03

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, through: size.width, by: 2) {
                for y in stride(from: 0, through: size.height, by: 2) {
                    let brightness = Double.random(in: 0...1)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 2, height: 2)),
                        with: .color(Color.white.opacity(brightness * opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Animated Background

struct AnimatedMeshBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Simple solid background that adapts to light/dark mode
        ShiftProColors.background
            .ignoresSafeArea()
    }
}

#Preview("Mesh Background") {
    AnimatedMeshBackground()
}

#Preview("Glass Card") {
    ZStack {
        AnimatedMeshBackground()

        VStack(spacing: 20) {
            Text("Premium Card")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("With glass morphism effect")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(32)
        .glassMorphism()
    }
}
