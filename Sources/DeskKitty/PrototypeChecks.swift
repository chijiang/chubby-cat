import AppKit
import Security

/// Opt-in native integration checks, using only the local API fixture.
@MainActor enum PrototypeChecks {
    static func run(_ app: AppDelegate) async {
        var failures: [String] = []
        let model = app.model!
        model.settings.baseURL = "http://127.0.0.1:18743/v1"
        model.settings.model = "fixture-fail"
        model.key = ""
        model.draft = "original question"
        model.send()
        model.draft = "my next question"
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        if model.draft != "my next question" { failures.append("request failure overwrote a new draft") }
        model.newConversation()
        model.settings.model = "fixture-slow"
        model.selectedTab = .chat
        app.showCompanion()
        model.draft = "cancel when closed"
        model.send()
        app.controlWindow?.performClose(nil)
        if model.sending { failures.append("closing main chat window left its request running") }
        model.stopChat()
        model.settings.model = "fixture-slow"
        model.testConnection()
        model.saveAPI(base: model.settings.baseURL, model: "fixture-slow", key: "", streaming: true)
        model.testConnection()
        try? await Task.sleep(nanoseconds: 100_000_000)
        if !model.testingConnection { failures.append("canceled test cleared the newer test's running flag") }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        model.shutdown()
        do {
            try CredentialStore.save("", for: "regression-fixture", delete: { _ in errSecAuthFailed })
            failures.append("credential deletion error was reported as success")
        } catch {}
        if failures.isEmpty { print("APP CHECKS PASS: preserved draft, window-close cancellation, connection-test isolation") }
        else { for item in failures { print("APP CHECK FAIL: \(item)") } }
        UserDefaults.standard.removePersistentDomain(forName: "com.deskkitty.prototype.checks")
        exit(failures.isEmpty ? 0 : 1)
    }
}
