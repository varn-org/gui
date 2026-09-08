import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// The button that opens the chooser the system ships and reports what came back.
///
/// Two different controllers stand behind it. A picture comes from the photo library through
/// `PHPickerViewController`, which needs no permission at all because the reader chooses inside a view
/// the system owns, and anything else comes from the files app through `UIDocumentPickerViewController`.
/// A file chosen there is reached inside a security-scoped resource, which has to be given up again or
/// the process leaks the access for the life of the app.
final class VarnFilePicker: UIButton {
    private var kind = "file"
    private var accept: [String] = []
    private var multiple = false
    private(set) var limit = 8 * 1024 * 1024

    var onPick: (([String: Any]) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(open), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func setKind(_ value: String?) {
        kind = value ?? "file"
    }

    func setAccept(_ value: [String]) {
        accept = value
    }

    func setMultiple(_ value: Bool) {
        multiple = value
    }

    func setMaxBytes(_ value: Int) {
        limit = value
    }

    /// Answers the types the chooser offers, which is everything when the tree named none.
    ///
    /// An entry with a slash in it is a mime type and anything else is an extension, since those are the
    /// two ways a caller writes one and neither is worth a prop of its own.
    private var types: [UTType] {
        let named = accept.compactMap { entry -> UTType? in
            entry.contains("/") ? UTType(mimeType: entry) : UTType(filenameExtension: entry)
        }

        if !named.isEmpty {
            return named
        }

        return kind == "image" ? [.image] : [.item]
    }

    @objc private func open() {
        guard let presenter = window?.rootViewController else {
            return
        }

        if kind == "image" {
            var settings = PHPickerConfiguration()

            settings.filter = .images
            settings.selectionLimit = multiple ? 0 : 1

            let picker = PHPickerViewController(configuration: settings)
            picker.delegate = self
            presenter.present(picker, animated: true)
            return
        }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)

        picker.allowsMultipleSelection = multiple
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    /// Answers one chosen file as the four fields every renderer reports, reading it only within the cap.
    func entry(name: String, type: String, data: @autoclosure () -> Data?) -> [String: Any] {
        guard let bytes = data() else {
            return ["name": name, "size": 0, "type": type, "bytes": NSNull()]
        }

        guard bytes.count <= limit else {
            return ["name": name, "size": bytes.count, "type": type, "bytes": NSNull()]
        }

        return [
            "name": name,
            "size": bytes.count,
            "type": type,
            "bytes": bytes.base64EncodedString(),
        ]
    }

    /// Reports one chosen file, as soon as it has been read.
    ///
    /// Gathering the whole set first put the bytes of every photograph into one message, which is
    /// decoded and written in a single turn of the loop: nothing moved until the last one landed.
    private func report(_ file: [String: Any]) {
        onPick?(file)
    }
}

extension VarnFilePicker: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            let reached = url.startAccessingSecurityScopedResource()

            let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"

            report(entry(name: url.lastPathComponent, type: type, data: try? Data(contentsOf: url)))

            if reached {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

extension VarnFilePicker: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard !results.isEmpty else {
            return
        }

        for (index, result) in results.enumerated() {
            let provider = result.itemProvider

            // The library names a picture only sometimes, and several chosen at once would all arrive
            // called the same thing — which is one file written over and over for anything that keeps
            // them by name. The type is the one the item actually carries rather than a guess.
            let carried = provider.registeredTypeIdentifiers.compactMap(UTType.init).first { $0.conforms(to: .image) }
            let type = carried ?? .jpeg
            let extension_ = type.preferredFilenameExtension ?? "jpg"
            let name = provider.suggestedName.map { "\($0).\(extension_)" } ?? "picture \(index + 1).\(extension_)"

            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { [weak self] data, _ in
                guard let self else {
                    return
                }

                let file = self.entry(
                    name: name,
                    type: type.preferredMIMEType ?? "image/jpeg",
                    data: data
                )

                DispatchQueue.main.async { self.report(file) }
            }
        }
    }
}
