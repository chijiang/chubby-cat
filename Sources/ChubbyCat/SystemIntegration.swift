import AppKit
import Carbon
import ServiceManagement
import Darwin

enum MonotonicTime {
    private static let factor: Double = { var info = mach_timebase_info_data_t(); mach_timebase_info(&info); return Double(info.numer) / Double(info.denom) / 1_000_000_000 }()
    static var now: Double { Double(mach_continuous_time()) * factor }
}

@MainActor
final class SystemIntegration {
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?
    private weak var model: AppModel?
    init(model: AppModel) {
        self.model = model
        let center = NSWorkspace.shared.notificationCenter
        let events: [(Notification.Name, String, Bool)] = [
            (NSWorkspace.screensDidSleepNotification, "display", true), (NSWorkspace.screensDidWakeNotification, "display", false),
            (NSWorkspace.willSleepNotification, "system", true), (NSWorkspace.didWakeNotification, "system", false),
            (NSWorkspace.sessionDidResignActiveNotification, "session", true), (NSWorkspace.sessionDidBecomeActiveNotification, "session", false)
        ]
        for (name, reason, inactive) in events {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak model] _ in MainActor.assumeIsolated { model?.systemState(reason, inactive: inactive) } })
        }
        // Best-effort system notifications: useful in the prototype, not a documented lock-state API.
        for (name, inactive) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            distributedObservers.append(DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak model] _ in MainActor.assumeIsolated { model?.systemState("lock", inactive: inactive) } })
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak model] _ in
            MainActor.assumeIsolated { model?.cancelReminder(restoreHome: true); model?.pet.recoverPosition(); model?.savePosition() }
        }
        model.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            model?.launchAtLogin = SMAppService.mainApp.status == .enabled
            model?.loginError = SMAppService.mainApp.status == .requiresApproval ? "Approve chubby-cat in System Settings → General → Login Items." : nil
        } catch { model?.launchAtLogin = SMAppService.mainApp.status == .enabled; model?.loginError = error.localizedDescription }
    }
    deinit {
        for token in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        for token in distributedObservers { DistributedNotificationCenter.default().removeObserver(token) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
}

final class HotkeyManager {
    private var handler: EventHandlerRef?
    private var hotkey: EventHotKeyRef?
    var action: (() -> Void)?
    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(context).takeUnretainedValue()
            manager.action?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(choice: Int) -> String {
        if let hotkey { UnregisterEventHotKey(hotkey); self.hotkey = nil }
        if choice == 2 { return "Global shortcut is off" }
        let modifiers = UInt32(controlKey | (choice == 1 ? shiftKey : optionKey))
        let result = RegisterEventHotKey(UInt32(kVK_Space), modifiers, EventHotKeyID(signature: 0x444B5459, id: 1), GetApplicationEventTarget(), 0, &hotkey)
        if result != noErr { return "Shortcut unavailable. Choose another combination." }
        return choice == 1 ? "⌃⇧Space opens Quick Q&A" : "⌃⌥Space opens Quick Q&A"
    }
    deinit { if let hotkey { UnregisterEventHotKey(hotkey) }; if let handler { RemoveEventHandler(handler) } }
}
