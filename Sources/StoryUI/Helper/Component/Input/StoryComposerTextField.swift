//
//  StoryComposerTextField.swift
//  StoryUI
//
//  Reply composer input.
//

import SwiftUI
import UIKit

/// The reply composer's text input.
///
/// Wraps `UITextField` instead of using `TextField` + `@FocusState` on purpose:
/// the story viewer lives inside a paging `TabView` whose pages are rebuilt
/// whenever the story data changes. A SwiftUI focus binding does not survive
/// that rebuild — the field silently loses first responder and the keyboard
/// closes under the user, seconds after the last keystroke. The `UITextField`
/// instance here is kept by the representable across those updates, so first
/// responder and the typed text are only ever given up when this view asks for
/// it (send, explicit dismissal, real navigation).
struct StoryComposerTextField: UIViewRepresentable {

    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()

        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )

        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textColor = .white
        field.tintColor = .white
        field.font = .systemFont(ofSize: 17)
        field.returnKeyType = .send
        field.enablesReturnKeyAutomatically = true
        field.keyboardAppearance = .dark
        field.text = text
        field.attributedPlaceholder = Self.attributedPlaceholder(placeholder)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self

        // Never overwrite what the user is typing with an identical value: that
        // would reset the caret on every re-render.
        if field.text != text {
            field.text = text
        }

        if context.coordinator.placeholder != placeholder {
            context.coordinator.placeholder = placeholder
            field.attributedPlaceholder = Self.attributedPlaceholder(placeholder)
        }

        syncFirstResponder(of: field, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, placeholder: placeholder)
    }

    /// Focus changes are applied on the next runloop turn: calling
    /// `becomeFirstResponder()` inside a SwiftUI update cycle re-enters that
    /// cycle and can be undone by the very layout pass that triggered it.
    private func syncFirstResponder(of field: UITextField, coordinator: Coordinator) {
        DispatchQueue.main.async {
            let shouldFocus = coordinator.parent.isFocused

            guard field.window != nil else { return }

            if shouldFocus, !field.isFirstResponder {
                field.becomeFirstResponder()
            } else if !shouldFocus, field.isFirstResponder {
                field.resignFirstResponder()
            }
        }
    }

    private static func attributedPlaceholder(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                .font: UIFont.systemFont(ofSize: 17)
            ]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: StoryComposerTextField
        var placeholder: String

        init(parent: StoryComposerTextField, placeholder: String) {
            self.parent = parent
            self.placeholder = placeholder
        }

        @objc func textDidChange(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            guard !parent.isFocused else { return }
            parent.isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            guard parent.isFocused else { return }
            parent.isFocused = false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}
