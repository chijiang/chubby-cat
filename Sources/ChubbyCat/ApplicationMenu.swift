import AppKit

@MainActor enum ApplicationMenu {
    static func install() {
        let main = NSMenu()
        let application = NSMenu(title: "chubby-cat")
        add("About chubby-cat", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), to: application)
        application.addItem(.separator())
        add("Hide chubby-cat", action: #selector(NSApplication.hide(_:)), key: "h", to: application)
        application.addItem(.separator())
        add("Quit chubby-cat", action: #selector(NSApplication.terminate(_:)), key: "q", to: application)
        let appItem = NSMenuItem(); appItem.submenu = application; main.addItem(appItem)

        let edit = NSMenu(title: "Edit")
        add("Undo", action: Selector(("undo:")), key: "z", to: edit)
        let redo = add("Redo", action: Selector(("redo:")), key: "z", to: edit)
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        add("Cut", action: #selector(NSText.cut(_:)), key: "x", to: edit)
        add("Copy", action: #selector(NSText.copy(_:)), key: "c", to: edit)
        add("Paste", action: #selector(NSText.paste(_:)), key: "v", to: edit)
        add("Select All", action: #selector(NSText.selectAll(_:)), key: "a", to: edit)
        let editItem = NSMenuItem(); editItem.submenu = edit; main.addItem(editItem)
        NSApp.mainMenu = main
    }

    @discardableResult private static func add(_ title: String, action: Selector, key: String = "", to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        // nil target lets the active text field/editor handle standard actions.
        item.target = nil
        menu.addItem(item)
        return item
    }
}
