//
//  AppDelegate+Menu.swift
//  Pixel Picker
//

/**
 * This file is responsible for managing PixelPicker's dropdown menu when
 * the user clicks on the status bar item.
 */

import LaunchAtLogin

// The settings available for displaying a grid in the picker's preview.
enum GridSetting {
    case never, always, inFocusMode
    static let withNames: [(String, GridSetting)] = [
        ("仅对焦模式", .inFocusMode),
        ("总是", .always),
        ("永不", .never)
    ]
}

// The modifiers available to use to toggle "focusMode".
let focusModifiers: [(String, NSEvent.ModifierFlags)] = [
    ("fn Function", .function),
    ("⌘ Command", .command),
    ("⌃ Control", .control),
    ("⌥ Option", .option),
    ("⇧ Shift ", .shift)
]

// The available status item images that the user may pick from.
let statusItemImages: [(String, String)] =  [
    ("彩虹马", "icon-default"),
    ("调色板", "icon-palette"),
    ("吸管", "icon-dropper"),
    ("放大镜吸管", "icon-mag-dropper"),
    ("放大镜吸管2", "icon-mag-dropper-flat")
]

extension AppDelegate: NSMenuDelegate {
    // Unregister the activating shortcut when the menu is opened/closed so it can't be called when
    // setting a new shortcut. Also start a run loop observer so we know when the modifierFlags have
    // changed (used to dynamically update the menu).
    func menuWillOpen(_ menu: NSMenu) {
        unregisterActivatingShortcut()
        if runLoopObserver == nil {
            let activites = CFRunLoopActivity.beforeWaiting.rawValue
            runLoopObserver = CFRunLoopObserverCreateWithHandler(nil, activites, true, 0, { [unowned self] (_, _) in
                self.updateMenuItems()
            })
            CFRunLoopAddObserver(CFRunLoopGetCurrent(), runLoopObserver, CFRunLoopMode.commonModes)
        }
    }

    // Re-register the activating shortcut, and remove the run loop observer.
    func menuDidClose(_ menu: NSMenu) {
        registerActivatingShortcut()
        if (runLoopObserver != nil) {
            CFRunLoopObserverInvalidate(runLoopObserver)
            runLoopObserver = nil
        }
        PPState.shared.saveToDisk()
    }

    // Updates the titles of the recently picked colors - if the `option` key is pressed, then
    // the colors will be in the format they were *when* they were picked, otherwise they'll be
    // in the currently chosen format.
    private func updateMenuItems() {
        // Update recent picks list with correct titles.
        let alternate = NSEvent.modifierFlags.contains(.option)
        for item in contextMenu.items {
            if let pickedColor = item.representedObject as? PPPickedColor {
                item.title = alternate
                    ? pickedColor.asString
                    : PPState.shared.chosenFormat.asString(withColor: pickedColor.color)
            }
        }
    }

    // This rebuilds the context menu from scratch. For the sake of simplicity, we re-create the
    // menu from scratch each time. It's not an expensive operation, and is only called when the
    // user opens the menu.
    func rebuildContextMenu() {
        contextMenu.removeAllItems()

        let pickItem = contextMenu.addItem(withTitle: APP_NAME, action: #selector(showPicker), keyEquivalent: "")
        pickItem.image = PPState.shared.statusItemImage(withName: PPState.shared.statusItemImageName)

        buildRecentPicks()

        contextMenu.addItem(.separator())
        buildAppIconMenu()
        buildShowGridMenu()
        buildColorSpaceItem()
        buildColorFormatsMenu()
        buildMagnificationMenu()
        buildFocusModeModifierMenu()
        buildFloatPrecisionSlider()
        buildShortcutMenuItem()
        buildUseUppercaseItem()
        buildLaunchAtLoginItem()
        buildShowWCAGItem()

        contextMenu.addItem(.separator())
        contextMenu.addItem(withTitle: "导出日志", action: #selector(exportLog), keyEquivalent: "")
        contextMenu.addItem(withTitle: "关于", action: #selector(showAboutPanel), keyEquivalent: "")
        contextMenu.addItem(withTitle: "退出 \(APP_NAME)", action: #selector(quitApplication), keyEquivalent: "")
    }

    // Choose the status item icon.
    private func buildAppIconMenu() {
        let submenu = NSMenu()
        for (name, imageName) in statusItemImages {
            let item = submenu.addItem(withTitle: name, action: #selector(selectAppIcon(_:)), keyEquivalent: "")
            item.representedObject = imageName
            item.state = PPState.shared.statusItemImageName == imageName ? .on : .off
            item.image = PPState.shared.statusItemImage(withName: imageName)
        }

        let item = contextMenu.addItem(withTitle: "App图标", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    @objc private func selectAppIcon(_ sender: NSMenuItem) {
        if let imageName = sender.representedObject as? String {
            menuBarItem.image = PPState.shared.statusItemImage(withName: imageName)
            PPState.shared.statusItemImageName = imageName
        }
    }

    // Choose whether to always draw a grid, never draw one, or only draw one when in focus mode.
    private func buildShowGridMenu() {
        let submenu = NSMenu()
        for (title, setting) in GridSetting.withNames {
            let item = submenu.addItem(withTitle: title, action: #selector(selectGridSetting(_:)), keyEquivalent: "")
            item.representedObject = setting
            item.state = PPState.shared.gridSetting == setting ? .on : .off
        }

        let item = contextMenu.addItem(withTitle: "显示网格", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    @objc private func selectGridSetting(_ sender: NSMenuItem) {
        if let setting = sender.representedObject as? GridSetting {
            PPState.shared.gridSetting = setting
        }
    }

    // A menu that allows choosing what color space the picker will use.
    private func buildColorSpaceItem() {
        let submenu = NSMenu()

        let defaultItem = submenu.addItem(withTitle: "默认值(从屏幕上推断)", action: #selector(setColorSpace(_:)), keyEquivalent: "")
        defaultItem.state = PPState.shared.colorSpace == nil ? .on : .off
        submenu.addItem(.separator())
        for (title, name) in PPColor.colorSpaceNames {
            let item = submenu.addItem(withTitle: title, action: #selector(setColorSpace(_:)), keyEquivalent: "")
            item.representedObject = name
            item.state = PPState.shared.colorSpace == name ? .on : .off
        }

        let item = contextMenu.addItem(withTitle: "色彩空间", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    // If the selected color space is nil, then the preview will just infer the color space from
    // the screen the picker is currently on.
    @objc private func setColorSpace(_ sender: NSMenuItem) {
        PPState.shared.colorSpace = sender.representedObject as? String
    }
    
    static let MIN_MAGNIFICATION = 4
    static let MAX_MAGNIFICATION = 24

    // A menu which allows the magnification level of the picker to be adjusted.
    private func buildMagnificationMenu() {
        let submenu = NSMenu()
        for i in stride(from: AppDelegate.MIN_MAGNIFICATION, through: AppDelegate.MAX_MAGNIFICATION, by: 2) {
            let item = submenu.addItem(withTitle: "\(i)x", action: #selector(selectMagnification(_:)), keyEquivalent: "")
            item.representedObject = i
            item.state = PPState.shared.magnificationLevel == i ? .on : .off
        }
        let item = contextMenu.addItem(withTitle: "放大倍率", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    @objc private func selectMagnification(_ sender: NSMenuItem) {
        if let level = sender.representedObject as? Int {
            PPState.shared.magnificationLevel = level
        }
    }

    // Format hex colors to uppercase.
    private func buildUseUppercaseItem() {
        let item = contextMenu.addItem(withTitle: "大写16进制颜色", action: #selector(setUseUppercase(_:)), keyEquivalent: "")
        item.state = PPState.shared.useUppercase ? .on : .off
    }

    @objc private func setUseUppercase(_ sender: NSMenuItem) {
        PPState.shared.useUppercase = sender.state != .on
    }

    // Simple launch app at login menu item.
    private func buildLaunchAtLoginItem() {
        let item = contextMenu.addItem(withTitle: "登录时启动\(APP_NAME)", action: #selector(launchAtLogin(_:)), keyEquivalent: "")
        item.state = LaunchAtLogin.isEnabled ? .on : .off
    }
    
    private func buildShowWCAGItem() {
        let item = contextMenu.addItem(withTitle: "显示WCAG对比度级别", action: #selector(setShowWCAG(_:)), keyEquivalent: "")
        item.state = PPState.shared.showWCAGLevel ? .on : .off
    }
    
    @objc private func setShowWCAG(_ sender: NSMenuItem) {
        PPState.shared.showWCAGLevel = sender.state != .on
    }

    @objc private func launchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
    }

    // Show the user's recent picks in the menu.
    private func buildRecentPicks() {
        if PPState.shared.recentPicks.count > 0 {
            contextMenu.addItem(.separator())
            contextMenu.addItem(withTitle: "历史", action: nil, keyEquivalent: "")
            for pickedColor in PPState.shared.recentPicks.reversed() {
                let item = NSMenuItem.init()
                let view = PPRecentView.init(frame: .init(x: 0, y: 0, width: 100, height: 20), color: pickedColor)
                view.delegate = self
                item.view = view
                contextMenu.addItem(item)
            }
        }
    }

    // Copies the recently picked color (associated with the menu item) to the clipboard.
    // If the `option` key is pressed, then it copies the color in the same format it was
    // when it was picked (otherwise, it copies it in the currently chosen format).
    private func copyRecentPick(_ sender: PPRecentView) {
        if let pickedColor = sender.pickedColor {
            let value = NSEvent.modifierFlags.contains(.option)
                ? pickedColor.asString
                : PPState.shared.chosenFormat.asString(withColor: pickedColor.color)
            copyToPasteboard(stringValue: value)
        }
    }

    // A slider to change the float precision.
    private func buildFloatPrecisionSlider() {
        contextMenu.addItem(withTitle: "浮点精度 (\(PPState.shared.floatPrecision))", action: nil, keyEquivalent: "")

        let value = Double(PPState.shared.floatPrecision)
        let maxValue = Double(PPState.maxFloatPrecision)
        let slider = NSSlider(value: value, minValue: 1, maxValue: maxValue, target: self, action: #selector(sliderUpdate(_:)))
        slider.allowsTickMarkValuesOnly = true
        slider.autoresizingMask = .width
        slider.tickMarkPosition = .above
        slider.numberOfTickMarks = PPState.maxFloatPrecision
        slider.frame = slider.frame.insetBy(dx: 20, dy: 0)

        let item = contextMenu.addItem(withTitle: "Slider", action: nil, keyEquivalent: "")
        item.view = NSView(frame: NSMakeRect(0, 0, 100, 20))
        item.view!.autoresizingMask = .width
        item.view!.addSubview(slider)
    }

    // Called when the slider is updated.
    @objc private func sliderUpdate(_ sender: NSSlider) {
        let newValue = UInt(sender.intValue)

        // Update slider title.
        if let item = contextMenu.item(withTitle: "Float Precision (\(PPState.shared.floatPrecision))") {
            item.title = "Float Precision (\(newValue))"
        }

        // Update state.
        PPState.shared.floatPrecision = newValue

        // Update recent picks list with new precision.
        updateMenuItems()
    }

    // Build a submenu with each case in the PPColor enum.
    private func buildColorFormatsMenu() {
        let submenu = NSMenu()
        for format in PPColor.allCases {
            let formatItem = submenu.addItem(withTitle: format.rawValue, action: #selector(selectFormat(_:)), keyEquivalent: "")
            formatItem.representedObject = format
            if PPState.shared.chosenFormat == format { formatItem.state = .on }
        }

        let item = contextMenu.addItem(withTitle: "色彩格式", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    // Set the selected format as the default.
    @objc private func selectFormat(_ sender: NSMenuItem) {
        if let format = sender.representedObject as? PPColor {
            PPState.shared.chosenFormat = format
        }
    }

    // Builds and adds the focus modifier submenu.
    private func buildFocusModeModifierMenu() {
        let submenu = NSMenu()
        for (name, modifier) in focusModifiers {
            let modifierItem = submenu.addItem(withTitle: name, action: #selector(selectModifier(_:)), keyEquivalent: "")
            modifierItem.representedObject = modifier
            if PPState.shared.focusModeModifier == modifier { modifierItem.state = .on }
        }

        let item = contextMenu.addItem(withTitle: "焦点模式修改器", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    // Set the chosen modifier to toggle "focusMode".
    @objc private func selectModifier(_ sender: NSMenuItem) {
        if let modifier = sender.representedObject as? NSEvent.ModifierFlags {
            PPState.shared.focusModeModifier = modifier
        }
    }

    // Builds and adds the MASShortcutView to be used in the menu.
    // Uses a custom view to handle events correctly (since it's inside a NSMenu).
    private func buildShortcutMenuItem() {
        contextMenu.addItem(withTitle: "快捷键", action: nil, keyEquivalent: "")

        let shortcutView = MASShortcutView()
        shortcutView.style = .flat
        shortcutView.shortcutValue = PPState.shared.activatingShortcut
        shortcutView.shortcutValueChange = { PPState.shared.activatingShortcut = $0?.shortcutValue }

        let item = contextMenu.addItem(withTitle: "Shortcut", action: nil, keyEquivalent: "")
        item.view = PPMenuShortcutView(shortcut: shortcutView)
    }
}

extension AppDelegate: PPRecentViewDelegate {
    func recentView(didSelectItemAt view: PPRecentView) {
        let format = PPState.shared.chosenFormat
        let color = format.asString(withColor: view.pickedColor.color)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(color, forType: .string)
        contextMenu.cancelTracking()
    }
    
    func recentView(didDeleteItemAt view: PPRecentView) {
        guard let index = PPState.shared.recentPicks.firstIndex(where: { return $0.equalTo(view.pickedColor) }) else {
            return
        }
        PPState.shared.recentPicks.remove(at: index)
        contextMenu.cancelTracking()
    }
}
