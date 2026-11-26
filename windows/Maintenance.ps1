param([ValidateSet('check','stage','diagnose','capture','test','activate','rollback')][string]$Action='check',[int]$Slot=0)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.Encoding]::UTF8
$root=Join-Path $env:LOCALAPPDATA 'ARIZONA Quest Live Public'
$eng=Join-Path $root 'engines';$stateFile=Join-Path $eng 'state.json'
$base=Join-Path $PSScriptRoot 'scrcpy\scrcpy.exe'
$adb=Join-Path $PSScriptRoot 'scrcpy\adb.exe'
$p=Get-Process adb -ErrorAction SilentlyContinue|Select-Object -First 1
if($p -and $p.Path){$adb=$p.Path}
$env:ADB=$adb
function State {
 if(Test-Path $stateFile){return ConvertFrom-Json -InputObject (Get-Content $stateFile -Raw -Encoding UTF8)}
 return [pscustomobject]@{active='';previous='';candidate='';tested='';tested_build='';tested_slot=-1}
}
function Save-State($s){
 New-Item -ItemType Directory -Path $eng -Force|Out-Null
 $temp=$stateFile+'.new';$s|ConvertTo-Json|Set-Content $temp -Encoding UTF8
 if(Test-Path $stateFile){[IO.File]::Replace($temp,$stateFile,($stateFile+'.backup'))}else{Move-Item $temp $stateFile}
}
function Engine($tag){
 if(!$tag){return $base}
 if($tag -notmatch '^v\d+\.\d+(\.\d+)?$'){throw 'Invalid engine tag'}
 $f=Join-Path $eng "$tag\scrcpy.exe";if(!(Test-Path -LiteralPath $f)){throw 'Engine unavailable'};return $f
}
function Run($exe,[string[]]$args1,[int]$ms=12000){
 $p=New-Object Diagnostics.Process
 $p.StartInfo.FileName=$exe
 $p.StartInfo.Arguments=($args1|ForEach-Object{'"'+$_.Replace('"','\"')+'"'}) -join ' '
 $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 try{[void]$p.Start();$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
 if(!$p.WaitForExit($ms)){$p.Kill();throw 'Command timeout'};$p.WaitForExit()
 if($p.ExitCode){throw ('Command failed: '+$e.Result)}
 return @{out=$o.Result.Trim();err=$e.Result}
 }finally{$p.Dispose()}
}
function Api($path){Invoke-RestMethod -Uri ("https://api.github.com/repos/"+$path) -Headers @{'User-Agent'='ARIZONA-Quest-Live';Accept='application/vnd.github+json'} -TimeoutSec 12}
function Latest {
 $r=Api 'Genymobile/scrcpy/releases/latest';$tag=$r.tag_name
 if($tag -notmatch '^v\d+\.\d+(\.\d+)?$'){throw 'Unexpected upstream release'}
 $name="scrcpy-win64-$tag.zip";$a=$r.assets|Where-Object{$_.name -eq $name}|Select-Object -First 1
 if(!$a -or $a.digest -notmatch '^sha256:([0-9a-f]{64})$'){throw 'Missing official digest'}
 return @{tag=$tag;name=$name;sha=$Matches[1]}
}
function Stage {
 $r=Latest;$tag=$r.tag;$target=Join-Path $eng $tag
 New-Item -ItemType Directory -Path $eng -Force|Out-Null
 if(!(Test-Path $target)){
  $tmp=Join-Path $eng ('tmp-'+[guid]::NewGuid());New-Item -ItemType Directory -Path $tmp|Out-Null
  try{
   $zip=Join-Path $tmp $r.name
   Invoke-WebRequest -UseBasicParsing -Uri ("https://github.com/Genymobile/scrcpy/releases/download/$tag/"+$r.name) -OutFile $zip -TimeoutSec 60
   if((Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $r.sha){throw 'SHA-256 mismatch'}
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   $z=[IO.Compression.ZipFile]::OpenRead($zip)
   try{foreach($e in $z.Entries){if($e.FullName -match '(^[/\\]|:|(^|[/\\])\.\.([/\\]|$))'){throw 'Unsafe archive member'}}}finally{$z.Dispose()}
   Expand-Archive -LiteralPath $zip -DestinationPath $tmp
   $folder=Join-Path $tmp "scrcpy-win64-$tag";$exe=Join-Path $folder 'scrcpy.exe'
   if(!(Test-Path $exe) -or !(Test-Path (Join-Path $folder 'scrcpy-server'))){throw 'Invalid archive'}
   $v=(Run $exe @('--version')).out
   if(!$v.StartsWith("scrcpy "+$tag.Substring(1)+" ")){throw 'Version mismatch'}
   $h=(Run $exe @('--help')).out
   foreach($a in @('--crop','--no-window','--no-playback','--record-format','--time-limit')){if(!$h.Contains($a)){throw "Missing option $a"}}
   Move-Item $folder $target
  }finally{Remove-Item -LiteralPath $tmp -Recurse -Force}
 }
 $s=State;if($s.active -ne $tag){$s.candidate=$tag;$s.tested='';Save-State $s}
 return @{message="Staged $tag; current engine unchanged."}
}
function Diagnose($candidate,$capture){
 $st=State
 if($candidate){$st.tested='';$st.tested_build='';$st|Add-Member -NotePropertyName tested_slot -NotePropertyValue -1 -Force;Save-State $st}
 $slots=ConvertFrom-Json -InputObject (Get-Content (Join-Path $root 'settings.json') -Raw -Encoding UTF8)
 if($Slot -lt 0 -or $Slot -ge $slots.Count -or !$slots[$Slot].serial){throw 'Slot not registered'}
 $s=$slots[$Slot];$addr=$s.address
 if($addr -notmatch '^\d+\.\d+\.\d+\.\d+:\d+$'){throw 'Invalid address'}
 if((Run $adb @('-s',$addr,'get-state')).out -ne 'device'){throw 'ADB unavailable'}
 if((Run $adb @('-s',$addr,'shell','getprop','ro.serialno')).out -ne $s.serial){throw 'Wrong headset'}
 $d=@{model=(Run $adb @('-s',$addr,'shell','getprop','ro.product.model')).out;android=(Run $adb @('-s',$addr,'shell','getprop','ro.build.version.release')).out;build=(Run $adb @('-s',$addr,'shell','getprop','ro.build.version.incremental')).out;size=(Run $adb @('-s',$addr,'shell','wm','size')).out;adb='device'}
 $st=State;$tag=$st.active;if($candidate){$tag=$st.candidate;if(!$tag){throw 'Stage an engine first'}}
 $exe=Engine $tag;$d.engine=((Run $exe @('--version')).out -split '\r?\n')[0]
 if(!$capture){return $d}
 if($d.size -match 'Override size:'){throw 'Non-default display size'}
 if($d.size -notmatch 'Physical size:\s*(\d+)x(\d+)'){throw 'Invalid display size'}
 $w=[int]$Matches[1];$h=[int]$Matches[2];if($w%4 -or $h%2 -or $w -lt $h){throw 'Invalid display size'}
 $f=Join-Path ([IO.Path]::GetTempPath()) ('arizona-diag-'+[guid]::NewGuid()+'.mkv')
 try{
  $null=Run $exe @("--serial=$addr",("--crop={0}:{1}:0:0" -f ($w/2),$h),'--no-audio','--no-control','--no-window','--no-playback','--max-size=1080','--max-fps=30','--time-limit=4',"--record=$f") 18000
  $ff=(Get-Command ffmpeg.exe -ErrorAction Stop).Source;$fp=(Get-Command ffprobe.exe -ErrorAction Stop).Source
  $frames=[int](Run $fp @('-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=nb_read_frames','-of','csv=p=0',$f)).out
  $log=(Run $ff @('-hide_banner','-i',$f,'-vf','blackframe=amount=98:threshold=32','-an','-f','null','NUL') 15000).err
  $black=[regex]::Matches($log,'\bpblack:').Count
  $d.frames=$frames;$d.black_frames=$black;$d.passed=($frames -ge 10 -and ($frames-$black) -ge [Math]::Max(5,[int][Math]::Floor($frames/10)))
  if($candidate -and $d.passed){$st.tested=$tag;$st.tested_build=$d.build;$st|Add-Member -NotePropertyName tested_slot -NotePropertyValue $Slot -Force;Save-State $st}
 }finally{if(Test-Path $f){Remove-Item -LiteralPath $f -Force}}
 return $d
}
try{
 $s=State
 switch($Action){
 'check'{$r=Latest;$app=@(Api 'STANxAERO/arizona-quest-live/releases?per_page=10')|ForEach-Object{$_}|Where-Object{!$_.draft}|Select-Object -First 1
 $result=@{engine=((Run (Engine $s.active) @('--version')).out -split '\r?\n')[0];latest=$r.tag;app=$app.tag_name;active=$s.active;candidate=$s.candidate;tested=$s.tested;previous=$s.previous}}
 'stage'{$result=Stage}
 'diagnose'{$result=Diagnose $false $false}
 'capture'{$result=Diagnose $false $true}
 'test'{$result=Diagnose $true $true}
 'activate'{if(!$s.candidate -or $s.tested -ne $s.candidate){throw 'Candidate must pass capture test'};if(!$s.PSObject.Properties['tested_slot'] -or $s.tested_slot -lt 0){throw 'Test candidate again'}
 $Slot=[int]$s.tested_slot;$d=Diagnose $false $false
 if($d.build -ne $s.tested_build){throw 'Firmware changed; test candidate again'}
 $tag=$s.candidate;$null=Run (Engine $tag) @('--version');$s.previous=$s.active;$s.active=$tag;$s.candidate='';$s.tested='';$s.tested_build='';$s|Add-Member -NotePropertyName tested_slot -NotePropertyValue -1 -Force;Save-State $s;$result=@{message="Selected $tag"}}
 'rollback'{if(!$s.active){throw 'No prior managed engine'};$tag=$s.previous;$null=Run (Engine $tag) @('--version');$s.previous=$s.active;$s.active=$tag;$s.candidate='';$s.tested='';$s.tested_build='';$s|Add-Member -NotePropertyName tested_slot -NotePropertyValue -1 -Force;Save-State $s;$result=@{message="Selected "+$tag}}
 }
 $result|ConvertTo-Json -Compress -Depth 4
}catch{@{error=$_.Exception.Message}|ConvertTo-Json -Compress;exit 1}
