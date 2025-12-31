import SwiftUI

// MARK: - Glassy Button
struct GlassyButton: View {
    let iconName: String
    let action: () -> Void
    var size: CGFloat = 20
    var padding: CGFloat = 12
    var isActive: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: size, weight: .bold))
                .foregroundColor(.white)
                .padding(padding)
                .background(
                    ZStack {
                        // Glass effect
                        Color.white.opacity(isActive ? 0.3 : 0.1)

                        // Subtle border
                        RoundedRectangle(cornerRadius: padding * 2)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
        }
    }
}

// MARK: - Glassy Control Button (Larger for Play/Pause)
struct GlassyControlButton: View {
    let iconName: String
    let action: () -> Void
    var size: CGFloat = 40

    var body: some View {
        Button(action: action) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: size * 2.5, height: size * 2.5)
                    .blur(radius: 10)

                Image(systemName: iconName)
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: size * 2, height: size * 2)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
    }
}

// MARK: - Neumorphic Slider
struct NeumorphicSlider: View {
    @Binding var value: Double
    var inRange: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(height: 6)

                // Progress
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.cyan, .blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat((value - inRange.lowerBound) / (inRange.upperBound - inRange.lowerBound)), height: 6)
            }
            .frame(height: 44) // Ensure visual center alignment
            .contentShape(Rectangle()) // Make the whole area tappable
        }
        .frame(height: 44) // Tappable area height
        .overlay(
            Slider(value: $value, in: inRange, onEditingChanged: onEditingChanged)
                .accentColor(.clear) // Hide default knob color
                .opacity(0.05) // Invisible but interactable
        )
        // Visible custom knob
        .overlay(
             GeometryReader { geometry in
                 Circle()
                     .fill(Color.white)
                     .frame(width: 16, height: 16)
                     .shadow(radius: 4)
                     .position(
                        x: geometry.size.width * CGFloat((value - inRange.lowerBound) / (inRange.upperBound - inRange.lowerBound)),
                        y: geometry.size.height / 2
                     )
                     .allowsHitTesting(false) // Let touches pass to the slider
             }
        )
    }
}
