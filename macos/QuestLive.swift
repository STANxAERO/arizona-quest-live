import SwiftUI
import AppKit
import Foundation

struct Slot: Codable {
    var serial: String
    var address: String
    var eye: String
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
    let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ARIZONA Quest Live Public")
    let adb = "/opt/homebrew/bin/adb"
    let viewer = "/opt/homebrew/bin/scrcpy"
    let python = "/opt/homebrew/bin/python3.13"
    @Published var slots: [Slot] = []
    @Published var status = ["Waiting", "Waiting"]
    @Published var running = [false,false]
    @Published var wanted = [false,false]
    @Published var searching = false
    @Published var wide = [false,false]
    @Published var quality = "1600 / 30 FPS"
    @Published var alert = ""
    private var children: [Process?] = [nil,nil]
    private var known: [Headset?] = [nil,nil]
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
                let empty=[Slot(serial:"",address:"",eye:"Left"),Slot(serial:"",address:"",eye:"Left")]
                try JSONEncoder().encode(empty).write(to:url,options:.atomic)
            }
            slots = try JSONDecoder().decode([Slot].self, from: Data(contentsOf:url))
        }
        catch { alert = "Could not read settings: \(error.localizedDescription)" }
        if slots.count != 2 { slots = [Slot(serial:"",address:"",eye:"Left"),Slot(serial:"",address:"",eye:"Left")] }
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
    func startAll() { start(0); start(1) }
    func stopAll() { stop(0); stop(1) }
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
        for i in 0..<2 {
            if let p = children[i], !p.isRunning {
                children[i] = nil; running[i] = false
                if wanted[i] { status[i] = "Reconnecting…"; retryAfter = Date().addingTimeInterval(2) }
            }
        }
        if !searching && Date() >= retryAfter && (0..<2).contains(where: { wanted[$0] && children[$0] == nil }) {
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
            for i in 0..<2 where self.wanted[i] && self.children[i] == nil {
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
        if wide[i] { h = min(d.h, (half*9/16)/2*2); y = (d.h-h)/2 }
        w = w/2*2; x = x/2*2; y = y/2*2
        let maxSize = quality == "1080 / 30 FPS" ? "1080" : "1600"
        let fps = quality == "1600 / 60 FPS" ? "60" : "30"
        let rate = fps == "60" ? "8M" : "5M"
        let p = Process()
        p.executableURL = URL(fileURLWithPath:viewer)
        p.arguments = ["--serial=\(d.address)","--crop=\(w):\(h):\(x):\(y)","--no-audio","--no-control","--video-codec=h264","--max-size=\(maxSize)","--max-fps=\(fps)","--video-bit-rate=\(rate)","--window-height=600","--window-title=ARIZONA-Quest-\(i+1)"]
        var env = ProcessInfo.processInfo.environment; env["ADB"] = adb
        env["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"; p.environment = env
        let log = root.appendingPathComponent("headset-\(i+1).log")
        _ = FileManager.default.createFile(atPath:log.path,contents:nil)
        if let f = try? FileHandle(forWritingTo:log) { p.standardOutput=f; p.standardError=f }
        do { try p.run(); children[i]=p; running[i]=true; status[i]="Stream process started" }
        catch { status[i]="Launch error: \(error.localizedDescription)" }
    }
    func configureUSB(_ i: Int) {
        if searching { alert="Discovery in progress. Try again shortly."; return }
        if children[i] != nil { alert="Stop this headset before setup."; return }
        let a=NSAlert(); a.messageText="Set up network ADB?"
        a.informativeText="Connect the correct Quest via USB and approve debugging. Use only a trusted private LAN."
        a.addButton(withTitle:"Set up");a.addButton(withTitle:"Cancel")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        wanted[i]=false; status[i]="USB setup…"
        invoke(["usb",slots[i].serial,slots[1-i].serial]) { [weak self] data in
            guard let self=self else{return}
            if let data=data, let d=try? JSONDecoder().decode(Headset.self,from:data), (self.slots[i].serial.isEmpty || d.serial==self.slots[i].serial), d.serial != self.slots[1-i].serial {
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
    func restart(_ i: Int) { guard !slots[i].serial.isEmpty else { status[i]="Connect via USB to register";return }; if let p=children[i],p.isRunning{p.terminate()};wanted[i]=true;retryAfter = .distantPast }
}
struct ContentView: View {
    @ObservedObject var c=Controller.shared
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack {
                VStack(alignment:.leading,spacing:5){
                    Text("ARIZONA  /  QUEST LIVE").font(.system(size:26,weight:.heavy,design:.rounded))
                    Text("Two headsets. One local network.").foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName:"wifi").font(.system(size:28)).foregroundStyle(.green)
            }
            HStack(spacing:12) {
                Button{c.startAll()}label:{Label("Start both",systemImage:"play.fill").frame(maxWidth:.infinity)}
                    .buttonStyle(.borderedProminent).tint(.green)
                Button{c.stopAll()}label:{Label("Stop both",systemImage:"stop.fill").frame(maxWidth:.infinity)}.buttonStyle(.bordered)
            }.controlSize(.large)
            HStack(spacing:14){card(0);card(1)}
            HStack {
                Text("Quality").foregroundStyle(.secondary)
                Picker("",selection:$c.quality){ForEach(["1080 / 30 FPS","1600 / 30 FPS","1600 / 60 FPS"],id:\.self){Text($0)}}.labelsHidden().frame(width:180)
                Spacer()
                if c.searching { ProgressView().controlSize(.small);Text("Searching…").foregroundStyle(.secondary) }
                Button("Logs"){NSWorkspace.shared.open(c.root)}
            }
            Text("If a reboot disables network ADB, use USB / Wi-Fi setup. For a black screen, open a VR app and restart the stream.").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width:720,height:465)
            .preferredColorScheme(.dark)
            .onAppear{c.startOnce()}
            .alert("Quest Live",isPresented:Binding(get:{!c.alert.isEmpty},set:{if !$0{c.alert=""}})){Button("OK"){c.alert=""}}message:{Text(c.alert)}
    }
    func card(_ i:Int)->some View {
        VStack(alignment:.leading,spacing:12){
            HStack {
                Image(systemName:"visionpro").font(.title2).foregroundStyle(c.running[i] ? .green:.secondary)
                Text("Headset \(i+1)").font(.title2.bold());Spacer()
                Circle().fill(c.running[i] ? Color.green:Color.gray).frame(width:9,height:9)
            }
            Text(c.status[i]).font(.callout).frame(height:34,alignment:.topLeading)
                .foregroundStyle(c.running[i] ? Color.green:Color.secondary)
            Text(c.slots[i].address).font(.caption.monospaced()).foregroundStyle(.secondary)
            Picker("Eye",selection:Binding(get:{c.slots[i].eye},set:{c.slots[i].eye=$0;c.save()})){
                Text("Left").tag("Left");Text("Right").tag("Right")
            }.pickerStyle(.segmented)
            Toggle("Wide crop 16:9",isOn:$c.wide[i]).toggleStyle(.switch).controlSize(.small)
            HStack{
                Button("Start"){c.start(i)}.buttonStyle(.borderedProminent).tint(.green)
                Button("Stop"){c.stop(i)}
                Button{c.restart(i)}label:{Image(systemName:"arrow.clockwise")}.help("Restart with current settings")
            }
            HStack{
                Button("USB / Wi-Fi"){c.configureUSB(i)}
                Button("Graffism"){c.graffiti(i)}
            }
        }.padding(16).frame(maxWidth:.infinity,alignment:.leading)
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