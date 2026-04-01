import SwiftUI
import PhotosUI

struct MultiImagePicker: UIViewControllerRepresentable {
    let onImagesSelected: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagesSelected: onImagesSelected)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // unlimited
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagesSelected: ([UIImage]) -> Void

        init(onImagesSelected: @escaping ([UIImage]) -> Void) {
            self.onImagesSelected = onImagesSelected
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            let group = DispatchGroup()
            var images: [(Int, UIImage)] = []

            for (index, result) in results.enumerated() {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        images.append((index, image))
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                let sorted = images.sorted { $0.0 < $1.0 }.map { $0.1 }
                self.onImagesSelected(sorted)
            }
        }
    }
}
