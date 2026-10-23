import AppKit

/// Native command routing checks with a temporary, non-sensitive clipboard value.
@MainActor enum ClipboardChecks {
    static func run() async {
        let board = NSPasteboard.general
        let original = (board.pasteboardItems ?? []).map { item in item.types.compactMap { type in item.data(forType: type).map { (type, $0) } } }
        defer {
            board.clearContents()
            let items = original.map { values in let item = NSPasteboardItem(); for (type, data) in values { item.setData(data, forType: type) }; return item }
            board.writeObjects(items)
        }
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 400, height: 160), styleMask: [.titled], backing: .buffered, defer: false)
        let field = NSTextField(frame: .init(x: 20, y: 40, width: 350, height: 28))
        window.contentView?.addSubview(field)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        for _ in 0..<30 {
            if window.isKeyWindow && NSApp.isActive { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        var failures: [String] = []
        for secure in [false, true] {
            let input: NSTextField
            if secure { let value = NSSecureTextField(frame: field.frame); window.contentView?.addSubview(value); field.isHidden = true; input = value }
            else { input = field }
            window.makeFirstResponder(input)
            await Task.yield()
            NSApp.mainMenu?.items.forEach { $0.submenu?.update() }
            board.clearContents(); board.setString("https://example.test/v1", forType: .string)
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "v", charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9)!
            let handled = NSApp.mainMenu?.performKeyEquivalent(with: event) ?? false
            input.validateEditing()
            print("CLIPBOARD CHECK: secure=\(secure), keyWindow=\(window.isKeyWindow), active=\(NSApp.isActive), responder=\(String(describing: window.firstResponder.map { type(of: $0) })), handled=\(handled), matched=\(input.stringValue == "https://example.test/v1")")
            if !handled || input.stringValue != "https://example.test/v1" { failures.append(secure ? "secure field Command-V" : "text field Command-V") }
            if !secure {
                let select = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0)!
                _ = NSApp.mainMenu?.performKeyEquivalent(with: select)
                if (window.firstResponder as? NSTextView)?.selectedRange().length != 23 { failures.append("Command-A selection") }
            }
        }
        let chat = NSTextView(frame: .init(x: 20, y: 10, width: 350, height: 120))
        chat.isRichText = false
        window.contentView?.addSubview(chat)
        window.makeFirstResponder(chat)
        await Task.yield()
        NSApp.mainMenu?.items.forEach { $0.submenu?.update() }
        let paste = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "v", charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9)!
        if NSApp.mainMenu?.performKeyEquivalent(with: paste) != true || chat.string != "https://example.test/v1" { failures.append("multiline chat Command-V") }
        window.orderOut(nil)
        if failures.isEmpty { print("CLIPBOARD PASS: Command-V in text, secure and multiline chat fields; Command-A") }
        else { print("CLIPBOARD FAIL: \(failures.joined(separator: ", "))") }
        // Restore the clipboard before exiting (defer must execute).
        DispatchQueue.main.async { exit(failures.isEmpty ? 0 : 1) }
    }
}
