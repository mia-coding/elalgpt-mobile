//
//  ContentView.swift
//  elalgpt
//
//  Created by Mia Yair on 9/15/25.
//

import SwiftUI

struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let time: String
}

struct ContentView: View {
    @State private var messages: [Message] = [
        Message(text: "Hi, welcome! What question do you have?", isUser: false, time: getCurrentTime())
    ]
    @State private var userInput: String = ""
    @FocusState private var inputFocused: Bool
    @Namespace private var bottomID
    @State private var isTyping: Bool = false
    @State private var isDarkMode: Bool = true
    
    private let brandPink = Color(red: 1.0, green: 105/255.0, blue: 180/255.0)
    private let brandPinkUIColor = UIColor(red: 1.0, green: 105/255.0, blue: 180/255.0, alpha: 1.0)

    var body: some View {
        VStack(spacing: 0) {
            
            HStack {
                Text("elalgpt")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(brandPink)
                
                Spacer()
                
                Button(action: { isDarkMode.toggle() }) {
                    Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                        .foregroundColor(Color.yellow)
                        .font(.title2)
                }
            }
            .padding()
            .background(isDarkMode ? Color.black.opacity(0.9) : Color.white.opacity(0.9))

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(messages) { msg in
                            if msg.isUser {
                                HStack {
                                    Spacer()
                                    messageView(msg)
                                        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .id(msg.id)
                                }
                            } else {
                                HStack {
                                    messageView(msg)
                                        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                                        .id(msg.id)
                                    Spacer()
                                }
                            }
                        }
                        
                        if isTyping {
                            HStack {
                                TypingIndicator()
                                    .padding(12)
                                    .background(isDarkMode ? brandPink : brandPink)
                                    .cornerRadius(20, corners: [.topLeft, .topRight, .bottomRight])
                                Spacer()
                            }
                        }
                        
                        Color.clear.frame(height: 1).id(bottomID)
                    }
                    .padding()
                }
                .background(isDarkMode ? Color.black : Color(white: 0.95))
                .onChange(of: messages) { _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
                .onChange(of: isTyping) { _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            
            HStack(spacing: 8) {
                TextField("Type a message...", text: $userInput)
                    .padding(12)
                    .background(isDarkMode ? Color.white : Color(white: 0.9))
                    .cornerRadius(999)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { sendMessage() }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding()
                        .background(brandPink)
                        .clipShape(Circle())
                        .shadow(color: brandPink.opacity(0.5), radius: 4, x: 0, y: 2)
                }
            }
            .padding()
            .background(isDarkMode ? Color.black.opacity(0.9) : Color.white.opacity(0.9))
        }
        .edgesIgnoringSafeArea(.bottom)
        .background(isDarkMode ? Color.black : Color(white: 0.95))
    }
    
    @ViewBuilder
    func messageView(_ msg: Message) -> some View {
        VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
            TextWithLinks(
                text: msg.text,
                linkColor: msg.isUser ? .black : .white
            )
            Text(msg.time)
                .font(.caption2)
                .foregroundColor(msg.isUser ? .gray : .white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: msg.isUser ? .trailing : .leading)
        }
        .padding(12)
        .background(msg.isUser ? Color.white : brandPink)
        .cornerRadius(20, corners: msg.isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
        .transition(.move(edge: msg.isUser ? .trailing : .leading).combined(with: .opacity))
        .onTapGesture {
            if !msg.isUser {
                UIPasteboard.general.string = msg.text
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
    }
    
    func sendMessage() {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let time = Self.getCurrentTime()
        
        // Haptic feedback for sending
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            messages.append(Message(text: trimmed, isUser: true, time: time))
        }
        userInput = ""
        inputFocused = false
        isTyping = true
        
        // Call backend
        guard let url = URL(string: "https://elalgpt.onrender.com/get_response") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["message": trimmed])
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            var responseText = "Oops, sorry... An error occurred."
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resp = json["response"] as? String {
                responseText = resp
            }
            let botTime = Self.getCurrentTime()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                // Haptic feedback for bot response
                let botGenerator = UIImpactFeedbackGenerator(style: .light)
                botGenerator.impactOccurred()
                
                withAnimation(.easeOut(duration: 0.4)) {
                    messages.append(Message(text: responseText, isUser: false, time: botTime))
                    isTyping = false
                }
            }
        }.resume()
    }
    
    // MARK: Current time formatter
    static func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: Date())
    }
}

// MARK: Typing indicator – fade + bounce dots
struct TypingIndicator: View {
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animate ? 1 : 0.5)
                    .opacity(animate ? 1 : 0.3)
                    .animation(Animation.easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(i)*0.2), value: animate)
            }
        }
        .onAppear { animate = true }
    }
}

// Rounded corners helper
struct RoundedCorner: Shape {
    var radius: CGFloat = 12
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                         cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

struct TextWithLinks: View {
    let text: String
    let linkColor: Color

    var body: some View {
        let parts = parseURLs(text)
        
        Text(parts.reduce(into: AttributedString()) { result, part in
            if part.isURL, let url = URL(string: part.text) {
                var linkText = AttributedString(part.text)
                linkText.link = url
                linkText.foregroundColor = linkColor
                linkText.underlineStyle = .single
                result += linkText
            } else {
                var regularText = AttributedString(part.text)
                regularText.foregroundColor = linkColor
                result += regularText
            }
        })
    }
}

func parseURLs(_ text: String) -> [(text: String, isURL: Bool)] {
    var result: [(String, Bool)] = []
    let pattern = #"https?:\/\/[^\s]+"#
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let nsText = text as NSString
    var lastIndex = 0
    regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)).forEach { match in
        let range = match.range
        if range.location > lastIndex {
            result.append((nsText.substring(with: NSRange(location: lastIndex, length: range.location - lastIndex)), false))
        }
        result.append((nsText.substring(with: range), true))
        lastIndex = range.location + range.length
    }
    if lastIndex < nsText.length {
        result.append((nsText.substring(from: lastIndex), false))
    }
    return result
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
