using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
static class Launcher {
    [STAThread] static void Main() {
        try {
            string root=AppDomain.CurrentDomain.BaseDirectory;
            string ps=Path.Combine(Environment.SystemDirectory,"WindowsPowerShell","v1.0","powershell.exe");
            if(!File.Exists(Path.Combine(root,"scrcpy","scrcpy.exe"))) {
                if(MessageBox.Show("Download the official scrcpy 5.0.1 runtime from GitHub? Internet access is needed once.","ARIZONA Quest Live",MessageBoxButtons.YesNo,MessageBoxIcon.Question)!=DialogResult.Yes) return;
                using(var setup=Process.Start(new ProcessStartInfo(ps,"-NoProfile -ExecutionPolicy RemoteSigned -File \""+Path.Combine(root,"Setup.ps1")+"\""){UseShellExecute=true,WorkingDirectory=root})) {
                    setup.WaitForExit();
                    if(setup.ExitCode!=0 || !File.Exists(Path.Combine(root,"scrcpy","scrcpy.exe"))) throw new Exception("Setup failed. See the README for offline setup and troubleshooting.");
                }
            }
            Process.Start(new ProcessStartInfo(ps,"-NoProfile -STA -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File \""+Path.Combine(root,"QuestLive.ps1")+"\""){UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=root});
        } catch(Exception e){MessageBox.Show(e.Message,"ARIZONA Quest Live",MessageBoxButtons.OK,MessageBoxIcon.Error);}
    }
}
