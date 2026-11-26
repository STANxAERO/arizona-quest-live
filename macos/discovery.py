import concurrent.futures, ipaddress, json, os, re, socket, subprocess, sys, time
from pathlib import Path
ADB="/opt/homebrew/bin/adb"
ROOT=Path.home()/"Library/Application Support/ARIZONA Quest Live Public"
def run(*args, timeout=4):
    try:
        p=subprocess.run([ADB,*args],capture_output=True,text=True,timeout=timeout)
        return p.stdout.strip() if p.returncode==0 else ""
    except (OSError,subprocess.TimeoutExpired): return ""
def devices():
    return {m[1]:m[2] for line in run("devices","-l").splitlines() if (m:=re.match(r"^(\S+)\s+(device|offline|unauthorized)\b",line))}
def info(addr):
    if run("-s",addr,"get-state")!="device": return None
    serial=run("-s",addr,"shell","getprop","ro.serialno")
    model=run("-s",addr,"shell","getprop","ro.product.model")
    size=run("-s",addr,"shell","wm","size")
    m=re.search(r"Physical size:\s*(\d+)x(\d+)",size)
    if not serial or "Quest" not in model or not m: return None
    w,h=map(int,m.groups())
    if w<h or w%4 or h%2: return None
    override=re.search(r"Override size:\s*(\d+x\d+)",size)
    return dict(serial=serial,address=addr,model=model,w=w,h=h,override=override[1] if override else "",build=run("-s",addr,"shell","getprop","ro.build.version.incremental"))
def local_networks():
    raw=subprocess.run(["/sbin/ifconfig"],capture_output=True,text=True).stdout
    networks=set()
    for block in re.split(r"(?m)^(?=\S+:\s)",raw):
        if not re.match(r"en\d+:",block) or "status: active" not in block: continue
        for ip,mask in re.findall(r"\binet (\d+\.\d+\.\d+\.\d+) netmask (0x[0-9a-f]+)",block):
            if not any(ipaddress.ip_address(ip) in ipaddress.ip_network(n) for n in ("10.0.0.0/8","172.16.0.0/12","192.168.0.0/16")):continue
            network=ipaddress.ip_network((ip,int(mask,16).bit_count()),strict=False)
            # Bound discovery to directly connected local /24 or smaller.
            if network.prefixlen>=24:networks.add(network)
            else:networks.add(ipaddress.ip_network(ip+"/24",strict=False))
    return networks
def port(ip):
    try:
        with socket.create_connection((str(ip),5555),timeout=.35):return str(ip)+":5555"
    except OSError:return None
def discover(force=False):
    cfg=json.loads((ROOT/"settings.json").read_text())
    wanted={s["serial"] for s in cfg if s["serial"]}
    initial=devices(); found={}; tried=set(); auth=[]
    def probe(addr,connect=True):
        if addr in tried:return
        tried.add(addr)
        if connect and initial.get(addr)!="device":run("connect",addr,timeout=4)
        state=devices().get(addr)
        if state=="unauthorized":auth.append(addr);return
        d=info(addr)
        if d and d["serial"] in wanted:found[d["serial"]]=d
        elif d and addr not in initial:run("disconnect",addr)
    if not force:
        for addr,state in initial.items():
            if ":" in addr and state in ("device","unauthorized"):probe(addr,False)
        for slot in cfg:
            if slot["serial"] and slot["serial"] not in found and slot["address"]:
                try:
                    ip=ipaddress.ip_address(slot["address"].rsplit(":",1)[0])
                    if any(ip in net for net in local_networks()):probe(slot["address"])
                except ValueError:pass
    nets=[]
    if wanted-found.keys():
        for net in sorted(local_networks(),key=str):
            nets.append(str(net))
            with concurrent.futures.ThreadPoolExecutor(max_workers=32) as pool:
                for addr in pool.map(port,net.hosts()):
                    if addr:probe(addr)
                    if wanted<=found.keys():break
            if wanted<=found.keys():break
    print(json.dumps(dict(found=list(found.values()),unauthorized=auth,networks=nets)))
def usb(serial,others):
    ids=[a for a,s in devices().items() if ":" not in a and not a.startswith("emulator") and s=="device"]
    candidates=[d for a in ids if (d:=info(a)) and (not serial or d["serial"]==serial) and d["serial"] not in others]
    if len(candidates)!=1:raise RuntimeError("Connect the correct Quest via USB and approve debugging.")
    d=candidates[0];a=d["address"]
    net=run("-s",a,"shell","ip","-4","addr","show","wlan0")
    m=re.search(r"inet\s+(\d+\.\d+\.\d+\.\d+)/",net)
    if not m:raise RuntimeError("Quest is not connected to Wi-Fi.")
    addr=m[1]+":5555"
    run("-s",a,"tcpip","5555");time.sleep(2);run("connect",addr,timeout=6)
    verified=info(addr)
    if not verified or verified["serial"]!=d["serial"]:raise RuntimeError("Network ADB is not authorized. Check the headset prompt.")
    print(json.dumps(verified))
if __name__=="__main__":
    try:
        if sys.argv[1]=="usb":usb(sys.argv[2],sys.argv[3:])
        else:discover("--force" in sys.argv)
    except Exception as e:
        print(json.dumps({"error":str(e)}));sys.exit(1)