import AppKit

MainActor.assumeIsolated {
    #if LINESHELF_CHECKS
    do { try runLineShelfChecks() } catch { fatalError("Checks failed: \(error)") }
    #else
    UserDefaults.standard.register(defaults: ["keepOnLine": 50])
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
    #endif
}
