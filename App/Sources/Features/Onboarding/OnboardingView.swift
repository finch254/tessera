import SwiftUI

// MARK: - Onboarding page model
struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
}

// MARK: - Onboarding flow
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var selectedPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to Tessera",
            subtitle: "Discover stunning wallpapers from world-class photographers. Browse, preview, and make them yours — all free.",
            systemImage: "photo.on.rectangle.angled",
            color: .accentColor
        ),
        OnboardingPage(
            title: "Browse & Search",
            subtitle: "Explore thousands of curated wallpapers. Tap category chips or search by keyword to find your perfect match.",
            systemImage: "magnifyingglass",
            color: .blue
        ),
        OnboardingPage(
            title: "Preview & Customize",
            subtitle: "See your wallpaper with a live springboard preview. Apply camera-style filters, add blur, and extract dominant colors.",
            systemImage: "camera.filters",
            color: .purple
        ),
        OnboardingPage(
            title: "Save & Share",
            subtitle: "Save favorites for offline access. Share filtered wallpapers with friends or set them as your lock screen background.",
            systemImage: "square.and.arrow.up",
            color: .green
        ),
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.gray.opacity(0.15),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        onComplete()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                // Page content
                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        pageView(for: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Bottom button
                VStack(spacing: 16) {
                    if selectedPage == pages.count - 1 {
                        Button(action: onComplete) {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityLabel("Get started with Tessera")
                        .accessibilityHint("Tap to begin browsing wallpapers")
                        .padding(.horizontal, 24)
                    } else {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedPage += 1
                            }
                        }) {
                            Text("Next")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityLabel("Next page")
                        .accessibilityHint("Swipe to the next introduction page")
                        .padding(.horizontal, 24)
                    }

                    // Page indicator dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == selectedPage ? Color.accentColor : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == selectedPage ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: selectedPage)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func pageView(for page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: page.systemImage)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(page.color)
            }

            // Text
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(onComplete: {})
}
