import Photos

/// Puts a file where the system keeps pictures and films, which is what a phone means by kept.
///
/// The library is asked for rather than written to: a reader who has not allowed it is told so, and one
/// who has never been asked is asked once. Adding is the narrow permission of the two, since an
/// application that only keeps what it made has no business reading what was already there.
enum VarnLibrary {
    /// What the photo library holds, which is pictures and films and nothing else.
    private static let pictures = ["png", "jpg", "jpeg", "heic", "gif"]
    private static let films = ["mov", "mp4", "m4v"]

    static func keep(_ file: URL, then answer: @escaping (String?) -> Void) {
        // A sound is neither a picture nor a film, and the library refuses one outright. What a phone
        // has instead is the application's own documents, which the Files application opens.
        guard holds(file) else {
            answer(filed(file))
            return
        }

        allowed { granted in
            guard granted else {
                answer("the photo library was refused")
                return
            }

            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: kind(of: file), fileURL: file, options: nil)
            }, completionHandler: { saved, problem in
                DispatchQueue.main.async {
                    answer(saved ? nil : (problem?.localizedDescription ?? "the file could not be kept"))
                }
            })
        }
    }

    private static func allowed(then answer: @escaping (Bool) -> Void) {
        let level = PHAccessLevel.addOnly

        switch PHPhotoLibrary.authorizationStatus(for: level) {
        case .authorized, .limited:
            answer(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: level) { status in
                DispatchQueue.main.async { answer(status == .authorized || status == .limited) }
            }
        default:
            answer(false)
        }
    }

    /// Answers what the library should file it as, which it reads from nothing but the name.
    private static func kind(of file: URL) -> PHAssetResourceType {
        films.contains(file.pathExtension.lowercased()) ? .video : .photo
    }

    private static func holds(_ file: URL) -> Bool {
        let ending = file.pathExtension.lowercased()

        return pictures.contains(ending) || films.contains(ending)
    }

    /// Keeps what the library will not hold where the reader can open it, answering what went wrong.
    ///
    /// The application's own documents, which the Files application shows because the bundle says it may.
    /// A sound recorded in an application and left in its temporary directory is gone by the next run.
    private static func filed(_ file: URL) -> String? {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)

        guard let documents = folder.first else {
            return "there is nowhere to keep it"
        }

        let kept = documents.appendingPathComponent(file.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: kept.path) {
                try FileManager.default.removeItem(at: kept)
            }

            try FileManager.default.copyItem(at: file, to: kept)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
