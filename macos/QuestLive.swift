import SwiftUI
import AppKit
import Foundation

struct Slot: Codable {
    var serial: String
    var address: String
    var eye: String
    var wide: Bool? = nil
}
struct Headset: Codable {
    var serial: String
    var address: String
    var model: String
    var w: Int
    var h: Int
    var override: String
}
struct Discovery: Codable {
    var found: [Headset]?
    var unauthorized: [String]?
    var networks: [String]?
    var error: String?
}
final class Controller: ObservableObject {
    static let shared = Controller()
    static let capacity = 4
    static let ru: [String:String] = [
        "Up to four headsets. One local network.":"До четырёх шлемов. Одна локальная сеть.",
        "Auto discovery • Wi-Fi • one eye • auto reconnect":"Автопоиск • Wi-Fi • один глаз • переподключение",
        "Start all":"Запустить все",
        "Stop all":"Остановить все",
        "Start":"Запустить",
        "Stop":"Стоп",
        "Headset":"Шлем",
        "Left":"Левый",
        "Right":"Правый",
        "Left eye":"Левый глаз",
        "Right eye":"Правый глаз",
        "Eye":"Глаз",
        "Quality":"Качество",
        "Searching…":"Поиск…",
        "Logs":"Журналы",
        "Wide crop 16:9":"Кадр 16:9",
        "Restart with current settings":"Перезапуск с текущими настройками",
        "Set up USB / Wi-Fi":"Настроить USB / Wi-Fi",
        "Mode":"Режим",
        "Fisheye":"Рыбий глаз",
        "Correction":"Коррекция",
        "Waiting":"Ожидание",
        "Stopped":"Остановлен",
        "Connect via USB to register":"Подключите USB для регистрации",
        "Finding headset…":"Поиск шлема…",
        "Finding headset...":"Поиск шлема…",
        "Reconnecting…":"Переподключение…",
        "Connection lost. Reconnecting...":"Связь потеряна. Переподключение…",
        "Approve debugging in the headset":"Подтвердите отладку в шлеме",
        "Retrying • use USB if needed":"Повтор поиска • при необходимости USB",
        "Not found. Retrying...":"Не найден. Повтор поиска…",
        "Waiting for network ADB. Use USB if needed.":"Ожидание ADB. При необходимости USB.",
        "Stream process started":"Процесс трансляции запущен",
        "Stream window open":"Окно трансляции открыто",
        "Starting video...":"Запуск изображения…",
        "Correction process started":"Процесс коррекции запущен",
        "Non-default display size: ":"Нестандартное разрешение: ",
        "Launch error: ":"Ошибка запуска: ",
        "Could not read settings: ":"Не удалось прочитать настройки: ",
        "Could not save settings: ":"Не удалось сохранить настройки: ",
        "Settings exceed supported capacity.":"Превышено количество поддерживаемых шлемов.",
        "Install ADB, scrcpy and Python 3.13 first (see README).":"Сначала установите ADB, scrcpy и Python 3.13 (см. README).",
        "Discovery in progress. Try again shortly.":"Идёт поиск. Повторите немного позже.",
        "Stop this headset before setup.":"Сначала остановите этот шлем.",
        "Stop this headset first.":"Сначала остановите этот шлем.",
        "Set up network ADB?":"Настроить сетевой ADB?",
        "Connect the correct Quest via USB and approve debugging. Use only a trusted private LAN.":"Подключите нужный Quest по USB и разрешите отладку. Только доверенная локальная сеть.",
        "Set up":"Настроить",
        "Cancel":"Отмена",
        "USB setup…":"Настройка USB…",
        "Not registered":"Не зарегистрирован",
        "Check USB debugging and Wi-Fi.":"Проверьте USB-отладку и Wi-Fi.",
        "Connect the headset first.":"Сначала подключите шлем.",
        "Connect the correct Quest via USB and approve debugging.":"Подключите нужный Quest по USB и разрешите отладку.",
        "Quest is not connected to Wi-Fi.":"Quest не подключён к Wi-Fi.",
        "Network ADB is not authorized. Check the headset prompt.":"ADB по сети не авторизован. Проверьте запрос в шлеме.",
        "Connect one Quest via USB and approve USB debugging in the headset.":"Подключите один Quest через USB и разрешите отладку.",
        "Headset already registered to another slot.":"Шлем уже назначен другому слоту.",
        "Different headset. Registration unchanged.":"Это другой шлем. Регистрация не изменена.",
        "Connect the headset to Wi-Fi.":"Подключите шлем к Wi-Fi.",
        "Enable network ADB? Use only a trusted private LAN.":"Включить сетевой ADB? Только доверенная локальная сеть.",
        "ADB timeout":"Тайм-аут ADB",
        "Correction needs ffplay. Install FFmpeg (see README).":"Для коррекции нужен ffplay. Установите FFmpeg (см. README).",
        "If a reboot disables network ADB, use USB / Wi-Fi setup. For a black screen, open a VR app and restart the stream.":"После перезагрузки при необходимости настройте USB / Wi-Fi. При чёрном экране запустите VR-приложение и перезапустите поток.",
        "Correction is approximate; switching modes restarts active streams.":"Коррекция приблизительная; смена режима перезапускает активные потоки."
    ]
    @Published var language = UserDefaults.standard.string(forKey:"language") ?? (Locale.preferredLanguages.first?.hasPrefix("ru") == true ? "RU" : "EN") {
        didSet { UserDefaults.standard.set(language,forKey:"language") }
    }
    @Published var corrected = UserDefaults.standard.bool(forKey:"corrected") {
        didSet {
            UserDefaults.standard.set(corrected,forKey:"corrected")
            if oldValue != corrected {
                for i in slots.indices where wanted[i] { restart(i) }
            }
        }
    }
    func tr(_ key:String)->String {
        guard language=="RU" else { return key }
        if let s=Self.ru[key] { return s }
        for (k,v) in Self.ru where k.hasSuffix(": ") && key.hasPrefix(k) { return v+key.dropFirst(k.count) }
        return key
    }

    let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ARIZONA Quest Live Public")
    let adb = "/opt/homebrew/bin/adb"
    let viewer = "/opt/homebrew/bin/scrcpy"
    let python = "/opt/homebrew/bin/python3.13"
    @Published var slots: [Slot] = []
    @Published var status = Array(repeating: "Waiting", count: Controller.capacity)
    @Published var running = Array(repeating:false,count:Controller.capacity)
    @Published var wanted = Array(repeating:false,count:Controller.capacity)
    @Published var searching = false
    @Published var wide = Array(repeating:false,count:Controller.capacity)
    @Published var quality = UserDefaults.standard.string(forKey:"quality") ?? "1600 / 30 FPS" {
        didSet {
            UserDefaults.standard.set(quality,forKey:"quality")
            if quality != oldValue { for i in slots.indices where wanted[i] { restart(i) } }
        }
    }
    @Published var alert = ""
    private var children: [Process?] = Array(repeating:nil,count:Controller.capacity)
    private var known: [Headset?] = Array(repeating:nil,count:Controller.capacity)
    private var retryAfter = Date.distantPast
    private var timer: Timer?
    private var helper: Process?
    private var started = false
    private var closing = false

    init() {
        do {
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            let url=root.appendingPathComponent("settings.json")
            if !FileManager.default.fileExists(atPath:url.path) {
                let empty=Array(repeating:Slot(serial:"",address:"",eye:"Left"),count:Self.capacity)
                try JSONEncoder().encode(empty).write(to:url,options:.atomic)
            }
            slots = try JSONDecoder().decode([Slot].self, from: Data(contentsOf:url))
        }
        catch { alert = "Could not read settings: \(error.localizedDescription)" }
        if slots.count > Self.capacity { alert="Settings exceed supported capacity."; slots=Array(slots.prefix(Self.capacity)) }
        while slots.count < Self.capacity { slots.append(Slot(serial:"",address:"",eye:"Left")) }
        wide = slots.map { $0.wide ?? false }
        if alert.isEmpty { save() }
    }
    func save() {
        do { try JSONEncoder().encode(slots).write(to: root.appendingPathComponent("settings.json"),options:.atomic) }
        catch { alert = "Could not save settings: \(error.localizedDescription)" }
    }
    func startOnce() {
        guard !started else { return }; started = true
        guard FileManager.default.isExecutableFile(atPath: adb), FileManager.default.isExecutableFile(atPath: viewer), FileManager.default.isExecutableFile(atPath:python) else {
            alert = "Install ADB, scrcpy and Python 3.13 first (see README)."; return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.8,repeats:true) { [weak self] _ in self?.tick() }
        startAll()
    }
    func startAll() { for i in slots.indices { start(i) } }
    func stopAll() { for i in slots.indices { stop(i) } }
    func start(_ i: Int) {
        guard !slots[i].serial.isEmpty else { status[i]="Connect via USB to register";return }
        wanted[i] = true
        if children[i] == nil { status[i] = "Finding headset…" }
        retryAfter = .distantPast
    }
    func stop(_ i: Int) {
        wanted[i] = false
        if let p = children[i], p.isRunning { p.terminate() }
        status[i] = "Stopped"; running[i] = false
    }
    func shutdown() {
        closing = true; timer?.invalidate(); stopAll()
        if let p = helper, p.isRunning { p.terminate() }
    }
    func tick() {
        guard !closing else { return }
        for i in 0..<Self.capacity {
            if let p = children[i], !p.isRunning {
                children[i] = nil; running[i] = false
                if wanted[i] { status[i] = "Reconnecting…"; retryAfter = Date().addingTimeInterval(2) }
            }
        }
        if !searching && Date() >= retryAfter && (0..<Self.capacity).contains(where: { wanted[$0] && children[$0] == nil }) {
            discover()
        }
    }
    func invoke(_ args: [String], completion: @escaping (Data?) -> Void) {
        guard !searching else { return }
        searching = true
        let p = Process(), pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: python)
        guard let script=Bundle.main.url(forResource:"discovery",withExtension:"py") else { searching=false;completion(nil);return }
        p.arguments = [script.path] + args
        p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        helper = p
        do { try p.run() } catch { searching = false; helper = nil; completion(nil); return }
        DispatchQueue.global(qos:.utility).async { [weak self] in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.closing else { return }
                self.searching = false; self.helper = nil
                completion(data)
            }
        }
    }
    func discover() {
        invoke(["discover"]) { [weak self] data in
            guard let self = self else { return }
            self.retryAfter = Date().addingTimeInterval(6)
            let result = data.flatMap { try? JSONDecoder().decode(Discovery.self, from:$0) }
            for i in 0..<Self.capacity where self.wanted[i] && self.children[i] == nil {
                if let d = result?.found?.first(where: { $0.serial == self.slots[i].serial }) {
                    self.known[i] = d
                    self.slots[i].address = d.address; self.save(); self.open(i,d)
                } else if let addr = result?.unauthorized, addr.contains(self.slots[i].address) {
                    self.status[i] = "Approve debugging in the headset"
                } else {
                    self.status[i] = "Retrying • use USB if needed"
                }
            }
        }
    }
    func open(_ i: Int,_ d: Headset) {
        guard wanted[i], children[i] == nil else { return }
        guard d.override.isEmpty else { status[i] = "Non-default display size: \(d.override)"; return }
        let half = d.w/2
        var w = half, h = d.h, x = slots[i].eye == "Right" ? half : 0, y = 0
        if wide[i] && !corrected { h = min(d.h, (half*9/16)/2*2); y = (d.h-h)/2 }
        w = w/2*2; x = x/2*2; y = y/2*2
        let maxSize = quality == "1080 / 30 FPS" ? "1080" : "1600"
        let fps = quality == "1600 / 60 FPS" ? "60" : "30"
        let rate = fps == "60" ? "8M" : (maxSize == "1080" ? "3M" : "5M")
        let p = Process()
        let captureArgs = ["--serial=\(d.address)","--crop=\(w):\(h):\(x):\(y)","--no-audio","--no-control","--video-codec=h264","--max-size=\(maxSize)","--max-fps=\(fps)","--video-bit-rate=\(rate)","--window-height=600","--window-title=ARIZONA-Quest-\(i+1)"]
        if corrected {
            guard FileManager.default.isExecutableFile(atPath:"/opt/homebrew/bin/ffplay"),
                  let script=Bundle.main.url(forResource:"lens_viewer",withExtension:"py") else {
                status[i]="Correction needs ffplay. Install FFmpeg (see README).";wanted[i]=false;return
            }
            p.executableURL=URL(fileURLWithPath:python)
            p.arguments=[script.path,String(ProcessInfo.processInfo.processIdentifier),"ARIZONA-Quest-\(i+1)",wide[i] ? "wide":"normal"] + captureArgs
        } else {
            p.executableURL=URL(fileURLWithPath:viewer);p.arguments=captureArgs
        }
        var env = ProcessInfo.processInfo.environment; env["ADB"] = adb
        env["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"; p.environment = env
        let log = root.appendingPathComponent("headset-\(i+1).log")
        _ = FileManager.default.createFile(atPath:log.path,contents:nil)
        if let f = try? FileHandle(forWritingTo:log) { p.standardOutput=f; p.standardError=f }
        do { try p.run(); children[i]=p; running[i]=true; status[i]=corrected ? "Correction process started":"Stream process started" }
        catch { status[i]="Launch error: \(error.localizedDescription)" }
    }
    func configureUSB(_ i: Int) {
        if searching { alert="Discovery in progress. Try again shortly."; return }
        if children[i] != nil { alert="Stop this headset before setup."; return }
        let a=NSAlert(); a.messageText=tr("Set up network ADB?")
        a.informativeText=tr("Connect the correct Quest via USB and approve debugging. Use only a trusted private LAN.")
        a.addButton(withTitle:tr("Set up"));a.addButton(withTitle:tr("Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        wanted[i]=false; status[i]="USB setup…"
        invoke(["usb",slots[i].serial] + slots.indices.filter{$0 != i}.map{slots[$0].serial}) { [weak self] data in
            guard let self=self else{return}
            if let data=data, let d=try? JSONDecoder().decode(Headset.self,from:data), (self.slots[i].serial.isEmpty || d.serial==self.slots[i].serial), !self.slots.indices.contains(where:{$0 != i && self.slots[$0].serial == d.serial}) {
                self.slots[i].serial=d.serial;self.slots[i].address=d.address;self.save();self.start(i)
            } else {
                let r=data.flatMap {try? JSONDecoder().decode(Discovery.self,from:$0)}
                self.status[i]="Not registered";self.alert=r?.error ?? "Check USB debugging and Wi-Fi."
            }
        }
    }
    func graffiti(_ i: Int) {
        guard let d=known[i] else { alert="Connect the headset first.";return }
        let p=Process();p.executableURL=URL(fileURLWithPath:adb)
        p.arguments=["-s",d.address,"shell","am","start","-n","com.vrite.Graffism/com.unity3d.player.UnityPlayerActivity"]
        p.standardOutput=FileHandle.nullDevice;p.standardError=FileHandle.nullDevice
        do{try p.run()}catch{alert=error.localizedDescription}
    }
    func setEye(_ i:Int,_ value:String) {
        guard slots[i].eye != value else { return }
        slots[i].eye=value;save()
        if wanted[i] { restart(i) }
    }
    func setWide(_ i:Int,_ value:Bool) {
        guard wide[i] != value else { return }
        wide[i]=value;slots[i].wide=value;save()
        if wanted[i] { restart(i) }
    }
    func restart(_ i: Int) { guard !slots[i].serial.isEmpty else { status[i]="Connect via USB to register";return }; if let p=children[i],p.isRunning{p.terminate()};wanted[i]=true;retryAfter = .distantPast }
}
// Template artwork: circular bowed grid for the original view, straight grid for correction.
private enum ModeArtwork {
    static let fisheye = make(false)
    static let correction = make(true)
    private static func make(_ corrected: Bool) -> NSImage {
        let image = NSImage(size:NSSize(width:20,height:20),flipped:false) { _ in
            let outline = corrected
                ? NSBezierPath(roundedRect:NSRect(x:2,y:2,width:16,height:16),xRadius:1.4,yRadius:1.4)
                : NSBezierPath(ovalIn:NSRect(x:2,y:2,width:16,height:16))
            NSGraphicsContext.saveGraphicsState()
            outline.addClip()
            NSColor.black.setStroke()
            let grid = NSBezierPath();grid.lineWidth=0.85
            for v in [CGFloat(6),10,14] {
                grid.move(to:NSPoint(x:v,y:1))
                if corrected { grid.line(to:NSPoint(x:v,y:19)) }
                else { grid.curve(to:NSPoint(x:v,y:19),controlPoint1:NSPoint(x:10+(v-10)*1.65,y:7),controlPoint2:NSPoint(x:10+(v-10)*1.65,y:13)) }
                grid.move(to:NSPoint(x:1,y:v))
                if corrected { grid.line(to:NSPoint(x:19,y:v)) }
                else { grid.curve(to:NSPoint(x:19,y:v),controlPoint1:NSPoint(x:7,y:10+(v-10)*1.65),controlPoint2:NSPoint(x:13,y:10+(v-10)*1.65)) }
            }
            grid.stroke()
            NSGraphicsContext.restoreGraphicsState()
            NSColor.black.setStroke();outline.lineWidth=1.25;outline.stroke()
            return true
        }
        image.isTemplate=true
        return image
    }
}
struct ContentView: View {
    @ObservedObject var c=Controller.shared
    @State private var expanded: Set<Int> = []
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                VStack(alignment:.leading,spacing:5){
                    Text("ARIZONA  /  QUEST LIVE").font(.system(size:26,weight:.heavy,design:.rounded))
                    Text(c.tr("Up to four headsets. One local network.")).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment:.trailing,spacing:5) {
                    HStack(spacing:2) {
                        segment("RU",selected:c.language=="RU"){c.language="RU"} label:{Text("RU").font(.system(size:12,weight:.medium))}
                        segment("EN",selected:c.language=="EN"){c.language="EN"} label:{Text("EN").font(.system(size:12,weight:.medium))}
                    }.padding(1).background(Color.white.opacity(0.08),in:RoundedRectangle(cornerRadius:6))
                    HStack(spacing:8) {
                        Text(c.tr("Mode")).font(.callout).foregroundStyle(.secondary)
                        HStack(spacing:2) {
                            segment(c.tr("Fisheye"),selected:!c.corrected){c.corrected=false} label:{Image(nsImage:ModeArtwork.fisheye)}
                            segment(c.tr("Correction"),selected:c.corrected){c.corrected=true} label:{Image(nsImage:ModeArtwork.correction)}
                        }.padding(1).background(Color.white.opacity(0.08),in:RoundedRectangle(cornerRadius:6))
                    }
                }
            }
            HStack(spacing:12) {
                Button{c.startAll()}label:{Label(c.tr("Start all"),systemImage:"play.fill").frame(maxWidth:.infinity)}
                    .buttonStyle(.borderedProminent).tint(.green)
                Button{c.stopAll()}label:{Label(c.tr("Stop all"),systemImage:"stop.fill").frame(maxWidth:.infinity)}.buttonStyle(.bordered)
            }.controlSize(.large)
            HStack(alignment:.top,spacing:12){card(0);card(1)}
            HStack(alignment:.top,spacing:12){card(2);card(3)}
            HStack {
                Text(c.tr("Quality")).foregroundStyle(.secondary)
                Picker("",selection:$c.quality){ForEach(["1080 / 30 FPS","1600 / 30 FPS","1600 / 60 FPS"],id:\.self){Text($0)}}.labelsHidden().frame(width:180)
                Spacer()
                if c.searching { ProgressView().controlSize(.small);Text(c.tr("Searching…")).foregroundStyle(.secondary) }
                Button(c.tr("Logs")){NSWorkspace.shared.open(c.root)}
            }
            Text(c.tr("If a reboot disables network ADB, use USB / Wi-Fi setup. For a black screen, open a VR app and restart the stream.")+" "+c.tr("Correction is approximate; switching modes restarts active streams.")).font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width:720).fixedSize(horizontal:false,vertical:true)
            .preferredColorScheme(.dark)
            .onAppear{c.startOnce()}
            .alert("Quest Live",isPresented:Binding(get:{!c.alert.isEmpty},set:{if !$0{c.alert=""}})){Button("OK"){c.alert=""}}message:{Text(c.tr(c.alert))}
    }
    private func segment<V:View>(_ name:String,selected:Bool,action:@escaping ()->Void,@ViewBuilder label:()->V)->some View {
        Button(action:action) {
            label().frame(width:44,height:25)
                .foregroundStyle(selected ? Color.white:Color.primary)
                .background(selected ? Color.accentColor:Color.clear,in:RoundedRectangle(cornerRadius:5))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(Text(name))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .help(name)
    }
    func card(_ i:Int)->some View {
        VStack(alignment:.leading,spacing:6){
            if i>=2 {
                Button {
                    if expanded.contains(i) { expanded.remove(i) } else { expanded.insert(i) }
                } label: {
                    HStack(spacing:8) {
                        Image(systemName:"visionpro").font(.title3).foregroundStyle(c.running[i] ? Color.green:Color.secondary)
                        Text("\(c.tr("Headset")) \(i+1)").font(.headline)
                        Spacer()
                        Circle().fill(c.running[i] ? Color.green:Color.gray).frame(width:8,height:8)
                        Image(systemName:expanded.contains(i) ? "chevron.up":"chevron.down").foregroundStyle(.secondary)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(Text("\(c.tr("Headset")) \(i+1)"))
            } else {
                HStack {
                    Image(systemName:"visionpro").font(.title3).foregroundStyle(c.running[i] ? .green:.secondary)
                    Text("\(c.tr("Headset")) \(i+1)").font(.headline);Spacer()
                    Circle().fill(c.running[i] ? Color.green:Color.gray).frame(width:8,height:8)
                }
            }
            if i<2 || expanded.contains(i) {
            Text(c.tr(c.status[i])).font(.callout).frame(height:19,alignment:.topLeading)
                .foregroundStyle(c.running[i] ? Color.green:Color.secondary)
            Text(c.slots[i].address).font(.caption.monospaced()).foregroundStyle(.secondary)
            Picker(c.tr("Eye"),selection:Binding(get:{c.slots[i].eye},set:{c.setEye(i,$0)})){
                Text(c.tr("Left")).tag("Left");Text(c.tr("Right")).tag("Right")
            }.pickerStyle(.segmented)
            Toggle(c.tr("Wide crop 16:9"),isOn:Binding(get:{c.wide[i]},set:{c.setWide(i,$0)})).toggleStyle(.switch).controlSize(.small)
            HStack{
                Button(c.tr("Start")){c.start(i)}.buttonStyle(.borderedProminent).tint(.green)
                Button(c.tr("Stop")){c.stop(i)}
                Button{c.restart(i)}label:{Image(systemName:"arrow.clockwise")}.help(c.tr("Restart with current settings"))
            }
            HStack{
                Button("USB / Wi-Fi"){c.configureUSB(i)}
                Button("Graffism"){c.graffiti(i)}
            }
            }
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
        .background(Color.white.opacity(0.055),in:RoundedRectangle(cornerRadius:16))
    }
}
final class Delegate:NSObject,NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
    func applicationWillTerminate(_ notification:Notification){Controller.shared.shutdown()}
}
@main struct QuestLiveApp: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene {
        WindowGroup("ARIZONA Quest Live"){ContentView()}.windowResizability(.contentSize)
    }
}