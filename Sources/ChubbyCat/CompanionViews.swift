import SwiftUI
import AppKit
import ChubbyCatCore

enum KittyStyle {
    static let ink = Color(red: 0.16, green: 0.19, blue: 0.17)
    static let moss = Color(red: 0.32, green: 0.42, blue: 0.30)
    static let paper = Color(red: 0.97, green: 0.98, blue: 0.96)
    static let sidebar = Color(red: 0.92, green: 0.94, blue: 0.91)
    static let line = Color(red: 0.84, green: 0.87, blue: 0.82)
}

struct CompanionRootView: View {
    @ObservedObject var model: AppModel
    var onLoginChange: (Bool) -> Void
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Image(nsImage: SpriteAtlas.shared.master).resizable().scaledToFit().frame(width: 92, height: 112).frame(maxWidth: .infinity).padding(.top, 20)
                Text("chubby-cat").font(.system(size: 21, weight: .semibold, design: .rounded)).frame(maxWidth: .infinity)
                Text("A small friend for your day.").font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom, 22)
                ForEach(CompanionTab.allCases, id: \.self) { tab in
                    Button { model.selectedTab = tab } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab == .companion ? "pawprint" : tab == .chat ? "bubble.left.and.bubble.right" : "slider.horizontal.3").frame(width: 18)
                            Text(tab.rawValue).font(.system(size: 13, weight: model.selectedTab == tab ? .semibold : .regular))
                            Spacer()
                        }.padding(.horizontal, 13).padding(.vertical, 11)
                            .foregroundStyle(model.selectedTab == tab ? KittyStyle.moss : KittyStyle.ink)
                            .background(model.selectedTab == tab ? Color.white.opacity(0.85) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
                Spacer()
                HStack(spacing: 7) { Circle().fill(model.paused ? .gray : KittyStyle.moss).frame(width: 6, height: 6); Text(model.paused ? "Timer paused" : "Here with you").font(.system(size: 11)).foregroundStyle(.secondary) }
                Text("Prototype 0.1").font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 4).padding(.bottom, 10)
            }.padding(.horizontal, 16).frame(width: 190).background(KittyStyle.sidebar)
            Rectangle().fill(KittyStyle.line).frame(width: 1)
            Group {
                switch model.selectedTab {
                case .companion: DashboardView(model: model)
                case .chat: ChatView(model: model)
                case .settings: SettingsView(model: model, onLoginChange: onLoginChange)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(KittyStyle.paper)
        }.foregroundStyle(KittyStyle.ink).tint(KittyStyle.moss).frame(minWidth: 860, minHeight: 650)
    }
}

struct DashboardView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Your day, with a little company.").font(.system(size: 27, weight: .semibold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                        Text("A quick answer when you need one.\nA gentle nudge when it's time to look away.").font(.system(size: 13)).lineSpacing(4).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Image(nsImage: SpriteAtlas.shared.master).resizable().scaledToFit().frame(width: 130, height: 155)
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("Your next little break", systemImage: "leaf").font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(model.status).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(AppModel.clock(model.remaining)).font(.system(size: 48, weight: .light, design: .rounded)).monospacedDigit()
                        Text("remaining").font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(model.elapsed / 60)) min together").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    ProgressView(value: model.progress).tint(KittyStyle.moss)
                    HStack(spacing: 9) {
                        Button(model.paused ? "Resume timer" : "Pause timer", systemImage: model.paused ? "play" : "pause") { model.togglePause() }
                        Menu {
                            Button("Quiet for 30 minutes") { model.setQuiet(minutes: 30) }
                            Button("Quiet for 1 hour") { model.setQuiet(minutes: 60) }
                            Button("End quiet time") { model.setQuiet(minutes: nil) }
                        } label: { Label("Quiet time", systemImage: "moon") }
                        Spacer()
                        Button("Demo reminder", systemImage: "sparkles") { model.beginReminder(demo: true) }.buttonStyle(.borderedProminent).disabled(model.reminderActive)
                    }.controlSize(.regular)
                    if model.reminderActive { Button("Cancel demonstration / reminder") { model.cancelReminder(restoreHome: true) }.font(.system(size: 12)) }
                }.padding(22).background(.white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(KittyStyle.line, lineWidth: 1))
                if model.restRemaining != nil || model.restNeedsConfirmation {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.restNeedsConfirmation ? "Welcome back." : "Give your eyes a little space.").font(.system(size: 15, weight: .semibold))
                            Text(model.restNeedsConfirmation ? "Confirm when you've finished resting." : "Rest time left: \(AppModel.clock(model.restRemaining ?? 0))").font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("I've rested") { model.confirmRest() }.buttonStyle(.borderedProminent)
                        Button("Cancel") { model.cancelRest() }
                    }.padding(18).background(KittyStyle.sidebar, in: RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Meet your cat").font(.system(size: 17, weight: .semibold, design: .rounded)); Spacer(); Button(model.petVisible ? "Hide from desktop" : "Show on desktop") { model.togglePet() }.font(.system(size: 12)) }
                    Text("Click your cat to ask a question. Drag to find a favorite spot.\nTry an expression below to see it on your desktop.").font(.system(size: 12)).lineSpacing(4).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(CatAction.allCases) { action in
                            Button { model.preview(action) } label: {
                                VStack(spacing: 4) {
                                    Image(nsImage: SpriteAtlas.shared.frames[action.row][action == .stretch ? 3 : 0]).resizable().scaledToFit().frame(height: 62)
                                    Text(action.label).font(.system(size: 11))
                                }.frame(maxWidth: .infinity).padding(.vertical, 8).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
                            }.buttonStyle(.plain).disabled(model.reminderActive || !model.petVisible)
                        }
                    }
                }
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "eye").foregroundStyle(KittyStyle.moss)
                    Text("Reading counts too. The timer follows your screen session, not your keystrokes. A sustained screen-off break resets the cycle.").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                }
            }.padding(32)
        }
    }
}

struct ChatView: View {
    @ObservedObject var model: AppModel
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Q&A").font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(model.apiReady ? model.settings.model : "Connect your model to get started").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button("New conversation", systemImage: "square.and.pencil") { model.newConversation() }.labelStyle(.iconOnly).help("New conversation")
            }.padding(22)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if model.entries.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Image(nsImage: SpriteAtlas.shared.frames[0][0]).resizable().scaledToFit().frame(height: 110).frame(maxWidth: .infinity)
                                Text("What's on your mind?").font(.system(size: 21, weight: .medium, design: .rounded))
                                Text("Ask something small. Keep your flow.").font(.system(size: 13)).foregroundStyle(.secondary)
                                if !model.apiReady {
                                    Text("Add an API URL and model in Settings. Your key stays in Keychain, and conversations stay in memory.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                                    Button("Open connection settings") { model.selectedTab = .settings; model.onShowWindow?() }
                                } else {
                                    ForEach(["Help me write a clearer sentence", "Explain a concept simply", "Suggest a five-minute screen break"], id: \.self) { suggestion in
                                        Button(suggestion) { model.draft = suggestion; focused = true }.buttonStyle(.bordered)
                                    }
                                }
                            }.padding(.top, 12)
                        }
                        ForEach(model.entries) { entry in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack { Text(entry.role == "user" ? "You" : "Kitty").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary); Spacer(); if entry.role == "assistant" && !entry.text.isEmpty { Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(entry.text, forType: .string) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("Copy answer") } }
                                if entry.text.isEmpty { ProgressView().controlSize(.small).frame(height: 22) }
                                else { Text(entry.text).font(.system(size: 13)).lineSpacing(4).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                            }.padding(14).background(entry.role == "user" ? KittyStyle.sidebar : .white, in: RoundedRectangle(cornerRadius: 10)).id(entry.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(22)
                }.onChange(of: model.entries.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                 .onChange(of: model.entries.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
            if let error = model.chatError { Text(error).font(.system(size: 12)).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.bottom, 10) }
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask your cat…", text: $model.draft, axis: .vertical).lineLimit(1...5).textFieldStyle(.plain).focused($focused).onSubmit { model.send() }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 9))
                if model.sending { Button("Stop", systemImage: "stop.fill") { model.stopChat() }.labelStyle(.iconOnly).controlSize(.large) }
                else { Button { model.send() } label: { Image(systemName: "arrow.up").fontWeight(.semibold) }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.padding(.horizontal, 20).padding(.top, 15)
            Text("Only what you type is sent to your chosen API.").font(.system(size: 10)).foregroundStyle(.tertiary).padding(.vertical, 10)
        }.background(KittyStyle.paper).tint(KittyStyle.moss).onAppear { focused = true }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var onLoginChange: (Bool) -> Void
    @State private var base = ""
    @State private var modelName = ""
    @State private var apiKey = ""
    @State private var streaming = true
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Make yourself at home.").font(.system(size: 26, weight: .semibold, design: .rounded))
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your companion").font(.system(size: 17, weight: .semibold))
                    HStack { Text("Cat size"); Slider(value: $model.settings.petSize, in: 130...260, step: 5); Text("\(Int(model.settings.petSize))").monospacedDigit().frame(width: 35) }
                    Toggle("Gentle motion only", isOn: $model.settings.reducedMotion)
                    Text("Keeps reminders in place and avoids large movement. Your Mac's Reduce Motion setting is also respected.").font(.system(size: 11)).foregroundStyle(.secondary)
                    Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: onLoginChange))
                    if let error = model.loginError { Text(error).font(.system(size: 11)).foregroundStyle(.secondary) }
                    Picker("Quick Q&A shortcut", selection: $model.settings.hotkeyChoice) { Text("Control + Option + Space").tag(0); Text("Control + Shift + Space").tag(1); Text("Off").tag(2) }
                    Text(model.shortcutStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                }.font(.system(size: 13))
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    Text("A moment away").font(.system(size: 17, weight: .semibold))
                    Toggle("Remind me to rest my eyes", isOn: $model.settings.remindersEnabled)
                    Stepper("Reminder every \(Int(model.settings.reminderMinutes)) minutes", value: $model.settings.reminderMinutes, in: 1...180, step: 1)
                    Stepper("Rest for \(Int(model.settings.restMinutes)) minutes", value: $model.settings.restMinutes, in: 1...20, step: 1)
                    Text("Default: 90 minutes of screen use, with a 5-minute rest. Snoozing postpones the reminder without clearing your time.").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                }.font(.system(size: 13))
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Your AI connection").font(.system(size: 17, weight: .semibold)); Spacer(); Text("OpenAI-compatible").font(.system(size: 10)).foregroundStyle(.secondary) }
                    labeled("API URL") { TextField("https://your-service.example/v1", text: $base).textContentType(.URL) }
                    labeled("Model") { TextField("Model name from your provider", text: $modelName) }
                    labeled("API key") { SecureField("Optional for local services", text: $apiKey) }
                    Toggle("Stream answers as they arrive", isOn: $streaming)
                    HStack {
                        Button("Save connection") { model.saveAPI(base: base, model: modelName, key: apiKey, streaming: streaming) }.buttonStyle(.borderedProminent)
                        Button(model.testingConnection ? "Testing…" : "Test saved connection") { model.testConnection() }.disabled(model.testingConnection || !model.apiReady)
                        Spacer()
                        Button("Forget saved key") { model.forgetKey(); apiKey = "" }.font(.system(size: 11))
                    }
                    if let message = model.credentialStatus { Text(message).font(.system(size: 11)).foregroundStyle(.secondary) }
                    if let message = model.connectionStatus { Text(message).font(.system(size: 11)).foregroundStyle(.secondary) }
                    Text("Requests go directly to this service. No chubby-cat account or cloud relay. Testing sends one short prompt and may use API credit.").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                }.font(.system(size: 13)).textFieldStyle(.roundedBorder)
                Divider()
                HStack { Text("Conversations are kept in memory and cleared when you quit.").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Button("Clear conversation") { model.newConversation() }.font(.system(size: 11)) }
            }.padding(32)
        }.onAppear { base = model.settings.baseURL; modelName = model.settings.model; apiKey = model.key; streaming = model.settings.streaming }
         .onChange(of: base) { _, value in if value.trimmingCharacters(in: .whitespacesAndNewlines) != model.settings.baseURL { apiKey = "" } }
         .onChange(of: model.settings) { _, _ in model.saveSettings() }
    }
    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary); content() }
    }
}

struct BreakReminderView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("A little time for your eyes", systemImage: "leaf").font(.system(size: 16, weight: .semibold, design: .rounded))
            Text("You've been here a while. Look away, stretch,\nand let your eyes wander somewhere farther.").font(.system(size: 12)).lineSpacing(3).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Take a break") { model.finishReminder(.rest) }.buttonStyle(.borderedProminent)
                Button("In 10 min") { model.finishReminder(.snooze) }.buttonStyle(.bordered)
                Button("Skip") { model.finishReminder(.skip) }.buttonStyle(.plain).font(.system(size: 11))
            }.controlSize(.small)
        }.padding(20).frame(width: 345, alignment: .leading).background(KittyStyle.paper).tint(KittyStyle.moss).foregroundStyle(KittyStyle.ink)
    }
}
