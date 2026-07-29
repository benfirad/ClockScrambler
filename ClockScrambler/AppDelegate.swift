import AppKit
import CoreAudio
import Sparkle

@_silgen_name("CGWindowListCreateImage")
private func legacyWindowListCreateImage(
    _ screenBounds: CGRect,
    _ listOption: CGWindowListOption,
    _ windowID: CGWindowID,
    _ imageOption: CGWindowImageOption
) -> CGImage?

private enum OverlayDisplayMode: String, Equatable {
    case writtenClock
    case digitalClock
    case emoji

    var title: String {
        switch self {
        case .writtenClock: "Yazıyla saat"
        case .digitalClock: "Dijital saat"
        case .emoji: "Emoji"
        }
    }

    static let allCases: [OverlayDisplayMode] = [.writtenClock, .digitalClock, .emoji]
}

private enum ClockLanguage: String, Equatable {
    case turkish
    case spanish
    case english

    var title: String {
        switch self {
        case .turkish: "Türkçe"
        case .spanish: "Español"
        case .english: "English"
        }
    }

    static let allCases: [ClockLanguage] = [.turkish, .spanish, .english]
}

private enum MenuBarEdgeAnchor: String, Equatable {
    case free
    case topLeft
    case topRight
}

private enum SystemClockFace: String, Equatable {
    case automatic
    case digital
    case analog

    var title: String {
        switch self {
        case .automatic: "Otomatik algıla"
        case .digital: "Dijital"
        case .analog: "Analog"
        }
    }

    static let allCases: [SystemClockFace] = [.automatic, .digital, .analog]
}

private enum SystemActivity: Equatable {
    case normal
    case microphone
    case screenSharing

    var color: NSColor? {
        switch self {
        case .normal: nil
        case .microphone:
            // Calibrated against the live Apple microphone indicator.
            NSColor(
                srgbRed: 1.0,
                green: 149.0 / 255.0,
                blue: 0,
                alpha: 1
            )
        case .screenSharing:
            // Calibrated against the live Apple screen-sharing indicator.
            NSColor(
                srgbRed: 85.0 / 255.0,
                green: 82.0 / 255.0,
                blue: 205.0 / 255.0,
                alpha: 1
            )
        }
    }
}

private final class OverlaySettings {
    private let defaults = UserDefaults.standard
    var onChange: (() -> Void)?
    var systemActivity: SystemActivity = .normal
    var isFullScreenActive = false
    var sampledMenuBarColor: NSColor?

    var displayMode: OverlayDisplayMode {
        get {
            guard
                let rawValue = defaults.string(forKey: "displayMode"),
                let mode = OverlayDisplayMode(rawValue: rawValue)
            else {
                return .writtenClock
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: "displayMode")
            onChange?()
        }
    }

    var privacyColorsEnabled: Bool {
        get {
            defaults.object(forKey: "privacyColorsEnabled") == nil
                ? true
                : defaults.bool(forKey: "privacyColorsEnabled")
        }
        set {
            defaults.set(newValue, forKey: "privacyColorsEnabled")
            onChange?()
        }
    }

    var screenFrameStyleEnabled: Bool {
        get { defaults.bool(forKey: "screenFrameStyleEnabled") }
        set {
            defaults.set(newValue, forKey: "screenFrameStyleEnabled")
            onChange?()
        }
    }

    var screenFrameStrokeEnabled: Bool {
        get {
            defaults.object(forKey: "screenFrameStrokeEnabled") == nil
                ? true
                : defaults.bool(forKey: "screenFrameStrokeEnabled")
        }
        set {
            defaults.set(newValue, forKey: "screenFrameStrokeEnabled")
            onChange?()
        }
    }

    var clockLanguage: ClockLanguage {
        get {
            guard
                let rawValue = defaults.string(forKey: "clockLanguage"),
                let language = ClockLanguage(rawValue: rawValue)
            else {
                return .turkish
            }
            return language
        }
        set {
            defaults.set(newValue.rawValue, forKey: "clockLanguage")
            onChange?()
        }
    }

    var edgeAnchor: MenuBarEdgeAnchor {
        get {
            guard
                let rawValue = defaults.string(forKey: "edgeAnchor"),
                let anchor = MenuBarEdgeAnchor(rawValue: rawValue)
            else {
                return .free
            }
            return anchor
        }
        set {
            defaults.set(newValue.rawValue, forKey: "edgeAnchor")
            onChange?()
        }
    }

    var systemClockFace: SystemClockFace {
        get {
            guard
                let rawValue = defaults.string(forKey: "systemClockFace"),
                let face = SystemClockFace(rawValue: rawValue)
            else {
                return .automatic
            }
            return face
        }
        set {
            defaults.set(newValue.rawValue, forKey: "systemClockFace")
            onChange?()
        }
    }

    var isClockCoverageAutomatic: Bool {
        defaults.object(forKey: "clockCoverageWidth") == nil
    }

    var clockCoverageWidth: Double {
        get {
            if defaults.object(forKey: "clockCoverageWidth") != nil {
                return defaults.double(forKey: "clockCoverageWidth")
            }
            return automaticClockCoverageWidth
        }
        set {
            defaults.set(newValue, forKey: "clockCoverageWidth")
            onChange?()
        }
    }

    func setClockCoverageAutomatic(_ automatic: Bool) {
        if automatic {
            defaults.removeObject(forKey: "clockCoverageWidth")
        } else if isClockCoverageAutomatic {
            defaults.set(automaticClockCoverageWidth, forKey: "clockCoverageWidth")
        }
        onChange?()
    }

    var emoji: String {
        get { defaults.string(forKey: "emoji") ?? "🙈" }
        set {
            defaults.set(newValue.isEmpty ? "🙈" : newValue, forKey: "emoji")
            onChange?()
        }
    }

    var rotation: Double {
        get { number(forKey: "rotation", fallback: 0) }
        set { defaults.set(newValue, forKey: "rotation"); onChange?() }
    }

    var horizontalPosition: Double {
        get { number(forKey: "horizontalPosition", fallback: 97) }
        set {
            defaults.set(newValue, forKey: "horizontalPosition")
            defaults.set(4, forKey: "positionPreset")
            defaults.set(MenuBarEdgeAnchor.free.rawValue, forKey: "edgeAnchor")
            onChange?()
        }
    }

    var topOffset: Double {
        get { number(forKey: "topOffset", fallback: 8) }
        set {
            defaults.set(newValue, forKey: "topOffset")
            defaults.set(4, forKey: "positionPreset")
            defaults.set(MenuBarEdgeAnchor.free.rawValue, forKey: "edgeAnchor")
            onChange?()
        }
    }

    var positionPreset: Int {
        defaults.object(forKey: "positionPreset") == nil
            ? 0
            : defaults.integer(forKey: "positionPreset")
    }

    var size: Double {
        get {
            switch displayMode {
            case .emoji:
                if defaults.object(forKey: "emojiSize") != nil {
                    return defaults.double(forKey: "emojiSize")
                }
                return number(forKey: "size", fallback: 19)
            case .writtenClock, .digitalClock:
                return number(forKey: "clockSize", fallback: 14)
            }
        }
        set {
            let key = displayMode == .emoji ? "emojiSize" : "clockSize"
            defaults.set(newValue, forKey: key)
            onChange?()
        }
    }

    var backgroundOpacity: Double {
        get { number(forKey: "backgroundOpacity", fallback: 0.92) }
        set { defaults.set(newValue, forKey: "backgroundOpacity"); onChange?() }
    }

    func reset() {
        [
            "emoji",
            "displayMode",
            "privacyColorsEnabled",
            "screenFrameStyleEnabled",
            "screenFrameStrokeEnabled",
            "clockLanguage",
            "edgeAnchor",
            "systemClockFace",
            "clockCoverageWidth",
            "rotation",
            "horizontalPosition",
            "topOffset",
            "positionPreset",
            "horizontalOffset",
            "verticalOffset",
            "emojiSize",
            "clockSize",
            "size",
            "backgroundOpacity"
        ]
            .forEach(defaults.removeObject)
        onChange?()
    }

    func applyPositionPreset(_ preset: Int) {
        defaults.set(preset, forKey: "positionPreset")
        defaults.set(MenuBarEdgeAnchor.free.rawValue, forKey: "edgeAnchor")
        switch preset {
        case 1:
            defaults.set(5, forKey: "horizontalPosition")
            defaults.set(8, forKey: "topOffset")
        case 2:
            defaults.set(50, forKey: "horizontalPosition")
            defaults.set(8, forKey: "topOffset")
        case 3:
            defaults.set(95, forKey: "horizontalPosition")
            defaults.set(8, forKey: "topOffset")
        case 4:
            break
        default:
            defaults.set(97, forKey: "horizontalPosition")
            defaults.set(8, forKey: "topOffset")
        }
        onChange?()
    }

    func applyEdgeAnchor(_ anchor: MenuBarEdgeAnchor) {
        defaults.set(anchor.rawValue, forKey: "edgeAnchor")
        if anchor != .free {
            defaults.set(4, forKey: "positionPreset")
        }
        onChange?()
    }

    private func number(forKey key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }

    private var effectiveSystemClockFace: SystemClockFace {
        switch systemClockFace {
        case .automatic:
            return systemClockPreferenceBool(forKey: "IsAnalog") ? .analog : .digital
        case .digital:
            return .digital
        case .analog:
            return .analog
        }
    }

    private var automaticClockCoverageWidth: Double {
        guard effectiveSystemClockFace == .digital else {
            return 48
        }

        let showsSeconds = systemClockPreferenceBool(forKey: "ShowSeconds")
        let uses24Hour = systemClockPreferenceBool(forKey: "Show24Hour")
        let sample: String

        if uses24Hour {
            sample = showsSeconds ? "00:00:00" : "00:00"
        } else {
            sample = showsSeconds ? "00:00:00 p.m." : "00:00 p.m."
        }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let measuredWidth = (sample as NSString).size(
            withAttributes: [.font: font]
        ).width
        return min(max(86, ceil(measuredWidth) + 24), 180)
    }

    private func systemClockPreferenceBool(forKey key: String) -> Bool {
        guard
            let value = CFPreferencesCopyAppValue(
                key as CFString,
                "com.apple.menuextra.clock" as CFString
            ) as? NSNumber
        else {
            return false
        }
        return value.boolValue
    }

    func displayedText(at date: Date = Date()) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        switch displayMode {
        case .emoji:
            return emoji
        case .digitalClock:
            return String(format: "%02d:%02d", hour, minute)
        case .writtenClock:
            return NaturalClockPhrase.text(
                hour24: hour,
                minute: minute,
                language: clockLanguage
            )
        }
    }

    var font: NSFont {
        switch displayMode {
        case .emoji:
            .systemFont(ofSize: size)
        case .writtenClock, .digitalClock:
            .systemFont(ofSize: size, weight: .semibold)
        }
    }

    var foregroundColor: NSColor {
        if screenFrameStyleEnabled {
            return .white
        }
        if isFullScreenActive || (privacyColorsEnabled && systemActivity != .normal) {
            return .white
        }
        if let sampledMenuBarColor {
            guard
                let rgbColor = sampledMenuBarColor.usingColorSpace(.sRGB)
            else {
                return .labelColor
            }
            let luminance =
                0.2126 * rgbColor.redComponent +
                0.7152 * rgbColor.greenComponent +
                0.0722 * rgbColor.blueComponent
            return luminance < 0.48 ? .white : .black
        }
        return .labelColor
    }

    var solidBackgroundColor: NSColor? {
        if screenFrameStyleEnabled {
            return .black
        }
        if isFullScreenActive {
            return NSColor(
                srgbRed: 0,
                green: 0,
                blue: 0,
                alpha: 1
            )
        }
        if privacyColorsEnabled, let activityColor = systemActivity.color {
            return activityColor
        }
        if let sampledMenuBarColor {
            return edgeAnchor == .free
                ? sampledMenuBarColor.withAlphaComponent(backgroundOpacity)
                : sampledMenuBarColor
        }
        return nil
    }

    var cornerRadius: CGFloat {
        screenFrameStyleEnabled ? 12 : (edgeAnchor == .free ? 6 : 0)
    }
}

private enum NaturalClockPhrase {
    private static let turkishHours = [
        "", "bir", "iki", "üç", "dört", "beş", "altı",
        "yedi", "sekiz", "dokuz", "on", "on bir", "on iki"
    ]
    private static let turkishPastHours = [
        "", "biri", "ikiyi", "üçü", "dördü", "beşi", "altıyı",
        "yediyi", "sekizi", "dokuzu", "onu", "on biri", "on ikiyi"
    ]
    private static let turkishToHours = [
        "", "bire", "ikiye", "üçe", "dörde", "beşe", "altıya",
        "yediye", "sekize", "dokuza", "ona", "on bire", "on ikiye"
    ]

    private static let englishHours = [
        "", "one", "two", "three", "four", "five", "six",
        "seven", "eight", "nine", "ten", "eleven", "twelve"
    ]

    private static let spanishHours = [
        "", "una", "dos", "tres", "cuatro", "cinco", "seis",
        "siete", "ocho", "nueve", "diez", "once", "doce"
    ]

    static func text(hour24: Int, minute: Int, language: ClockLanguage) -> String {
        let hour = normalizedHour(hour24)
        let nextHour = hour == 12 ? 1 : hour + 1

        switch language {
        case .turkish:
            return turkish(hour: hour, nextHour: nextHour, minute: minute)
        case .spanish:
            return spanish(hour: hour, nextHour: nextHour, minute: minute)
        case .english:
            return english(hour: hour, nextHour: nextHour, minute: minute)
        }
    }

    private static func turkish(hour: Int, nextHour: Int, minute: Int) -> String {
        switch minute {
        case 0:
            return "saat \(turkishHours[hour])"
        case 15:
            return "\(turkishPastHours[hour]) çeyrek geçiyor"
        case 30:
            return "\(turkishHours[hour]) buçuk"
        case 45:
            return "\(turkishToHours[nextHour]) çeyrek var"
        case 1..<30:
            return "\(turkishPastHours[hour]) \(turkishNumber(minute)) geçiyor"
        default:
            return "\(turkishToHours[nextHour]) \(turkishNumber(60 - minute)) var"
        }
    }

    private static func english(hour: Int, nextHour: Int, minute: Int) -> String {
        switch minute {
        case 0:
            return "\(englishHours[hour]) o'clock"
        case 15:
            return "quarter past \(englishHours[hour])"
        case 30:
            return "half past \(englishHours[hour])"
        case 45:
            return "quarter to \(englishHours[nextHour])"
        case 1..<30:
            return "\(englishNumber(minute)) past \(englishHours[hour])"
        default:
            return "\(englishNumber(60 - minute)) to \(englishHours[nextHour])"
        }
    }

    private static func spanish(hour: Int, nextHour: Int, minute: Int) -> String {
        switch minute {
        case 0:
            return "\(spanishPrefix(hour)) \(spanishHours[hour]) en punto"
        case 15:
            return "\(spanishPrefix(hour)) \(spanishHours[hour]) y cuarto"
        case 30:
            return "\(spanishPrefix(hour)) \(spanishHours[hour]) y media"
        case 45:
            return "\(spanishPrefix(nextHour)) \(spanishHours[nextHour]) menos cuarto"
        case 1..<30:
            return "\(spanishPrefix(hour)) \(spanishHours[hour]) y \(spanishNumber(minute))"
        default:
            return "\(spanishPrefix(nextHour)) \(spanishHours[nextHour]) menos \(spanishNumber(60 - minute))"
        }
    }

    private static func normalizedHour(_ hour24: Int) -> Int {
        let hour = hour24 % 12
        return hour == 0 ? 12 : hour
    }

    private static func turkishNumber(_ number: Int) -> String {
        let ones = [
            "", "bir", "iki", "üç", "dört", "beş", "altı", "yedi", "sekiz", "dokuz"
        ]
        if number < 10 {
            return ones[number]
        }
        if number < 20 {
            return number == 10 ? "on" : "on \(ones[number - 10])"
        }
        return number == 20 ? "yirmi" : "yirmi \(ones[number - 20])"
    }

    private static func englishNumber(_ number: Int) -> String {
        let underTwenty = [
            "", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
            "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
            "seventeen", "eighteen", "nineteen"
        ]
        if number < 20 {
            return underTwenty[number]
        }
        return number == 20 ? "twenty" : "twenty-\(underTwenty[number - 20])"
    }

    private static func spanishNumber(_ number: Int) -> String {
        let underThirty = [
            "", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho",
            "nueve", "diez", "once", "doce", "trece", "catorce", "quince", "dieciséis",
            "diecisiete", "dieciocho", "diecinueve", "veinte", "veintiuno", "veintidós",
            "veintitrés", "veinticuatro", "veinticinco", "veintiséis", "veintisiete",
            "veintiocho", "veintinueve"
        ]
        return underThirty[number]
    }

    private static func spanishPrefix(_ hour: Int) -> String {
        hour == 1 ? "es la" : "son las"
    }
}

private final class EmojiOverlayView: NSView {
    let settings: OverlaySettings
    var onClick: (() -> Void)?

    init(settings: OverlaySettings) {
        self.settings = settings
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: settings.font,
            .foregroundColor: settings.foregroundColor
        ]
        let text = NSAttributedString(string: settings.displayedText(), attributes: attributes)
        let textSize = text.size()

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.rotate(by: settings.rotation * .pi / 180)
        text.draw(at: NSPoint(x: -textSize.width / 2, y: -textSize.height / 2))
        context.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let settings: OverlaySettings
    private let updaterController: SPUStandardUpdaterController
    private var valueLabels: [Int: NSTextField] = [:]
    private weak var positionPresetButton: NSPopUpButton?
    private weak var edgeAnchorControl: NSSegmentedControl?

    init(
        settings: OverlaySettings,
        updaterController: SPUStandardUpdaterController
    ) {
        self.settings = settings
        self.updaterController = updaterController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 825),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Saat Kaplaması"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.contentView = makeContentView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        guard let window else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeContentView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let help = NSTextField(wrappingLabelWithString: "Üst bardaki kutuya tıklayarak bu paneli açabilirsin.")
        help.textColor = .secondaryLabelColor
        stack.addArrangedSubview(help)

        let displayMode = NSPopUpButton()
        displayMode.addItems(withTitles: OverlayDisplayMode.allCases.map(\.title))
        displayMode.selectItem(
            at: OverlayDisplayMode.allCases.firstIndex(of: settings.displayMode) ?? 0
        )
        displayMode.target = self
        displayMode.action = #selector(displayModeChanged(_:))
        stack.addArrangedSubview(row(label: "Görünüm", control: displayMode))

        let systemClockFace = NSPopUpButton()
        systemClockFace.addItems(withTitles: SystemClockFace.allCases.map(\.title))
        systemClockFace.selectItem(
            at: SystemClockFace.allCases.firstIndex(of: settings.systemClockFace) ?? 0
        )
        systemClockFace.target = self
        systemClockFace.action = #selector(systemClockFaceChanged(_:))
        stack.addArrangedSubview(row(label: "Sistem saati", control: systemClockFace))

        let automaticCoverage = NSButton(
            checkboxWithTitle: "Sayı/analog görünüme göre hesapla",
            target: self,
            action: #selector(clockCoverageAutomaticChanged(_:))
        )
        automaticCoverage.state = settings.isClockCoverageAutomatic ? .on : .off
        stack.addArrangedSubview(row(label: "Otomatik boyut", control: automaticCoverage))

        stack.addArrangedSubview(sliderRow(
            label: "Kaplama genişliği",
            value: settings.clockCoverageWidth,
            range: 44...200,
            tag: 6,
            suffix: " px",
            isEnabled: !settings.isClockCoverageAutomatic
        ))

        let clockLanguage = NSPopUpButton()
        clockLanguage.addItems(withTitles: ClockLanguage.allCases.map(\.title))
        clockLanguage.selectItem(
            at: ClockLanguage.allCases.firstIndex(of: settings.clockLanguage) ?? 0
        )
        clockLanguage.isEnabled = settings.displayMode == .writtenClock
        clockLanguage.target = self
        clockLanguage.action = #selector(clockLanguageChanged(_:))
        stack.addArrangedSubview(row(label: "Saat dili", control: clockLanguage))

        let emojiField = NSTextField(string: settings.emoji)
        emojiField.tag = 100
        emojiField.delegate = self
        emojiField.alignment = .center
        emojiField.font = .systemFont(ofSize: 22)
        emojiField.isEnabled = settings.displayMode == .emoji
        stack.addArrangedSubview(row(label: "Emoji", control: emojiField))

        let sizeLabel = settings.displayMode == .emoji ? "Emoji boyutu" : "Yazı boyutu"
        let sizeRange: ClosedRange<Double> = settings.displayMode == .emoji ? 12...30 : 10...20
        stack.addArrangedSubview(sliderRow(
            label: sizeLabel,
            value: settings.size,
            range: sizeRange,
            tag: 1,
            suffix: " pt"
        ))
        stack.addArrangedSubview(sliderRow(
            label: "Dönüş",
            value: settings.rotation,
            range: -180...180,
            tag: 2,
            suffix: "°"
        ))

        let positionPreset = NSPopUpButton()
        positionPreset.addItems(withTitles: ["Saatin üstü", "Sol üst", "Orta üst", "Sağ üst", "Özel"])
        positionPreset.selectItem(at: settings.positionPreset)
        positionPreset.target = self
        positionPreset.action = #selector(positionPresetChanged(_:))
        positionPresetButton = positionPreset
        stack.addArrangedSubview(row(label: "Hazır konum", control: positionPreset))

        let edgeAnchor = NSSegmentedControl(
            labels: ["Serbest", "↖︎ Sol", "Sağ ↗︎"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(edgeAnchorChanged(_:))
        )
        switch settings.edgeAnchor {
        case .free:
            edgeAnchor.selectedSegment = 0
        case .topLeft:
            edgeAnchor.selectedSegment = 1
        case .topRight:
            edgeAnchor.selectedSegment = 2
        }
        edgeAnchorControl = edgeAnchor
        stack.addArrangedSubview(row(label: "Köşeye sabitle", control: edgeAnchor))

        stack.addArrangedSubview(sliderRow(
            label: "Kutunun X'i",
            value: settings.horizontalPosition,
            range: 0...100,
            tag: 3,
            suffix: "%"
        ))
        stack.addArrangedSubview(sliderRow(
            label: "Üstten uzaklık",
            value: settings.topOffset,
            range: 0...300,
            tag: 4,
            suffix: " px"
        ))
        stack.addArrangedSubview(sliderRow(
            label: "Arka plan",
            value: settings.backgroundOpacity * 100,
            range: 65...100,
            tag: 5,
            suffix: "%"
        ))

        let privacyColors = NSButton(
            checkboxWithTitle: "Mikrofon turuncu, ekran paylaşımı mor",
            target: self,
            action: #selector(privacyColorsChanged(_:))
        )
        privacyColors.state = settings.privacyColorsEnabled ? .on : .off
        stack.addArrangedSubview(row(label: "Canlı renk", control: privacyColors))

        let screenFrameStyle = NSButton(
            checkboxWithTitle: "Siyah, çizgili ve sol altı yuvarlak",
            target: self,
            action: #selector(screenFrameStyleChanged(_:))
        )
        screenFrameStyle.state = settings.screenFrameStyleEnabled ? .on : .off
        stack.addArrangedSubview(row(label: "Ekran çerçevesi", control: screenFrameStyle))

        let screenFrameStroke = NSButton(
            checkboxWithTitle: "İnce dış çizgiyi göster",
            target: self,
            action: #selector(screenFrameStrokeChanged(_:))
        )
        screenFrameStroke.state = settings.screenFrameStrokeEnabled ? .on : .off
        stack.addArrangedSubview(row(label: "Çerçeve çizgisi", control: screenFrameStroke))

        let automaticUpdates = NSButton(
            checkboxWithTitle: "Otomatik indir ve yükle",
            target: self,
            action: #selector(automaticUpdatesChanged(_:))
        )
        automaticUpdates.state =
            updaterController.updater.automaticallyChecksForUpdates ? .on : .off

        let checkForUpdates = NSButton(
            title: "Şimdi denetle",
            target: self,
            action: #selector(checkForUpdates)
        )

        let updateControls = NSStackView()
        updateControls.orientation = .horizontal
        updateControls.spacing = 8
        updateControls.addArrangedSubview(automaticUpdates)
        updateControls.addArrangedSubview(NSView())
        updateControls.addArrangedSubview(checkForUpdates)
        stack.addArrangedSubview(row(label: "Güncellemeler", control: updateControls))

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10

        let resetButton = NSButton(title: "Sıfırla", target: self, action: #selector(resetSettings))
        let closeButton = NSButton(title: "Kapat", target: self, action: #selector(closeSettings))
        closeButton.keyEquivalent = "\r"
        buttons.addArrangedSubview(resetButton)
        buttons.addArrangedSubview(NSView())
        buttons.addArrangedSubview(closeButton)
        stack.addArrangedSubview(buttons)

        return container
    }

    private func row(label: String, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10

        let title = NSTextField(labelWithString: label)
        title.setContentHuggingPriority(.required, for: .horizontal)
        title.widthAnchor.constraint(equalToConstant: 110).isActive = true
        row.addArrangedSubview(title)
        row.addArrangedSubview(control)
        return row
    }

    private func sliderRow(
        label: String,
        value: Double,
        range: ClosedRange<Double>,
        tag: Int,
        suffix: String,
        isEnabled: Bool = true
    ) -> NSView {
        let slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: self, action: #selector(sliderChanged(_:)))
        slider.tag = tag
        slider.isContinuous = true
        slider.isEnabled = isEnabled

        let valueLabel = NSTextField(labelWithString: formatted(value, suffix: suffix))
        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 58).isActive = true
        valueLabels[tag] = valueLabel

        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.addArrangedSubview(slider)
        controls.addArrangedSubview(valueLabel)
        return row(label: label, control: controls)
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        switch sender.tag {
        case 1:
            settings.size = value
            valueLabels[sender.tag]?.stringValue = formatted(value, suffix: " pt")
        case 2:
            settings.rotation = value
            valueLabels[sender.tag]?.stringValue = formatted(value, suffix: "°")
        case 3:
            settings.horizontalPosition = value
            positionPresetButton?.selectItem(at: 4)
            edgeAnchorControl?.selectedSegment = 0
            valueLabels[sender.tag]?.stringValue = formatted(value, suffix: "%")
        case 4:
            settings.topOffset = value
            positionPresetButton?.selectItem(at: 4)
            edgeAnchorControl?.selectedSegment = 0
            valueLabels[sender.tag]?.stringValue = formatted(value, suffix: " px")
        case 5:
            settings.backgroundOpacity = value / 100
            valueLabels[sender.tag]?.stringValue = formatted(value, suffix: "%")
        case 6:
            settings.clockCoverageWidth = value
            valueLabels[sender.tag]?.stringValue = formatted(value, suffix: " px")
        default:
            break
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        guard
            let field = notification.object as? NSTextField,
            field.tag == 100
        else { return }
        settings.emoji = field.stringValue
    }

    @objc private func resetSettings() {
        settings.reset()
        window?.contentView = makeContentView()
    }

    @objc private func positionPresetChanged(_ sender: NSPopUpButton) {
        settings.applyPositionPreset(sender.indexOfSelectedItem)
        window?.contentView = makeContentView()
    }

    @objc private func displayModeChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        guard OverlayDisplayMode.allCases.indices.contains(selectedIndex) else { return }
        settings.displayMode = OverlayDisplayMode.allCases[selectedIndex]
        window?.contentView = makeContentView()
    }

    @objc private func systemClockFaceChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        guard SystemClockFace.allCases.indices.contains(selectedIndex) else { return }
        settings.systemClockFace = SystemClockFace.allCases[selectedIndex]
        window?.contentView = makeContentView()
    }

    @objc private func clockCoverageAutomaticChanged(_ sender: NSButton) {
        settings.setClockCoverageAutomatic(sender.state == .on)
        window?.contentView = makeContentView()
    }

    @objc private func clockLanguageChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        guard ClockLanguage.allCases.indices.contains(selectedIndex) else { return }
        settings.clockLanguage = ClockLanguage.allCases[selectedIndex]
    }

    @objc private func edgeAnchorChanged(_ sender: NSSegmentedControl) {
        let anchor: MenuBarEdgeAnchor
        switch sender.selectedSegment {
        case 1:
            anchor = .topLeft
        case 2:
            anchor = .topRight
        default:
            anchor = .free
        }
        settings.applyEdgeAnchor(anchor)
        if anchor != .free {
            positionPresetButton?.selectItem(at: 4)
        }
    }

    @objc private func privacyColorsChanged(_ sender: NSButton) {
        settings.privacyColorsEnabled = sender.state == .on
    }

    @objc private func screenFrameStyleChanged(_ sender: NSButton) {
        settings.screenFrameStyleEnabled = sender.state == .on
    }

    @objc private func screenFrameStrokeChanged(_ sender: NSButton) {
        settings.screenFrameStrokeEnabled = sender.state == .on
    }

    @objc private func automaticUpdatesChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        updaterController.updater.automaticallyChecksForUpdates = enabled
        updaterController.updater.automaticallyDownloadsUpdates = enabled
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func closeSettings() {
        close()
    }

    private func formatted(_ value: Double, suffix: String) -> String {
        "\(Int(value.rounded()))\(suffix)"
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = OverlaySettings()
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private var overlays: [NSPanel] = []
    private var overlayViews: [EmojiOverlayView] = []
    private var refreshTimer: Timer?
    private var settingsController: SettingsWindowController?
    private var cachedMenuBarHeights: [CGDirectDisplayID: CGFloat] = [:]
    private var lastMenuBarSampleDate = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = updaterController
        settings.onChange = { [weak self] in
            self?.refreshOverlays()
        }
        rebuildOverlays()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildOverlays),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        refreshTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(refreshOverlays),
            userInfo: nil,
            repeats: true
        )
        refreshTimer?.tolerance = 0.2
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    @objc private func rebuildOverlays() {
        overlays.forEach { $0.close() }
        overlays = []
        overlayViews = []

        for screen in NSScreen.screens {
            let (panel, overlayView) = makeOverlay(for: screen)
            overlays.append(panel)
            overlayViews.append(overlayView)
        }
        refreshOverlays()
    }

    @objc private func activeSpaceDidChange() {
        rebuildOverlays()
    }

    @objc private func refreshOverlays() {
        let screens = NSScreen.screens
        if screens.count != overlays.count {
            rebuildOverlays()
            return
        }

        if settings.screenFrameStyleEnabled {
            settings.systemActivity = .normal
            settings.isFullScreenActive = false
        } else {
            settings.systemActivity = detectSystemActivity()
            settings.isFullScreenActive = screens.contains {
                isFullScreenApplicationVisible(on: $0)
            }
        }
        updateSampledMenuBarColorIfNeeded(on: screens.first)

        for (panel, screen) in zip(overlays, screens) {
            panel.setFrame(overlayFrame(for: screen), display: true)
            configureBackground(of: panel)
        }
        overlayViews.forEach { $0.needsDisplay = true }
    }

    private func updateSampledMenuBarColorIfNeeded(on screen: NSScreen?) {
        guard
            !settings.screenFrameStyleEnabled,
            !settings.isFullScreenActive,
            settings.systemActivity == .normal,
            let screen,
            Date().timeIntervalSince(lastMenuBarSampleDate) >= 1
        else {
            return
        }

        lastMenuBarSampleDate = Date()
        if let color = sampleMenuBarColor(on: screen) {
            settings.sampledMenuBarColor = color
        }
    }

    private func sampleMenuBarColor(on screen: NSScreen) -> NSColor? {
        guard
            let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]],
            let menuBarWindow = windowInfo.first(where: { window in
                guard
                    window[kCGWindowOwnerName as String] as? String == "Window Server",
                    window[kCGWindowName as String] as? String == "Menubar",
                    let boundsDictionary =
                        window[kCGWindowBounds as String] as? NSDictionary,
                    let bounds = CGRect(
                        dictionaryRepresentation: boundsDictionary as CFDictionary
                    )
                else {
                    return false
                }
                return
                    abs(bounds.minX - screen.frame.minX) <= 2 &&
                    abs(bounds.width - screen.frame.width) <= 2
            }),
            let boundsDictionary =
                menuBarWindow[kCGWindowBounds as String] as? NSDictionary,
            let windowBounds = CGRect(
                dictionaryRepresentation: boundsDictionary as CFDictionary
            ),
            let overlayWindowNumber = overlays.first?.windowNumber,
            overlayWindowNumber > 0,
            let image = legacyWindowListCreateImage(
                CGRect(
                    x: windowBounds.maxX - settings.clockCoverageWidth,
                    y: windowBounds.minY,
                    width: settings.clockCoverageWidth,
                    height: windowBounds.height
                ),
                .optionOnScreenBelowWindow,
                CGWindowID(overlayWindowNumber),
                [.bestResolution]
            )
        else {
            return nil
        }

        let imageWidth = image.width
        let imageHeight = image.height
        guard imageWidth > 0, imageHeight > 0 else {
            return nil
        }

        let bytesPerPixel = 4
        let bytesPerRow = imageWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * imageHeight)
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: &pixels,
                width: imageWidth,
                height: imageHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast.rawValue |
                    CGBitmapInfo.byteOrder32Big.rawValue
            )
        else {
            return nil
        }

        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        )

        let sampleWidth = imageWidth
        let startX = 0
        let verticalInset = min(3, max(0, imageHeight / 10))

        var redHistogram = [Int](repeating: 0, count: 256)
        var greenHistogram = [Int](repeating: 0, count: 256)
        var blueHistogram = [Int](repeating: 0, count: 256)
        var sampledPixelCount = 0

        for y in verticalInset..<(imageHeight - verticalInset) {
            for x in startX..<imageWidth {
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard pixels[offset + 3] > 200 else { continue }
                redHistogram[Int(pixels[offset])] += 1
                greenHistogram[Int(pixels[offset + 1])] += 1
                blueHistogram[Int(pixels[offset + 2])] += 1
                sampledPixelCount += 1
            }
        }

        guard sampledPixelCount > 0 else { return nil }

        return NSColor(
            srgbRed: CGFloat(histogramMedian(redHistogram, count: sampledPixelCount)) / 255,
            green: CGFloat(histogramMedian(greenHistogram, count: sampledPixelCount)) / 255,
            blue: CGFloat(histogramMedian(blueHistogram, count: sampledPixelCount)) / 255,
            alpha: 1
        )
    }

    private func histogramMedian(_ histogram: [Int], count: Int) -> Int {
        let target = count / 2
        var cumulative = 0
        for (value, frequency) in histogram.enumerated() {
            cumulative += frequency
            if cumulative > target {
                return value
            }
        }
        return 0
    }

    private func makeOverlay(for screen: NSScreen) -> (NSPanel, EmojiOverlayView) {
        let panel = NSPanel(
            contentRect: overlayFrame(for: screen),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let backgroundView = NSView(frame: panel.contentView?.bounds ?? .zero)
        backgroundView.autoresizingMask = [.width, .height]
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = settings.cornerRadius
        backgroundView.layer?.masksToBounds = true

        let overlayView = EmojiOverlayView(settings: settings)
        overlayView.frame = backgroundView.bounds
        overlayView.autoresizingMask = [.width, .height]
        overlayView.onClick = { [weak self] in
            self?.showSettings()
        }
        backgroundView.addSubview(overlayView)
        panel.contentView = backgroundView
        configureBackground(of: panel)
        panel.orderFrontRegardless()
        return (panel, overlayView)
    }

    private func configureBackground(of panel: NSPanel) {
        guard let backgroundView = panel.contentView else {
            return
        }

        if let solidColor = settings.solidBackgroundColor {
            backgroundView.layer?.backgroundColor = solidColor.cgColor
            backgroundView.alphaValue = 1
        } else {
            backgroundView.layer?.backgroundColor =
                NSColor.windowBackgroundColor.cgColor
            backgroundView.alphaValue =
                settings.edgeAnchor == .free ? settings.backgroundOpacity : 1
        }
        backgroundView.layer?.cornerRadius = settings.cornerRadius
        backgroundView.layer?.maskedCorners = settings.screenFrameStyleEnabled
            ? [.layerMinXMinYCorner]
            : [
                .layerMinXMinYCorner,
                .layerMaxXMinYCorner,
                .layerMinXMaxYCorner,
                .layerMaxXMaxYCorner
            ]
        let shouldShowStroke =
            settings.screenFrameStyleEnabled && settings.screenFrameStrokeEnabled
        backgroundView.layer?.borderWidth = shouldShowStroke ? 1 : 0
        backgroundView.layer?.borderColor = shouldShowStroke
            ? NSColor(white: 0.28, alpha: 1).cgColor
            : nil
        backgroundView.layer?.masksToBounds = true
    }

    private func overlayFrame(for screen: NSScreen) -> NSRect {
        let overlaySize = overlaySize()
        let width = overlaySize.width
        let menuBarHeight = menuBarHeight(for: screen, minimum: overlaySize.height)

        switch settings.edgeAnchor {
        case .topLeft:
            return NSRect(
                x: screen.frame.minX,
                y: screen.frame.maxY - menuBarHeight,
                width: width,
                height: menuBarHeight
            )
        case .topRight:
            return NSRect(
                x: screen.frame.maxX - width,
                y: screen.frame.maxY - menuBarHeight,
                width: width,
                height: menuBarHeight
            )
        case .free:
            break
        }

        let height = overlaySize.height

        return NSRect(
            x: min(
                max(
                    screen.frame.minX,
                    screen.frame.minX + screen.frame.width * settings.horizontalPosition / 100 - width / 2
                ),
                screen.frame.maxX - width
            ),
            y: min(
                max(screen.frame.minY, screen.frame.maxY - settings.topOffset - height),
                screen.frame.maxY - height
            ),
            width: width,
            height: height
        )
    }

    private func menuBarHeight(for screen: NSScreen, minimum: CGFloat) -> CGFloat {
        let currentHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        guard let displayID = displayID(for: screen) else {
            return max(minimum, currentHeight)
        }

        if currentHeight > minimum {
            cachedMenuBarHeights[displayID] = currentHeight
        }
        return max(minimum, currentHeight, cachedMenuBarHeights[displayID] ?? 0)
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .uint32Value
    }

    private func overlaySize() -> NSSize {
        let text = settings.displayedText() as NSString
        let measuredSize = text.size(withAttributes: [.font: settings.font])
        let width = min(
            max(58, ceil(measuredSize.width) + 18, settings.clockCoverageWidth),
            340
        )
        return NSSize(width: width, height: 22)
    }

    private func detectSystemActivity() -> SystemActivity {
        guard settings.privacyColorsEnabled else { return .normal }

        let microphoneActive = isDefaultMicrophoneActive()
        let privacyIndicatorVisible = isWindowServerPrivacyIndicatorVisible()

        if microphoneActive {
            return .microphone
        }
        if privacyIndicatorVisible {
            return .screenSharing
        }
        return .normal
    }

    private func isDefaultMicrophoneActive() -> Bool {
        var defaultInput = AudioDeviceID(kAudioObjectUnknown)
        var defaultInputSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let defaultInputStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            0,
            nil,
            &defaultInputSize,
            &defaultInput
        )
        guard defaultInputStatus == noErr, defaultInput != kAudioObjectUnknown else {
            return false
        }

        var isRunning = UInt32(0)
        var isRunningSize = UInt32(MemoryLayout<UInt32>.size)
        var isRunningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let runningStatus = AudioObjectGetPropertyData(
            defaultInput,
            &isRunningAddress,
            0,
            nil,
            &isRunningSize,
            &isRunning
        )
        return runningStatus == noErr && isRunning != 0
    }

    private func isWindowServerPrivacyIndicatorVisible() -> Bool {
        guard
            let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return false
        }

        return windowInfo.contains { window in
            guard
                window[kCGWindowOwnerName as String] as? String == "Window Server",
                let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(
                    dictionaryRepresentation: boundsDictionary as CFDictionary
                )
            else {
                return false
            }

            let windowName = window[kCGWindowName as String] as? String
            let hasIndicatorName = windowName == "StatusIndicator"
            let hasIndicatorGeometry =
                (26...30).contains(bounds.width) &&
                (26...30).contains(bounds.height) &&
                bounds.minY <= 5
            return hasIndicatorName || hasIndicatorGeometry
        }
    }

    private func isFullScreenApplicationVisible(on screen: NSScreen) -> Bool {
        guard
            let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return false
        }

        let screenFrame = screen.frame
        let cachedMenuBarHeight = displayID(for: screen)
            .flatMap { cachedMenuBarHeights[$0] } ?? 0
        let minimumFullScreenHeight =
            screenFrame.height - max(cachedMenuBarHeight, 44)
        let ignoredOwners = [
            "ClockScrambler",
            "Dock",
            "Finder",
            "Window Server",
            "Notification Center",
            "Centro de notificaciones",
            "screencapture",
            "Screenshot",
            "ScreenCaptureKitPicker"
        ]

        return windowInfo.contains { window in
            guard
                (window[kCGWindowLayer as String] as? Int) == 0,
                let ownerName = window[kCGWindowOwnerName as String] as? String,
                !ignoredOwners.contains(ownerName),
                let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(
                    dictionaryRepresentation: boundsDictionary as CFDictionary
                )
            else {
                return false
            }

            return
                abs(bounds.minX - screenFrame.minX) <= 2 &&
                bounds.minY <= 2 &&
                abs(bounds.width - screenFrame.width) <= 2 &&
                bounds.height >= minimumFullScreenHeight - 2
        }
    }

    private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                settings: settings,
                updaterController: updaterController
            )
        }
        settingsController?.present()
    }
}
