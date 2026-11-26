param([switch]$NoAuto,[switch]$Check)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root=$PSScriptRoot
$capacity=4
$mutex=New-Object Threading.Mutex($false,'Local\ArizonaQuestLivePublic')
if(!$mutex.WaitOne(0)){return}
$data=Join-Path $env:LOCALAPPDATA 'ARIZONA Quest Live Public'
New-Item -ItemType Directory -Path $data -Force | Out-Null
$settings=Join-Path $data 'settings.json'
if(!(Test-Path -LiteralPath $settings)){ @(1..$capacity | ForEach-Object { [pscustomobject]@{serial="";address="";eye="Left"} }) | ConvertTo-Json | Set-Content -LiteralPath $settings -Encoding UTF8 }
$cfg=@(ConvertFrom-Json -InputObject (Get-Content $settings -Raw -Encoding UTF8) | ForEach-Object {$_})
if($cfg.Count -gt $capacity){throw 'Settings exceed supported capacity'}
if($cfg.Count -lt $capacity){
 Copy-Item -LiteralPath $settings -Destination ($settings+'.v01-backup')
 while($cfg.Count -lt $capacity){$cfg+= [pscustomobject]@{serial="";address="";eye="Left"}}
 $cfg | ConvertTo-Json | Set-Content -LiteralPath $settings -Encoding UTF8
}
if($Check){ Write-Output ('Settings initialized: '+$cfg.Count); $mutex.ReleaseMutex();$mutex.Dispose();return }
$viewer=Join-Path $root 'scrcpy\scrcpy.exe'
$adb=Join-Path $root 'scrcpy\adb.exe'
$p=Get-Process adb -ErrorAction SilentlyContinue|Select-Object -First 1
if($p -and $p.Path){$adb=$p.Path}
$env:ADB=$adb
function Save-Cfg {
 $tmp=$settings+'.new'
 $cfg|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $tmp -Encoding UTF8
 [IO.File]::Replace($tmp,$settings,($settings+'.previous'))
}
function Adb([string[]]$a,[int]$timeout=6000){
 $p=New-Object Diagnostics.Process
 $p.StartInfo.FileName=$adb;$p.StartInfo.Arguments=$a -join ' '
 $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 try{
  [void]$p.Start();$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
  if(!$p.WaitForExit($timeout)){$p.Kill();throw 'ADB timeout'}
  $p.WaitForExit();if($p.ExitCode -ne 0){throw $e.Result}
  return $o.Result.Trim()
 }finally{$p.Dispose()}
}
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$form.Text='ARIZONA | QUEST LIVE 4'
$form.StartPosition='CenterScreen';$form.ClientSize=New-Object Drawing.Size(720,665)
$form.FormBorderStyle='FixedSingle';$form.MaximizeBox=$false
$form.BackColor=[Drawing.Color]::FromArgb(24,26,30);$form.ForeColor=[Drawing.Color]::White
$form.Font=New-Object Drawing.Font('Segoe UI',10)
function Label($text,$x,$y,$w,$h){
 $l=New-Object Windows.Forms.Label;$l.Text=$text;$l.SetBounds($x,$y,$w,$h);$l.ForeColor=$form.ForeColor;$form.Controls.Add($l);return $l
}
function Button($text,$x,$y,$w,$h){
 $b=New-Object Windows.Forms.Button;$b.Text=$text;$b.SetBounds($x,$y,$w,$h);$b.FlatStyle='Flat';$b.BackColor=[Drawing.Color]::FromArgb(46,50,56);$b.ForeColor=[Drawing.Color]::White;$form.Controls.Add($b);return $b
}
$h=Label 'QUEST LIVE / ARIZONA' 20 14 680 38
$h.Font=New-Object Drawing.Font('Segoe UI',21,[Drawing.FontStyle]::Bold)
$null=Label 'Auto discovery • Wi-Fi • one eye • auto reconnect' 22 56 680 25
$all=Button '▶ Start all' 20 90 335 40
$all.BackColor=[Drawing.Color]::FromArgb(27,112,66)
$stopAll=Button 'Stop all' 365 90 335 40
$slots=@();$streams=@($null)*$capacity;$want=@($false)*$capacity;$missing=@(0)*$capacity
$state=@{job=$null;out=$null;err=$null;next=[datetime]::MinValue;closing=$false}
function Stop-Slot([int]$i){
 $want[$i]=$false;$p=$streams[$i]
 if($p){if(!$p.HasExited){if(!$p.CloseMainWindow()){$p.Kill()}}}
 $slots[$i].status.Text='Stopped'
}
function Request-Slot([int]$i){
 if(!$cfg[$i].serial){$slots[$i].status.Text='Connect via USB to register';return}
 $want[$i]=$true;$state.next=[datetime]::MinValue
 if(!$streams[$i] -or $streams[$i].HasExited){$slots[$i].status.Text='Finding headset...'}
}
function Open-Viewer([int]$i,$info){
 if(!$want[$i] -or ($streams[$i] -and !$streams[$i].HasExited)){return}
 if($info.override){$slots[$i].status.Text='Non-default display size: '+$info.override;return}
 $cfg[$i].address=$info.address;$slots[$i].addr.Text=$info.address
 $cfg[$i].eye=if($slots[$i].eye.SelectedIndex -eq 1){'Right'}else{'Left'}
 Save-Cfg
 $half=[int]($info.w/2);$x=if($cfg[$i].eye -eq 'Right'){$half}else{0}
 $crop='{0}:{1}:{2}:0' -f $half,$info.h,$x
 $p=New-Object Diagnostics.Process
 $p.StartInfo.FileName=$viewer;$p.StartInfo.WorkingDirectory=Split-Path $viewer
 $p.StartInfo.Arguments="--serial=$($info.address) --crop=$crop --no-audio --no-control --video-codec=h264 --max-size=1600 --max-fps=30 --video-bit-rate=5M --window-height=660 --window-title=ARIZONA-Quest-$($i+1)"
 $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 [void]$p.Start();$streams[$i]=$p;$missing[$i]=0
 $slots[$i].status.Text='Starting video...'
}
for($i=0;$i -lt $capacity;$i++){
 $x=20+345*($i%2)
 $dy=250*[int][Math]::Floor($i/2)
 $title=Label ("Headset "+($i+1)) $x (148+$dy) 335 27
 $title.Font=New-Object Drawing.Font('Segoe UI',14,[Drawing.FontStyle]::Bold)
 $addr=Label ([string]$cfg[$i].address) $x (181+$dy) 335 25
 $addr.ForeColor=[Drawing.Color]::LightGray
 $eye=New-Object Windows.Forms.ComboBox;$eye.SetBounds($x,(210+$dy),335,30);$eye.DropDownStyle='DropDownList'
 [void]$eye.Items.Add('Left eye');[void]$eye.Items.Add('Right eye');$eye.SelectedIndex=0
 if($cfg[$i].eye -eq 'Right'){$eye.SelectedIndex=1};$form.Controls.Add($eye)
 $go=Button 'Start' $x (250+$dy) 210 36;$stop=Button 'Stop' ($x+220) (250+$dy) 115 36
 $usb=Button 'Set up USB / Wi-Fi' $x (294+$dy) 335 32
 $status=Label $(if($cfg[$i].serial){'Stopped'}else{'Connect via USB to register'}) $x (336+$dy) 335 45
 $slots+=@{addr=$addr;eye=$eye;go=$go;stop=$stop;usb=$usb;status=$status}
 $go.Tag=$i;$stop.Tag=$i;$usb.Tag=$i
 $go.Add_Click({param($sender,$e) Request-Slot ([int]$sender.Tag)})
 $stop.Add_Click({param($sender,$e) Stop-Slot ([int]$sender.Tag)})
 $usb.Add_Click({
  param($sender,$e)
  $j=[int]$sender.Tag
  try{
   if($streams[$j] -and !$streams[$j].HasExited){throw 'Stop this headset first.'}
   $list=Adb @('devices','-l')
   $ids=@($list -split '\r?\n'|ForEach-Object{if($_ -match '^([A-Za-z0-9]+)\s+device\s+.*model:Quest'){$Matches[1]}})
   if($ids.Count -ne 1){throw 'Connect one Quest via USB and approve USB debugging in the headset.'}
   $id=$ids[0];$serial=Adb @('-s',$id,'shell','getprop','ro.serialno')
   if(!$serial -or @($cfg | Where-Object {$_.serial -eq $serial}).Count -gt $(if($cfg[$j].serial -eq $serial){1}else{0})){throw 'Headset already registered to another slot.'}
   if($cfg[$j].serial -and $cfg[$j].serial -ne $serial){throw 'Different headset. Registration unchanged.'}
   $net=Adb @('-s',$id,'shell','ip','-4','addr','show','wlan0')
   if($net -notmatch 'inet\s+(\d+\.\d+\.\d+\.\d+)/'){throw 'Connect the headset to Wi-Fi.'}
   $address=$Matches[1]+':5555'
   $answer=[Windows.Forms.MessageBox]::Show('Enable network ADB? Use only a trusted private LAN.','Quest Live','YesNo','Question')
   if($answer -ne 'Yes'){return}
   $want[$j]=$false
   $null=Adb @('-s',$id,'tcpip','5555')
   $cfg[$j].serial=$serial;$cfg[$j].address=$address;Save-Cfg
   $slots[$j].addr.Text=$address;Request-Slot $j
  }catch{$slots[$j].status.Text='USB: '+$_.Exception.Message}
 })
}
$all.Add_Click({for($k=0;$k -lt $capacity;$k++){Request-Slot $k}})
$stopAll.Add_Click({for($k=0;$k -lt $capacity;$k++){Stop-Slot $k}})
function Begin-Discovery {
 $p=New-Object Diagnostics.Process
 $p.StartInfo.FileName=Join-Path $PSHOME 'powershell.exe'
 $p.StartInfo.Arguments='-NoProfile -ExecutionPolicy RemoteSigned -File "'+(Join-Path $root 'DiscoverQuest.ps1')+'" -Settings "'+$settings+'"'
 $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 [void]$p.Start();$state.job=$p;$state.out=$p.StandardOutput.ReadToEndAsync();$state.err=$p.StandardError.ReadToEndAsync()
 $state.started=[datetime]::Now
}
$timer=New-Object Windows.Forms.Timer;$timer.Interval=700
$timer.Add_Tick({
 try{
  for($j=0;$j -lt $capacity;$j++){
   $p=$streams[$j]
   if($p -and $p.HasExited){
    $p.Dispose();$streams[$j]=$null
    if($want[$j]){$slots[$j].status.Text='Connection lost. Reconnecting...';$state.next=[datetime]::Now.AddSeconds(2)}
   }elseif($p -and $want[$j]){
    $p.Refresh()
    if($p.MainWindowHandle -ne 0){$slots[$j].status.Text='Stream window open'}
   }
  }
  if($state.job){
   if(!$state.job.HasExited -and ([datetime]::Now-$state.started).TotalSeconds -gt 65){$state.job.Kill()}
   if($state.job.HasExited){
    $p=$state.job;$p.WaitForExit();$raw=$state.out.Result;$p.Dispose();$state.job=$null
    $state.next=[datetime]::Now.AddSeconds(7)
    $result=$null
    if($raw){$result=ConvertFrom-Json -InputObject $raw}
    for($j=0;$j -lt $capacity;$j++){
     if(!$want[$j] -or ($streams[$j] -and !$streams[$j].HasExited)){continue}
     $info=@($result.found|Where-Object{$_.serial -eq $cfg[$j].serial})|Select-Object -First 1
     if($info){Open-Viewer $j $info}
     else{$missing[$j]++;$slots[$j].status.Text='Not found. Retrying...';if($missing[$j] -ge 2){$slots[$j].status.Text='Waiting for network ADB. Use USB if needed.'}}
    }
   }
  }elseif([datetime]::Now -ge $state.next){
   $need=$false
   for($j=0;$j -lt $capacity;$j++){if($want[$j] -and !$streams[$j]){$need=$true}}
   if($need){Begin-Discovery}
  }
 }catch{$state.next=[datetime]::Now.AddSeconds(7);$form.Text='ARIZONA | QUEST LIVE 4 - retrying'}
})
$form.Add_Shown({if(!$NoAuto){for($k=0;$k -lt $capacity;$k++){Request-Slot $k}};$timer.Start()})
$form.Add_FormClosed({
 $timer.Stop();$timer.Dispose()
 if($state.job -and !$state.job.HasExited){$state.job.Kill()}
 for($j=0;$j -lt $capacity;$j++){Stop-Slot $j}
})
try{[void]$form.ShowDialog()}finally{$mutex.ReleaseMutex();$mutex.Dispose()}