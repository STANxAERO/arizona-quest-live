"""Local-only live lens correction using a private FIFO. No video file is retained."""
import os, signal, subprocess, sys, tempfile, time
from pathlib import Path
FILTER="lenscorrection=k1=-0.10:k2=0:i=bilinear,crop=trunc(iw*0.82/2)*2:trunc(ih*0.82/2)*2"
def main():
    if len(sys.argv)<5: return 2
    parent=int(sys.argv[1]);title=sys.argv[2];wide=sys.argv[3]=="wide";args=sys.argv[4:]
    stop=False;children=[]
    def halt(*_):
        nonlocal stop
        stop=True
    signal.signal(signal.SIGTERM,halt);signal.signal(signal.SIGINT,halt)
    vf=FILTER
    if wide:vf+=",crop=iw:trunc(iw*9/16/2)*2"
    with tempfile.TemporaryDirectory(prefix="arizona-lens-") as td:
        fifo=str(Path(td)/"stream.mkv");os.mkfifo(fifo,0o600)
        try:
            play=subprocess.Popen(["/opt/homebrew/bin/ffplay","-hide_banner","-loglevel","warning","-autoexit","-framedrop","-sync","video","-probesize","65536","-analyzeduration","0","-f","matroska","-vf",vf,"-window_title",title,"-y","600","-i",fifo])
            children.append(play)
            capture=subprocess.Popen([os.environ.get("QUEST_SCRCPY","/opt/homebrew/bin/scrcpy"),*args,"--no-window","--no-playback","--record-format=mkv","--record="+fifo])
            children.append(capture)
            while not stop and os.getppid()==parent and all(p.poll() is None for p in children):time.sleep(.2)
        finally:
            for p in children:
                if p.poll() is None:p.terminate()
            for p in children:
                try:p.wait(timeout=2)
                except subprocess.TimeoutExpired:p.kill();p.wait()
    return 0
if __name__=="__main__":sys.exit(main())
