// MARK: - Imports
import SwiftUI

// MARK: - Splash Screen
struct SplashScreen: View {
    // MARK: - Properties
    @Binding var isAppReady: Bool
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Animation States
    // Phase 1: Particles gather
    @State private var particlesActive = false
    @State private var particlesConverged = false

    // Phase 2: Book Appearance
    @State private var bookScale: CGFloat = 0.0
    @State private var bookOpacity: Double = 0.0

    // Phase 3: Book Opening (Page Turn)
    @State private var isBookOpen = false
    @State private var bookRotation: Double = 0.0

    // Phase 4: Text Reveal
    @State private var textOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 10.0

    // MARK: - Body
    var body: some View {
        ZStack {
            // 0. Transparent Background (Aurora shows through)
            Color.clear.ignoresSafeArea()

            // 1. Particle System (Behind everything)
            if !particlesConverged {
                ParticleSystemView(isActive: $particlesActive, isDarkMode: themeManager.isDarkMode)
            }

            // 2. Main Content
            VStack(spacing: 25) {
                // Book Icon Container
                ZStack {
                    // "Holy Glow" - Appears with the book
                    Circle()
                        .fill(ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode))
                        .frame(width: 120, height: 120)
                        .blur(radius: 50)
                        .opacity(bookOpacity * 0.4) // Subtle glow

                    // The Book
                    Image(systemName: isBookOpen ? "book.fill" : "book.closed.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode))
                        // 3D Rotation Effect for "Page Turn"
                        .rotation3DEffect(
                            .degrees(bookRotation),
                            axis: (x: 0.0, y: 1.0, z: 0.0),
                            anchor: .center,
                            perspective: 0.5
                        )
                        .scaleEffect(bookScale)
                        .opacity(bookOpacity)
                        // Add a subtle shadow for depth
                        .shadow(
                            color: ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode).opacity(0.5),
                            radius: 10, x: 0, y: 5
                        )
                }
                .frame(height: 120) // Fixed height container

                // App Title
                Text("Sesli Kuran")
                    .font(.system(.title2, design: .serif).smallCaps())
                    .fontWeight(.semibold)
                    .kerning(4) // Elegant spacing
                    .foregroundStyle(ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode))
                    .shadow(color: ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode).opacity(0.3), radius: 8)
                    .opacity(textOpacity)
                    .offset(y: textOffset)
            }
        }
        .onAppear {
            runAnimationSequence()
        }
    }

    // MARK: - Animation Sequence
    private func runAnimationSequence() {
        // Step 1: Start Particles (T = 0s)
        particlesActive = true

        // Step 2: Particles Converge & Disappear -> Book Appears (T = 1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.3)) {
                particlesConverged = true // Hides particles
            }

            // Book Pops in (Spring)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                bookOpacity = 1.0
                bookScale = 1.0
            }
        }

        // Step 3: Book Opens / Page Turn (T = 2.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // First Half: Rotate "closed" book to 90 degrees (invisible edge)
            withAnimation(.easeInOut(duration: 0.4)) {
                bookRotation = 90
            }

            // Second Half: Swap to "Open" icon and rotate back from -90
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isBookOpen = true
                bookRotation = -90 // Start from other side (invisible edge)

                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    bookRotation = 0 // Settle at 0 (Face forward)
                }
            }
        }

        // Step 4: Text Reveal (T = 2.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeOut(duration: 0.8)) {
                textOpacity = 1.0
                textOffset = 0
            }
        }

        // Step 5: Finish & Dismiss (T = 4.0s minimum, or when ready)
        Task {
            // Ensure minimum display time AND data preparation
            async let minTime = Task.sleep(nanoseconds: 3_800 * 1_000_000) // ~3.8s total
            async let preparation = audioManager.prepare()

            _ = try? await (minTime, preparation)

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.8)) {
                    isAppReady = true
                }
            }
        }
    }
}

// MARK: - Particle System
struct ParticleSystemView: View {
    @Binding var isActive: Bool
    let isDarkMode: Bool

    // Generate constant random data for particles to avoid redraw shuffling
    private let particles: [Particle] = (0..<20).map { _ in Particle.random() }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(ThemeColors.primaryColor(isDarkMode: isDarkMode))
                        .frame(width: particle.size, height: particle.size)
                        .opacity(isActive ? 0.0 : particle.opacity) // Fade out as they move? Or move IN?
                        // Let's Move IN: Start far away, End at center
                        .offset(
                            x: isActive ? 0 : particle.xOffset,
                            y: isActive ? 0 : particle.yOffset
                        )
                        // Add some scale animation too
                        .scaleEffect(isActive ? 0.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.2)
                            .delay(particle.delay),
                            value: isActive
                        )
                }
            }
            .position(center)
        }
    }
}

// MARK: - Helper Data
struct Particle: Identifiable {
    let id = UUID()
    let xOffset: CGFloat
    let yOffset: CGFloat
    let size: CGFloat
    let opacity: Double
    let delay: Double

    static func random() -> Particle {
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = Double.random(in: 150...300) // Start outside the center area

        return Particle(
            xOffset: CGFloat(cos(angle) * distance),
            yOffset: CGFloat(sin(angle) * distance),
            size: CGFloat.random(in: 4...10),
            opacity: Double.random(in: 0.4...0.8),
            delay: Double.random(in: 0.0...0.2) // Slight staggering
        )
    }
}

// MARK: - Preview
struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen(isAppReady: .constant(false))
            .environmentObject(ThemeManager())
            .environmentObject(AudioManager())
            .background(Color.black)
    }
}
