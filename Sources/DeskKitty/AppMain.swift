import AppKit
import SwiftUI
import DeskKittyCore

final class CompanionWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    var model: AppModel!
    var integration: SystemIntegration?
    let hotkey = HotkeyManager()
    var statusItem: NSStatusItem!
    var controlWindow: NSWindow?
    var chatWindow: NSWindow?
    var reminderPanel: PetPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel(defaults: CommandLine.arguments.contains("--app-checks") ? UserDefaults(suiteName: "com.deskkitty.prototype.checks")! : .standard)
        integration = SystemIntegration(model: model)
        model.onShowWindow = { [weak self] in self?.showCompanion() }
        model.onShowChat = { [weak self] in self?.showChat() }
        model.onShowReminder = { [weak self] in self?.showReminder() }
        model.onHideReminder = { [weak self] in self?.reminderPanel?.orderOut(nil) }
        model.onRefreshMenu = { [weak self] in guard let self else { return }; self.statusItem?.button?.toolTip = "Desk Kitty · \(AppModel.clock(self.model.remaining)) until a break" }
        model.onHotkeyChanged = { [weak self] in self?.registerShortcut() }
        model.pet.sprite.contextMenu = { [weak self] in self?.makeMenu() ?? NSMenu() }
        hotkey.action = { [weak self] in Task { @MainActor in self?.model.openChat() } }
        registerShortcut()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Desk Kitty")
        let menu = NSMenu(); menu.delegate = self; statusItem.menu = menu
        if !CommandLine.arguments.contains("--background") { showCompanion() }
        if CommandLine.arguments.contains("--demo") { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.model.beginReminder(demo: true) } }
        if CommandLine.arguments.contains("--app-checks") { Task { await PrototypeChecks.run(self) } }
    }
    func registerShortcut() { model.shortcutStatus = hotkey.register(choice: model.settings.hotkeyChoice) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showCompanion(); return true }

    @objc func showCompanion() {
        if controlWindow == nil {
            let window = CompanionWindow(contentRect: .init(x: 0, y: 0, width: 980, height: 750), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Desk Kitty"; window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false; window.minSize = .init(width: 880, height: 690); window.delegate = self
            window.contentView = NSHostingView(rootView: CompanionRootView(model: model, onLoginChange: { [weak self] value in self?.integration?.setLogin(value) }))
            window.center(); controlWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); controlWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func showChat() {
        if chatWindow == nil {
            let window = CompanionWindow(contentRect: .init(x: 0, y: 0, width: 460, height: 620), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "Ask Kitty"; window.titlebarAppearsTransparent = true
            window.level = .floating; window.isReleasedWhenClosed = false; window.minSize = .init(width: 360, height: 430); window.delegate = self
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: ChatView(model: model)); chatWindow = window
        }
        if let window = chatWindow {
            let cat = model.pet.panel.frame
            let area = model.pet.screen.visibleFrame
            let target = CGRect(x: cat.midX - window.frame.width / 2, y: cat.maxY + 8, width: window.frame.width, height: window.frame.height)
            window.setFrame(Placement.clamp(target, to: area), display: true)
            NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
        }
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let closingChat = window === chatWindow || (window === controlWindow && model.selectedTab == .chat)
        let anotherChatVisible = (window !== chatWindow && chatWindow?.isVisible == true)
            || (window !== controlWindow && controlWindow?.isVisible == true && model.selectedTab == .chat)
        if closingChat && !anotherChatVisible { model.stopChat() }
    }
    func showReminder() {
        if reminderPanel == nil {
            let panel = PetPanel(contentRect: .init(x: 0, y: 0, width: 385, height: 155), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true; panel.level = .floating; panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let host = NSHostingView(rootView: BreakReminderView(model: model))
            host.wantsLayer = true; host.layer?.cornerRadius = 14; host.layer?.masksToBounds = true
            panel.contentView = host; reminderPanel = panel
        }
        let cat = model.pet.panel.frame
        let area = model.pet.screen.visibleFrame
        let target = CGRect(x: cat.midX - 192.5, y: cat.maxY - 15, width: 385, height: 155)
        reminderPanel?.setFrame(Placement.clamp(target, to: area), display: true)
        reminderPanel?.orderFrontRegardless()
    }
    func menuNeedsUpdate(_ menu: NSMenu) { fill(menu) }
    func makeMenu() -> NSMenu { let menu = NSMenu(); fill(menu); return menu }
    private func fill(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: "Next break in \(AppModel.clock(model.remaining))", action: nil, keyEquivalent: ""); status.isEnabled = false; menu.addItem(status)
        menu.addItem(.separator())
        item("Open Desk Kitty", #selector(showCompanion), in: menu)
        item("Ask Kitty…", #selector(showChat), in: menu)
        item(model.paused ? "Resume timer" : "Pause timer", #selector(togglePause), in: menu)
        item("Demo reminder", #selector(demo), in: menu)
        if model.reminderActive { item("Cancel reminder", #selector(cancelReminder), in: menu) }
        item(model.petVisible ? "Hide cat" : "Show cat", #selector(togglePet), in: menu)
        item(model.quiet ? "End quiet time" : "Quiet for 30 minutes", #selector(toggleQuiet), in: menu)
        if model.restRemaining != nil || model.restNeedsConfirmation { item("I've finished resting", #selector(confirmRest), in: menu); item("Cancel rest", #selector(cancelRest), in: menu) }
        menu.addItem(.separator())
        item("Settings…", #selector(showSettings), in: menu)
        let quit = NSMenuItem(title: "Quit Desk Kitty", action: #selector(quit), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
    }
    private func item(_ title: String, _ selector: Selector, in menu: NSMenu) { let item = NSMenuItem(title: title, action: selector, keyEquivalent: ""); item.target = self; menu.addItem(item) }
    @objc func showSettings() { model.selectedTab = .settings; showCompanion() }
    @objc func togglePause() { model.togglePause() }
    @objc func togglePet() { model.togglePet() }
    @objc func demo() { model.beginReminder(demo: true) }
    @objc func cancelReminder() { model.cancelReminder(restoreHome: true) }
    @objc func toggleQuiet() { model.setQuiet(minutes: model.quiet ? nil : 30) }
    @objc func confirmRest() { model.confirmRest() }
    @objc func cancelRest() { model.cancelRest() }
    @objc func quit() { NSApp.terminate(nil) }
}

@main
enum DeskKittyMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        if CommandLine.arguments.contains("--smoke-test") {
            let atlas = SpriteAtlas.shared
            precondition(atlas.frames.count == 6 && atlas.frames.allSatisfy { $0.count == 6 })
            let pet = PetWindowController()
            precondition(!pet.panel.canBecomeKey && !pet.panel.isOpaque)
            precondition(atlas.bitmaps.allSatisfy { $0.allSatisfy { $0.pixelsWide == 512 && $0.pixelsHigh == 512 } })
            print("SMOKE PASS: 36 normalized frames, bundled master, alpha masks, nonactivating transparent pet panel")
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--test-api"), CommandLine.arguments.count > index + 1 {
            let endpoint = CommandLine.arguments[index + 1]
            Task { @MainActor in
                do {
                    let client = ChatClient()
                    for streaming in [true, false] {
                        var answer = ""
                        try await client.complete(configuration: .init(baseURL: endpoint, model: "fixture-cat", key: "", streaming: streaming), messages: [.init(role: "user", content: "hello")]) { answer += $0 }
                        guard answer == "Hello from Desk Kitty." else { throw ChatFailure.provider("Integration response did not match fixture.") }
                        print("API PASS: \(streaming ? "SSE" : "JSON") via real URLSession")
                    }
                    exit(0)
                } catch { print("API FAIL: \(error.localizedDescription)"); exit(1) }
            }
            dispatchMain()
        }
        let delegate = AppDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
