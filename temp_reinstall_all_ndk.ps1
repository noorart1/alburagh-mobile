$sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$sdkManager = Join-Path $sdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'

$versions = @('27.3.13750724', '28.2.13676358')
foreach ($ver in $versions) {
    $ndkPath = Join-Path $sdkRoot ('ndk\' + $ver)
    if (Test-Path $ndkPath) {
        Write-Output "Removing corrupted NDK at $ndkPath"
        Remove-Item -Path $ndkPath -Recurse -Force
    }
    Write-Output "Installing NDK $ver..."
    & $sdkManager --sdk_root=$sdkRoot --install "ndk;$ver"
}

Write-Output "All NDK versions reinstalled successfully."