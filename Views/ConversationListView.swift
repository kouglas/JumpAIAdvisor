import SwiftUI

struct ConversationListView: View {
    @ObservedObject var chatManager: ChatManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedConversation: Conversation?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    //  header
                    HStack {
                        Text("Conversations")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Gradients.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            chatManager.createNewConversation()
                            dismiss()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Gradients.primary)
                                .symbolEffect(.pulse)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    
                    // Search bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    
                    // Conversation list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredConversations) { conversation in
                                ConversationCard(
                                    conversation: conversation,
                                    isSelected: selectedConversation?.id == conversation.id
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedConversation = conversation
                                        chatManager.selectConversation(conversation)
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return chatManager.conversations
        } else {
            return chatManager.conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText) ||
                conversation.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
}

// MARK: -  Search Bar
struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("Search conversations", text: $text)
                .font(.system(size: 17))
                .focused($isFocused)
                .submitLabel(.search)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isFocused ? Gradients.primary : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1
                        )
                }
        }
    }
}

// MARK: -  Conversation Card
struct ConversationCard: View {
    let conversation: Conversation
    let isSelected: Bool
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(conversation.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Preview
            if let lastMessage = conversation.messages.last(where: { !$0.isThinking }) {
                Text(lastMessage.content)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // Metadata
            HStack {
                Label(formatDate(conversation.updatedAt), systemImage: "clock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("\(conversation.messages.count)", systemImage: "bubble.left.and.bubble.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isSelected ? Gradients.primary : LinearGradient(colors: [.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double.random(in: 0...0.2))) {
                appeared = true
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
        }
        
        return formatter.string(from: date)
    }
}
