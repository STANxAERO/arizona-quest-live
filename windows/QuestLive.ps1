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
foreach($entry in $cfg){if(!$entry.PSObject.Properties['wide']){$entry|Add-Member -NotePropertyName wide -NotePropertyValue $false}}
foreach($entry in $cfg){if(!$entry.PSObject.Properties['lastBuild']){$entry|Add-Member -NotePropertyName lastBuild -NotePropertyValue ''}}
foreach($entry in $cfg){if(!$entry.PSObject.Properties['firmwarePending']){$entry|Add-Member -NotePropertyName firmwarePending -NotePropertyValue $false}}
if($Check){ Write-Output ('Settings initialized: '+$cfg.Count); $mutex.ReleaseMutex();$mutex.Dispose();return }
$viewer=Join-Path $root 'scrcpy\scrcpy.exe'
function Get-Viewer {
 $f=Join-Path $data 'engines\state.json'
 if(Test-Path $f){try{$st=ConvertFrom-Json -InputObject (Get-Content $f -Raw -Encoding UTF8);if($st.active -match '^v\d+\.\d+(\.\d+)?$'){$p=Join-Path $data ('engines\'+$st.active+'\scrcpy.exe');if(Test-Path $p){return $p}}}catch{}}
 return (Join-Path $root 'scrcpy\scrcpy.exe')
}
$adb=Join-Path $root 'scrcpy\adb.exe'
$p=Get-Process adb -ErrorAction SilentlyContinue|Select-Object -First 1
if($p -and $p.Path){$adb=$p.Path}
$env:ADB=$adb

$prefs=Join-Path $data 'preferences.json'
$uiState=@{language=if([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'ru'){'RU'}else{'EN'};corrected=$false;quality='1600 / 30 FPS'}
if(Test-Path -LiteralPath $prefs){try{$pr=ConvertFrom-Json -InputObject (Get-Content -LiteralPath $prefs -Raw -Encoding UTF8);if($pr.language -in @('RU','EN')){$uiState.language=$pr.language};$uiState.corrected=[bool]$pr.corrected;if($pr.quality -in @('1080 / 30 FPS','1600 / 30 FPS','1600 / 60 FPS')){$uiState.quality=$pr.quality}}catch{}}
$ru=@{
 'Up to four headsets. One local network.'='До четырёх шлемов. Одна локальная сеть.'
 'Auto discovery • Wi-Fi • one eye • auto reconnect'='Автопоиск • Wi-Fi • один глаз • переподключение'
 'Start all'='Запустить все'
 'Stop all'='Остановить все'
 'Start'='Запустить'
 'Stop'='Стоп'
 'Headset'='Шлем'
 'Left'='Левый'
 'Right'='Правый'
 'Left eye'='Левый глаз'
 'Right eye'='Правый глаз'
 'Eye'='Глаз'
 'Quality'='Качество'
 'Searching…'='Поиск…'
 'Logs'='Журналы'
 'Wide crop 16:9'='Кадр 16:9'
 'Applying video settings...'='Применение настроек видео…'
 'Restart with current settings'='Перезапуск с текущими настройками'
 'Set up USB / Wi-Fi'='Настроить USB / Wi-Fi'
 'Mode'='Режим'
 'Fisheye'='Рыбий глаз'
 'Correction'='Коррекция'
 'Waiting'='Ожидание'
 'Stopped'='Остановлен'
 'Connect via USB to register'='Подключите USB для регистрации'
 'Finding headset…'='Поиск шлема…'
 'Reconnecting…'='Переподключение…'
 'Approve debugging in the headset'='Подтвердите отладку в шлеме'
 'Retrying • use USB if needed'='Повтор поиска • при необходимости USB'
 'Not found. Retrying...'='Не найден. Повтор поиска…'
 'Waiting for network ADB. Use USB if needed.'='Ожидание ADB. При необходимости USB.'
 'Stream process started'='Процесс трансляции запущен'
 'Starting video...'='Запуск изображения…'
 'Correction process started'='Процесс коррекции запущен'
 'Non-default display size: '='Нестандартное разрешение: '
 'Launch error: '='Ошибка запуска: '
 'Could not read settings: '='Не удалось прочитать настройки: '
 'Could not save settings: '='Не удалось сохранить настройки: '
 'Settings exceed supported capacity.'='Превышено количество поддерживаемых шлемов.'
 'Install ADB, scrcpy and Python 3.13 first (see README).'='Сначала установите ADB, scrcpy и Python 3.13 (см. README).'
 'Discovery in progress. Try again shortly.'='Идёт поиск. Повторите немного позже.'
 'Stop this headset before setup.'='Сначала остановите этот шлем.'
 'Stop this headset first.'='Сначала остановите этот шлем.'
 'Set up network ADB?'='Настроить сетевой ADB?'
 'Connect the correct Quest via USB and approve debugging. Use only a trusted private LAN.'='Подключите нужный Quest по USB и разрешите отладку. Только доверенная локальная сеть.'
 'Set up'='Настроить'
 'Cancel'='Отмена'
 'USB setup…'='Настройка USB…'
 'Not registered'='Не зарегистрирован'
 'Check USB debugging and Wi-Fi.'='Проверьте USB-отладку и Wi-Fi.'
 'Connect the headset first.'='Сначала подключите шлем.'
 'Connect the correct Quest via USB and approve debugging.'='Подключите нужный Quest по USB и разрешите отладку.'
 'Quest is not connected to Wi-Fi.'='Quest не подключён к Wi-Fi.'
 'Network ADB is not authorized. Check the headset prompt.'='ADB по сети не авторизован. Проверьте запрос в шлеме.'
 'Connect one Quest via USB and approve USB debugging in the headset.'='Подключите один Quest через USB и разрешите отладку.'
 'Headset already registered to another slot.'='Шлем уже назначен другому слоту.'
 'Different headset. Registration unchanged.'='Это другой шлем. Регистрация не изменена.'
 'Connect the headset to Wi-Fi.'='Подключите шлем к Wi-Fi.'
 'Enable network ADB? Use only a trusted private LAN.'='Включить сетевой ADB? Только доверенная локальная сеть.'
 'ADB timeout'='Тайм-аут ADB'
 'Correction needs ffplay. Install FFmpeg (see README).'='Для коррекции нужен ffplay. Установите FFmpeg (см. README).'
 'If a reboot disables network ADB, use USB / Wi-Fi setup. For a black screen, open a VR app and restart the stream.'='После перезагрузки при необходимости настройте USB / Wi-Fi. При чёрном экране запустите VR-приложение и перезапустите поток.'
 'Correction is approximate; switching modes restarts active streams.'='Коррекция приблизительная; смена режима перезапускает активные потоки.'
}
function Tr([string]$key){
 if($uiState.language -ne 'RU'){return $key}
 if($ru.ContainsKey($key)){return $ru[$key]}
 foreach($k in $ru.Keys){if($k.EndsWith(': ') -and $key.StartsWith($k)){return $ru[$k]+$key.Substring($k.Length)}}
 return $key
}
function Save-Prefs { $uiState|ConvertTo-Json|Set-Content -LiteralPath $prefs -Encoding UTF8 }
function Set-Status([int]$i,[string]$key){$slots[$i].statusKey=$key;$slots[$i].status.Text=(Tr $key);$slots[$i].status.ForeColor=$(if($key -in @('Stream process started','Correction process started')){$runningColor}else{$mutedColor});$slots[$i].title.Invalidate()}

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
$iconPath=Join-Path $root 'AppIcon-A.ico'
if(Test-Path -LiteralPath $iconPath){$form.Icon=New-Object Drawing.Icon($iconPath)}
$form.Text='ARIZONA Quest Live'
$form.StartPosition='CenterScreen';$form.ClientSize=New-Object Drawing.Size(720,476)
$form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::Dpi
$form.FormBorderStyle='FixedSingle';$form.MaximizeBox=$false
$form.BackColor=[Drawing.Color]::FromArgb(29,29,29);$form.ForeColor=[Drawing.Color]::FromArgb(231,231,231)
$panelColor=[Drawing.Color]::FromArgb(40,40,40)
$idleColor=[Drawing.Color]::FromArgb(56,56,56)
$accentColor=[Drawing.Color]::FromArgb(0,122,255)
$selectedColor=[Drawing.Color]::FromArgb(82,82,82)
$mutedColor=[Drawing.Color]::FromArgb(160,160,160)
$runningColor=[Drawing.Color]::FromArgb(48,209,88)
$headerControlColor=[Drawing.Color]::FromArgb(47,47,47)
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using System.Runtime.InteropServices;
public static class QuestRounded {
 [DllImport("uxtheme.dll",CharSet=CharSet.Unicode)] static extern int SetWindowTheme(IntPtr h,string app,string id);
 public static void DarkScroll(Control c){try{SetWindowTheme(c.Handle,"DarkMode_Explorer",null);}catch{}}
 [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h,int a,ref int v,int n);
 public static void DarkTitle(Form f){int one=1,caption=0x242424,text=0xe7e7e7,border=0x363636;try{
 DwmSetWindowAttribute(f.Handle,20,ref one,4);DwmSetWindowAttribute(f.Handle,35,ref caption,4);DwmSetWindowAttribute(f.Handle,36,ref text,4);DwmSetWindowAttribute(f.Handle,34,ref border,4);
 }catch{}}
 public class DarkMenuColors:ProfessionalColorTable {
  public override Color ToolStripDropDownBackground{get{return Color.FromArgb(47,47,47);}}
  public override Color ImageMarginGradientBegin{get{return ToolStripDropDownBackground;}}
  public override Color ImageMarginGradientMiddle{get{return ToolStripDropDownBackground;}}
  public override Color ImageMarginGradientEnd{get{return ToolStripDropDownBackground;}}
  public override Color MenuItemSelected{get{return Color.FromArgb(70,70,70);}}
  public override Color MenuItemSelectedGradientBegin{get{return MenuItemSelected;}}
  public override Color MenuItemSelectedGradientEnd{get{return MenuItemSelected;}}
  public override Color MenuItemBorder{get{return MenuItemSelected;}}
  public override Color MenuBorder{get{return Color.FromArgb(66,66,66);}}
  public override Color CheckBackground{get{return Color.FromArgb(82,82,82);}}
  public override Color CheckSelectedBackground{get{return CheckBackground;}}
 }
 public static void Glyph(Graphics g,string kind,float x,float y,Color col){
  var state=g.Save();g.TranslateTransform(x,y);g.SmoothingMode=SmoothingMode.AntiAlias;
  using(var pen=new Pen(col,1.6f)){pen.StartCap=LineCap.Round;pen.EndCap=LineCap.Round;pen.LineJoin=LineJoin.Round;
   using(var brush=new SolidBrush(col)){
    if(kind=="play"){g.FillPolygon(brush,new[]{new PointF(3,1),new PointF(13,7),new PointF(3,13)});}
    else if(kind=="stop"){g.FillRectangle(brush,2,2,11,11);}
    else if(kind=="restart"){g.DrawArc(pen,2,3,11,11,-65,305);g.DrawLines(pen,new[]{new PointF(9,1),new PointF(13,3),new PointF(10,6)});}
    else if(kind=="down"){g.DrawLines(pen,new[]{new PointF(2,5),new PointF(7,10),new PointF(12,5)});}
    else if(kind=="up"){g.DrawLines(pen,new[]{new PointF(2,9),new PointF(7,4),new PointF(12,9)});}
    else if(kind=="headset"){
     using(var p=new GraphicsPath()){p.AddBezier(1,7,1,1,6,1,11,1);p.AddBezier(11,1,16,1,21,1,21,7);p.AddBezier(21,7,21,14,16,14,13,10);p.AddBezier(13,10,12,9,10,9,9,10);p.AddBezier(9,10,5,14,1,14,1,7);p.CloseFigure();g.DrawPath(pen,p);}
    }
   }
  }g.Restore(state);
 }
 public static void Switch(Graphics g,bool on,int w,int h){
  g.SmoothingMode=SmoothingMode.AntiAlias;
  using(var p=new GraphicsPath()){p.AddArc(0,1,h-2,h-2,90,180);p.AddArc(w-h+2,1,h-2,h-2,270,180);p.CloseFigure();using(var b=new SolidBrush(on?Color.FromArgb(48,209,88):Color.FromArgb(63,63,63)))g.FillPath(b,p);}
  using(var b=new SolidBrush(Color.White))g.FillEllipse(b,on?w-h+3:3,3,h-6,h-6);
 }
 public static Bitmap Icon(string kind,Color col){var b=new Bitmap(15,15);using(var g=Graphics.FromImage(b)){Glyph(g,kind,0,0,col);}return b;}
 public static void Apply(Control c,int radius) {
  if(c.Width<2||c.Height<2)return;
  int d=Math.Min(radius*2,Math.Min(c.Width,c.Height));
  using(var p=new GraphicsPath()){
   p.AddArc(0,0,d,d,180,90);p.AddArc(c.Width-d,0,d,d,270,90);
   p.AddArc(c.Width-d,c.Height-d,d,d,0,90);p.AddArc(0,c.Height-d,d,d,90,90);p.CloseFigure();
   Region old=c.Region;c.Region=new Region(p);if(old!=null)old.Dispose();
  }
 }
}
'@

$form.Font=New-Object Drawing.Font('Segoe UI',10)
[QuestRounded]::DarkTitle($form)
function Label($text,$x,$y,$w,$h){
 $l=New-Object Windows.Forms.Label;$l.Text=(Tr $text);$l.Name=$text;$l.SetBounds($x,$y,$w,$h);$l.ForeColor=$form.ForeColor;$form.Controls.Add($l);return $l
}
function Button($text,$x,$y,$w,$h){
 $b=New-Object Windows.Forms.Button;$b.Text=(Tr $text);$b.Name=$text;$b.SetBounds($x,$y,$w,$h);$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0;$b.BackColor=$idleColor;$b.ForeColor=$form.ForeColor;$b.UseVisualStyleBackColor=$false;$form.Controls.Add($b);[QuestRounded]::Apply($b,7);return $b
}
$h=Label 'ARIZONA  /  QUEST LIVE' 20 20 515 32
$h.Font=New-Object Drawing.Font('Segoe UI Black',19,[Drawing.FontStyle]::Regular)
$subtitle=Label 'Up to four headsets. One local network.' 20 56 505 22
$subtitle.ForeColor=$mutedColor
$all=Button 'Start all' 20 90 334 28
$stopAll=Button 'Stop all' 366 90 334 28
foreach($b in @($all,$stopAll)){$b.BackColor=$headerControlColor;[QuestRounded]::Apply($b,14);$b.TextImageRelation='ImageBeforeText';$b.ImageAlign='MiddleCenter';$b.TextAlign='MiddleCenter'}
$all.Image=[QuestRounded]::Icon('play',$form.ForeColor);$stopAll.Image=[QuestRounded]::Icon('stop',$form.ForeColor)
$ruBtn=Button 'RU' 608 20 44 26;$enBtn=Button 'EN' 654 20 44 26
$modeLabel=Label 'Mode' 520 52 80 26
$modeLabel.TextAlign=[Drawing.ContentAlignment]::MiddleRight
$modeLabel.ForeColor=[Drawing.Color]::LightGray
$fishBtn=Button '' 608 52 44 26;$corrBtn=Button '' 654 52 44 26
$fishBtn.Name='FisheyeIcon';$corrBtn.Name='CorrectionIcon'
$fishBtn.Tag=$false;$corrBtn.Tag=$true
foreach($top in @(19,51)){
 $bg=New-Object Windows.Forms.Panel;$bg.SetBounds(607,$top,92,28);$bg.BackColor=$headerControlColor;$form.Controls.Add($bg);$bg.SendToBack();[QuestRounded]::Apply($bg,6)
}
$modeTips=New-Object Windows.Forms.ToolTip
foreach($btn in @($fishBtn,$corrBtn)){
 $btn.Add_Paint({
  param($sender,$e)
  $g=$e.Graphics;$saved=$g.Save()
  $outline=New-Object Drawing.Drawing2D.GraphicsPath
  $pen=New-Object Drawing.Pen([Drawing.Color]::White,1.15)
  $grid=New-Object Drawing.Pen([Drawing.Color]::White,0.85)
  try {
   $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
   $x=[single](($sender.ClientSize.Width-18)/2);$y=[single](($sender.ClientSize.Height-18)/2)
   $g.TranslateTransform($x,$y)
   if($sender.Tag){$outline.AddRectangle([Drawing.RectangleF]::new(1,1,16,16))}
   else{$outline.AddEllipse([single]1,[single]1,[single]16,[single]16)}
   $g.SetClip($outline)
   foreach($v in @(5,9,13)){
    if($sender.Tag){$g.DrawLine($grid,[single]$v,[single]0,[single]$v,[single]18);$g.DrawLine($grid,[single]0,[single]$v,[single]18,[single]$v)}
    else{
     $b=[single](9+($v-9)*1.65)
     $g.DrawBezier($grid,[single]$v,[single]0,$b,[single]6,$b,[single]12,[single]$v,[single]18)
     $g.DrawBezier($grid,[single]0,[single]$v,[single]6,$b,[single]12,$b,[single]18,[single]$v)
    }
   }
   $g.ResetClip();$g.DrawPath($pen,$outline)
  }finally{$g.Restore($saved);$outline.Dispose();$pen.Dispose();$grid.Dispose()}
 })
}
$slots=@();$streams=@($null)*$capacity;$want=@($false)*$capacity;$missing=@(0)*$capacity;$expanded=@($true,$true,$false,$false)
$state=@{job=$null;out=$null;err=$null;next=[datetime]::MinValue;closing=$false}
function Stop-Slot([int]$i){
 $want[$i]=$false;$p=$streams[$i]
 if($p){if(!$p.HasExited){if(!$p.CloseMainWindow()){$p.Kill()}}}
 Set-Status $i 'Stopped'
}
function Request-Slot([int]$i){
 if(!$cfg[$i].serial){Set-Status $i 'Connect via USB to register';return}
 $want[$i]=$true;$state.next=[datetime]::MinValue
 if(!$streams[$i] -or $streams[$i].HasExited){Set-Status $i 'Finding headset…'}
}
function Open-Viewer([int]$i,$info){
 $viewer=Get-Viewer
 if(!$want[$i] -or ($streams[$i] -and !$streams[$i].HasExited)){return}
 if($info.override){Set-Status $i ('Non-default display size: '+$info.override);return}
 if($info.build){
  if($cfg[$i].lastBuild -and $cfg[$i].lastBuild -ne $info.build){$cfg[$i].firmwarePending=$true;$checkState.firmware=$true;$maintenanceBtn.Name='Firmware •';$maintenanceBtn.Text=Tr $maintenanceBtn.Name}
  $cfg[$i].lastBuild=$info.build
 }
 $cfg[$i].address=$info.address;$slots[$i].addr.Text=$info.address
 Save-Cfg
 $half=[int]($info.w/2);$x=if($cfg[$i].eye -eq 'Right'){$half}else{0}
 $height=[int]$info.h;$y=0
 if($cfg[$i].wide -and !$uiState.corrected){$height=[int]([Math]::Floor(($half*9/16)/2)*2);$y=[int]([Math]::Floor((($info.h-$height)/2)/2)*2)}
 $crop='{0}:{1}:{2}:{3}' -f $half,$height,$x,$y
 $p=New-Object Diagnostics.Process
 $p.StartInfo.FileName=$viewer;$p.StartInfo.WorkingDirectory=Split-Path $viewer
 $maxSize=if($uiState.quality -eq '1080 / 30 FPS'){1080}else{1600}
 $fps=if($uiState.quality -eq '1600 / 60 FPS'){60}else{30}
 $rate=if($fps -eq 60){'8M'}elseif($maxSize -eq 1080){'3M'}else{'5M'}
 $capArgs="--serial=$($info.address) --crop=$crop --no-audio --no-control --video-codec=h264 --max-size=$maxSize --max-fps=$fps --video-bit-rate=$rate --window-height=600 --window-title=ARIZONA-Quest-$($i+1)"
 if($uiState.corrected){
  $ff=Get-Command ffplay.exe -ErrorAction SilentlyContinue
  $helper=Join-Path $root 'LensViewer.exe'
  if(!$ff -or !(Test-Path -LiteralPath $helper)){Set-Status $i 'Correction needs ffplay. Install FFmpeg (see README).';$want[$i]=$false;return}
  $p.StartInfo.FileName=$helper
  $wideArg=if($cfg[$i].wide){'wide'}else{'normal'}
  $p.StartInfo.Arguments="$PID ""$($ff.Source)"" ""$viewer"" $wideArg ARIZONA-Quest-$($i+1) $capArgs"
 }else{$p.StartInfo.Arguments=$capArgs}
 $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 [void]$p.Start();$streams[$i]=$p;$missing[$i]=0
 Set-Status $i $(if($uiState.corrected){'Correction process started'}else{'Starting video...'})
}
function Restart-Active([int]$i){
 if(!$want[$i]){return}
 $p=$streams[$i]
 if($p -and !$p.HasExited){if(!$p.CloseMainWindow()){$p.Kill()}}
 Set-Status $i 'Applying video settings...'
 $state.next=[datetime]::MinValue
}
function Refresh-Slot([int]$i){
 $u=$slots[$i]
 $u.title.Text=(Tr 'Headset')+' '+($i+1)
 $u.title.Invalidate()
 $u.status.Text=(Tr $u.statusKey)
 $u.left.BackColor=$(if($cfg[$i].eye -ne 'Right'){$selectedColor}else{$idleColor})
 $u.right.BackColor=$(if($cfg[$i].eye -eq 'Right'){$selectedColor}else{$idleColor})
 $u.wideLabel.Width=if($uiState.language -eq 'RU'){70}else{104};$u.wide.Left=$u.wideLabel.Right+1
 $u.wide.AccessibleName=Tr 'Wide crop 16:9';$u.wide.AccessibleDescription=if($cfg[$i].wide){'On'}else{'Off'};$u.wide.Invalidate()
 $u.refresh.AccessibleName=Tr 'Restart with current settings';$modeTips.SetToolTip($u.refresh,(Tr 'Restart with current settings'))
}
function Set-Eye([int]$i,[string]$eye){
 if($cfg[$i].eye -eq $eye){return}
 $cfg[$i].eye=$eye;Save-Cfg;Refresh-Slot $i;Restart-Active $i
}
function Toggle-Wide([int]$i){
 $cfg[$i].wide=(!$cfg[$i].wide);Save-Cfg;Refresh-Slot $i;Restart-Active $i
}
for($i=0;$i -lt $capacity;$i++){
 $x=20+346*($i%2);$top=if($i -lt 2){130}else{342}
 $panel=New-Object Windows.Forms.Panel
 $panel.SetBounds($x,$top,334,200);$panel.BackColor=$panelColor;$form.Controls.Add($panel);$panel.SendToBack();[QuestRounded]::Apply($panel,16)
 $title=Button ("Headset "+($i+1)) ($x+12) ($top+10) 310 20
 $title.TextAlign=[Drawing.ContentAlignment]::MiddleLeft
 $title.Padding=New-Object Windows.Forms.Padding(31,0,36,0)
 $title.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
 $title.BackColor=$panelColor;$title.FlatAppearance.MouseOverBackColor=$panelColor;$title.FlatAppearance.MouseDownBackColor=$panelColor
 $title.Add_Paint({
  param($sender,$e)
  $j=[int]$sender.Tag;$u=$slots[$j];$active=$u.statusKey -in @('Correction process started','Stream process started')
  $col=if($active){$runningColor}else{$mutedColor}
  [QuestRounded]::Glyph($e.Graphics,'headset',2,4,$col)
  $b=New-Object Drawing.SolidBrush($col)
  try{$e.Graphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias;$dx=if($j -ge 2){$sender.Width-31}else{$sender.Width-9};$e.Graphics.FillEllipse($b,$dx,6,8,8)}finally{$b.Dispose()}
  if($j -ge 2){[QuestRounded]::Glyph($e.Graphics,$(if($expanded[$j]){'up'}else{'down'}),($sender.Width-13),3,$mutedColor)}
 })
 $addr=Label ([string]$cfg[$i].address) ($x+12) ($top+59) 310 16
 $addr.ForeColor=$mutedColor;$addr.BackColor=$panelColor;$addr.Font=New-Object Drawing.Font('Consolas',8.5)
 $status=Label $(if($cfg[$i].serial){'Stopped'}else{'Connect via USB to register'}) ($x+12) ($top+34) 310 21
 $status.ForeColor=$mutedColor;$status.BackColor=$panelColor
 $eyeLabel=Label 'Eye' ($x+12) ($top+79) 35 24;$eyeLabel.TextAlign='MiddleLeft';$eyeLabel.BackColor=$panelColor
 $left=Button 'Left' ($x+48) ($top+78) 74 24
 $right=Button 'Right' ($x+122) ($top+78) 74 24
 $wideLabel=Label 'Wide crop 16:9' ($x+12) ($top+108) 104 23;$wideLabel.TextAlign='MiddleLeft';$wideLabel.BackColor=$panelColor
 $wide=Button '' ($x+117) ($top+109) 44 20;$wide.BackColor=$panelColor;$wide.FlatAppearance.MouseOverBackColor=$panelColor;$wide.FlatAppearance.MouseDownBackColor=$panelColor
 $wide.Add_Paint({param($sender,$e)[QuestRounded]::Switch($e.Graphics,[bool]$cfg[[int]$sender.Tag].wide,$sender.Width,$sender.Height)})
 $go=Button 'Start' ($x+12) ($top+134) 89 24
 $stop=Button 'Stop' ($x+109) ($top+134) 55 24
 $refresh=Button '' ($x+172) ($top+134) 38 24;$refresh.Image=[QuestRounded]::Icon('restart',$form.ForeColor)
 $usb=Button 'USB / Wi-Fi' ($x+12) ($top+164) 94 24
 foreach($ctrl in @($title,$addr,$status,$eyeLabel,$left,$right,$wideLabel,$wide,$go,$stop,$refresh,$usb)){
  $cx=$ctrl.Left-$x;$cy=$ctrl.Top-$top
  $panel.Controls.Add($ctrl);$ctrl.Left=$cx;$ctrl.Top=$cy
 }
 $slots+=@{panel=$panel;title=$title;addr=$addr;left=$left;right=$right;wide=$wide;wideLabel=$wideLabel;go=$go;stop=$stop;refresh=$refresh;usb=$usb;status=$status;body=@($addr,$status,$eyeLabel,$left,$right,$wideLabel,$wide,$go,$stop,$refresh,$usb);statusKey=$(if($cfg[$i].serial){'Stopped'}else{'Connect via USB to register'})}
 $go.Tag=$i;$stop.Tag=$i;$usb.Tag=$i;$left.Tag=$i;$right.Tag=$i;$wide.Tag=$i;$wideLabel.Tag=$i;$title.Tag=$i;$refresh.Tag=$i
 $go.Add_Click({param($sender,$e) Request-Slot ([int]$sender.Tag)})
 $stop.Add_Click({param($sender,$e) Stop-Slot ([int]$sender.Tag)})
 $left.Add_Click({param($sender,$e) Set-Eye ([int]$sender.Tag) 'Left'})
 $right.Add_Click({param($sender,$e) Set-Eye ([int]$sender.Tag) 'Right'})
 $wide.Add_Click({param($sender,$e) Toggle-Wide ([int]$sender.Tag)})
 $wideLabel.Add_Click({param($sender,$e) Toggle-Wide ([int]$sender.Tag)})
 $refresh.Add_Click({param($sender,$e)$j=[int]$sender.Tag;Request-Slot $j;Restart-Active $j})
 if($i -ge 2){$title.Add_Click({param($sender,$e)$j=[int]$sender.Tag;$expanded[$j]=!$expanded[$j];Refresh-Layout;Refresh-Slot $j})}
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
   $answer=[Windows.Forms.MessageBox]::Show((Tr 'Connect the correct Quest via USB and approve debugging. Use only a trusted private LAN.'),(Tr 'Set up network ADB?'),'YesNo','Question')
   if($answer -ne 'Yes'){return}
   $want[$j]=$false
   $null=Adb @('-s',$id,'tcpip','5555')
   $cfg[$j].serial=$serial;$cfg[$j].address=$address;Save-Cfg
   $slots[$j].addr.Text=$address;Request-Slot $j
  }catch{Set-Status $j ('USB: '+(Tr $_.Exception.Message))}
 })
}

function Refresh-Layout {
 for($k=0;$k -lt $capacity;$k++){
  $u=$slots[$k];$open=$expanded[$k]
  foreach($ctrl in $u.body){$ctrl.Visible=$open}
  $u.panel.Height=$(if($open){200}else{40})
  [QuestRounded]::Apply($u.panel,16)
 }
 $bottom=if($expanded[2] -or $expanded[3]){554}else{394}
 if($footer){
  foreach($c in @($qualityLabel,$qualityPicker,$searchLabel,$searchProgress,$logsBtn,$maintenanceBtn)){$c.Top=$bottom}
  $footer.Top=$bottom+37
  $form.ClientSize=New-Object Drawing.Size(720,($bottom+82))
 }
}
function Refresh-Language {
 $controls=@($form.Controls | ForEach-Object {$_})
 foreach($u in $slots){$controls+=@($u.panel.Controls | ForEach-Object {$_})}
 foreach($c in $controls){if($c -is [Windows.Forms.Button] -or $c -is [Windows.Forms.Label]){if($c.Name -and $ru.ContainsKey($c.Name)){$c.Text=(Tr $c.Name)}}}
 for($k=0;$k -lt $capacity;$k++){Refresh-Slot $k}
 if($footer){$footer.Text=(Tr 'If a reboot disables network ADB, use USB / Wi-Fi setup. For a black screen, open a VR app and restart the stream.')+' '+(Tr 'Correction is approximate; switching modes restarts active streams.')}
 $active=$accentColor;$idle=$headerControlColor
 $ruBtn.BackColor=$(if($uiState.language -eq 'RU'){$active}else{$idle})
 $enBtn.BackColor=$(if($uiState.language -eq 'EN'){$active}else{$idle})
 $fishBtn.BackColor=$(if(!$uiState.corrected){$active}else{$idle})
 $corrBtn.BackColor=$(if($uiState.corrected){$active}else{$idle})
 $fishBtn.AccessibleName=(Tr 'Fisheye');$corrBtn.AccessibleName=(Tr 'Correction')
 $modeTips.SetToolTip($fishBtn,(Tr 'Fisheye'));$modeTips.SetToolTip($corrBtn,(Tr 'Correction'))
 $fishBtn.Invalidate();$corrBtn.Invalidate()
 if($qualityPicker){$qualityPicker.AccessibleName=Tr 'Quality'}
 if($maintenanceBtn){$maintenanceBtn.Text=Tr $maintenanceBtn.Name}
}
function Set-Lens([bool]$corrected){
 if($corrected -eq $uiState.corrected){return}
 if($corrected -and (!(Get-Command ffplay.exe -ErrorAction SilentlyContinue) -or !(Test-Path (Join-Path $root 'LensViewer.exe')))){
  [Windows.Forms.MessageBox]::Show((Tr 'Correction needs ffplay. Install FFmpeg (see README).'),'Quest Live')|Out-Null;return
 }
 $uiState.corrected=$corrected;Save-Prefs;Refresh-Language
 for($k=0;$k -lt $capacity;$k++){
  if($want[$k] -and $streams[$k] -and !$streams[$k].HasExited){
   $p=$streams[$k];if(!$p.CloseMainWindow()){$p.Kill()}
  }
 }
 $state.next=[datetime]::MinValue
}
$ruBtn.Add_Click({$uiState.language='RU';Save-Prefs;Refresh-Language})
$enBtn.Add_Click({$uiState.language='EN';Save-Prefs;Refresh-Language})
$fishBtn.Add_Click({Set-Lens $false})
$corrBtn.Add_Click({Set-Lens $true})
Refresh-Language
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
    if($want[$j]){Set-Status $j 'Reconnecting…';$state.next=[datetime]::Now.AddSeconds(2)}
   }elseif($p -and $want[$j]){
    $p.Refresh()
    if($uiState.corrected){Set-Status $j 'Correction process started'}elseif($p.MainWindowHandle -ne 0){Set-Status $j 'Stream process started'}
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
     else{$missing[$j]++;if($result.unauthorized -contains $cfg[$j].address){Set-Status $j 'Approve debugging in the headset'}else{Set-Status $j 'Retrying • use USB if needed'}}
    }
   }
  }elseif([datetime]::Now -ge $state.next){
   $need=$false
   for($j=0;$j -lt $capacity;$j++){if($want[$j] -and !$streams[$j]){$need=$true}}
   if($need){Begin-Discovery}
  }
 }catch{$state.next=[datetime]::Now.AddSeconds(7)}
 $searchLabel.Visible=[bool]$state.job;$searchProgress.Visible=[bool]$state.job
})
$qualityLabel=Label 'Quality' 20 394 86 24;$qualityLabel.ForeColor=$mutedColor;$qualityLabel.TextAlign='MiddleLeft'
$qualityPicker=Button $uiState.quality 110 394 134 24;$qualityPicker.BackColor=$headerControlColor;$qualityPicker.TextAlign='MiddleLeft';$qualityPicker.Padding=New-Object Windows.Forms.Padding(8,0,18,0)
$qualityPicker.AccessibleName=Tr 'Quality';$qualityPicker.AccessibleDescription=$uiState.quality
$qualityPicker.Add_Paint({param($sender,$e)[QuestRounded]::Glyph($e.Graphics,'up',($sender.Width-19),0,$form.ForeColor);[QuestRounded]::Glyph($e.Graphics,'down',($sender.Width-19),10,$form.ForeColor)})
$qualityMenu=New-Object Windows.Forms.ContextMenuStrip;$qualityMenu.BackColor=$headerControlColor;$qualityMenu.ForeColor=$form.ForeColor;$qualityMenu.Renderer=New-Object Windows.Forms.ToolStripProfessionalRenderer((New-Object QuestRounded+DarkMenuColors))
foreach($q in @('1080 / 30 FPS','1600 / 30 FPS','1600 / 60 FPS')){
 $item=New-Object Windows.Forms.ToolStripMenuItem;$item.Text=$q;$item.Tag=$q;$item.ForeColor=$form.ForeColor;$item.Checked=($q -eq $uiState.quality)
 [void]$qualityMenu.Items.Add($item)
 $item.Add_Click({param($sender,$e)$q=[string]$sender.Tag;if($q -ne $uiState.quality){$uiState.quality=$q;$qualityPicker.Text=$q;$qualityPicker.AccessibleDescription=$q;foreach($x in $qualityMenu.Items){$x.Checked=($x.Tag -eq $q)};Save-Prefs;for($k=0;$k -lt $capacity;$k++){Restart-Active $k}}})
}
$qualityPicker.Add_Click({$qualityMenu.Show($qualityPicker,[Drawing.Point]::new(0,$qualityPicker.Height))})
$searchProgress=New-Object Windows.Forms.ProgressBar;$searchProgress.SetBounds(344,394,30,16);$searchProgress.Style='Marquee';$searchProgress.MarqueeAnimationSpeed=50;$searchProgress.Visible=$false;$form.Controls.Add($searchProgress)
$searchLabel=Label 'Searching…' 380 394 105 24;$searchLabel.ForeColor=$mutedColor;$searchLabel.Visible=$false
$logsBtn=Button 'Logs' 502 394 84 24;$logsBtn.BackColor=$headerControlColor
$logsBtn.Add_Click({Start-Process explorer.exe -ArgumentList ('"'+$data+'"')})
$maintenanceBtn=Button 'Maintenance' 594 394 106 24;$maintenanceBtn.BackColor=$headerControlColor
$footer=Label '' 20 431 680 34;$footer.Font=New-Object Drawing.Font('Segoe UI',8.5)

$ru['Maintenance']='Диагностика'
$ru['Firmware •']='Прошивка •'
$ru['Update •']='Обновление •'
$checkState=@{job=$null;out=$null;err=$null;next=[datetime]::MinValue;result='';available=$false;firmware=(@($cfg|Where-Object{$_.firmwarePending}).Count -gt 0)}
function Start-MaintenanceJob([string]$action,[int]$slot){
 $p=New-Object Diagnostics.Process
 $p.StartInfo.FileName=Join-Path $PSHOME 'powershell.exe'
 $p.StartInfo.Arguments='-NoProfile -ExecutionPolicy RemoteSigned -File "'+(Join-Path $root 'Maintenance.ps1')+'" -Action '+$action+' -Slot '+$slot
 $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 $p.StartInfo.StandardOutputEncoding=[Text.Encoding]::UTF8
 [void]$p.Start();return @{p=$p;out=$p.StandardOutput.ReadToEndAsync();err=$p.StandardError.ReadToEndAsync()}
}
$updateTimer=New-Object Windows.Forms.Timer;$updateTimer.Interval=1000
$updateTimer.Add_Tick({
 try{
  if($checkState.job){
   $j=$checkState.job
   if($j.p.HasExited){$j.p.WaitForExit();$checkState.result=$j.out.Result;$j.p.Dispose();$checkState.job=$null;$checkState.next=[datetime]::Now.AddHours(6)
    $v=ConvertFrom-Json -InputObject $checkState.result
    if($v.latest -and $v.engine -match '^scrcpy ([0-9.]+)'){$ver=$Matches[1];$checkState.available=([version]($v.latest.TrimStart('v')) -gt [version]$ver) -or ([version]($v.app.TrimStart('v')) -gt [version]'0.5.2')}
    $maintenanceBtn.Name=if($checkState.available){'Update •'}elseif($checkState.firmware){'Firmware •'}else{'Maintenance'};$maintenanceBtn.Text=Tr $maintenanceBtn.Name
   }
  }elseif([datetime]::Now -ge $checkState.next){$checkState.job=Start-MaintenanceJob 'check' 0}
 }catch{$checkState.next=[datetime]::Now.AddMinutes(10);$checkState.job=$null}
})
$maintenanceBtn.Add_Click({
 $dlg=New-Object Windows.Forms.Form;$dlg.Icon=$form.Icon;$dlg.Text=if($uiState.language -eq 'RU'){'Диагностика и обновления'}else{'Diagnostics & updates'};$dlg.StartPosition='CenterParent';$dlg.ClientSize=New-Object Drawing.Size(680,430);$dlg.BackColor=$form.BackColor;$dlg.ForeColor=$form.ForeColor;$dlg.Font=$form.Font;$dlg.FormBorderStyle='FixedDialog';$dlg.MaximizeBox=$false;$dlg.MinimizeBox=$false;[QuestRounded]::DarkTitle($dlg)
 $isRU=$uiState.language -eq 'RU'
 $heading=New-Object Windows.Forms.Label;$heading.Text=$dlg.Text;$heading.Font=New-Object Drawing.Font('Segoe UI',15,[Drawing.FontStyle]::Bold);$heading.SetBounds(20,14,640,30);$dlg.Controls.Add($heading)
 $firmwareLabel=New-Object Windows.Forms.Label;$firmwareLabel.SetBounds(20,44,640,20);$firmwareLabel.ForeColor=[Drawing.Color]::Orange
 $pending=@(0..3|Where-Object{$cfg[$_].firmwarePending}|ForEach-Object{$_+1})
 $firmwareLabel.Text=if($pending.Count){$(if($isRU){'Изменилась прошивка. Проверьте захват: '}else{'Firmware changed. Test capture: '})+($pending -join ', ')}else{''}
 $firmwareLabel.Visible=($pending.Count -gt 0);$dlg.Controls.Add($firmwareLabel)
 $dy=if($pending.Count){20}else{0}
 $hint=New-Object Windows.Forms.Label;$hint.SetBounds(20,(48+$dy),640,49);$hint.TextAlign="TopLeft";$hint.AutoSize=$false;$hint.Text=if($isRU){'Обновления не устанавливаются автоматически. Для теста и смены движка остановите все потоки. Откройте любое VR-приложение в выбранном шлеме.'}else{'Updates are never installed automatically. Stop all streams before a capture test or engine switch. Open any VR application in the selected headset.'};$dlg.Controls.Add($hint)
 $select=New-Object Windows.Forms.Button;$select.SetBounds(20,(101+$dy),200,24);$select.Tag=0;$select.Text=(Tr 'Headset')+' 1';$select.AccessibleName=Tr 'Headset';$select.BackColor=$headerControlColor;$select.ForeColor=$form.ForeColor;$select.FlatStyle='Flat';$select.FlatAppearance.BorderSize=0;$select.TextAlign='MiddleLeft';$select.Padding=New-Object Windows.Forms.Padding(8,0,18,0);$dlg.Controls.Add($select);[QuestRounded]::Apply($select,6)
 $select.Add_Paint({param($sender,$e)[QuestRounded]::Glyph($e.Graphics,'up',($sender.Width-19),0,$form.ForeColor);[QuestRounded]::Glyph($e.Graphics,'down',($sender.Width-19),10,$form.ForeColor)})
 $slotMenu=New-Object Windows.Forms.ContextMenuStrip;$slotMenu.BackColor=$headerControlColor;$slotMenu.ForeColor=$form.ForeColor;$slotMenu.Renderer=New-Object Windows.Forms.ToolStripProfessionalRenderer((New-Object QuestRounded+DarkMenuColors))
 foreach($k in 0..3){$item=New-Object Windows.Forms.ToolStripMenuItem;$item.Text=(Tr 'Headset')+' '+($k+1);$item.Tag=$k;$item.ForeColor=$form.ForeColor;$item.Checked=($k -eq 0);[void]$slotMenu.Items.Add($item);$item.Add_Click({param($sender,$e)$select.Tag=[int]$sender.Tag;$select.Text=$sender.Text;foreach($it in $slotMenu.Items){$it.Checked=($it.Tag -eq $select.Tag)}})}
 $select.Add_Click({$slotMenu.Show($select,[Drawing.Point]::new(0,$select.Height))})
 $output=New-Object Windows.Forms.TextBox;$output.Multiline=$true;$output.ReadOnly=$true;$output.ScrollBars='Vertical';$output.SetBounds(20,(201+$dy),640,190);$output.Font=New-Object Drawing.Font('Consolas',9);$output.BorderStyle='None';$output.BackColor=$panelColor;$output.ForeColor=$form.ForeColor;$output.Text=$checkState.result;$dlg.Controls.Add($output);[QuestRounded]::DarkScroll($output)
 function Format-Maintenance([string]$raw){
  try{$v=ConvertFrom-Json -InputObject $raw;return (($v.PSObject.Properties|Sort-Object Name|ForEach-Object{$_.Name+': '+$_.Value}) -join [Environment]::NewLine)}catch{return $raw}
 }
 $output.Text=Format-Maintenance $checkState.result
 $ds=@{job=$null;action='';slot=0}
 $actions=@('check','diagnose','capture','stage','test','activate','rollback');$actionButtons=@()
 $names=if($isRU){@('Проверить обновления','Проверить ADB','Тест захвата','Загрузить движок','Тест нового','Применить','Откат')}else{@('Check updates','Check ADB','Capture test','Stage engine','Test candidate','Activate','Rollback')}
 for($k=0;$k -lt $actions.Count;$k++){
  $b=New-Object Windows.Forms.Button;$b.Text=$names[$k];$b.Tag=$actions[$k];$row=if($k -lt 3){0}else{1};$col=if($row -eq 0){$k}else{$k-3};$bw=if($row -eq 0){204}else{154};$b.SetBounds((20+($bw+8)*$col),(133+$dy+30*$row),$bw,25);$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0;$b.BackColor=$idleColor;$b.ForeColor=$form.ForeColor;$dlg.Controls.Add($b);[QuestRounded]::Apply($b,6);$actionButtons+=,$b
  $b.Add_Click({param($sender,$e)
   if($ds.job){return}
   if($sender.Tag -in @('capture','test','activate','rollback') -and (($want -contains $true) -or @($streams|Where-Object{$_ -and !$_.HasExited}).Count -gt 0 -or $state.job)){$output.Text=if($isRU){'Сначала остановите все потоки и дождитесь завершения.'}else{'Stop all streams and wait for them to exit.'};return}
   $output.Text='…';$ds.action=$sender.Tag;$ds.slot=([int]$select.Tag);try{$ds.job=Start-MaintenanceJob $sender.Tag ([int]$select.Tag)}catch{$output.Text=$_.Exception.Message}
  })
 }
 $dlg.ClientSize=New-Object Drawing.Size(680,(437+$dy))
 $stopButton=New-Object Windows.Forms.Button;$stopButton.SetBounds(20,(401+$dy),142,25);$stopButton.Text=Tr 'Stop all';$dlg.Controls.Add($stopButton);$stopButton.Add_Click({for($k=0;$k -lt $capacity;$k++){Stop-Slot $k}})
 $link=New-Object Windows.Forms.Button;$link.SetBounds(388,(401+$dy),158,25);$link.Text=if($isRU){'Релизы приложения'}else{'App releases'};$dlg.Controls.Add($link);$link.Add_Click({Start-Process 'https://github.com/STANxAERO/arizona-quest-live/releases'})
 $closeBtn=New-Object Windows.Forms.Button;$closeBtn.SetBounds(554,(401+$dy),106,25);$closeBtn.Text=if($isRU){'Закрыть'}else{'Close'};$dlg.Controls.Add($closeBtn);$closeBtn.Add_Click({if(!$ds.job){$dlg.Close()}})
 foreach($b in @($stopButton,$link,$closeBtn)){$b.FlatStyle='Flat';$b.FlatAppearance.BorderSize=0;$b.BackColor=$idleColor;$b.ForeColor=$form.ForeColor;[QuestRounded]::Apply($b,6)}
 $busyLabel=New-Object Windows.Forms.Label;$busyLabel.SetBounds(172,(401+$dy),150,25);$busyLabel.ForeColor=$mutedColor;$dlg.Controls.Add($busyLabel)
 function Refresh-MaintenanceControls {
  $busy=[bool]$ds.job;$idle=!(($want -contains $true) -or @($streams|Where-Object{$_ -and !$_.HasExited}).Count -gt 0 -or $state.job)
  foreach($b in $actionButtons){$b.Enabled=!$busy -and ($b.Tag -notin @('capture','test','activate','rollback') -or $idle)}
  $closeBtn.Enabled=!$busy;$busyLabel.Text=if($busy){'…'}else{''}
 }
 Refresh-MaintenanceControls
 $dt=New-Object Windows.Forms.Timer;$dt.Interval=500;$dt.Add_Tick({if($ds.job -and $ds.job.p.HasExited){$j=$ds.job;$j.p.WaitForExit();$raw=$j.out.Result;if(!$raw){$raw=$j.err.Result};$output.Text=Format-Maintenance $raw;$j.p.Dispose();$ds.job=$null
  if($ds.action -eq 'capture'){try{$v=ConvertFrom-Json -InputObject $raw;if($v.passed -and $v.build -eq $cfg[$ds.slot].lastBuild){$cfg[$ds.slot].firmwarePending=$false;Save-Cfg;$checkState.firmware=@($cfg|Where-Object{$_.firmwarePending}).Count -gt 0;$maintenanceBtn.Name=if($checkState.available){'Update •'}elseif($checkState.firmware){'Firmware •'}else{'Maintenance'};$maintenanceBtn.Text=Tr $maintenanceBtn.Name}}catch{}}
 };Refresh-MaintenanceControls})
 $dlg.Add_FormClosing({param($sender,$e)if($ds.job){$e.Cancel=$true}})
 $dt.Start();try{[void]$dlg.ShowDialog($form)}finally{$dt.Stop();$dt.Dispose();$dlg.Dispose()}
})
$updateTimer.Start()
$footer.ForeColor=$mutedColor
Refresh-Layout
Refresh-Language
$form.Add_Shown({[QuestRounded]::DarkTitle($form);if(!$NoAuto){for($k=0;$k -lt $capacity;$k++){Request-Slot $k}};$timer.Start()})
$form.Add_FormClosed({
 $timer.Stop();$timer.Dispose()
 $updateTimer.Stop();$updateTimer.Dispose();if($checkState.job -and !$checkState.job.p.HasExited){$checkState.job.p.Kill()}
 if($state.job -and !$state.job.HasExited){$state.job.Kill()}
 for($j=0;$j -lt $capacity;$j++){Stop-Slot $j}
})
try{[void]$form.ShowDialog()}finally{$mutex.ReleaseMutex();$mutex.Dispose()}