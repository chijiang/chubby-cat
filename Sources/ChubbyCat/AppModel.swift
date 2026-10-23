import AppKit
import SwiftUI
import ChubbyCatCore

enum CompanionTab: String, CaseIterable { case companion = "Companion", chat = "Quick Q&A", settings = "Settings" }
struct ConversationEntry: Identifiable {
    let id = UUID()
    let role: String
    var text: String
    var completed = true
}
struct AppSettings: Codable, Equatable {
    var petSize: Double = 190
    var reminderMinutes: Double = 90
    var restMinutes: Double = 5
    var remindersEnabled = true
    var reducedMotion = false
    var baseURL = "https://api.openai.com/v1"
    var model = ""
    var streaming = true
    var hotkeyChoice = 0
}
enum ReminderChoice { case snooze, skip, rest }

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTab: CompanionTab = .companion
    @Published var settings: AppSettings
    @Published var paused = false
    @Published var quietUntil: Date?
    @Published var petVisible = true
    @Published var elapsed: Double = 0
    @Published var remaining: Double = 5400
    @Published var status = "Settling in"
    @Published var reminderActive = false
    @Published var reminderMessageVisible = false
    @Published var restRemaining: Double?
    @Published var restNeedsConfirmation = false
    @Published var entries: [ConversationEntry] = []
    @Published var draft = ""
    @Published var sending = false
    @Published var chatError: String?
    @Published var connectionStatus: String?
    @Published var testingConnection = false
    @Published var credentialStatus: String?
    @Published var launchAtLogin = false
    @Published var loginError: String?
    @Published var shortcutStatus = "⌃⌥Space opens Quick Q&A"
    let pet = PetWindowController()
    let client = ChatClient()
    var onShowWindow: (() -> Void)?
    var onShowChat: (() -> Void)?
    var onShowReminder: (() -> Void)?
    var onHideReminder: (() -> Void)?
    var onRefreshMenu: (() -> Void)?
    var onHotkeyChanged: (() -> Void)?
    var key = ""
    private var scheduler: BreakScheduler
    private var timer: Timer?
    private var lastTick = MonotonicTime.now
    private var lastCheckpoint = MonotonicTime.now
    private var inactiveReasons: Set<String> = []
    private var reminderTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var testTask: Task<Void, Never>?
    private var requestID = UUID()
    private var connectionTestID = UUID()
    private var reminderID = UUID()
    private var home: NSPoint?
    private var isDemo = false
    private var savedPauseBeforeRest = false
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let config = defaults.data(forKey: "settings").flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) } ?? AppSettings()
        settings = config
        let checkpoint = defaults.data(forKey: "breakCheckpoint").flatMap { try? JSONDecoder().decode(BreakCheckpoint.self, from: $0) }
        scheduler = checkpoint.map { BreakScheduler(checkpoint: $0, interval: config.reminderMinutes * 60, restThreshold: config.restMinutes * 60) }
            ?? BreakScheduler(interval: config.reminderMinutes * 60, restThreshold: config.restMinutes * 60)
        key = CredentialStore.read(for: config.baseURL)
        pet.normalSize = config.petSize
        pet.sprite.reducedMotion = config.reducedMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        pet.sprite.onClick = { [weak self] in self?.openChat() }
        pet.sprite.onDragStart = { [weak self] in self?.cancelReminder(restoreHome: false); self?.previewTask?.cancel() }
        pet.sprite.onDragEnd = { [weak self] in self?.pet.recoverPosition(); self?.savePosition() }
        let position: NSPoint? = defaults.object(forKey: "petX") == nil ? nil : NSPoint(x: defaults.double(forKey: "petX"), y: defaults.double(forKey: "petY"))
        pet.show(at: position)
        elapsed = scheduler.elapsed; remaining = scheduler.remaining
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        timer?.tolerance = 0.1
        tick()
    }

    var reducedMotion: Bool { settings.reducedMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var quiet: Bool { (quietUntil ?? .distantPast) > Date() }
    var canPresentReminder: Bool { settings.remindersEnabled && !paused && !quiet && inactiveReasons.isEmpty && restRemaining == nil && !restNeedsConfirmation && !reminderActive && selectedInteractionIsIdle && petVisible }
    private var selectedInteractionIsIdle: Bool { !pet.sprite.isDragging && !(NSApp.isActive && NSApp.keyWindow != nil) }
    var progress: Double { min(1, elapsed / (settings.reminderMinutes * 60)) }
    var apiReady: Bool { !settings.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    static func clock(_ seconds: Double) -> String {
        let value = max(0, Int(ceil(seconds)))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    func tick() {
        let now = MonotonicTime.now
        let delta = max(0, now - lastTick); lastTick = now
        scheduler.advance(by: delta, active: inactiveReasons.isEmpty, paused: paused || restRemaining != nil || restNeedsConfirmation)
        if let current = restRemaining {
            restRemaining = max(0, current - delta)
            if restRemaining == 0 { restRemaining = nil; restNeedsConfirmation = true }
        }
        elapsed = scheduler.elapsed; remaining = scheduler.remaining
        pet.isSystemActive = inactiveReasons.isEmpty
        if let until = quietUntil, until <= Date() { quietUntil = nil }
        if !inactiveReasons.isEmpty { status = "Screen session paused" }
        else if restNeedsConfirmation { status = "Ready when you are" }
        else if restRemaining != nil { status = "Taking a little break" }
        else if paused { status = "Timer paused" }
        else if quiet { status = "Quiet time" }
        else if reminderActive { status = "A little nudge to rest" }
        else if scheduler.shouldRemind { status = "Break reminder waiting" }
        else if scheduler.snoozeRemaining > 0 { status = "Snoozed, still keeping time" }
        else { status = "Keeping you company" }
        if scheduler.shouldRemind && canPresentReminder { beginReminder(demo: false) }
        if now - lastCheckpoint >= 15 { persist(); lastCheckpoint = now }
        onRefreshMenu?()
    }

    func systemState(_ reason: String, inactive: Bool) {
        tick()
        if inactive { inactiveReasons.insert(reason); cancelReminder(restoreHome: true) }
        else { inactiveReasons.remove(reason) }
        pet.isSystemActive = inactiveReasons.isEmpty
    }
    func saveSettings() {
        settings.petSize = min(260, max(130, settings.petSize))
        settings.reminderMinutes = min(180, max(1, settings.reminderMinutes))
        settings.restMinutes = min(20, max(1, settings.restMinutes))
        scheduler.interval = settings.reminderMinutes * 60; scheduler.restThreshold = settings.restMinutes * 60
        pet.sprite.reducedMotion = reducedMotion
        if !reminderActive { pet.resize(to: settings.petSize) }
        persist(); onHotkeyChanged?()
    }
    func persist() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: "settings") }
        if let data = try? JSONEncoder().encode(scheduler.checkpoint) { defaults.set(data, forKey: "breakCheckpoint") }
        if !reminderActive { savePosition() }
    }
    func savePosition() { defaults.set(pet.panel.frame.minX, forKey: "petX"); defaults.set(pet.panel.frame.minY, forKey: "petY") }
    func togglePet() {
        if petVisible { cancelReminder(restoreHome: true); pet.hide() } else { pet.show(at: pet.panel.frame.origin) }
        petVisible.toggle(); onRefreshMenu?()
    }
    func togglePause() { tick(); paused.toggle(); if paused { cancelReminder(restoreHome: true) }; tick(); persist() }
    func setQuiet(minutes: Double?) {
        quietUntil = minutes.map { Date().addingTimeInterval($0 * 60) }
        if quiet { cancelReminder(restoreHome: true) }
        tick()
    }
    func openChat() { cancelReminder(restoreHome: true); onShowChat?() }
    func newConversation() { stopChat(); entries = []; chatError = nil }

    func preview(_ action: CatAction) {
        cancelReminder(restoreHome: true); previewTask?.cancel()
        pet.sprite.action = action
        previewTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 3_000_000_000); try Task.checkCancellation(); self?.pet.sprite.action = .idle } catch {}
        }
    }

    func beginReminder(demo: Bool) {
        guard !reminderActive, inactiveReasons.isEmpty else { return }
        previewTask?.cancel()
        if !petVisible { petVisible = true; pet.show(at: pet.panel.frame.origin) }
        isDemo = demo; reminderActive = true; reminderMessageVisible = false
        if !demo { scheduler.markPresented() }
        home = pet.panel.frame.origin
        let token = UUID(); reminderID = token
        reminderTask = Task { [weak self] in
            guard let self else { return }
            do {
                let area = self.pet.screen.visibleFrame
                let size = self.pet.normalSize
                if !self.reducedMotion {
                    try await self.pet.move(to: .init(x: area.midX - size / 2, y: area.midY - size / 2), speed: 340, reduced: false)
                    try await self.pet.scale(to: size * 1.8, reduced: false)
                    self.pet.sprite.action = .stretch
                    try await Task.sleep(nanoseconds: 1_400_000_000)
                }
                try Task.checkCancellation()
                guard self.reminderID == token else { return }
                self.pet.sprite.action = .idle
                self.reminderMessageVisible = true; self.onShowReminder?()
                try await Task.sleep(nanoseconds: 8_000_000_000)
                try Task.checkCancellation()
                guard self.reminderID == token else { return }
                self.finishReminder(.snooze)
            } catch {}
        }
    }
    func finishReminder(_ choice: ReminderChoice) {
        let demo = isDemo
        reminderTask?.cancel(); reminderID = UUID()
        reminderMessageVisible = false; onHideReminder?()
        if !demo {
            switch choice {
            case .snooze: scheduler.snooze()
            case .skip: scheduler.skip()
            case .rest: scheduler.snooze(); startRest()
            }
        }
        let destination = home; home = nil
        reminderTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.pet.scale(to: self.pet.normalSize, reduced: self.reducedMotion)
                if let destination { try await self.pet.move(to: destination, speed: 230, reduced: self.reducedMotion) }
                self.pet.recoverPosition(); self.pet.sprite.action = self.restRemaining != nil ? .sleep : .idle
                self.reminderActive = false; self.persist()
            } catch {}
        }
    }
    func cancelReminder(restoreHome: Bool) {
        guard reminderActive else { return }
        reminderTask?.cancel(); reminderID = UUID()
        onHideReminder?(); reminderMessageVisible = false
        let origin = restoreHome ? (home ?? pet.panel.frame.origin) : pet.panel.frame.origin
        pet.panel.setFrame(.init(origin: origin, size: .init(width: pet.normalSize, height: pet.normalSize)), display: true)
        pet.recoverPosition(); pet.sprite.action = .idle
        home = nil; reminderActive = false
        if !isDemo { scheduler.snooze() }
    }
    func startRest() {
        savedPauseBeforeRest = paused
        restRemaining = settings.restMinutes * 60; restNeedsConfirmation = false
        pet.sprite.action = .sleep
    }
    func confirmRest() {
        restRemaining = nil; restNeedsConfirmation = false
        scheduler.completeRest(); paused = savedPauseBeforeRest
        pet.sprite.action = .idle; tick(); persist()
    }
    func cancelRest() {
        restRemaining = nil; restNeedsConfirmation = false
        paused = savedPauseBeforeRest; pet.sprite.action = .idle; tick()
    }

    func saveAPI(base: String, model: String, key newKey: String, streaming: Bool) {
        do {
            _ = try ChatEndpoint.url(from: base)
            let base = base.trimmingCharacters(in: .whitespacesAndNewlines)
            try CredentialStore.save(newKey.trimmingCharacters(in: .whitespacesAndNewlines), for: base)
            stopChat(); connectionTestID = UUID(); testTask?.cancel(); testingConnection = false
            entries = []; connectionStatus = nil
            settings.baseURL = base; settings.model = model.trimmingCharacters(in: .whitespacesAndNewlines); settings.streaming = streaming
            key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
            credentialStatus = "Connection saved. API keys stay in your Mac's Keychain."
            persist()
        } catch { credentialStatus = error.localizedDescription }
    }
    func forgetKey() {
        do { try CredentialStore.save("", for: settings.baseURL); key = ""; credentialStatus = "Saved key removed." }
        catch { credentialStatus = error.localizedDescription }
    }
    private var apiConfiguration: APIConfiguration { .init(baseURL: settings.baseURL, model: settings.model, key: key, streaming: settings.streaming) }
    func testConnection() {
        guard !testingConnection else { return }
        connectionStatus = nil; testingConnection = true
        let token = UUID(); connectionTestID = token
        let configuration = apiConfiguration
        testTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.client.complete(configuration: configuration, messages: [.init(role: "user", content: "Reply with just: hello")]) { _ in }
                try Task.checkCancellation()
                guard self.connectionTestID == token else { return }
                self.connectionStatus = "Connected. Your model returned text."
            } catch {
                guard self.connectionTestID == token else { return }
                if !Task.isCancelled { self.connectionStatus = error.localizedDescription }
            }
            guard self.connectionTestID == token else { return }
            self.testingConnection = false
        }
    }
    func send() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !sending else { return }
        guard apiReady else { chatError = "Add your API model in Settings before sending."; return }
        guard question.count <= 8000 else { chatError = "Please keep a quick question under 8,000 characters."; return }
        draft = ""; chatError = nil
        entries.append(.init(role: "user", text: question))
        let history = Array(entries.filter { $0.completed && !$0.text.isEmpty }.suffix(12)).map { ChatMessage(role: $0.role, content: String($0.text.prefix(12000))) }
        let messages = [ChatMessage(role: "system", content: "You are a friendly, concise desktop cat companion. Answer the user's question directly, in their language. Do not claim to see their screen or perform actions. Keep answers brief unless asked for detail.")] + history
        let entry = ConversationEntry(role: "assistant", text: "", completed: false)
        let answerID = entry.id; entries.append(entry); sending = true
        let token = UUID(); requestID = token
        let configuration = apiConfiguration
        if !reminderActive { pet.sprite.action = .think }
        chatTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.client.complete(configuration: configuration, messages: messages) { [weak self] text in
                    guard let self, self.requestID == token, let index = self.entries.firstIndex(where: { $0.id == answerID }) else { return }
                    self.entries[index].text += text
                    if !self.reminderActive { self.pet.sprite.action = .talk }
                }
                try Task.checkCancellation()
                guard self.requestID == token else { return }
                if let index = self.entries.firstIndex(where: { $0.id == answerID }) { self.entries[index].completed = true }
            } catch {
                guard self.requestID == token else { return }
                if !Task.isCancelled {
                    self.chatError = error.localizedDescription
                    if self.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { self.draft = question }
                }
            }
            guard self.requestID == token else { return }
            self.entries.removeAll { $0.id == answerID && $0.text.isEmpty }
            self.sending = false
            if !self.reminderActive { self.pet.sprite.action = .idle }
        }
    }
    func stopChat() {
        requestID = UUID(); chatTask?.cancel(); chatTask = nil; sending = false
        entries.removeAll { $0.role == "assistant" && $0.text.isEmpty }
        if !reminderActive { pet.sprite.action = .idle }
    }
    func shutdown() { timer?.invalidate(); previewTask?.cancel(); chatTask?.cancel(); testTask?.cancel(); cancelReminder(restoreHome: true); persist() }
}
