import SwiftUI

/// Star rating picker sheet for rating other users
struct StarRatingPickerView: View {
    let userName: String
    let currentRating: Int?
    let onSubmit: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRating: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Rate \(userName)")
                        .font(.title2.bold())
                    Text("Your rating helps build trust in our community")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Star selector
                HStack(spacing: 16) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                selectedRating = star
                            }
                        } label: {
                            Image(systemName: selectedRating >= star ? "star.fill" : "star")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)
                                .scaleEffect(selectedRating >= star ? 1.1 : 1.0)
                        }
                    }
                }
                .padding(.vertical)
                
                // Rating label
                if selectedRating > 0 {
                    Text(ratingLabel(for: selectedRating))
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // Submit button
                Button {
                    onSubmit(selectedRating)
                    dismiss()
                } label: {
                    Text("Submit Rating")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedRating > 0 ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(selectedRating == 0)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let current = currentRating {
                selectedRating = current
            }
        }
    }
    
    private func ratingLabel(for rating: Int) -> String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent!"
        default: return ""
        }
    }
}

#Preview {
    StarRatingPickerView(userName: "Alex", currentRating: nil, onSubmit: { _ in })
}
