import AppKit
import SwiftUI
import ApplicationServices
import IOKit.ps
import ServiceManagement

struct Preferences: Codable {
    var delay = 300
    var interval = 10
    var mode = "Natural"
    var range = "Small"
    var schedule = false
    var startHour = 9
    var endHour = 17
    var weekdays = Set([2, 3, 4, 5, 6])
    var deactivate = false
    var stopMinutes = 60
    var onlyApp = false
    var appID = ""
    var appName = "Выберите приложение"
    var appRule = "В фокусе"
    var clicks = "None"
    var scroll = "None"
    var keyPress = false
}

final class Controller: ObservableObject {
    @Published private(set) var loginStatus = SMAppService.mainApp.status
    @Published private(set) var loginError: String?
    private var nextLoginRead = Date.distantPast

    var launchAtLogin: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginError = error.localizedDescription
        }
        loginStatus = SMAppService.mainApp.status
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    @Published var batteryProtection = UserDefaults.standard.bool(forKey: "batteryProtection") {
        didSet { UserDefaults.standard.set(batteryProtection, forKey: "batteryProtection") }
    }
    @Published var batteryThreshold = UserDefaults.standard.object(forKey: "batteryThreshold") as? Int ?? 5 {
        didSet { UserDefaults.standard.set(batteryThreshold, forKey: "batteryThreshold") }
    }
    @Published private(set) var batteryPercent: Int?
    private var nextBatteryRead = Date.distantPast

    private func updateBattery(_ now: Date) {
        guard now >= nextBatteryRead else { return }
        nextBatteryRead = now.addingTimeInterval(5)
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            batteryPercent = nil
            return
        }
        var levels: [Int] = []
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = info[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            levels.append(min(100, max(0, Int(Double(current) / Double(maximum) * 100))))
        }
        batteryPercent = levels.min()
    }

    @Published var language = UserDefaults.standard.string(forKey: "language") ?? (Locale.preferredLanguages.first?.hasPrefix("ru") == true ? "ru" : "en") {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }
    func text(_ value: String) -> String {
        guard language == "en" else { return value }
        let translations: [String: String] = [
            "На паузе": "Paused",
            "Движение": "Movement",
            "Автоматизация": "Automation",
            "Настройки": "Settings",
            "Начать": "Start",
            "Приостановить": "Pause",
            "Дополнительные действия": "Additional actions",
            "Плавное": "Smooth",
            "Незаметное": "Subtle",
            "Поведение курсора": "Cursor behavior",
            "Когда работать": "When to run",
            "Питание и запуск": "Power and startup",
            "Доступ разрешён": "Access granted",
            "Запускать при входе": "Launch at login",
            "Всегда запускается на паузе": "Always starts paused",
            "Подтвердить в настройках macOS": "Approve in System Settings",
            "Не удалось изменить автозапуск": "Could not change launch at login",
            "Низкий заряд батареи": "Battery below threshold",
            "При низком заряде": "Low battery pause",
            "Порог": "Threshold",
            "Заряд": "Battery",
            "Батарея не обнаружена": "No battery detected",
            "Движение приостанавливается при заряде ниже порога, в том числе при подключённой зарядке. Возобновляется, когда заряд достигает порога.": "Movement pauses below the threshold, including while charging. Resumes when the battery reaches the threshold.",
            "Нужно разрешение на управление": "Accessibility permission required",
            "Сеанс неактивен": "Session inactive",
            "Вне расписания": "Outside schedule",
            "Ожидание выбранного приложения": "Waiting for selected app",
            "Ожидание после пробуждения": "Waiting after wake",
            "Активен · двигаю курсор": "Active · moving cursor",
            "Включить": "Enable",
            "Расписание": "Schedule",
            "С": "From",
            "До": "To",
            "Дни": "Repeat",
            "Пн": "Mo",
            "Вт": "Tu",
            "Ср": "We",
            "Чт": "Th",
            "Пт": "Fr",
            "Сб": "Sa",
            "Вс": "Su",
            "Автоотключение": "Deactivate",
            "Через": "After",
            "Только для приложения": "Only while app",
            "Запущено": "Running",
            "В фокусе": "In front",
            "Не в фокусе": "Not in front",
            "Выберите приложение": "Choose application",
            "Режимы": "Modes",
            "Начинать через": "Start moving after",
            "Двигать каждые": "Move every",
            "Диапазон": "Movement range",
            "Малый": "Small",
            "Средний": "Medium",
            "Весь экран": "Full",
            "Клики": "Clicks",
            "Нет": "None",
            "Левый": "Left",
            "Правый": "Right",
            "Прокрутка": "Scroll",
            "Вверх": "Up",
            "Вниз": "Down",
            "Нажимать Shift": "Press Shift",
            "Настройки доступа": "Permissions",
            "Разрешить управление": "Allow control",
            "Выйти": "Quit",
            "Начало": "Start",
            "Конец": "End",
            "Ожидание": "Idle delay",
            "Интервал": "Interval",
            "Язык": "Language",
            "Natural — плавное движение. Silent — сдвиг на одну точку и возврат.": "Natural: smooth movement. Silent: move one point and return.",
            "Время без мыши и клавиатуры до начала движения.": "Time without mouse or keyboard activity before movement starts.",
            "Интервал между перемещениями.": "Time between movements.",
            "Движение ограничено текущим монитором.": "Movement stays on the current display.",
            "Клик в точке курсора после каждого перемещения.": "Click at the cursor after each movement.",
            "Прокрутка на одну строку в активном приложении.": "Scroll one line in the active application.",
        ]
        if let translated = translations[value] { return translated }
        if value.hasPrefix("Начну через ") { return value.replacingOccurrences(of: "Начну через ", with: "Starting in ").replacingOccurrences(of: " сек", with: " sec") }
        return value.replacingOccurrences(of: " мин", with: " min").replacingOccurrences(of: " сек", with: " sec")
    }

    @Published var preferences: Preferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) { UserDefaults.standard.set(data, forKey: "preferences") }
            nextMove = .distantPast
            if preferences.deactivate != oldValue.deactivate || preferences.stopMinutes != oldValue.stopMinutes {
                stopAt = Date().addingTimeInterval(Double(preferences.stopMinutes * 60))
            }
        }
    }
    @Published var enabled = false {
        didSet { nextMove = .distantPast; stopAt = Date().addingTimeInterval(Double(preferences.stopMinutes * 60)) }
    }
    @Published var status = "На паузе"
    @Published var permitted = false
    private var timer: Timer?
    private var nextMove = Date.distantPast
    private var stopAt = Date.distantFuture
    private var wakeAfter = Date.distantPast
    private var sessionAvailable = true
    private var path: [CGPoint] = []
    private var pathIndex = 0
    private var source = CGEventSource(stateID: .privateState)
    private let inputs: [CGEventType] = [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .keyDown, .flagsChanged, .scrollWheel, .tabletPointer]

    init() {
        if let data = UserDefaults.standard.data(forKey: "preferences"), let value = try? JSONDecoder().decode(Preferences.self, from: data) {
            preferences = value
        } else { preferences = Preferences() }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            center.addObserver(self, selector: #selector(suspend), name: name, object: nil)
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(self, selector: #selector(resume), name: name, object: nil)
        }
        timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private var idle: Double { inputs.map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }.min() ?? 0 }

    private func scheduleAllows(_ now: Date) -> Bool {
        guard preferences.schedule else { return true }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        var day = calendar.component(.weekday, from: now)
        let start = preferences.startHour, end = preferences.endHour
        if start == end { return preferences.weekdays.contains(day) }
        if start < end { return preferences.weekdays.contains(day) && hour >= start && hour < end }
        // After midnight the window belongs to the previous selected day.
        if hour < end { day = day == 1 ? 7 : day - 1 }
        return preferences.weekdays.contains(day) && (hour >= start || hour < end)
    }

    private var appAllows: Bool {
        guard preferences.onlyApp else { return true }
        guard !preferences.appID.isEmpty else { return false }
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: preferences.appID).isEmpty
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == preferences.appID
        switch preferences.appRule {
        case "Запущено": return running
        case "Не в фокусе": return running && !front
        default: return front
        }
    }

    private func tick() {
        permitted = CGPreflightPostEventAccess()
        let now = Date()
        updateBattery(now)
        if now >= nextLoginRead {
            loginStatus = SMAppService.mainApp.status
            nextLoginRead = now.addingTimeInterval(5)
        }
        if enabled && preferences.deactivate && now >= stopAt { enabled = false }
        var blocked: String?
        if !enabled { blocked = "На паузе" }
        else if !permitted { blocked = "Нужно разрешение на управление" }
        else if batteryProtection, let percent = batteryPercent, percent < batteryThreshold { blocked = "Низкий заряд батареи" }
        else if !sessionAvailable { blocked = "Сеанс неактивен" }
        else if !scheduleAllows(now) { blocked = "Вне расписания" }
        else if !appAllows { blocked = "Ожидание выбранного приложения" }
        else if now < wakeAfter { blocked = "Ожидание после пробуждения" }
        else if idle < Double(preferences.delay) { blocked = "Начну через \(Int(ceil(Double(preferences.delay) - idle))) сек" }
        if let blocked {
            status = blocked
            path = []; pathIndex = 0
            nextMove = .distantPast
            return
        }
        status = "Активен · двигаю курсор"
        if pathIndex < path.count {
            postMove(path[pathIndex]); pathIndex += 1
            if pathIndex == path.count { extraEvents() }
            return
        }
        guard now >= nextMove else { return }
        beginMovement()
        nextMove = now.addingTimeInterval(Double(preferences.interval))
    }

    private func beginMovement() {
        guard let position = CGEvent(source: nil)?.location else { return }
        var displays = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(UInt32(displays.count), &displays, &count) == .success,
              let display = displays.prefix(Int(count)).first(where: { CGDisplayBounds($0).contains(position) }) else { return }
        let bounds = CGDisplayBounds(display).insetBy(dx: 3, dy: 3)
        let distance: Double = preferences.mode == "Silent" ? 1 : (preferences.range == "Small" ? 45 : 180)
        let angle = Double.random(in: 0..<(2 * .pi))
        let target: CGPoint
        if preferences.range == "Full" && preferences.mode != "Silent" {
            target = CGPoint(x: Double.random(in: bounds.minX...bounds.maxX), y: Double.random(in: bounds.minY...bounds.maxY))
        } else {
            target = CGPoint(x: min(max(position.x + cos(angle) * distance, bounds.minX), bounds.maxX),
                             y: min(max(position.y + sin(angle) * distance, bounds.minY), bounds.maxY))
        }
        if preferences.mode == "Silent" {
            postMove(target)
            path = [position]; pathIndex = 0
        } else {
            // Smooth ease-in/ease-out path; real hardware input cancels it on the next tick.
            path = (1...16).map { step in
                let t = Double(step) / 16
                let eased = t * t * (3 - 2 * t)
                return CGPoint(x: position.x + (target.x - position.x) * eased, y: position.y + (target.y - position.y) * eased)
            }
            pathIndex = 0
        }
    }

    private func postMove(_ point: CGPoint) {
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cgSessionEventTap)
    }

    private func extraEvents() {
        if preferences.clicks != "None", let point = CGEvent(source: nil)?.location {
            let right = preferences.clicks == "Right"
            for type: CGEventType in right ? [.rightMouseDown, .rightMouseUp] : [.leftMouseDown, .leftMouseUp] {
                CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: right ? .right : .left)?.post(tap: .cgSessionEventTap)
            }
        }
        if preferences.scroll != "None" {
            CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1, wheel1: preferences.scroll == "Up" ? 1 : -1, wheel2: 0, wheel3: 0)?.post(tap: .cgSessionEventTap)
        }
        if preferences.keyPress {
            for down in [true, false] { CGEvent(keyboardEventSource: source, virtualKey: 56, keyDown: down)?.post(tap: .cgSessionEventTap) }
        }
    }

    func permission() {
        CGRequestPostEventAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
    func chooseApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        preferences.appID = id
        preferences.appName = url.deletingPathExtension().lastPathComponent
    }
    @objc private func suspend() { sessionAvailable = false; path = [] }
    @objc private func resume() { sessionAvailable = true; wakeAfter = Date().addingTimeInterval(Double(preferences.delay)) }
}

struct Dashboard: View {
    @ObservedObject var model: Controller
    @State private var selectedTab = 0
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "cursorarrow.motionlines").font(.title2).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cursor Drift").font(.headline)
                    Text(model.text(model.status)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Toggle(model.text("Включить"), isOn: $model.enabled).labelsHidden().toggleStyle(.switch)
            }
            Divider()
            Picker("", selection: $selectedTab) {
                Text(model.text("Движение")).tag(0)
                Text(model.text("Автоматизация")).tag(1)
                Text(model.text("Настройки")).tag(2)
            }.pickerStyle(.segmented).labelsHidden()
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    Text(model.text(selectedTab == 0 ? "Поведение курсора" : selectedTab == 1 ? "Когда работать" : "Питание и запуск"))
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).padding(.top, 12)
                    if selectedTab == 0 {
                        Picker(model.text("Режимы"), selection: $model.preferences.mode) {
                            Text(model.text("Плавное")).tag("Natural")
                            Text(model.text("Незаметное")).tag("Silent")
                        }.pickerStyle(.segmented).labelsHidden()
                        row("Начинать через", help: "Время без мыши и клавиатуры до начала движения.") {
                            choice("Ожидание", $model.preferences.delay, [60, 180, 300, 600, 900].map { ($0, "\($0 / 60) мин") })
                        }
                        line
                        row("Двигать каждые", help: "Интервал между перемещениями.") {
                            choice("Интервал", $model.preferences.interval, [2, 5, 10, 20, 30, 60].map { ($0, "\($0) сек") })
                        }
                        line
                        row("Диапазон", help: "Движение ограничено текущим монитором.") {
                            choice("Диапазон", $model.preferences.range, [("Small", "Малый"), ("Medium", "Средний"), ("Full", "Весь экран")])
                        }.disabled(model.preferences.mode == "Silent")
                        line
                        Text(model.text("Дополнительные действия")).foregroundStyle(.secondary).font(.system(size: 10, weight: .semibold))
                        row("Клики", help: "Клик в точке курсора после каждого перемещения.") {
                            choice("Клики", $model.preferences.clicks, [("None", "Нет"), ("Left", "Левый"), ("Right", "Правый")])
                        }
                        line
                        row("Прокрутка", help: "Прокрутка на одну строку в активном приложении.") {
                            choice("Прокрутка", $model.preferences.scroll, [("None", "Нет"), ("Up", "Вверх"), ("Down", "Вниз")])
                        }
                        line
                        toggleRow("Нажимать Shift", $model.preferences.keyPress)

                    } else if selectedTab == 1 {
                        toggleRow("Расписание", $model.preferences.schedule)
                        HStack(spacing: 7) {
                            Text(model.text("С")).foregroundStyle(.secondary)
                            choice("Начало", $model.preferences.startHour, (0..<24).map { ($0, String(format: "%02d:00", $0)) })
                            Spacer(minLength: 8)
                            Text(model.text("До")).foregroundStyle(.secondary)
                            choice("Конец", $model.preferences.endHour, (0..<24).map { ($0, String(format: "%02d:00", $0)) })
                        }.disabled(!model.preferences.schedule)
                        HStack(spacing: 4) {
                            Text(model.text("Дни")).foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            ForEach(Array(zip([2, 3, 4, 5, 6, 7, 1], ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"])), id: \.0) { day, label in
                                Toggle(model.text(label), isOn: Binding(
                                    get: { model.preferences.weekdays.contains(day) },
                                    set: { selected in
                                        if selected { model.preferences.weekdays.insert(day) }
                                        else { model.preferences.weekdays.remove(day) }
                                    }
                                )).toggleStyle(.button).controlSize(.small)

                            }
                        }.disabled(!model.preferences.schedule)
                        line
                        toggleRow("Автоотключение", $model.preferences.deactivate)
                        HStack(spacing: 8) {
                            Text(model.text("Через")).foregroundStyle(.secondary)
                            choice("Через", $model.preferences.stopMinutes, [15, 30, 60, 120, 240, 480].map { ($0, "\($0) мин") })
                            Spacer()
                        }.disabled(!model.preferences.deactivate)

                        line
                        toggleRow("Только для приложения", $model.preferences.onlyApp)
                        Picker("", selection: $model.preferences.appRule) {
                            ForEach(["Запущено", "В фокусе", "Не в фокусе"], id: \.self) { rule in Text(model.text(rule)).tag(rule) }
                        }.pickerStyle(.segmented).labelsHidden().disabled(!model.preferences.onlyApp)
                        Button(action: model.chooseApp) {
                            HStack(spacing: 7) {
                                Image(systemName: "plus").font(.system(size: 19, weight: .medium))
                                if !model.preferences.appID.isEmpty { Text(model.preferences.appName).lineLimit(1) }
                                if model.preferences.appID.isEmpty { Text(model.text("Выберите приложение")) }
                            }
                        }.disabled(!model.preferences.onlyApp)
                            .help(model.text(model.preferences.appName))

                    } else {
                        toggleRow("При низком заряде", $model.batteryProtection)
                        HStack(spacing: 8) {
                            Text(model.text("Порог")).foregroundStyle(.secondary)
                            Slider(value: Binding(get: { Double(model.batteryThreshold) },
                                                  set: { model.batteryThreshold = Int($0) }), in: 1...100, step: 1)
                                .labelsHidden().accessibilityLabel(model.text("Порог"))
                            Text("\(model.batteryThreshold)%").monospacedDigit().frame(width: 34, alignment: .trailing)
                        }.disabled(!model.batteryProtection)
                        Text(model.batteryPercent.map { "\(model.text("Заряд")): \($0)%" } ?? model.text("Батарея не обнаружена"))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                            .help(model.text("Движение приостанавливается при заряде ниже порога, в том числе при подключённой зарядке. Возобновляется, когда заряд достигает порога."))

                        line
                        toggleRow("Запускать при входе", Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                        if model.loginStatus == .requiresApproval {
                            Button(model.text("Подтвердить в настройках macOS"), action: model.openLoginSettings)
                                .buttonStyle(.plain).foregroundStyle(Color.accentColor).font(.system(size: 10))
                        } else {
                            Text(model.text("Всегда запускается на паузе"))
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        if let error = model.loginError {
                            Text(model.text("Не удалось изменить автозапуск"))
                                .font(.system(size: 10)).foregroundStyle(.orange).help(error)
                        }

                        line
                        row("Язык", help: "Language") {
                            choice("Language", $model.language, [("en", "English"), ("ru", "Русский")])
                        }
                    }
                }.padding(.horizontal, 2).padding(.bottom, 12)
            }.frame(height: 345)
            line
            HStack {
                Button(action: model.permission) {
                    Label(model.text(model.permitted ? "Доступ разрешён" : "Разрешить управление"), systemImage: model.permitted ? "checkmark.shield" : "lock.open")
                        .font(.system(size: 10)).foregroundStyle(model.permitted ? Color.secondary : Color.accentColor)
                }.buttonStyle(.plain)
                Spacer()
                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power").font(.system(size: 13)).frame(width: 28, height: 26)
                }.buttonStyle(.plain).help(model.text("Выйти"))
            }.padding(.top, 5)
        }.padding(14).frame(width: 380).font(.system(size: 12))
            .background(NativePopoverBackground())
    }
    private var line: some View { Divider().padding(.vertical, 1) }
    private func switchControl(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(model.text(title), isOn: value).labelsHidden().toggleStyle(.switch).controlSize(.small)
    }
    private func toggleRow(_ title: String, _ value: Binding<Bool>) -> some View {
        HStack { Text(model.text(title)).fontWeight(.semibold); Spacer(); switchControl(title, value) }.frame(minHeight: 23)
    }
    private func info(_ help: String) -> some View {
        Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(.secondary).help(model.text(help))
    }
    private func row<Content: View>(_ title: String, help: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 5) { Text(model.text(title)).fontWeight(.semibold); info(help); Spacer(minLength: 2); content() }.frame(minHeight: 26)
    }
    private func choice<T: Hashable>(_ title: String, _ selection: Binding<T>, _ options: [(T, String)]) -> some View {
        Picker(model.text(title), selection: selection) {
            ForEach(options, id: \.0) { value, label in Text(model.text(label)).tag(value) }
        }.labelsHidden().pickerStyle(.menu).fixedSize().help(model.text(title))
    }
}

struct NativePopoverBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let view = NSGlassEffectView()
            view.style = .regular
            return view
        }
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let model = Controller()

    func applicationDidFinishLaunching(_ notification: Notification) {
        popover.behavior = .transient
        popover.animates = true
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "Cursor Drift")
            button.toolTip = "Cursor Drift"
            button.target = self
            button.action = #selector(togglePopover)
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        let screen = button.window?.screen ?? NSScreen.main
        let available = screen?.visibleFrame.size ?? NSSize(width: 1024, height: 768)
        let dashboard = NSHostingController(rootView: Dashboard(model: model))
        let naturalHeight = dashboard.view.fittingSize.height
        let size = NSSize(width: min(380, available.width - 32),
                          height: min(naturalHeight, available.height - 48))
        let content = NSHostingController(rootView:
            ScrollView([.vertical, .horizontal]) {
                Dashboard(model: model)
            }.frame(width: size.width, height: size.height)

        )
        popover.contentViewController = content
        popover.contentSize = size
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) }
        else { showPopover() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { showPopover() }
        return false
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
