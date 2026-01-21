import SwiftUI

// MARK: - Glassy Button
struct GlassyButton: View {
    let iconName: String
    let action: () -> Void
    var size: CGFloat = 20
    var padding: CGFloat = 12
    var isActive: Bool = false
    var isDarkMode: Bool // Added theme parameter

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: size, weight: .bold))
                // Updated to foregroundStyle for modern iOS support
                .foregroundStyle(ThemeColors.buttonForeground(isDarkMode: isDarkMode))
                .padding(padding)
                .background(
                    ZStack {
                        // Glass effect with subtle primary color tint
                        if isDarkMode {
                            ThemeColors.primaryColor(isDarkMode: true).opacity(0.1) // Subtle Cyan Tint
                                .background(Color.white.opacity(0.05)) // Base Glass
                        } else {
                            Color.white.opacity(0.8)
                        }

                        // Subtle border
                        RoundedRectangle(cornerRadius: padding * 2)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: isDarkMode ? [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.1)
                                    ] : [
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.4)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
                .clipShape(Circle())
                .shadow(
                    // Unified Glow using Primary Color
                    color: ThemeColors.primaryColor(isDarkMode: isDarkMode).opacity(isDarkMode ? 0.6 : 0.4),
                    radius: 10, x: 0, y: 0
                )
        }
    }
}

// MARK: - Glassy Control Button (Larger for Play/Pause)
struct GlassyControlButton: View {
    let iconName: String
    let action: () -> Void
    var size: CGFloat = 40
    var isDarkMode: Bool // Added theme parameter

    var body: some View {
        Button(action: action) {
            ZStack {
                // Glow effect (Unified: Primary Color)
                Circle()
                    .fill(ThemeColors.primaryColor(isDarkMode: isDarkMode).opacity(0.5))
                    .frame(width: size * 2.5, height: size * 2.5)
                    .blur(radius: 15)

                Image(systemName: iconName)
                    .font(.system(size: size, weight: .bold))
                    // Icon Foreground: Primary Color
                    .foregroundStyle(ThemeColors.primaryColor(isDarkMode: isDarkMode))
                    .frame(width: size * 2, height: size * 2)
                    .background(
                        ZStack {
                            // Glassy Background instead of Gradient Fill
                            if isDarkMode {
                                Color.white.opacity(0.1)
                                    .background(.ultraThinMaterial)
                            } else {
                                Color.white.opacity(0.8)
                            }
                        }
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: ThemeColors.gradientColors(isDarkMode: isDarkMode)),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: ThemeColors.primaryColor(isDarkMode: isDarkMode).opacity(0.4),
                        radius: 5, x: 0, y: 2
                    )
            }
        }
    }
}

// MARK: - Neumorphic Slider
struct NeumorphicSlider: View {
    @Binding var value: Double
    var inRange: ClosedRange<Double>
    @Binding var isDragging: Bool // Lifted state to binding
    var onEditingChanged: (Bool) -> Void = { _ in }
    var isDarkMode: Bool // Added theme parameter
    var timeFormatter: ((Double) -> String)? = nil // Optional formatter for floating label

    // Computed property to centralize progress calculation (DRY Principle)
    private var progress: CGFloat {
        let rangeDistance = inRange.upperBound - inRange.lowerBound
        // Guard against division by zero or invalid ranges
        guard rangeDistance > 0 else { return 0 }

        let calculatedProgress = CGFloat((value - inRange.lowerBound) / rangeDistance)

        // Strict Clamping to prevent layout glitches ("going through the app")
        // if value is momentarily out of sync with range.
        return min(max(calculatedProgress, 0), 1)
    }

    var body: some View {
        ZStack {
            // 1. Custom Visual Track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track - SLEEKER DESIGN (Very Thin)
                    Capsule()
                        .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .frame(height: 3) // Further reduced to 3 for elegance

                    // Progress - Gradient Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: ThemeColors.gradientColors(isDarkMode: isDarkMode)),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 3)
                }
                .frame(height: 44) // Center vertically in the ZStack
            }

            // 2. Visible Custom Knob & Label (Visual Overlay)
            GeometryReader { geometry in
                ZStack {
                    // The Knob
                    Circle()
                        .fill(ThemeColors.buttonForeground(isDarkMode: isDarkMode))
                        .frame(width: 10, height: 10) // Reduced to 10 for very fine look
                        .shadow(radius: 2)
                        .position(
                            x: geometry.size.width * progress,
                            y: geometry.size.height / 2
                        )

                    // Floating Time Label (Visible on Drag)
                    if isDragging, let formatter = timeFormatter {
                        Text(formatter(value))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(ThemeColors.buttonForeground(isDarkMode: isDarkMode))
                            .padding(6)
                            // Background removed per user request
                            // Offset above the knob
                            .position(
                                x: geometry.size.width * progress,
                                y: (geometry.size.height / 2) - 30
                            )
                            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    }
                }
                .allowsHitTesting(false) // Pass touches through visual elements
            }

            // 3. Interactive Slider (Top Layer)
            // This is the actual slider that captures touches.
            Slider(value: $value, in: inRange, onEditingChanged: { editing in
                isDragging = editing
                onEditingChanged(editing)
            })
            .accentColor(.clear) // Hide default thumb color
            .opacity(0.05) // Almost invisible but hit-testable
        }
        .frame(height: 44) // Tappable area height
    }
}
