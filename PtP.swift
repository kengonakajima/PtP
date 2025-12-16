import AppKit

class ImageDropView: NSView {
    var imageView: NSImageView!
    var label: NSTextField!

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.png, .tiff, .fileURL])

        imageView = NSImageView(frame: bounds)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)

        label = NSTextField(labelWithString: "Paste or Drop\nImage Here")
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 50, width: frame.width, height: 50)
        label.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        return handlePasteboard(pasteboard)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            let pasteboard = NSPasteboard.general
            _ = handlePasteboard(pasteboard)
        } else {
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    func handlePasteboard(_ pasteboard: NSPasteboard) -> Bool {
        var image: NSImage? = nil

        // ファイルURLからの画像
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first,
           let img = NSImage(contentsOf: url) {
            image = img
        }
        // 直接の画像データ
        else if let img = NSImage(pasteboard: pasteboard) {
            image = img
        }

        guard let img = image else { return false }

        saveAndCopyPath(image: img)
        return true
    }

    func saveAndCopyPath(image: NSImage) {
        let fileManager = FileManager.default
        let ptpDir = NSHomeDirectory() + "/.ptp"

        // ディレクトリ作成
        try? fileManager.createDirectory(atPath: ptpDir, withIntermediateDirectories: true)

        // 連番でファイル名を決定
        var index = 1
        var filePath: String
        repeat {
            filePath = "\(ptpDir)/img\(index).png"
            index += 1
        } while fileManager.fileExists(atPath: filePath)

        // PNG として保存
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        do {
            try pngData.write(to: URL(fileURLWithPath: filePath))
        } catch {
            return
        }

        // パスをクリップボードにコピー
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(filePath, forType: .string)

        // 画像を表示
        imageView.image = image
        label.isHidden = true

        // 音を鳴らす
        NSSound(named: "Glass")?.play()

        // 視覚的フィードバック
        if let window = self.window {
            window.title = "PtP - Copied!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                window.title = "PtP"
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var dropView: ImageDropView!
    var clipboardTimer: Timer?
    var lastChangeCount: Int = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // アプリアイコンを設定
        if let resourcePath = Bundle.main.path(forResource: "ptp", ofType: "png"),
           let iconImage = NSImage(contentsOfFile: resourcePath) {
            NSApp.applicationIconImage = iconImage
        }

        // メニューバーを設定
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit PtP", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu

        let windowRect = NSRect(x: 0, y: 0, width: 200, height: 150)
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PtP"
        window.center()

        dropView = ImageDropView(frame: windowRect)
        dropView.wantsLayer = true
        dropView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        window.contentView = dropView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(dropView)

        // 起動時にクリップボードをチェック
        let pasteboard = NSPasteboard.general
        _ = dropView.handlePasteboard(pasteboard)
        lastChangeCount = pasteboard.changeCount
        startClipboardMonitoring()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard dropView != nil else { return }
        // クリップボードをチェック
        let pasteboard = NSPasteboard.general
        _ = dropView.handlePasteboard(pasteboard)
        lastChangeCount = pasteboard.changeCount
        if clipboardTimer == nil {
            startClipboardMonitoring()
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        stopClipboardMonitoring()
    }

    func startClipboardMonitoring() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        RunLoop.main.add(timer, forMode: .common)
        clipboardTimer = timer
    }

    func stopClipboardMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }

    func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            _ = dropView.handlePasteboard(pasteboard)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
