using System;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
static class LensViewer {
    const string Filter="lenscorrection=k1=-0.10:k2=0:i=bilinear,crop=trunc(iw*0.82/2)*2:trunc(ih*0.82/2)*2";
    [StructLayout(LayoutKind.Sequential)] struct Basic {public long A,B;public uint Flags;public UIntPtr C,D;public uint E;public UIntPtr F;public uint G,H;}
    [StructLayout(LayoutKind.Sequential)] struct IO {public ulong A,B,C,D,E,F;}
    [StructLayout(LayoutKind.Sequential)] struct Extended {public Basic Basic;public IO IO;public UIntPtr A,B,C,D;}
    [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr a,string b);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr j,int c,ref Extended e,uint n);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr j,IntPtr p);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    static string Q(string s){return "\""+s.Replace("\"","\\\"")+"\"";}
    static string log;
    static readonly object logLock=new object();
    static void Log(string msg) {try{lock(logLock){File.AppendAllText(log,DateTime.Now.ToString("s")+" "+msg+Environment.NewLine);}}catch{}}
    static Process Spawn(IntPtr job,ProcessStartInfo psi){ 
        psi.RedirectStandardError=true;psi.RedirectStandardOutput=true;
        var p=Process.Start(psi);
        if(!AssignProcessToJobObject(job,p.Handle)){try{p.Kill();}catch{}throw new IOException("Cannot supervise viewer process");}
        p.ErrorDataReceived+=(sender,e)=>{if(e.Data!=null)Log(e.Data);};p.OutputDataReceived+=(sender,e)=>{if(e.Data!=null)Log(e.Data);};p.BeginErrorReadLine();p.BeginOutputReadLine();return p;
    }
    [STAThread] static int Main(string[] a) {
        if(a.Length<5)return 2;
        log=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"ARIZONA Quest Live Public","lens-"+a[4]+".log");
        Log("Starting correction helper");
        IntPtr job=CreateJobObject(IntPtr.Zero,null);
        if(job==IntPtr.Zero)return 3;
        var ext=new Extended();ext.Basic.Flags=0x2000; // Kill on job close.
        if(!SetInformationJobObject(job,9,ref ext,(uint)Marshal.SizeOf(typeof(Extended)))){Log("SetInformationJobObject "+Marshal.GetLastWin32Error());CloseHandle(job);return 3;}
        string name="ArizonaLens"+Guid.NewGuid().ToString("N");
        try{
            using(var parent=Process.GetProcessById(int.Parse(a[0])))
            using(var pipe=new NamedPipeServerStream(name,PipeDirection.In,1,PipeTransmissionMode.Byte,PipeOptions.Asynchronous)){
                string filter=Filter+(a[3]=="wide"?",crop=iw:trunc(iw*9/16/2)*2":"");
                string playArgs="-hide_banner -loglevel warning -autoexit -framedrop -sync video -probesize 65536 -analyzeduration 0 -f matroska -vf "+Q(filter)+" -window_title "+Q(a[4])+" -y 600 -i pipe:0";
                var play=Spawn(job,new ProcessStartInfo(a[1],playArgs){UseShellExecute=false,CreateNoWindow=true,RedirectStandardInput=true});
                string capArgs=string.Join(" ",a,5,a.Length-5)+" --no-window --no-playback --record-format=mkv --record=\\\\.\\pipe\\"+name;
                var cap=Spawn(job,new ProcessStartInfo(a[2],capArgs){UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=Path.GetDirectoryName(a[2])});
                var connect=pipe.WaitForConnectionAsync();
                for(int t=0;!connect.IsCompleted && t<100;t++){if(parent.HasExited||play.HasExited||cap.HasExited){Log("Child exited before pipe connection");return 4;}Thread.Sleep(100);}
                if(!connect.IsCompleted||connect.IsFaulted){Log("Pipe connection failed");return 4;}
                var pump=pipe.CopyToAsync(play.StandardInput.BaseStream);
                while(!parent.HasExited&&!play.HasExited&&!cap.HasExited&&!pump.IsCompleted)Thread.Sleep(200);
                Log("Pipeline ended; capture="+cap.HasExited+" player="+play.HasExited+" pump="+pump.Status);return 0;
            }
        }catch(Exception e){Log(e.ToString());return 5;}finally{CloseHandle(job);}
    }
}
