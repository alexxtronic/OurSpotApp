import SwiftUI

/// Reusable view for displaying a list of users (e.g. Followers, Following)
struct UserListView: View {
    let title: String
    let users: [UserProfile]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blockService: BlockService
    
    private var filteredUsers: [UserProfile] {
        users.filter { !blockService.isBlocked(userId: $0.id.uuidString) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filteredUsers.isEmpty {
                    Text("No users found.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(filteredUsers, id: \.id) { user in
                        NavigationLink(destination: PublicProfileView(userId: user.id)) {
                            HStack(spacing: 12) {
                                AvatarView(
                                    name: user.name,
                                    size: 40,
                                    url: URL(string: user.avatarUrl ?? ""),
                                    assetName: user.avatarLocalAssetName
                                )
                                
                                Text(user.name)
                                    .font(.body.weight(.medium))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UserListView(title: "Followers", users: [UserProfile.placeholder])
}
