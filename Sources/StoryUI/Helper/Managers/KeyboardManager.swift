//
//  KeyboardManager.swift
//  
//
//  Created by Naqibullah Malikzada on 4.06.2023.
//

import Foundation
import UIKit

final class KeyboardManager: ObservableObject {
    
    @Published private(set) var currentHeight: CGFloat = 0
    @Published private(set) var isKeyboardOpen = false

    private var notificationCenter: NotificationCenter
    
    init(center: NotificationCenter = .default) {
        notificationCenter = center
        notificationCenter.addObserver(
            self, 
            selector: #selector(keyBoardWillShow(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(keyBoardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        //the keyboard can change its height while staying open (predictive bar,
        //emoji switch, hardware keyboard). Without this the manual offset of the
        //message view goes stale and the input ends up behind the keyboard.
        notificationCenter.addObserver(
            self,
            selector: #selector(keyBoardWillChangeFrame(notification:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
    
    func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil, 
            for: nil
        )
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    @objc func keyBoardWillShow(notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            currentHeight = keyboardSize.height - UIApplication.bottomSafeAreaHeight
            isKeyboardOpen = true
        }
    }
    
    @objc func keyBoardWillHide(notification: Notification) {
        isKeyboardOpen = false
        currentHeight = 0
    }

    @objc func keyBoardWillChangeFrame(notification: Notification) {
        guard isKeyboardOpen,
              let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }

        let height = keyboardSize.height - UIApplication.bottomSafeAreaHeight
        //a frame ending off screen means the keyboard is on its way out, that is
        //handled by keyBoardWillHide
        guard height > 0 else { return }
        currentHeight = height
    }
}
