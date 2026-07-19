// HydraTypeKeyboard extension (E0-S1 scaffold; E2-S1 wiring is gated on E-SPIKE-1).
//
// This is intentionally minimal: a working keyboard that types, classifies the field
// into HydraCore's ModeEngine, and writes an App Group stamp so the host app can read
// it back (E0-S1 done-when). The actual correction call is stubbed — per E-SPIKE-1,
// whether AFM runs in-process or via the host broker is undecided (task cb4b60c1), so
// we do NOT pretend to correct here. Loud, not silent: mode + field kind are shown.

import UIKit
import HydraCore
import os

final class KeyboardViewController: UIInputViewController {
    private let log = Logger(subsystem: "com.mock1ngbb.hydratype", category: "keyboard")
    private let mode = ModeEngine()
    private var modeLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        writeLoadStamp()
        buildMinimalKeyRow()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        let kind = Self.fieldKind(from: textDocumentProxy)
        mode.resetForNewField(kind: kind)
        modeLabel?.text = "field: \(kind.rawValue)  ·  mode: \(mode.mode.rawValue)"
        log.info("field=\(kind.rawValue, privacy: .public) mode=\(self.mode.mode.rawValue, privacy: .public)")
    }

    /// Map the proxy's native traits into HydraCore's platform-neutral FieldKind.
    static func fieldKind(from proxy: UITextDocumentProxy) -> FieldKind {
        if proxy.keyboardType == .URL || proxy.keyboardType == .webSearch { return .url }
        if proxy.keyboardType == .emailAddress { return .email }
        // Secure fields: iOS usually swaps to the system keyboard (H2), but classify
        // defensively so we never correct a password if we are shown.
        switch proxy.textContentType {
        case UITextContentType.password, UITextContentType.newPassword, UITextContentType.oneTimeCode:
            return .password
        case UITextContentType.URL:
            return .url
        case UITextContentType.emailAddress:
            return .email
        default:
            return .plain
        }
    }

    private func writeLoadStamp() {
        do {
            let v = try AppGroupSmoke.write("keyboard@\(Int(Date().timeIntervalSince1970))")
            log.info("app-group stamp written: \(v, privacy: .public)")
        } catch {
            // LOUD: the extension may lack the App Group entitlement — surface it.
            log.error("app-group stamp FAILED: \(String(describing: error), privacy: .public)")
        }
    }

    private func buildMinimalKeyRow() {
        modeLabel = UILabel()
        modeLabel.font = .systemFont(ofSize: 12)
        modeLabel.textAlignment = .center
        modeLabel.text = "HydraType — mode pending"

        let space = makeKey("space") { [weak self] in self?.textDocumentProxy.insertText(" ") }
        let back = makeKey("⌫") { [weak self] in self?.textDocumentProxy.deleteBackward() }
        let next = makeKey("🌐") { [weak self] in self?.advanceToNextInputMode() }
        let demo = makeKey("hydra") { [weak self] in self?.textDocumentProxy.insertText("hydra") }

        let keys = UIStackView(arrangedSubviews: [next, demo, space, back])
        keys.axis = .horizontal
        keys.distribution = .fillEqually
        keys.spacing = 6

        let root = UIStackView(arrangedSubviews: [modeLabel, keys])
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            keys.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func makeKey(_ title: String, _ action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        return button
    }
}
