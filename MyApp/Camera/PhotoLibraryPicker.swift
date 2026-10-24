//
//  PhotoLibraryPicker.swift
//  EmergencyFirst
//
//  A SwiftUI wrapper around PHPickerViewController for choosing an existing
//  photo from the library. PHPicker runs out of process, so it needs NO
//  photo-library permission prompt — the user picks in a system UI and only
//  the chosen image is handed back. This keeps the app simple and privacy
//  friendly.
//
//  Usage: present this (e.g. via .sheet). It calls `onImage` with the picked
//  photo, or `onCancel` if the user dismisses without choosing.
//

import SwiftUI
import PhotosUI

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images      // only photos, no videos
        config.selectionLimit = 1    // one image at a time

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // Nothing to update.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onCancel()
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [onImage, onCancel] object, _ in
                // loadObject's completion runs on a background thread; hop
                // back to the main actor before touching UI state.
                Task { @MainActor in
                    if let image = object as? UIImage {
                        onImage(image)
                    } else {
                        onCancel()
                    }
                }
            }
        }
    }
}
