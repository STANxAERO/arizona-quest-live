param([switch]$ForceScan,[string]$Settings=(Join-Path $env:LOCALAPPDATA 'ARIZONA Quest Live Public\settings.json'))
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$adb=Join-Path $root 'scrcpy\adb.exe'
$p=Get-Process adb -ErrorAction SilentlyContinue | Select-Object -First 1
if($p -and $p.Path){$adb=$p.Path}
$cfg=ConvertFrom-Json -InputObject (Get-Content -LiteralPath $Settings -Raw -Encoding UTF8)
$found=@{}
$seen=@{}
$notes=New-Object 'System.Collections.Generic.List[string]'
function A([string[]]$args1,[int]$ms=3500){
 $p=New-Object Diagnostics.Process
 $p.StartInfo.FileName=$adb;$p.StartInfo.Arguments=$args1 -join ' '
 $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 try{
  [void]$p.Start();$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
  if(!$p.WaitForExit($ms)){$p.Kill();return ''}
  $p.WaitForExit();if($p.ExitCode -ne 0){return ''}
  return $o.Result.Trim()
 }catch{return ''}finally{$p.Dispose()}
}
function Probe([string]$addr,[bool]$connect){
 if($seen.ContainsKey($addr)){return};$seen[$addr]=$true
 if($connect){$null=A @('connect',$addr) 3500}
 if((A @('-s',$addr,'get-state')) -ne 'device'){return}
 $serial=A @('-s',$addr,'shell','getprop','ro.serialno')
 if(!$serial){return}
 if($serial -notin @($cfg | ForEach-Object {$_.serial})){if($connect -and $addr -notin $initial){$null=A @('disconnect',$addr)};return}
 if($found.ContainsKey($serial)){return}
 $model=A @('-s',$addr,'shell','getprop','ro.product.model')
 if($model -notmatch 'Quest'){return}
 $size=A @('-s',$addr,'shell','wm','size')
 if($size -notmatch 'Physical size:\s*(\d+)x(\d+)'){return}
 $w=[int]$Matches[1];$h=[int]$Matches[2]
 if($w -lt $h -or $w%4 -ne 0 -or $h%2 -ne 0){return}
 $override=''
 if($size -match 'Override size:\s*(\d+x\d+)'){$override=$Matches[1]}
 $found[$serial]=[pscustomobject]@{serial=$serial;address=$addr;model=$model;w=$w;h=$h;override=$override}
}
function Complete {return ($found.Count -ge @($cfg | Where-Object {$_.serial}).Count)}
$initial=@((A @('devices','-l')) -split '\r?\n' | ForEach-Object {if($_ -match '^(\S+)\s+device\s'){$Matches[1]}})
# Only local RFC1918 IPv4 /24 segments that share a prefix with a saved headset.
# No Internet, VPN-wide, or arbitrary-port scan.
$prefixes=@()
foreach($entry in $cfg){if($entry.address -match '^((?:10\.\d+\.\d+|192\.168\.\d+|172\.(?:1[6-9]|2\d|3[01])\.\d+))\.\d+:5555$'){$prefixes+=$Matches[1]}}
$local=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.AddressState -eq 'Preferred' -and $_.PrefixLength -le 24} | ForEach-Object {($_.IPAddress -split '\.')[0..2] -join '.'})
$prefixes=@($prefixes | Where-Object {$_ -in $local})
# Add current directly attached private /24 Ethernet/Wi-Fi LANs, excluding virtual adapters.
$lan=@(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object {$_.IPv4DefaultGateway -and $_.NetAdapter.HardwareInterface} | ForEach-Object {$_.IPv4Address} | Where-Object {$_.PrefixLength -eq 24 -and $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)'} | ForEach-Object {($_.IPAddress -split '\.')[0..2] -join '.'})
$prefixes=@(($prefixes+$lan)|Select-Object -Unique)
# First check already-connected transports and cached addresses.
if(!$ForceScan){
 foreach($addr in $initial){if($addr -match '^\d+\.\d+\.\d+\.\d+:\d+$'){Probe $addr $false}}
 foreach($entry in $cfg){if($entry.serial -and !$found.ContainsKey([string]$entry.serial) -and $entry.address -match '^(\d+\.\d+\.\d+)\.\d+:5555$' -and $Matches[1] -in $prefixes){Probe $entry.address $true}}
}
if(!(Complete)){
 foreach($prefix in $prefixes){
  $notes.Add("Scan $prefix.0/24")
  for($base=1;$base -le 254;$base+=32){
   if(Complete){break}
   $pending=@()
   for($n=$base;$n -le [Math]::Min(254,$base+31);$n++){
    $ip="$prefix.$n";$addr=$ip+':5555'
    if($seen.ContainsKey($addr)){continue}
    $tcp=New-Object Net.Sockets.TcpClient
    try{$task=$tcp.ConnectAsync($ip,5555);$pending+=@{tcp=$tcp;task=$task;addr=$addr}}catch{$tcp.Dispose()}
   }
   if($pending.Count){Start-Sleep -Milliseconds 280}
   $open=@()
   foreach($q in $pending){if($q.task.Status -eq 'RanToCompletion' -and $q.tcp.Connected){$open+=$q.addr};$q.tcp.Dispose()}
   foreach($addr in $open){Probe $addr ($addr -notin $initial);if(Complete){break}}
  }
 }
}
[pscustomobject]@{found=@($found.Values);notes=@($notes.ToArray())}|ConvertTo-Json -Depth 5 -Compress