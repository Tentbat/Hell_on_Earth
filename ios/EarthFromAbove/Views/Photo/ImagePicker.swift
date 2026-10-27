import SwiftUI
import UIKit
import Photos

/// Camera or library picker. The pose is sampled by the caller when the image
/// arrives, which is within a second of the shutter for the camera case.
struct ImagePicker: UIViewControllerRepresentable {
    enum Source { case camera, library }
    var source: Source
    var onImage: (UIImage, Date?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = source == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.originalImage] as? UIImage) ?? UIImage()
            // For library photos, the asset's creation date tells us when in the flight it was taken.
            var taken: Date? = nil
            if let asset = info[.phAsset] as? PHAsset { taken = asset.creationDate }
            parent.onImage(image, taken)
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
