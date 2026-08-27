import UIKit
import CoreImage
import SnapKit

// MARK: - Detail view controller (port from wallpaper-ios, modern Swift)
final class WallpaperDetailViewController: UIViewController {

    // MARK: - UI elements
    private var displayedImage: UIImageView!
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
    private var shareButton: UIBarButtonItem!
    private var attributionView: UITextView!

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

        applyButton = UIBarButtonItem(image: UIImage(systemName: "checkmark.circle"), style: .plain, target: self, action: #selector(applyTapped))
        applyButton.accessibilityLabel = "Save wallpaper"

        navigationItem.leftBarButtonItem = closeButton
        navigationItem.rightBarButtonItems = [shareButton, applyButton, favoriteButton, saveButton]
        navigationItem.rightBarButtonItems?.forEach { $0.tintColor = .white }
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Main image
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
        refreshCachedBlurMode()
        buildFilterStrip()
        updatePalette(nil)
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
                    // Show error state
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
        // Refresh favorite button when model changes (e.g. toggled from another tab)
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

    @objc private func saveTapped() {
        guard let ciImage = ciImage else { return }
        // removed unused ctx
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
            // toast in production
            return
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    @objc private func favoriteTapped() {
        model.toggleFavorite()
        updateFavoriteButton()
    }

    @objc private func applyTapped() {
        // Save to Photos as the primary "apply" — iOS wallpaper APIs are limited.
        // For iOS 16+, you could use the Intents/Wallpaper intent to set lock screen
        // wallpaper programmatically, but that requires entitlements and user consent.
        // Best approach on public App Store: save to Photos and provide a system
        // Settings deep link / guide. For enterprise/MDM you have more options.
        saveTapped()
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
            // Scale icons image to match base image size
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
        displayedImage.image = uiImage

        // Update icons overlay tint to match
        updateIconsTintSync(for: uiImage)
    }

    private func updateIconsTintSync(for image: UIImage) {
        // Simple luminance-based tint from the center pixel (sync, no palette extraction)
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
        // Extract average color from palette (async, more accurate)
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

// MARK: - Device icons image (port from wallpaper-ios UIDevice+Model)
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

// MARK: - Device type helper (simplified)
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
