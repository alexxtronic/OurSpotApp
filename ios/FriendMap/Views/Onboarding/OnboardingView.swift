import SwiftUI

/// Onboarding flow shown after sign-up
struct OnboardingView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Binding var isComplete: Bool
    
    @State private var currentStep = 0
    @State private var referralSource = ""
    @State private var age = ""
    @State private var countryOfBirth = ""
    @State private var funFact = ""
    
    private let totalSteps = 3
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
            
            // Content
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                surveyStep.tag(1)
                profileStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
            
            // Navigation buttons
            navigationButtons
        }
        .background(DesignSystem.Colors.primaryBackground)
    }
    
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? DesignSystem.Colors.primaryFallback : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.lg)
    }
    
    private var welcomeStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Colors.primaryFallback)
            
            Text("Welcome to OurSpot!")
                .font(.largeTitle.bold())
            
            Text("Create and discover plans with friends. Share moments, meet up, and make memories.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
            
            Spacer()
            Spacer()
        }
    }
    
    private var surveyStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            Image(systemName: "questionmark.bubble.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.primaryFallback)
            
            Text("How did you hear about us?")
                .font(.title2.bold())
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(referralOptions, id: \.self) { option in
                    Button {
                        referralSource = option
                    } label: {
                        HStack {
                            Text(option)
                                .foregroundColor(.primary)
                            Spacer()
                            if referralSource == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primaryFallback)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(referralSource == option ? DesignSystem.Colors.primaryFallback.opacity(0.1) : DesignSystem.Colors.secondaryBackground)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Spacer()
            Spacer()
        }
    }
    
    private var profileStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.primaryFallback)
                .padding(.top, DesignSystem.Spacing.xl)
            
            Text("Tell us about yourself")
                .font(.title2.bold())
            
            VStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Age")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Your age", text: $age)
                        .keyboardType(.numberPad)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.secondaryBackground)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Country of Birth")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Where are you from?", text: $countryOfBirth)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.secondaryBackground)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fun Fact")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Something interesting about you...", text: $funFact)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.secondaryBackground)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Spacer()
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.md)
                }
            }
            
            Spacer()
            
            if currentStep < totalSteps - 1 {
                Button {
                    withAnimation { currentStep += 1 }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.primaryFallback)
                        .cornerRadius(DesignSystem.CornerRadius.lg)
                }
            } else {
                Button {
                    completeOnboarding()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.primaryFallback)
                        .cornerRadius(DesignSystem.CornerRadius.lg)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }
    
    private var referralOptions: [String] {
        ["Friend recommendation", "Social media", "App Store", "News/Article", "Other"]
    }
    
    private func completeOnboarding() {
        // Update profile
        if let ageInt = Int(age), ageInt > 0 {
            sessionStore.currentUser.age = ageInt
        }
        sessionStore.currentUser.countryOfBirth = countryOfBirth.isEmpty ? nil : countryOfBirth
        sessionStore.currentUser.funFact = funFact.isEmpty ? nil : funFact
        sessionStore.currentUser.referralSource = referralSource.isEmpty ? nil : referralSource
        sessionStore.currentUser.onboardingCompleted = true
        
        // Save and dismiss
        isComplete = true
    }
}

#Preview {
    OnboardingView(isComplete: .constant(false))
        .environmentObject(SessionStore())
}
