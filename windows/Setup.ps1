$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$exe=Join-Path $root 'scrcpy\scrcpy.exe'
if(Test-Path -LiteralPath $exe){exit 0}
$zip=Join-Path ([IO.Path]::GetTempPath()) ('quest-live-'+[guid]::NewGuid()+'.zip')
$stage=Join-Path ([IO.Path]::GetTempPath()) ('quest-live-'+[guid]::NewGuid())
try{
    Write-Host 'Downloading official scrcpy 5.0.1 (Windows x64)...'
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/Genymobile/scrcpy/releases/download/v5.0.1/scrcpy-win64-v5.0.1.zip' -OutFile $zip
    $sha=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if($sha -ne 'b12a2c4ee8be317422451fc7dcf8ee20a71b5ea7ef9ad73ddd825a25316227a5'){throw 'scrcpy archive hash mismatch'}
    Expand-Archive -LiteralPath $zip -DestinationPath $stage
    $src=Join-Path $stage 'scrcpy-win64-v5.0.1'
    if(!(Test-Path -LiteralPath (Join-Path $src 'scrcpy.exe'))){throw 'Invalid archive layout'}
    if(Test-Path -LiteralPath (Join-Path $root 'scrcpy')){throw 'Existing incomplete scrcpy folder; rename it and retry.'}
    Move-Item -LiteralPath $src -Destination (Join-Path $root 'scrcpy')
    Write-Host 'Setup complete.'
} finally {
    if(Test-Path -LiteralPath $zip){Remove-Item -LiteralPath $zip -Force}
    if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
}
