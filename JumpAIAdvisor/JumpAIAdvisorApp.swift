//
//  JumpAIAdvisorApp.swift
//  JumpAIAdvisor
//
//  Created by Kari Douglas on 5/10/25.
//

import SwiftUI

@main
struct JumpAIAdvisorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(chatManager: ChatManager())
        }
    }
}
