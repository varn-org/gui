import UIKit
import AVFoundation

/// What the camera sees, with what it captures written where the tree can show it.
///
/// The session runs only while the view is in a window, so leaving a screen puts the camera down rather
/// than leaving the indicator on over a screen nobody is looking at. Everything the session is told is
/// told on a queue of its own, since configuring one blocks the caller for as long as the hardware takes.
///
/// A look is drawn over the preview and written into a photograph, which is what makes what a reader sees
/// before they capture the picture they get. A film is recorded as the camera sees it, since a platform
/// writes frames straight from the hardware and rewriting each one is a different feature.
final class VarnCameraView: UIView, VarnReleasing {
    /// Told what the camera produced, which is a file the tree can show and what it turned out to be.
    var onEvent: ((String, [String: Any]) -> Void)?

    var facing: String = "back" {
        didSet {
            guard facing != oldValue else {
                return
            }

            frames.async { [weak self, facing] in self?.turned = facing }
            reopen()
        }
    }

    var zoom: CGFloat = 1 {
        didSet { settle() }
    }

    var torch = false {
        didSet { settle() }
    }

    var wantsAudio = false {
        didSet {
            guard wantsAudio != oldValue else {
                return
            }

            reopen()
        }
    }

    var filter: [Double]? {
        didSet {
            frames.async { [weak self] in self?.looked = self?.filter }
            showFilter()
        }
    }

    /// What the frames queue draws through, since the one above it is written from the main thread.
    ///
    /// A sample buffer arrives on a queue of its own and the tree writes the look and which way the
    /// camera is turned on the main one, so reading those from the buffer is two threads on one value.
    private var looked: [Double]?
    private var turned = "back"

    /// Whether a frame is already on its way to the main thread, so the next one is dropped rather
    /// than queued behind it. A camera produces frames faster than a screen can take them, and one
    /// block per frame is a backlog the main thread has to drain before it can do anything else —
    /// which is what leaving the screen had to wait for.
    private var drawing = false

    private let session = AVCaptureSession()
    private let work = DispatchQueue(label: "dev.varn.gui.camera")
    private let frames = DispatchQueue(label: "dev.varn.gui.camera.frames")

    private let photos = AVCapturePhotoOutput()
    private let films = AVCaptureMovieFileOutput()
    private let pictures = AVCaptureVideoDataOutput()

    private let preview = AVCaptureVideoPreviewLayer()

    /// What the filtered frames are drawn into, which stands over the preview while a look is on.
    private let looking = UIImageView()

    private var input: AVCaptureDeviceInput?
    private var opened = false
    private var began: Date?

    private lazy var delegate = VarnCameraDelegate(view: self)

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black
        clipsToBounds = true

        preview.videoGravity = .resizeAspectFill
        layer.addSublayer(preview)

        looking.contentMode = .scaleAspectFill
        looking.isHidden = true
        looking.isUserInteractionEnabled = false
        addSubview(looking)
    }

    required init?(coder: NSCoder) { fatalError("a camera is built by the factory rather than from a nib") }

    deinit {
        letGo()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        preview.frame = bounds
        looking.frame = bounds
    }

    /// Runs the camera only while there is a window to draw it in, which is what puts it down on leaving.
    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            work.async { [session] in
                if session.isRunning {
                    session.stopRunning()
                }
            }

            return
        }

        open()
    }

    func letGo() {
        work.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    /// Asks the reader for what it needs and opens the camera once they have answered.
    private func open() {
        guard !opened else {
            work.async { [session] in
                if !session.isRunning {
                    session.startRunning()
                }
            }

            return
        }

        opened = true

        VarnCameraView.allowed(for: .video) { [weak self] granted in
            guard let self else {
                return
            }

            guard granted else {
                self.onEvent?("onError", ["message": "the camera was refused"])
                return
            }

            guard self.wantsAudio else {
                self.build()
                return
            }

            VarnCameraView.allowed(for: .audio) { [weak self] allowed in
                guard let self else {
                    return
                }

                if !allowed {
                    self.onEvent?("onError", ["message": "the microphone was refused"])
                }

                self.build()
            }
        }
    }

    /// Asks for a device once, answering straight away when the reader has already been asked.
    private static func allowed(for kind: AVMediaType, then answer: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: kind) {
        case .authorized:
            answer(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: kind) { granted in
                DispatchQueue.main.async { answer(granted) }
            }
        default:
            answer(false)
        }
    }

    private func build() {
        work.async { [weak self] in
            guard let self else {
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            self.attachCamera()
            self.attachMicrophone()

            for output in [self.photos, self.films, self.pictures] as [AVCaptureOutput] {
                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                }
            }

            self.pictures.alwaysDiscardsLateVideoFrames = true
            self.session.commitConfiguration()

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.preview.session = self.session
                self.settle()
                self.showFilter()
                self.onEvent?("onReady", ["facing": self.facing])
            }
        }
    }

    /// Takes the camera the tree asked for, replacing whichever one the session already had.
    private func attachCamera() {
        let position: AVCaptureDevice.Position = facing == "front" ? .front : .back

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let taken = try? AVCaptureDeviceInput(device: device) else {
            DispatchQueue.main.async { self.onEvent?("onError", ["message": "there is no camera to open"]) }
            return
        }

        if let input {
            session.removeInput(input)
        }

        guard session.canAddInput(taken) else {
            DispatchQueue.main.async { self.onEvent?("onError", ["message": "the camera could not be opened"]) }
            return
        }

        session.addInput(taken)
        input = taken
    }

    private func attachMicrophone() {
        guard wantsAudio, let device = AVCaptureDevice.default(for: .audio),
              let taken = try? AVCaptureDeviceInput(device: device), session.canAddInput(taken) else {
            return
        }

        session.addInput(taken)
    }

    /// Turns the camera round, which is a new input on a session that is already running.
    private func reopen() {
        guard opened else {
            return
        }

        work.async { [weak self] in
            guard let self else {
                return
            }

            self.session.beginConfiguration()
            self.attachCamera()
            self.attachMicrophone()
            self.session.commitConfiguration()

            DispatchQueue.main.async {
                self.settle()
                self.onEvent?("onReady", ["facing": self.facing])
            }
        }
    }

    /// Applies how far in the camera is and whether its light is on, which the device itself holds.
    private func settle() {
        guard let device = input?.device else {
            return
        }

        work.async {
            guard (try? device.lockForConfiguration()) != nil else {
                return
            }

            device.videoZoomFactor = min(max(1, self.zoom), device.activeFormat.videoMaxZoomFactor)

            if device.hasTorch && device.isTorchAvailable {
                device.torchMode = self.torch ? .on : .off
            }

            device.unlockForConfiguration()
        }
    }

    /// Shows the filtered frames or the plain preview, which is what having a look or not means.
    /// Shows the look over the preview, and asks for frames only while there is one to draw through.
    ///
    /// A camera hands over every frame it takes, so leaving the delegate attached with no look is thirty
    /// buffers a second crossing a queue to be discarded, and a session that has to drain them before it
    /// can stop.
    private func showFilter() {
        let looking = filter != nil

        self.looking.isHidden = !looking
        preview.isHidden = looking

        if !looking {
            self.looking.image = nil
        }

        pictures.setSampleBufferDelegate(looking ? delegate : nil, queue: looking ? frames : nil)
    }

    /// Draws one frame from the camera through the look the tree asked for.
    fileprivate func draw(_ buffer: CMSampleBuffer) {
        guard let matrix = looked, !drawing, let pixels = CMSampleBufferGetImageBuffer(buffer) else {
            return
        }

        let image = CIImage(cvPixelBuffer: pixels)
        let drawn = VarnFilter.filtered(matrix, image)

        guard let made = VarnFilter.rendered(drawn) else {
            return
        }

        let angled = UIImage(cgImage: made, scale: 1, orientation: turned == "front" ? .leftMirrored : .right)

        drawing = true

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            if self.filter != nil {
                self.looking.image = angled
            }

            self.frames.async { [weak self] in self?.drawing = false }
        }
    }

    /// Takes a picture, which arrives as a file once the hardware and the look are both done with it.
    func capturePhoto() {
        guard session.isRunning else {
            onEvent?("onError", ["message": "the camera is not running"])
            return
        }

        photos.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
    }

    func startRecording() {
        guard session.isRunning, !films.isRecording else {
            return
        }

        began = Date()
        films.startRecording(to: VarnCameraView.somewhere(named: "film", ending: "mov"), recordingDelegate: delegate)
    }

    func stopRecording() {
        guard films.isRecording else {
            return
        }

        films.stopRecording()
    }

    /// Answers where a capture is written, which is a file of the application's own that it may replace.
    static func somewhere(named name: String, ending: String) -> URL {
        let folder = FileManager.default.temporaryDirectory
        let file = folder.appendingPathComponent("varn-\(name)-\(UUID().uuidString).\(ending)")

        return file
    }

    fileprivate func took(photo: Data?, problem: Error?) {
        if let problem {
            onEvent?("onError", ["message": problem.localizedDescription])
            return
        }

        guard let photo, let image = UIImage(data: photo) else {
            onEvent?("onError", ["message": "the picture could not be read"])
            return
        }

        // What a reader was looking at is what they took, so the look is written into the file rather
        // than being something that was only ever on the screen.
        let drawn = VarnFilter.apply(filter, to: image) ?? image

        guard let bytes = drawn.jpegData(compressionQuality: 0.9) else {
            onEvent?("onError", ["message": "the picture could not be written"])
            return
        }

        let file = VarnCameraView.somewhere(named: "photo", ending: "jpg")

        do {
            try bytes.write(to: file)
        } catch {
            onEvent?("onError", ["message": error.localizedDescription])
            return
        }

        onEvent?("onCapture", [
            "path": file.path,
            "width": Double(drawn.size.width * drawn.scale),
            "height": Double(drawn.size.height * drawn.scale),
        ])
    }

    fileprivate func recorded(_ file: URL, problem: Error?) {
        if let problem {
            onEvent?("onError", ["message": problem.localizedDescription])
            return
        }

        let seconds = began.map { Date().timeIntervalSince($0) } ?? 0
        began = nil

        onEvent?("onRecord", ["path": file.path, "duration": seconds])
    }
}

/// What the camera calls back on, kept apart from the view so the view holds no delegate conformances.
private final class VarnCameraDelegate: NSObject, AVCapturePhotoCaptureDelegate,
    AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    private weak var view: VarnCameraView?

    init(view: VarnCameraView) {
        self.view = view
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let data = photo.fileDataRepresentation()

        DispatchQueue.main.async { [weak view] in
            view?.took(photo: data, problem: error)
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo file: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { [weak view] in
            view?.recorded(file, problem: error)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        view?.draw(buffer)
    }
}

/// A microphone with nothing to draw, which is what a voice note is made of.
///
/// It is told whether it should be running rather than asked to start, since that is what the tree holds:
/// a state that says recording, and a file that arrives when it stops.
final class VarnRecorderView: UIView, VarnReleasing {
    var onEvent: ((String, [String: Any]) -> Void)?

    var recording = false {
        didSet {
            guard recording != oldValue else {
                return
            }

            if recording {
                start()
                return
            }

            finish()
        }
    }

    private var recorder: AVAudioRecorder?
    private var began: Date?

    func letGo() {
        recorder?.stop()
        recorder = nil
    }

    deinit {
        letGo()
    }

    private func start() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                guard granted else {
                    self.recording = false
                    self.onEvent?("onError", ["message": "the microphone was refused"])
                    return
                }

                self.listen()
            }
        }
    }

    private func listen() {
        let file = VarnCameraView.somewhere(named: "note", ending: "m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
        ]

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let made = try AVAudioRecorder(url: file, settings: settings)
            made.record()

            recorder = made
            began = Date()
            onEvent?("onReady", [:])
        } catch {
            recording = false
            onEvent?("onError", ["message": error.localizedDescription])
        }
    }

    private func finish() {
        guard let recorder else {
            return
        }

        let file = recorder.url
        let seconds = began.map { Date().timeIntervalSince($0) } ?? 0

        recorder.stop()
        self.recorder = nil
        began = nil

        onEvent?("onFinish", ["path": file.path, "duration": seconds])
    }
}
