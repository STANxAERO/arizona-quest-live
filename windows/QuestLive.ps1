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

$prefs=Join-Path $data 'preferences.json'
$uiState=@{language=if([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'ru'){'RU'}else{'EN'};corrected=$false}
if(Test-Path -LiteralPath $prefs){try{$pr=ConvertFrom-Json -InputObject (Get-Content -LiteralPath $prefs -Raw -Encoding UTF8);if($pr.language -in @('RU','EN')){$uiState.language=$pr.language};$uiState.corrected=[bool]$pr.corrected}catch{}}
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
 'Restart with current settings'='Перезапуск с текущими настройками'
 'Set up USB / Wi-Fi'='Настроить USB / Wi-Fi'
 'Fisheye'='Рыбий глаз'
 'Correction'='Коррекция'
 'Waiting'='Ожидание'
 'Stopped'='Остановлен'
 'Connect via USB to register'='Подключите USB для регистрации'
 'Finding headset…'='Поиск шлема…'
 'Finding headset...'='Поиск шлема…'
 'Reconnecting…'='Переподключение…'
 'Connection lost. Reconnecting...'='Связь потеряна. Переподключение…'
 'Approve debugging in the headset'='Подтвердите отладку в шлеме'
 'Retrying • use USB if needed'='Повтор поиска • при необходимости USB'
 'Not found. Retrying...'='Не найден. Повтор поиска…'
 'Waiting for network ADB. Use USB if needed.'='Ожидание ADB. При необходимости USB.'
 'Stream process started'='Процесс трансляции запущен'
 'Stream window open'='Окно трансляции открыто'
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
function Set-Status([int]$i,[string]$key){$slots[$i].statusKey=$key;$slots[$i].status.Text=(Tr $key)}

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
$form.StartPosition='CenterScreen';$form.ClientSize=New-Object Drawing.Size(720,690)
$form.FormBorderStyle='FixedSingle';$form.MaximizeBox=$false
$form.BackColor=[Drawing.Color]::FromArgb(24,26,30);$form.ForeColor=[Drawing.Color]::White
$form.Font=New-Object Drawing.Font('Segoe UI',10)
function Label($text,$x,$y,$w,$h){
 $l=New-Object Windows.Forms.Label;$l.Text=(Tr $text);$l.Name=$text;$l.SetBounds($x,$y,$w,$h);$l.ForeColor=$form.ForeColor;$form.Controls.Add($l);return $l
}
function Button($text,$x,$y,$w,$h){
 $b=New-Object Windows.Forms.Button;$b.Text=(Tr $text);$b.Name=$text;$b.SetBounds($x,$y,$w,$h);$b.FlatStyle='Flat';$b.BackColor=[Drawing.Color]::FromArgb(46,50,56);$b.ForeColor=[Drawing.Color]::White;$form.Controls.Add($b);return $b
}
$h=Label 'QUEST LIVE / ARIZONA' 20 14 330 38
$h.Font=New-Object Drawing.Font('Segoe UI',18,[Drawing.FontStyle]::Bold)
$null=Label 'Auto discovery • Wi-Fi • one eye • auto reconnect' 22 56 680 25
$all=Button 'Start all' 20 90 335 40
$all.BackColor=[Drawing.Color]::FromArgb(27,112,66)
$stopAll=Button 'Stop all' 365 90 335 40
$ruBtn=Button 'RU' 367 16 45 30;$enBtn=Button 'EN' 416 16 45 30
$fishBtn=Button 'Fisheye' 470 16 108 30;$corrBtn=Button 'Correction' 582 16 118 30
$slots=@();$streams=@($null)*$capacity;$want=@($false)*$capacity;$missing=@(0)*$capacity
$state=@{job=$null;out=$null;err=$null;next=[datetime]::MinValue;closing=$false}
function Stop-Slot([int]$i){
 $want[$i]=$false;$p=$streams[$i]
 if($p){if(!$p.HasExited){if(!$p.CloseMainWindow()){$p.Kill()}}}
 Set-Status $i 'Stopped'
}
function Request-Slot([int]$i){
 if(!$cfg[$i].serial){Set-Status $i 'Connect via USB to register';return}
 $want[$i]=$true;$state.next=[datetime]::MinValue
 if(!$streams[$i] -or $streams[$i].HasExited){Set-Status $i 'Finding headset...'}
}
function Open-Viewer([int]$i,$info){
 if(!$want[$i] -or ($streams[$i] -and !$streams[$i].HasExited)){return}
 if($info.override){Set-Status $i ('Non-default display size: '+$info.override);return}
 $cfg[$i].address=$info.address;$slots[$i].addr.Text=$info.address
 $cfg[$i].eye=if($slots[$i].eye.SelectedIndex -eq 1){'Right'}else{'Left'}
 Save-Cfg
 $half=[int]($info.w/2);$x=if($cfg[$i].eye -eq 'Right'){$half}else{0}
 $crop='{0}:{1}:{2}:0' -f $half,$info.h,$x
 $p=New-Object Diagnostics.Process
 $p.StartInfo.FileName=$viewer;$p.StartInfo.WorkingDirectory=Split-Path $viewer
 $capArgs="--serial=$($info.address) --crop=$crop --no-audio --no-control --video-codec=h264 --max-size=1600 --max-fps=30 --video-bit-rate=5M --window-height=660 --window-title=ARIZONA-Quest-$($i+1)"
 if($uiState.corrected){
  $ff=Get-Command ffplay.exe -ErrorAction SilentlyContinue
  $helper=Join-Path $root 'LensViewer.exe'
  if(!$ff -or !(Test-Path -LiteralPath $helper)){Set-Status $i 'Correction needs ffplay. Install FFmpeg (see README).';$want[$i]=$false;return}
  $p.StartInfo.FileName=$helper
  $p.StartInfo.Arguments="$PID ""$($ff.Source)"" ""$viewer"" normal ARIZONA-Quest-$($i+1) $capArgs"
 }else{$p.StartInfo.Arguments=$capArgs}
 $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 [void]$p.Start();$streams[$i]=$p;$missing[$i]=0
 Set-Status $i $(if($uiState.corrected){'Correction process started'}else{'Starting video...'})
}
for($i=0;$i -lt $capacity;$i++){
 $x=20+345*($i%2)
 $dy=250*[int][Math]::Floor($i/2)
 $title=Label ("Headset "+($i+1)) $x (148+$dy) 335 27
 $title.Font=New-Object Drawing.Font('Segoe UI',14,[Drawing.FontStyle]::Bold)
 $addr=Label ([string]$cfg[$i].address) $x (181+$dy) 335 25
 $addr.ForeColor=[Drawing.Color]::LightGray
 $eye=New-Object Windows.Forms.ComboBox;$eye.SetBounds($x,(210+$dy),335,30);$eye.DropDownStyle='DropDownList'
 [void]$eye.Items.Add((Tr 'Left eye'));[void]$eye.Items.Add((Tr 'Right eye'));$eye.SelectedIndex=0
 if($cfg[$i].eye -eq 'Right'){$eye.SelectedIndex=1};$form.Controls.Add($eye)
 $go=Button 'Start' $x (250+$dy) 210 36;$stop=Button 'Stop' ($x+220) (250+$dy) 115 36
 $usb=Button 'Set up USB / Wi-Fi' $x (294+$dy) 335 32
 $status=Label $(if($cfg[$i].serial){'Stopped'}else{'Connect via USB to register'}) $x (336+$dy) 335 45
 $slots+=@{title=$title;addr=$addr;eye=$eye;go=$go;stop=$stop;usb=$usb;status=$status;statusKey=$(if($cfg[$i].serial){'Stopped'}else{'Connect via USB to register'})}
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
   $answer=[Windows.Forms.MessageBox]::Show((Tr 'Enable network ADB? Use only a trusted private LAN.'),'Quest Live','YesNo','Question')
   if($answer -ne 'Yes'){return}
   $want[$j]=$false
   $null=Adb @('-s',$id,'tcpip','5555')
   $cfg[$j].serial=$serial;$cfg[$j].address=$address;Save-Cfg
   $slots[$j].addr.Text=$address;Request-Slot $j
  }catch{Set-Status $j ('USB: '+(Tr $_.Exception.Message))}
 })
}

function Refresh-Language {
 foreach($c in $form.Controls){if($c -is [Windows.Forms.Button] -or $c -is [Windows.Forms.Label]){if($c.Name -and $ru.ContainsKey($c.Name)){$c.Text=(Tr $c.Name)}}}
 for($k=0;$k -lt $capacity;$k++){
  $u=$slots[$k];$u.title.Text=(Tr 'Headset')+' '+($k+1);$u.status.Text=(Tr $u.statusKey)
  $idx=$u.eye.SelectedIndex;$u.eye.Items.Clear();[void]$u.eye.Items.Add((Tr 'Left eye'));[void]$u.eye.Items.Add((Tr 'Right eye'));$u.eye.SelectedIndex=[Math]::Max(0,$idx)
 }
 $active=[Drawing.Color]::FromArgb(27,112,66);$idle=[Drawing.Color]::FromArgb(46,50,56)
 $ruBtn.BackColor=$(if($uiState.language -eq 'RU'){$active}else{$idle})
 $enBtn.BackColor=$(if($uiState.language -eq 'EN'){$active}else{$idle})
 $fishBtn.BackColor=$(if(!$uiState.corrected){$active}else{$idle})
 $corrBtn.BackColor=$(if($uiState.corrected){$active}else{$idle})
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
    if($want[$j]){Set-Status $j 'Connection lost. Reconnecting...';$state.next=[datetime]::Now.AddSeconds(2)}
   }elseif($p -and $want[$j]){
    $p.Refresh()
    if($uiState.corrected){Set-Status $j 'Correction process started'}elseif($p.MainWindowHandle -ne 0){Set-Status $j 'Stream window open'}
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
     else{$missing[$j]++;Set-Status $j 'Not found. Retrying...';if($missing[$j] -ge 2){Set-Status $j 'Waiting for network ADB. Use USB if needed.'}}
    }
   }
  }elseif([datetime]::Now -ge $state.next){
   $need=$false
   for($j=0;$j -lt $capacity;$j++){if($want[$j] -and !$streams[$j]){$need=$true}}
   if($need){Begin-Discovery}
  }
 }catch{$state.next=[datetime]::Now.AddSeconds(7);$form.Text='ARIZONA | QUEST LIVE 4 - retrying'}
})
$null=Label 'Correction is approximate; switching modes restarts active streams.' 20 650 680 30
Refresh-Language
$form.Add_Shown({if(!$NoAuto){for($k=0;$k -lt $capacity;$k++){Request-Slot $k}};$timer.Start()})
$form.Add_FormClosed({
 $timer.Stop();$timer.Dispose()
 if($state.job -and !$state.job.HasExited){$state.job.Kill()}
 for($j=0;$j -lt $capacity;$j++){Stop-Slot $j}
})
try{[void]$form.ShowDialog()}finally{$mutex.ReleaseMutex();$mutex.Dispose()}