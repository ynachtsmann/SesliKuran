// MARK: - Imports
import SwiftUI

// MARK: - Splash Screen
struct SplashScreen: View {
    // MARK: - Properties
    @Binding var isAppReady: Bool
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Animation States
    // Phase 1: Particles
    @State private var particlesActive = false
    @State private var particlesConverged = false

    // Phase 2: Book Entry (Fly-In)
    @State private var bookScale: CGFloat = 0.0
    @State private var bookOffsetY: CGFloat = 200.0
    @State private var bookRotationY: Double = -180.0 // Spin in
    @State private var bookOpacity: Double = 0.0

    // Phase 3: Impact (Shockwave)
    @State private var shockwaveScale: CGFloat = 0.5
    @State private var shockwaveOpacity: Double = 0.0

    // Phase 4: Page Turn
    @State private var isBookOpen = false
    @State private var bookFlipAngle: Double = 0.0 // For the opening flip

    // Phase 5: Text Reveal
    @State private var showText = false

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
            VStack(spacing: 30) {
                // Book Icon & Shockwave Container
                ZStack {
                    // Shockwave Ring (Impact Effect)
                    Circle()
                        .stroke(ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode), lineWidth: 3)
                        .scaleEffect(shockwaveScale)
                        .opacity(shockwaveOpacity)

                    // "Holy Glow"
                    Circle()
                        .fill(ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode))
                        .frame(width: 120, height: 120)
                        .blur(radius: 50)
                        .opacity(bookOpacity * 0.4)

                    // The Book
                    Image(systemName: isBookOpen ? "book.fill" : "book.closed.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .foregroundStyle(ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode))
                        // Combined 3D Effects: Fly-In Spin + Page Turn Flip
                        .rotation3DEffect(
                            .degrees(bookRotationY + bookFlipAngle),
                            axis: (x: 0.0, y: 1.0, z: 0.0),
                            anchor: .center,
                            perspective: 0.6
                        )
                        .scaleEffect(bookScale)
                        .offset(y: bookOffsetY)
                        .opacity(bookOpacity)
                        // Dynamic Shadow
                        .shadow(
                            color: ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode).opacity(0.6),
                            radius: 15, x: 0, y: 10
                        )
                }
                .frame(height: 140) // Fixed height container

                // Staggered Text (Letters fly up)
                if showText {
                    HStack(spacing: 0) {
                        StaggeredLetters(text: "SESLI", delayOffset: 0.0, isDarkMode: themeManager.isDarkMode)
                        Text(" ") // Space
                            .font(.system(.title2, design: .serif))
                            .frame(width: 10)
                        StaggeredLetters(text: "KURAN", delayOffset: 0.4, isDarkMode: themeManager.isDarkMode)
                    }
                } else {
                    // Invisible placeholder to prevent layout shifts
                    Text("SESLI KURAN")
                        .font(.system(.title2, design: .serif).smallCaps())
                        .opacity(0)
                }
            }
        }
        .onAppear {
            runCinematicSequence()
        }
    }

    // MARK: - Cinematic Sequence
    private func runCinematicSequence() {
        // Step 1: Start Particles (Background Ambiance)
        particlesActive = true

        // Step 2: Book Fly-In (T = 0.8s)
        // We delay slightly to let particles form/implode a bit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Hide particles as book arrives
            withAnimation(.easeOut(duration: 0.3)) {
                particlesConverged = true
            }

            // Book Enters with Physics-based Spring
            // Grows, Moves Up, and Unspins simultaneously
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6, blendDuration: 0)) {
                bookOpacity = 1.0
                bookScale = 1.0
                bookOffsetY = 0
                bookRotationY = 0 // Spin from -180 to 0
            }
        }

        // Step 3: Shockwave Impact (T = 1.1s - just after landing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            // Initial burst state
            shockwaveOpacity = 0.6
            withAnimation(.easeOut(duration: 0.8)) {
                shockwaveScale = 2.5
                shockwaveOpacity = 0.0
            }
        }

        // Step 4: Page Turn (T = 1.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            // First Half: Rotate "closed" book to 90 degrees
            withAnimation(.easeInOut(duration: 0.3)) {
                bookFlipAngle = 90
            }

            // Second Half: Swap to "Open" icon and rotate back
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isBookOpen = true
                bookFlipAngle = -90 // Start from other side (invisible edge)

                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    bookFlipAngle = 0 // Settle at 0 (Face forward)
                }
            }
        }

        // Step 5: Text Reveal (T = 2.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            showText = true
        }

        // Step 6: Finish & Dismiss (T = 4.0s minimum)
        Task {
            // Ensure minimum display time AND data preparation
            // Using withTaskGroup to avoid 'void' assignment compiler errors
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    try? await Task.sleep(nanoseconds: 3_800 * 1_000_000) // ~3.8s total
                }
                group.addTask {
                    await audioManager.prepare()
                }
            }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.8)) {
                    isAppReady = true
                }
            }
        }
    }
}

// MARK: - Helper Components

struct StaggeredLetters: View {
    let text: String
    let delayOffset: Double
    let isDarkMode: Bool

    var body: some View {
        HStack(spacing: 2) { // Tight spacing for elegant kerning
            ForEach(0..<text.count, id: \.self) { index in
                Text(String(text[text.index(text.startIndex, offsetBy: index)]))
                    .font(.system(.title2, design: .serif).smallCaps())
                    .fontWeight(.semibold)
                    .foregroundStyle(ThemeColors.primaryColor(isDarkMode: isDarkMode))
                    .shadow(color: ThemeColors.primaryColor(isDarkMode: isDarkMode).opacity(0.3), radius: 8)
                    .modifier(FlyUpModifier(delay: delayOffset + Double(index) * 0.08)) // 0.08s stagger
            }
        }
    }
}

struct FlyUpModifier: ViewModifier {
    let delay: Double
    @State private var offset: CGFloat = 20
    @State private var opacity: Double = 0.0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                // Spring animation for each letter
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                    offset = 0
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Particle System (Reused)
struct ParticleSystemView: View {
    @Binding var isActive: Bool
    let isDarkMode: Bool

    // Generate constant random data for particles
    private let particles: [Particle] = (0..<20).map { _ in Particle.random() }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(ThemeColors.primaryColor(isDarkMode: isDarkMode))
                        .frame(width: particle.size, height: particle.size)
                        .opacity(isActive ? 0.0 : particle.opacity)
                        // Animation: Move from outside towards center
                        .offset(
                            x: isActive ? 0 : particle.xOffset,
                            y: isActive ? 0 : particle.yOffset
                        )
                        .scaleEffect(isActive ? 0.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8) // Faster implosion
                            .delay(particle.delay),
                            value: isActive
                        )
                }
            }
            .position(center)
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    let xOffset: CGFloat
    let yOffset: CGFloat
    let size: CGFloat
    let opacity: Double
    let delay: Double

    static func random() -> Particle {
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = Double.random(in: 150...300)

        return Particle(
            xOffset: CGFloat(cos(angle) * distance),
            yOffset: CGFloat(sin(angle) * distance),
            size: CGFloat.random(in: 4...10),
            opacity: Double.random(in: 0.4...0.8),
            delay: Double.random(in: 0.0...0.2)
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
