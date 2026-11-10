param(
  [string]$Sdk = 'D:\work\zhixingligongflash\.toolchain\android-sdk',
  [string]$Home_ = 'D:\work\zhixingligongflash'
)

$ErrorActionPreference = 'Stop'
$dl = Join-Path $Home_ 'tools\download.mjs'
$tc = Join-Path $Home_ '.toolchain'

$items = @(
  @{ url = 'https://dl.google.com/android/repository/platform-tools_r37.0.1-win.zip'; out = "$tc\platform-tools.zip" },
  @{ url = 'https://dl.google.com/android/repository/build-tools_r36_windows.zip'; out = "$tc\build-tools.zip" },
  @{ url = 'https://dl.google.com/android/repository/platform-36_r02.zip'; out = "$tc\platform-36.zip" }
)

foreach ($item in $items) {
  if (Test-Path $item.out) { Write-Host "skip $($item.out)"; continue }
  & node $dl $item.url $item.out
  if ($LASTEXITCODE -ne 0) { throw "download failed: $($item.url)" }
}

New-Item -ItemType Directory -Force -Path $Sdk | Out-Null

function Install-Package([string]$zip, [string]$tmpName, [string]$target) {
  Write-Host "extract $zip -> $target"
  $tmp = Join-Path $tc $tmpName
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  & tar.exe -xf $zip -C $tmp
  $dir = Get-ChildItem $tmp -Directory | Select-Object -First 1
  if (-not $dir) { throw "empty archive $zip" }
  if (Test-Path $target) { Remove-Item $target -Recurse -Force }
  $parent = Split-Path $target -Parent
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  Move-Item $dir.FullName $target
}

Install-Package "$tc\platform-tools.zip" '_pt' "$Sdk\platform-tools"
Install-Package "$tc\build-tools.zip" '_bt' "$Sdk\build-tools\36.0.0"
Install-Package "$tc\platform-36.zip" '_plat' "$Sdk\platforms\android-36"

New-Item -ItemType Directory -Force -Path "$Sdk\licenses" | Out-Null
$license = @(
  '24333f8a63b6825ea9c5514f83c2829b004d1fee',
  '8933bad161af4178b1185d1a37fbf41ea5269c55',
  'd56f5187479451eabf01fb78af6dfcb131a6481e'
) -join "`n"
Set-Content -Path "$Sdk\licenses\android-sdk-license" -Value $license -NoNewline

Write-Host 'done'
Get-ChildItem $Sdk | Select-Object Name | Format-Table -AutoSize
