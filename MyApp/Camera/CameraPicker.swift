//
//  CameraPicker.swift
//  EmergencyFirst
//
//  A thin SwiftUI wrapper around UIKit's UIImagePickerController configured
//  for the camera. SwiftUI has no built-in camera view, so we bridge to
//  UIKit using UIViewControllerRepresentable.
//
//  Usage: present this (e.g. via .fullScreenCover). It calls `onImage` with
//  the captured photo, or `onCancel` if the user backs out.
//
//  NOTE: The camera only works on a real device, not the simulator. It also
//  requires the NSCameraUsageDescription Info.plist key (added as a build
//  setting in the project), otherwise iOS terminates the app on launch of
//  the camera.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Nothing to update; the picker is configured once in make().
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    /// The Coordinator receives UIKit delegate callbacks and forwards them
    /// to the SwiftUI closures.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
