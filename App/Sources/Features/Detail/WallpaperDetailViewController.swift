import AVFoundation
import UIKit
import CoreImage
import SnapKit

// MARK: - Detail view controller
/// Handles both static image wallpapers (from Pexels Photos) and video
/// wallpapers (from Pexels Videos). Video wallpapers can be:
/// - Saved as Live Photos (Version A build)
/// - Applied directly to the lock screen via PosterBoard symlink trick (Version B build)
final class WallpaperDetailViewController: UIViewController {

    // MARK: - UI elements
    private var displayedImage: UIImageView!
    private var playerLayer: AVPlayerLayer?
    private var iconsOverlay: UIImageView!
    private var blurSlider: UISlider!
    private var iconsButton: UIButton!
    private var filterStrip: UIScrollView!
    private var filterButtons: [UIButton] = []
    private var paletteView: PaletteSwatchesView!
    private var saveButton: UIBarButtonItem!
    private var closeButton: UIBarButtonItem!
    private var favoriteButton: UIBarButtonItem!
    private var applyButton: UIBarButtonItem!
    private var livePhotoButton: UIBarButtonItem!
    private var shareButton: UIBarButtonItem!
    private var playButton: UIBarButtonItem!
    private var attributionView: UITextView!
    private var videoProgressView: UIProgressView!
    private var videoStatusLabel: UILabel!

    // MARK: - State
    private var model: WallpaperDetailModel!
    private var currentFilterIndex = 0
    private var ciImage: CIImage?
    private var cachedBlurMode: BlurMode = .off
    private let filterEngine = FilterEngine()
    private lazy var ciContext: CIContext = {
        CIContext(options: [.cacheIntermediates: false,
                            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
    }()
    private var videoPlayer: AVPlayer?
    private var isVideo: Bool { model.isVideo }

    // MARK: - Init
    static func create(model: WallpaperDetailModel) -> WallpaperDetailViewController {
        let vc = WallpaperDetailViewController()
        vc.model = model
        return vc
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupNavigation()
        setupUI()
        setupConstraints()
        setupContent()
        observeModel()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoPlayer?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        videoPlayer = nil
    }

    // MARK: - Navigation
    private func setupNavigation() {
        closeButton = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeTapped))
        closeButton.accessibilityLabel = "Close wallpaper detail"

        shareButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(shareTapped))
        shareButton.accessibilityLabel = "Share wallpaper"

        saveButton = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
        saveButton.accessibilityLabel = "Save wallpaper to Photos"

        favoriteButton = UIBarButtonItem(image: UIImage(systemName: "heart"), style: .plain, target: self, action: #selector(favoriteTapped))
        favoriteButton.accessibilityLabel = "Add wallpaper to favorites"

        var rightItems: [UIBarButtonItem] = [shareButton, favoriteButton, saveButton]
        if isVideo {
            // Add live photo save
            livePhotoButton = UIBarButtonItem(title: "Live", style: .plain, target: self, action: #selector(saveLivePhotoTapped))
            livePhotoButton.accessibilityLabel = "Save as Live Photo"
            rightItems.insert(livePhotoButton, at: rightItems.count - 1)

            // Add play/pause toggle
            playButton = UIBarButtonItem(image: UIImage(systemName: "play.circle"), style: .plain, target: self, action: #selector(toggleVideoPlayback))
            playButton.accessibilityLabel = "Play / pause video preview"
            rightItems.insert(playButton, at: 0)

            // Version B: PosterBoard apply button (sideloaded only)
            #if POSTERBOARD
            applyButton = UIBarButtonItem(image: UIImage(systemName: "checkmark.circle.fill"), style: .plain, target: self, action: #selector(applyPosterBoardTapped))
            applyButton.accessibilityLabel = "Set as live lock-screen wallpaper"
            rightItems.insert(applyButton, at: rightItems.count - 1)
            #endif
        } else {
            applyButton = UIBarButtonItem(image: UIImage(systemName: "checkmark.circle"), style: .plain, target: self, action: #selector(saveTapped))
            applyButton.accessibilityLabel = "Save wallpaper"
            rightItems.insert(applyButton, at: 0)
        }

        rightItems.forEach { $0.tintColor = .white }
        navigationItem.leftBarButtonItem = closeButton
        navigationItem.rightBarButtonItems = rightItems
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Main image / video view
        displayedImage = UIImageView()
        displayedImage.contentMode = .scaleAspectFill
        displayedImage.isUserInteractionEnabled = true
        view.addSubview(displayedImage)

        // Icon overlay (springboard mock)
        iconsOverlay = UIImageView()
        iconsOverlay.contentMode = .scaleAspectFill
        iconsOverlay.isUserInteractionEnabled = false
        iconsOverlay.alpha = 0
        view.addSubview(iconsOverlay)

        // Blur slider
        blurSlider = UISlider()
        blurSlider.value = 0
        blurSlider.minimumTrackTintColor = .white
        blurSlider.maximumTrackTintColor = .white.withAlphaComponent(0.5)
        blurSlider.thumbTintColor = .white
        blurSlider.accessibilityLabel = "Blur intensity"
        blurSlider.accessibilityHint = "Adjust blur amount on wallpaper"
        blurSlider.addTarget(self, action: #selector(blurChanged(_:)), for: .valueChanged)
        blurSlider.addTarget(self, action: #selector(blurChanged(_:)), for: [.touchUpInside, .touchUpOutside])
        view.addSubview(blurSlider)

        // Icons toggle button
        iconsButton = UIButton()
        iconsButton.backgroundColor = .white
        iconsButton.tintColor = .black
        iconsButton.setImage(UIImage(systemName: "square.grid.2x2"), for: .normal)
        iconsButton.layer.cornerRadius = 25
        iconsButton.accessibilityLabel = "Toggle app icon overlay"
        iconsButton.accessibilityHint = "Shows or hides springboard icons on wallpaper preview"
        iconsButton.addTarget(self, action: #selector(iconsTapped), for: .touchUpInside)
        view.addSubview(iconsButton)

        // Filter strip
        filterStrip = UIScrollView()
        filterStrip.showsHorizontalScrollIndicator = false
        filterStrip.backgroundColor = .clear
        view.addSubview(filterStrip)

        // Palette swatches
        paletteView = PaletteSwatchesView()
        paletteView.backgroundColor = UIColor.black.withAlphaComponent(0.5).withAlphaComponent(0.7)
        paletteView.layer.cornerRadius = 12
        view.addSubview(paletteView)

        // Video progress bar (only shown for video wallpapers)
        if isVideo {
            videoProgressView = UIProgressView(progressViewStyle: .bar)
            videoProgressView.progressTintColor = .white
            videoProgressView.trackTintColor = .white.withAlphaComponent(0.3)
            videoProgressView.progress = 0
            videoProgressView.alpha = 0.7
            view.addSubview(videoProgressView)

            videoStatusLabel = UILabel()
            videoStatusLabel.font = .systemFont(ofSize: 12, weight: .medium)
            videoStatusLabel.textColor = .white
            videoStatusLabel.textAlignment = .center
            videoStatusLabel.text = "Tap Live to save as Live Photo"
            view.addSubview(videoStatusLabel)
        }

        // Tap gesture to hide/show controls
        let tap = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        tap.numberOfTapsRequired = 1
        displayedImage.addGestureRecognizer(tap)

        // Attribution
        attributionView = UITextView()
        attributionView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        attributionView.textColor = .white
        attributionView.isEditable = false
        attributionView.isScrollEnabled = false
        attributionView.textAlignment = .center
        attributionView.font = .systemFont(ofSize: 11, weight: .regular)
        attributionView.alpha = 0
        view.addSubview(attributionView)
    }

    private func setupConstraints() {
        displayedImage.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconsOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconsButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.width.height.equalTo(50)
        }

        blurSlider.snp.makeConstraints { make in
            make.leading.equalTo(view).offset(20)
            make.trailing.lessThanOrEqualTo(iconsButton.snp.leading).offset(-16)
            make.centerY.equalTo(iconsButton)
        }

        filterStrip.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(iconsButton.snp.top).offset(-32)
            make.height.equalTo(44)
        }

        paletteView.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.bottom.equalTo(iconsButton.snp.top).offset(-8)
            make.height.equalTo(44)
            make.width.lessThanOrEqualTo(140)
        }

        if isVideo {
            videoProgressView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
                make.height.equalTo(2)
            }

            videoStatusLabel.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.bottom.equalTo(videoProgressView.snp.top).offset(-4)
                make.height.equalTo(16)
            }
        }

        attributionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.height.greaterThanOrEqualTo(24)
        }
    }

    // MARK: - Content
    private func setupContent() {
        iconsOverlay.image = UIDevice.current.iconsImage
        loadImage()
        loadVideoPreview()
        refreshCachedBlurMode()
        buildFilterStrip()
        updatePalette(nil)
    }

    private func loadVideoPreview() {
        guard isVideo, let file = model.bestVideoFile else { return }
        let url = file.link
        let player = AVPlayer(url: url)
        videoPlayer = player
        let layer = AVPlayerLayer(player: player)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, below: displayedImage.layer)
        playerLayer = layer
        // Hide the static image so the video plays on top
        displayedImage.isHidden = true
        player.play()

        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            player.seek(to: .zero)
            player.play()
        }

        updatePlayButtonIcon(isPlaying: true)
    }

    private func updatePlayButtonIcon(isPlaying: Bool) {
        guard let playBtn = playButton else { return }
        let name = isPlaying ? "pause.circle" : "play.circle"
        playBtn.image = UIImage(systemName: name)
    }

    @objc private func toggleVideoPlayback() {
        guard let player = videoPlayer else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            updatePlayButtonIcon(isPlaying: false)
        } else {
            player.play()
            updatePlayButtonIcon(isPlaying: true)
        }
    }

    private func refreshCachedBlurMode() {
        Task { @MainActor in
            self.cachedBlurMode = await self.model.blurMode
        }
    }

    private func loadImage() {
        Task {
            do {
                let uiImage = try await model.loadFullImage()
                await MainActor.run {
                    displayedImage.image = uiImage
                    if let ci = CIImage(image: uiImage) {
                        self.ciImage = ci
                        applyCurrentFilter()
                    }
                }
            } catch {
                await MainActor.run {
                    let label = UILabel()
                    label.text = "Failed to load image"
                    label.textColor = .white
                    label.textAlignment = .center
                    view.addSubview(label)
                    label.snp.makeConstraints { make in
                        make.center.equalToSuperview()
                    }
                }
            }
        }
    }

    private func buildFilterStrip() {
        let filters = FilterEngine.makeFilters()
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        filterStrip.addSubview(stack)

        for (index, filter) in filters.enumerated() {
            let btn = UIButton()
            btn.setTitle(filter.name, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
            btn.setTitleColor(.white, for: .normal)
            btn.setTitleColor(.white.withAlphaComponent(0.5), for: .highlighted)
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            btn.layer.cornerRadius = 14
            btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
            btn.tag = index
            btn.accessibilityLabel = "\(filter.name) filter"
            btn.accessibilityHint = "Tap to apply \(filter.name) filter to wallpaper"
            btn.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            btn.snp.makeConstraints { make in
                make.height.equalTo(28)
            }
            stack.addArrangedSubview(btn)
            filterButtons.append(btn)
        }

        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            make.height.equalToSuperview()
        }

        // Highlight first
        updateFilterHighlight()
    }

    private func updateFilterHighlight() {
        for (idx, btn) in filterButtons.enumerated() {
            btn.backgroundColor = idx == currentFilterIndex ? UIColor.white : UIColor.white.withAlphaComponent(0.15)
            btn.setTitleColor(idx == currentFilterIndex ? .black : .white, for: .normal)
        }
    }

    @objc private func filterTapped(_ sender: UIButton) {
        currentFilterIndex = sender.tag
        updateFilterHighlight()
        applyCurrentFilter()
    }

    // MARK: - Model observation
    private var favoriteUpdateTask: Task<Void, Never>?

    private func observeModel() {
        favoriteUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    self?.updateFavoriteButton()
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    deinit {
        favoriteUpdateTask?.cancel()
        videoPlayer?.pause()
    }

    private func updateFavoriteButton() {
        let isFav = model.isFavorited
        favoriteButton.image = UIImage(systemName: isFav ? "heart.fill" : "heart")
        favoriteButton.tintColor = isFav ? .systemRed : .white
    }

    // MARK: - Actions
    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Save static image
    @objc private func saveTapped() {
        guard !isVideo, let ciImage = ciImage else { return }
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        UIImageWriteToSavedPhotosAlbum(
            UIImage(cgImage: cgImage, scale: UIScreen.mainScreenScale, orientation: .up),
            self,
            #selector(savedImage(_:error:contextInfo:)),
            nil
        )
    }

    @objc private func savedImage(_ image: UIImage?, error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showToast(message: error.localizedDescription)
            return
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        showToast(message: "Saved to Photos")
    }

    // MARK: - Save as Live Photo (Version A)
    @objc private func saveLivePhotoTapped() {
        guard isVideo, let file = model.bestVideoFile else { return }
        guard let url = file.link as URL? else {
            showToast(message: "Invalid video URL")
            return
        }

        videoStatusLabel.text = "Downloading video…"
        videoProgressView.progress = 0
        livePhotoButton.isEnabled = false

        Task { [weak self] in
            do {
                // Download the video
                let localURL = try await VideoDownloader.shared.download(file) { progress in
                    Task { @MainActor in
                        self?.videoProgressView.progress = Float(progress)
                    }
                }

                self?.videoStatusLabel.text = "Converting to Live Photo…"

                // Convert and save
                try await LivePhotoConverter.shared.convertToLivePhoto(videoURL: localURL)

                await MainActor.run {
                    self?.videoStatusLabel.text = "Live Photo saved!"
                    self?.showToast(message: "Live Photo saved to Photos")
                    self?.videoProgressView.progress = 1.0
                    self?.livePhotoButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    self?.videoStatusLabel.text = "Failed: \(error.localizedDescription)"
                    self?.showToast(message: "Live Photo error: \(error.localizedDescription)")
                    self?.livePhotoButton.isEnabled = true
                }
            }
        }
    }

    // MARK: - Apply via PosterBoard (Version B)
    #if POSTERBOARD
    @objc private func applyPosterBoardTapped() {
        guard isVideo, let file = model.bestVideoFile, let url = file.link as URL? else { return }

        applyButton.isEnabled = false
        videoStatusLabel.text = "Preparing wallpaper…"
        videoProgressView.progress = 0

        Task { [weak self] in
            do {
                // Download the video
                let localURL = try await VideoDownloader.shared.download(file) { progress in
                    Task { @MainActor in
                        self?.videoProgressView.progress = Float(progress)
                    }
                }

                self?.videoStatusLabel.text = "Generating frames…"

                try await PosterBoardApplyService.shared.applyVideoWallpaper(videoURL: localURL) { frame, total in
                    Task { @MainActor in
                        self?.videoProgressView.progress = Double(frame) / Double(max(total, 1))
                        self?.videoStatusLabel.text = "Frame \(frame)/\(total)"
                    }
                }

                await MainActor.run {
                    self?.videoStatusLabel.text = "Wallpaper applied! Check your lock screen."
                    self?.showToast(message: "Opening PosterBoard…")
                    self?.applyButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    let msg = error.localizedDescription
                    self?.videoStatusLabel.text = "Error: \(msg)"
                    self?.showToast(message: msg)
                    self?.applyButton.isEnabled = true
                }
            }
        }
    }
    #endif

    @objc private func favoriteTapped() {
        model.toggleFavorite()
        updateFavoriteButton()
    }

    @objc private func shareTapped() {
        // Render the final filtered image
        guard let ciImage = ciImage else { return }
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let baseImage = UIImage(cgImage: cgImage, scale: UIScreen.mainScreenScale, orientation: .up)

        // If icon overlay is visible, composite it on top
        let finalImage: UIImage
        if iconsOverlay.alpha > 0, let iconsImage = iconsOverlay.image {
            finalImage = compositeIconsOnImage(baseImage, icons: iconsImage)
        } else {
            finalImage = baseImage
        }

        // Present share sheet
        let activityVC = UIActivityViewController(activityItems: [finalImage], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = shareButton
        present(activityVC, animated: true)
    }

    private func compositeIconsOnImage(_ base: UIImage, icons: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: base.size)
        return renderer.image { context in
            base.draw(in: CGRect(origin: .zero, size: base.size))
            icons.draw(in: CGRect(origin: .zero, size: base.size), blendMode: .normal, alpha: 0.85)
        }
    }

    @objc private func iconsTapped() {
        let shown = iconsOverlay.alpha > 0
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseInOut) {
            self.iconsOverlay.alpha = shown ? 0 : 1
            self.iconsButton.alpha = shown ? 0 : 1
        }
    }

    @objc private func screenTapped() {
        hideControls(hide: !(navigationItem.rightBarButtonItems?.isEmpty ?? true) &&
                         blurSlider.alpha > 0 &&
                         iconsButton.alpha > 0)
    }

    private func hideControls(hide: Bool) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.blurSlider.alpha = hide ? 0 : 1
            self.iconsButton.alpha = hide ? 0 : 1
            self.filterStrip.alpha = hide ? 0 : 1
            self.paletteView.alpha = hide ? 0 : 1
            if let vp = self.videoProgressView { vp.alpha = hide ? 0 : 0.7 }
            if let vs = self.videoStatusLabel { vs.alpha = hide ? 0 : 1 }
            self.attributionView.alpha = hide ? 0 : 1
            self.navigationItem.rightBarButtonItems?.forEach {
                $0.isEnabled = !hide
            }
            self.navigationController?.setNavigationBarHidden(hide, animated: true)
        }
    }

    @objc private func blurChanged(_ slider: UISlider) {
        applyCurrentFilter()
        if let ci = ciImage {
            Task { await updatePaletteFromImage(ci) }
        }
    }

    private func updatePaletteFromImage(_ ciImage: CIImage) async {
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage, scale: UIScreen.mainScreenScale, orientation: .up)
        let colors = await PaletteExtractor().extract(from: uiImage, maximumColorCount: 5)
        await MainActor.run {
            updatePalette(colors)
        }
    }

    private func applyCurrentFilter() {
        guard let ciImage = ciImage else { return }

        // 1. Apply filter first
        let filters = FilterEngine.makeFilters()
        var result = filters[currentFilterIndex].apply(ciImage)

        // 2. Apply blur based on selected mode
        let blurRadius = blurSlider.value * 10.0
        if blurRadius > 0.5 {
            switch cachedBlurMode {
            case .light:
                if let gaussian = CIFilter(name: "CIGaussianBlur", parameters: [
                    kCIInputImageKey: result, kCIInputRadiusKey: blurRadius
                ]) {
                    result = gaussian.outputImage?.cropped(to: result.extent) ?? result
                }
            case .dark:
                if let dark = CIFilter(name: "CIColorControls", parameters: [
                    kCIInputImageKey: result,
                    kCIInputBrightnessKey: -0.05,
                    kCIInputContrastKey: 1.1
                ]) {
                    result = dark.outputImage?.cropped(to: result.extent) ?? result
                }
            case .vibrant:
                if let vibrant = CIFilter(name: "CIExposureAdjust", parameters: [
                    kCIInputImageKey: result, kCIInputEVKey: 0.3
                ]) {
                    result = vibrant.outputImage?.cropped(to: result.extent) ?? result
                }
            case .tinted:
                if let tint = CIFilter(name: "CIColorMonochrome", parameters: [
                    kCIInputImageKey: result,
                    kCIInputColorKey: CIColor(red: 0.9, green: 0.9, blue: 0.95),
                    kCIInputIntensityKey: 0.25
                ]) {
                    result = tint.outputImage?.cropped(to: result.extent) ?? result
                }
            case .off:
                break
            }
        }

        // 3. Render to UIImage
        let outputCIImage = result.extent.width > 0 ? result : ciImage
        guard let cgImage = ciContext.createCGImage(outputCIImage, from: outputCIImage.extent) else { return }

        let uiImage = UIImage(cgImage: cgImage, scale: UIScreen.mainScreenScale, orientation: .up)

        // Only update the static image view; don't touch the video player layer
        displayedImage.image = uiImage
        displayedImage.isHidden = false

        // Update icons overlay tint to match
        updateIconsTintSync(for: uiImage)
    }

    private func updateIconsTintSync(for image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        let width = min(cgImage.width, 1)
        let height = min(cgImage.height, 1)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawPtr: UnsafeMutableRawPointer?
        rawPtr = malloc(4)
        guard let ptr = rawPtr else { return }
        defer { free(ptr) }
        if let ctx = CGContext(data: ptr, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        }
        let data = ptr.assumingMemoryBound(to: UInt8.self)
        let r = CGFloat(data[0]) / 255.0
        let g = CGFloat(data[1]) / 255.0
        let b = CGFloat(data[2]) / 255.0
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        let tint = UIColor(red: r, green: g, blue: b, alpha: 1.0)
        let textColor: UIColor = luminance > 0.5 ? .black : .white
        iconsButton.backgroundColor = tint
        iconsButton.tintColor = textColor
        iconsButton.alpha = iconsOverlay.alpha
    }

    private func updateIconsTint(for image: UIImage) async {
        guard let cgImage = image.cgImage else { return }
        let colors = await PaletteExtractor().extract(from: image, maximumColorCount: 1)
        let tint: UIColor = colors.first?.color ?? .white
        let textColor: UIColor = tint.luminance() > 0.5 ? .black : .white
        iconsButton.backgroundColor = tint
        iconsButton.tintColor = textColor
        iconsButton.alpha = iconsOverlay.alpha
    }

    private func updatePalette(_ colors: [PaletteColor]?) {
        let extracted = colors ?? []
        paletteView.colors = extracted
        paletteView.isHidden = extracted.isEmpty
    }

    // MARK: - Toast
    private func showToast(message: String) {
        let toast = UILabel()
        toast.text = message
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toast.textAlignment = .center
        toast.font = .systemFont(ofSize: 13, weight: .medium)
        toast.alpha = 0
        toast.layer.cornerRadius = 12
        toast.clipsToBounds = true
        view.addSubview(toast)

        let padding: CGFloat = 20
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(isVideo ? -60 : -16)
            make.leading.greaterThanOrEqualTo(view.snp.leading).offset(padding)
            make.trailing.lessThanOrEqualTo(view.snp.trailing).offset(-padding)
            make.height.greaterThanOrEqualTo(32)
        }

        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2, options: .curveEaseOut, animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
}

// MARK: - UIView corner radius helper
extension UIView {
    var cornerRadius: CGFloat {
        get { layer.cornerRadius }
        set { layer.cornerRadius = newValue }
    }
}

// MARK: - UIColor luminance helper
extension UIColor {
    func luminance() -> CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.299 * red + 0.587 * green + 0.114 * blue
    }
}

// MARK: - Palette swatches view
final class PaletteSwatchesView: UIView {
    var colors: [PaletteColor] = [] {
        didSet { setNeedsLayout() }
    }

    private var swatchViews: [UIView] = []

    override func layoutSubviews() {
        super.layoutSubviews()
        removeAllArranged()
        guard !colors.isEmpty else { return }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }

        // Show up to 5 swatches
        let shown = Array(colors.prefix(5))
        for pc in shown {
            let swatch = UIView()
            swatch.backgroundColor = pc.color
            swatch.layer.cornerRadius = 14
            swatch.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            swatch.layer.borderWidth = 1
            swatch.snp.makeConstraints { make in
                make.width.height.equalTo(28)
            }
            stack.addArrangedSubview(swatch)
            swatchViews.append(swatch)
        }
    }

    private func removeAllArranged() {
        swatchViews.forEach { $0.removeFromSuperview() }
        swatchViews.removeAll()
        subviews.forEach { $0.removeFromSuperview() }
    }
}

// MARK: - Device icons image
extension UIDevice {
    var type: DeviceType { .iPhone }
    var iconsImage: UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 390, height: 844), format: .preferred())
        return renderer.image { ctx in
            let ctxSize = ctx.format.bounds.size
            UIColor.black.setFill()
            UIRectFill(ctx.format.bounds)

            let icons = ["clock", "camera", "photos", "settings", "messages",
                         "music", "mail", "safari", "maps", "calendar",
                         "notes", "weather", "appstore", "phone", "faceid"]
            let cols = 4
            let iconSize: CGFloat = 44
            let padding: CGFloat = 8
            let totalWidth = CGFloat(cols) * iconSize + CGFloat(cols - 1) * padding
            let startX = (ctxSize.width - totalWidth) / 2
            let startY = ctxSize.height * 0.45
            let iconColor = UIColor(white: 0.9, alpha: 1)

            for (index, name) in icons.enumerated() {
                let col = index % cols
                let row = index / cols
                let x = startX + CGFloat(col) * (iconSize + padding)
                let y = startY + CGFloat(row) * (iconSize + padding)

                let iconRect = CGRect(x: x, y: y, width: iconSize, height: iconSize)
                if let iconImg = UIImage(systemName: name) {
                    let iconView = UIImageView(image: iconImg)
                    iconView.tintColor = iconColor
                    iconView.contentMode = .scaleAspectFit
                    iconView.frame = iconRect
                    iconView.cornerRadius = 8
                    iconView.drawHierarchy(in: iconRect, afterScreenUpdates: true)
                }
            }
        }
    }
}

// MARK: - Device type helper
enum DeviceType {
    case iPhone
    case iPad
    case simulator

    static func current() -> DeviceType {
        #if targetEnvironment(simulator)
        return .simulator
        #else
        let model = UIDevice.current.modelName
        if model.contains("iPad") { return .iPad }
        return .iPhone
        #endif
    }
}

extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(bitPattern: value)))
        }
        return identifier
    }
}
