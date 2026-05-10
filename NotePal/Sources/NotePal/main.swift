import AppKit

let app = NSApplication.shared
let delegate = NotePalAppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
