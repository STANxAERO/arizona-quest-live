"""Explicitly staged engine updates. No firmware changes or automatic installs."""
import json, os, re, sys, pathlib, tempfile, subprocess, urllib.request, hashlib, tarfile, shutil, datetime
ROOT=pathlib.Path.home()/"Library/Application Support/ARIZONA Quest Live Public"
ENG=ROOT/"engines"; STATE=ENG/"state.json"; ADB="/opt/homebrew/bin/adb"; FALLBACK="/opt/homebrew/bin/scrcpy"
TAG=re.compile(r"v\d+\.\d+(?:\.\d+)?$")
def run(args,timeout=12):
    p=subprocess.run(args,text=True,capture_output=True,timeout=timeout)
    if p.returncode:raise RuntimeError((p.stderr or p.stdout or "Command failed")[-700:])
    return p.stdout.strip()
def read(p,default):
    if not p.exists():return default
    return json.loads(p.read_text())
def write(p,obj):
    p.parent.mkdir(parents=True,exist_ok=True)
    fd,tmp=tempfile.mkstemp(dir=p.parent)
    with os.fdopen(fd,"w") as f:json.dump(obj,f)
    os.replace(tmp,p)
def state():return read(STATE,{"active":"","previous":"","candidate":"","tested":""})
def engine(tag):
    if not tag:return FALLBACK
    if not TAG.fullmatch(tag):raise ValueError("Invalid engine tag")
    p=ENG/tag/"scrcpy"
    if not p.is_file():raise RuntimeError("Engine unavailable")
    return str(p)
def api(path):
    req=urllib.request.Request("https://api.github.com/repos/"+path,headers={"User-Agent":"ARIZONA-Quest-Live","Accept":"application/vnd.github+json"})
    with urllib.request.urlopen(req,timeout=12) as r:return json.load(r)
def latest():
    r=api("Genymobile/scrcpy/releases/latest");tag=r["tag_name"]
    if not TAG.fullmatch(tag):raise ValueError("Unexpected upstream release")
    name=f"scrcpy-macos-aarch64-{tag}.tar.gz"
    a=next(x for x in r["assets"] if x["name"]==name)
    digest=a.get("digest","")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}",digest):raise ValueError("Missing official digest")
    return tag,name,digest[7:]
def check():
    st=state();version=run([engine(st["active"]),"--version"]).splitlines()[0]
    tag,_,_=latest()
    releases=api("STANxAERO/arizona-quest-live/releases?per_page=10")
    app=next((r["tag_name"] for r in releases if not r["draft"]),"")
    return dict(engine=version,latest=tag,app=app,active=st["active"],candidate=st["candidate"],tested=st["tested"],previous=st["previous"])
def stage():
    tag,name,digest=latest();ENG.mkdir(parents=True,exist_ok=True)
    target=ENG/tag
    if not target.exists():
        with tempfile.TemporaryDirectory(dir=ENG) as td:
            path=pathlib.Path(td)/name
            url=f"https://github.com/Genymobile/scrcpy/releases/download/{tag}/{name}"
            with urllib.request.urlopen(url,timeout=30) as r,open(path,"wb") as f:
                shutil.copyfileobj(r,f)
            if hashlib.sha256(path.read_bytes()).hexdigest()!=digest:raise ValueError("SHA-256 mismatch")
            unpack=pathlib.Path(td)/"unpack";unpack.mkdir()
            with tarfile.open(path) as z:
                for x in z.getmembers():
                    q=pathlib.PurePosixPath(x.name)
                    if q.is_absolute() or ".." in q.parts or not (x.isdir() or x.isfile()):raise ValueError("Unsafe archive member")
                z.extractall(unpack,filter="data")
            folder=unpack/f"scrcpy-macos-aarch64-{tag}"
            exe=folder/"scrcpy"
            if not exe.is_file() or not (folder/"scrcpy-server").is_file():raise ValueError("Invalid archive")
            v=run([str(exe),"--version"])
            if not v.startswith("scrcpy "+tag[1:]+" "):raise ValueError("Version mismatch")
            helptext=run([str(exe),"--help"])
            for arg in ("--crop","--no-window","--no-playback","--record-format","--time-limit"):
                if arg not in helptext:raise ValueError("Missing option "+arg)
            folder.rename(target)
    st=state()
    if st["active"]!=tag:
        st.update(candidate=tag,tested="");write(STATE,st)
    return {"message":"Staged "+tag+"; current engine unchanged."}
def headset(i):
    slots=read(ROOT/"settings.json",[])
    if not 0<=i<len(slots) or not slots[i]["serial"]:raise ValueError("Slot not registered")
    slot=slots[i];addr=slot["address"]
    if not re.fullmatch(r"\d+\.\d+\.\d+\.\d+:\d+",addr):raise ValueError("Invalid address")
    if run([ADB,"-s",addr,"get-state"])!="device":raise RuntimeError("ADB unavailable")
    def prop(key):return run([ADB,"-s",addr,"shell","getprop",key])
    if prop("ro.serialno")!=slot["serial"]:raise RuntimeError("Wrong headset")
    size=run([ADB,"-s",addr,"shell","wm","size"])
    return addr,{"model":prop("ro.product.model"),"android":prop("ro.build.version.release"),"build":prop("ro.build.version.incremental"),"size":size,"adb":"device"}
def diagnose(i,candidate=False,capture=False):
    st=state()
    if candidate:
        st.update(tested="",tested_build="",tested_slot=None);write(STATE,st)
    addr,d=headset(i)
    tag=st["candidate"] if candidate else st["active"]
    if candidate and not tag:raise RuntimeError("Stage an engine first")
    d["engine"]=run([engine(tag),"--version"]).splitlines()[0]
    if not capture:return d
    if "Override size:" in d["size"]:raise RuntimeError("Non-default display size")
    m=re.search(r"Physical size:\s*(\d+)x(\d+)",d["size"]);w,h=map(int,m.groups())
    if w%4 or h%2 or w<h:raise RuntimeError("Invalid display size")
    with tempfile.TemporaryDirectory(prefix="arizona-diagnostic-") as tmp:
        f=str(pathlib.Path(tmp)/"capture.mkv")
        env=dict(os.environ,ADB=ADB)
        p=subprocess.run([engine(tag),"--serial="+addr,"--crop=%d:%d:0:0"%(w//2,h),"--no-audio","--no-control","--no-window","--no-playback","--max-size=1080","--max-fps=30","--time-limit=4","--record="+f],env=env,capture_output=True,text=True,timeout=18)
        if p.returncode or not os.path.isfile(f):raise RuntimeError("Capture failed: "+p.stderr[-400:])
        # Count decoded frames and reject predominantly black output. No recording is retained.
        frames=int(run(["/opt/homebrew/bin/ffprobe","-v","error","-count_frames","-select_streams","v:0","-show_entries","stream=nb_read_frames","-of","csv=p=0",f],12))
        p=subprocess.run(["/opt/homebrew/bin/ffmpeg","-hide_banner","-i",f,"-vf","blackframe=amount=98:threshold=32","-an","-f","null","-"],capture_output=True,text=True,timeout=15)
        black=len(re.findall(r"\bpblack:",p.stderr))
        passed=p.returncode==0 and frames>=10 and (frames-black)>=max(5,frames//10)
        d.update(frames=frames,black_frames=black,passed=passed)
        if candidate and passed:
            st.update(tested=tag,tested_build=d["build"],tested_slot=i);write(STATE,st)
    return d
def switch(action):
    st=state()
    if action=="activate":
        tag=st["candidate"]
        if not tag or st["tested"]!=tag:raise RuntimeError("Candidate must pass capture test")
        if tag==st["active"]:raise RuntimeError("Already active")
        if st.get("tested_slot") is None or headset(st["tested_slot"])[1]["build"]!=st.get("tested_build"):raise RuntimeError("Firmware changed or test expired; test candidate again")
    else:
        if not st["active"]:raise RuntimeError("No prior managed engine")
        tag=st["previous"]
    run([engine(tag),"--version"])
    st.update(previous=st["active"],active=tag,candidate="",tested="",tested_build="",tested_slot=None)
    write(STATE,st);return {"message":"Selected "+(tag or "original engine")}
def main():
    a=sys.argv[1]
    if a=="check":return check()
    if a=="stage":return stage()
    if a in ("diagnose","capture","test"):return diagnose(int(sys.argv[2]),a=="test",a!="diagnose")
    if a in ("activate","rollback"):return switch(a)
    raise ValueError("Unknown action")
if __name__=="__main__":
    try:print(json.dumps(main()))
    except Exception as e:print(json.dumps({"error":str(e)}));sys.exit(1)
