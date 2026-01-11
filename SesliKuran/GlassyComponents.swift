import SwiftUI

// MARK: - Glassy Button
struct GlassyButton: View {
    let iconName: String
    let action: () -> Void
    var size: CGFloat = 20
    var padding: CGFloat = 12
    var isActive: Bool = false
    var isDarkMode: Bool = true // Added theme parameter

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
    var isDarkMode: Bool = true // Added theme parameter

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
    var onEditingChanged: (Bool) -> Void = { _ in }
    var isDarkMode: Bool = true // Added theme parameter

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track - SLEEKER DESIGN (Very Thin)
                Capsule()
                    .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .frame(height: 3) // Further reduced to 3 for elegance

                // Progress - Gradient Fill
                // Defensive: Guard against Division by Zero
                let rangeDistance = inRange.upperBound - inRange.lowerBound
                let progress = rangeDistance > 0 ? CGFloat((value - inRange.lowerBound) / rangeDistance) : 0

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
            .frame(height: 44) // Keep 44pt height for easy tapping
            .contentShape(Rectangle()) // Make the whole area tappable
        }
        .frame(height: 44) // Tappable area height
        .overlay(
            Slider(value: $value, in: inRange, onEditingChanged: onEditingChanged)
                .accentColor(.clear) // Hide default knob color
                .opacity(0.05) // Invisible but interactable
        )
        // Visible custom knob - Refined
        .overlay(
             GeometryReader { geometry in
                 // Defensive: Guard against Division by Zero
                 let rangeDistance = inRange.upperBound - inRange.lowerBound
                 let progress = rangeDistance > 0 ? CGFloat((value - inRange.lowerBound) / rangeDistance) : 0

                 Circle()
                     .fill(ThemeColors.buttonForeground(isDarkMode: isDarkMode))
                     .frame(width: 10, height: 10) // Reduced to 10 for very fine look
                     .shadow(radius: 2)
                     .position(
                        x: geometry.size.width * progress,
                        y: geometry.size.height / 2
                     )
                     .allowsHitTesting(false) // Let touches pass to the slider
             }
        )
    }
}
