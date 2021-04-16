//
//  File Name:  PPRecentView.swift
//  Product Name:   Pixel Picker
//  Created Date:   2021/4/16 17:10
//

import Cocoa

protocol PPRecentViewDelegate: NSObjectProtocol {
    func recentView(didSelectItemAt view: PPRecentView)
    func recentView(didDeleteItemAt view: PPRecentView)
}

class PPRecentView: NSView {

    fileprivate lazy var textLabel: NSTextField = {
        let label = NSTextField.init()
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.layer?.backgroundColor = .clear
        label.font = NSFont.systemFont(ofSize: 14)
        return label
    }()
    
    fileprivate lazy var imageView: NSImageView = {
        let view = NSImageView.init()
        return view
    }()
    
    fileprivate lazy var deleteButton: NSButton = {
        let btn = NSButton.init()
        btn.image = NSImage.init(named: "delete")
        btn.isBordered = false
        btn.bezelStyle = .recessed
        btn.target = self
        btn.action = #selector(deleteRecentColor)
        return btn
    }()
    
    fileprivate(set) var pickedColor: PPPickedColor!
    
    var delegate: PPRecentViewDelegate?
    
    init(frame frameRect: NSRect, color: PPPickedColor) {
        super.init(frame: frameRect)
        addSubview(textLabel)
        addSubview(imageView)
        addSubview(deleteButton)
        autoresizingMask = .width
        wantsLayer = true
        pickedColor = color
        let format = PPState.shared.chosenFormat
        textLabel.stringValue = format.asString(withColor: pickedColor.color)
        imageView.image = circleImage(withSize: 12, color: pickedColor.color)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        imageView.frame = CGRect.init(x: 20, y: 2.5, width: 15, height: 15)
        deleteButton.frame = CGRect.init(x: frame.width - 35, y: 2.5, width: 15, height: 15)
        textLabel.frame = CGRect.init(x: 40, y: 0, width: frame.width - 80, height: frame.height)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        delegate?.recentView(didSelectItemAt: self)
    }
    
    @objc private func deleteRecentColor() {
        delegate?.recentView(didDeleteItemAt: self)
    }
    
    // Simply creates a circle NSImage with the given size and color.
    private func circleImage(withSize size: CGFloat, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        color.set()
        NSBezierPath(roundedRect: NSMakeRect(0, 0, size, size), xRadius: size, yRadius: size).fill()
        image.unlockFocus()
        return image
    }
}
