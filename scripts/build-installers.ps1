param(
    [string]$Configuration = "Release",
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectName = "Mastermind GUI"
$projectDir = Join-Path $repoRoot $projectName
$outputRoot = Join-Path $repoRoot "dist"
$workRoot = Join-Path $repoRoot "build\installers"
$releaseDir = Join-Path $projectDir "bin\$Configuration"
$msbuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
$wixBin = "C:\Program Files (x86)\WiX Toolset v3.14\bin"

function Require-File([string]$Path, [string]$Message) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw $Message
    }
}

function New-ArArchive {
    param(
        [string]$OutputPath,
        [string[]]$InputFiles
    )

    $encoding = [System.Text.Encoding]::ASCII
    $stream = [System.IO.File]::Create($OutputPath)
    try {
        $globalHeader = $encoding.GetBytes("!<arch>`n")
        $stream.Write($globalHeader, 0, $globalHeader.Length)

        foreach ($file in $InputFiles) {
            $item = Get-Item -LiteralPath $file
            $name = $item.Name
            if ($name.Length -gt 15) {
                throw "ar member name '$name' is too long"
            }

            $header = "{0,-16}{1,-12}{2,-6}{3,-6}{4,-8}{5,-10}```n" -f (
                $name + "/"),
                [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds(),
                0,
                0,
                "100644",
                $item.Length

            $headerBytes = $encoding.GetBytes($header)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
            $stream.Write($bytes, 0, $bytes.Length)
            if (($item.Length % 2) -ne 0) {
                $stream.WriteByte(10)
            }
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Write-TarString {
    param(
        [byte[]]$Header,
        [int]$Offset,
        [int]$Length,
        [string]$Value
    )

    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Value)
    [Array]::Copy($bytes, 0, $Header, $Offset, [Math]::Min($bytes.Length, $Length))
}

function Write-TarOctal {
    param(
        [byte[]]$Header,
        [int]$Offset,
        [int]$Length,
        [Int64]$Value
    )

    $text = [Convert]::ToString($Value, 8).PadLeft($Length - 1, "0") + "`0"
    Write-TarString -Header $Header -Offset $Offset -Length $Length -Value $text
}

function New-TarHeader {
    param(
        [string]$Name,
        [Int64]$Size,
        [int]$Mode,
        [string]$TypeFlag
    )

    $header = New-Object byte[] 512
    $prefix = ""
    if ($Name.Length -gt 100) {
        $split = $Name.LastIndexOf("/")
        if ($split -lt 1) {
            throw "tar entry name '$Name' is too long"
        }
        $prefix = $Name.Substring(0, $split)
        $Name = $Name.Substring($split + 1)
        if ($Name.Length -gt 100 -or $prefix.Length -gt 155) {
            throw "tar entry name is too long"
        }
    }

    Write-TarString -Header $header -Offset 0 -Length 100 -Value $Name
    Write-TarOctal -Header $header -Offset 100 -Length 8 -Value $Mode
    Write-TarOctal -Header $header -Offset 108 -Length 8 -Value 0
    Write-TarOctal -Header $header -Offset 116 -Length 8 -Value 0
    Write-TarOctal -Header $header -Offset 124 -Length 12 -Value $Size
    Write-TarOctal -Header $header -Offset 136 -Length 12 -Value ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    for ($i = 148; $i -lt 156; $i++) {
        $header[$i] = 32
    }
    Write-TarString -Header $header -Offset 156 -Length 1 -Value $TypeFlag
    Write-TarString -Header $header -Offset 257 -Length 6 -Value "ustar"
    Write-TarString -Header $header -Offset 263 -Length 2 -Value "00"
    Write-TarString -Header $header -Offset 265 -Length 32 -Value "root"
    Write-TarString -Header $header -Offset 297 -Length 32 -Value "root"
    Write-TarString -Header $header -Offset 345 -Length 155 -Value $prefix

    $checksum = 0
    foreach ($byte in $header) {
        $checksum += $byte
    }
    $checksumText = [Convert]::ToString($checksum, 8).PadLeft(6, "0") + "`0 "
    Write-TarString -Header $header -Offset 148 -Length 8 -Value $checksumText

    return $header
}

function New-TarGzArchive {
    param(
        [string]$OutputPath,
        [array]$Entries
    )

    $fileStream = [System.IO.File]::Create($OutputPath)
    try {
        $gzipStream = [System.IO.Compression.GZipStream]::new($fileStream, [System.IO.Compression.CompressionLevel]::Optimal, $true)
        try {
            foreach ($entry in $Entries) {
                $name = $entry.Name.Replace("\", "/").TrimStart("/")
                $isDirectory = $entry.Type -eq "Directory"
                if ($isDirectory -and -not $name.EndsWith("/")) {
                    $name += "/"
                }

                $size = 0
                if (-not $isDirectory) {
                    $size = (Get-Item -LiteralPath $entry.Source).Length
                }

                $header = New-TarHeader -Name $name -Size $size -Mode $entry.Mode -TypeFlag $(if ($isDirectory) { "5" } else { "0" })
                $gzipStream.Write($header, 0, $header.Length)

                if (-not $isDirectory) {
                    $bytes = [System.IO.File]::ReadAllBytes($entry.Source)
                    $gzipStream.Write($bytes, 0, $bytes.Length)
                    $padding = (512 - ($bytes.Length % 512)) % 512
                    if ($padding -gt 0) {
                        $gzipStream.Write((New-Object byte[] $padding), 0, $padding)
                    }
                }
            }

            $gzipStream.Write((New-Object byte[] 1024), 0, 1024)
        }
        finally {
            $gzipStream.Dispose()
        }
    }
    finally {
        $fileStream.Dispose()
    }
}

Require-File $msbuild "MSBuild was not found at $msbuild"
Require-File (Join-Path $wixBin "candle.exe") "WiX candle.exe was not found."
Require-File (Join-Path $wixBin "light.exe") "WiX light.exe was not found."

New-Item -ItemType Directory -Force -Path $outputRoot, $workRoot | Out-Null

& $msbuild (Join-Path $repoRoot "Mastermind GUI.sln") `
    /p:Configuration=$Configuration `
    /p:Platform="Any CPU" `
    /p:_EnableDefaultWindowsPlatform=false `
    /m
if ($LASTEXITCODE -ne 0) {
    throw "Release build failed."
}

$appExe = Join-Path $releaseDir "Mastermind GUI.exe"
$appConfig = Join-Path $releaseDir "Mastermind GUI.exe.config"
Require-File $appExe "Release executable was not produced."
Require-File $appConfig "Release app config was not produced."

$wixRoot = Join-Path $workRoot "wix"
New-Item -ItemType Directory -Force -Path $wixRoot | Out-Null

$licensePath = Join-Path $wixRoot "License.rtf"
@"
{\rtf1\ansi\deff0
{\fonttbl{\f0 Segoe UI;}}
\fs20 Mastermind GUI\par
\par
This installer installs Mastermind GUI, a Windows Forms desktop application.\par
}
"@ | Set-Content -LiteralPath $licensePath -Encoding ASCII

$wxsPath = Join-Path $wixRoot "MastermindGUI.wxs"
@"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="Mastermind GUI" Language="1033" Version="$Version" Manufacturer="Mastermind GUI" UpgradeCode="F9D58C1B-217F-4971-8A5A-3A41A5481F35">
    <Package InstallerVersion="500" Compressed="yes" InstallScope="perMachine" />
    <MajorUpgrade DowngradeErrorMessage="A newer version of Mastermind GUI is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <Property Id="WIXUI_INSTALLDIR" Value="INSTALLFOLDER" />
    <Property Id="NETFRAMEWORK45">
      <RegistrySearch Id="NetFramework45Release" Root="HKLM" Key="SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" Name="Release" Type="raw" />
    </Property>
    <Condition Message="Mastermind GUI requires Microsoft .NET Framework 4.7.2 or later.">Installed OR (NETFRAMEWORK45 AND NETFRAMEWORK45 &gt;= "#461808")</Condition>

    <Icon Id="AppIcon.ico" SourceFile="$(Join-Path $repoRoot "logo.ico")" />
    <Property Id="ARPPRODUCTICON" Value="AppIcon.ico" />

    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder">
        <Directory Id="INSTALLFOLDER" Name="Mastermind GUI">
          <Component Id="AppFiles" Guid="A771B54B-6674-47CF-9D5D-D16C3912F936">
            <File Id="MastermindExe" Source="$appExe" KeyPath="yes" />
            <File Id="MastermindConfig" Source="$appConfig" />
          </Component>
        </Directory>
      </Directory>
      <Directory Id="ProgramMenuFolder">
        <Directory Id="ApplicationProgramsFolder" Name="Mastermind GUI" />
      </Directory>
      <Directory Id="DesktopFolder" Name="Desktop" />
    </Directory>

    <DirectoryRef Id="ApplicationProgramsFolder">
      <Component Id="ApplicationShortcut" Guid="E1976EB2-B34D-44C9-B862-FB39A3D40AC2">
        <Shortcut Id="ApplicationStartMenuShortcut" Name="Mastermind GUI" Description="Play Mastermind" Target="[INSTALLFOLDER]Mastermind GUI.exe" WorkingDirectory="INSTALLFOLDER" Icon="AppIcon.ico" />
        <RemoveFolder Id="ApplicationProgramsFolder" On="uninstall" />
        <RegistryValue Root="HKCU" Key="Software\Mastermind GUI" Name="startMenuShortcut" Type="integer" Value="1" KeyPath="yes" />
      </Component>
    </DirectoryRef>

    <DirectoryRef Id="DesktopFolder">
      <Component Id="DesktopShortcut" Guid="9B6B1D81-FD25-4238-80AA-4681B7536348">
        <Shortcut Id="ApplicationDesktopShortcut" Name="Mastermind GUI" Description="Play Mastermind" Target="[INSTALLFOLDER]Mastermind GUI.exe" WorkingDirectory="INSTALLFOLDER" Icon="AppIcon.ico" />
        <RegistryValue Root="HKCU" Key="Software\Mastermind GUI" Name="desktopShortcut" Type="integer" Value="1" KeyPath="yes" />
      </Component>
    </DirectoryRef>

    <Feature Id="ProductFeature" Title="Mastermind GUI" Level="1">
      <ComponentRef Id="AppFiles" />
      <ComponentRef Id="ApplicationShortcut" />
      <ComponentRef Id="DesktopShortcut" />
    </Feature>

    <UIRef Id="WixUI_InstallDir" />
    <WixVariable Id="WixUILicenseRtf" Value="$licensePath" />
  </Product>
</Wix>
"@ | Set-Content -LiteralPath $wxsPath -Encoding UTF8

$wixObj = Join-Path $wixRoot "MastermindGUI.wixobj"
$msiPath = Join-Path $outputRoot "Mastermind-GUI-$Version-win-x86.msi"
& (Join-Path $wixBin "candle.exe") -out $wixObj $wxsPath
if ($LASTEXITCODE -ne 0) {
    throw "WiX candle failed."
}

& (Join-Path $wixBin "light.exe") -sval -ext WixUIExtension -out $msiPath $wixObj
if ($LASTEXITCODE -ne 0) {
    throw "WiX light failed."
}

$debRoot = Join-Path $workRoot "deb"
$debControl = Join-Path $debRoot "control"
$debData = Join-Path $debRoot "data"
Remove-Item -Recurse -Force -LiteralPath $debRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path `
    (Join-Path $debControl "DEBIAN"),
    (Join-Path $debData "opt\mastermind-gui"),
    (Join-Path $debData "usr\bin"),
    (Join-Path $debData "usr\share\applications") | Out-Null

Copy-Item -LiteralPath $appExe -Destination (Join-Path $debData "opt\mastermind-gui\Mastermind GUI.exe")
Copy-Item -LiteralPath $appConfig -Destination (Join-Path $debData "opt\mastermind-gui\Mastermind GUI.exe.config")

@"
Package: mastermind-gui
Version: $Version
Section: games
Priority: optional
Architecture: all
Depends: wine | mono-runtime
Maintainer: Mastermind GUI <noreply@example.invalid>
Description: Mastermind GUI desktop game
 Mastermind GUI is a Windows Forms implementation of the Mastermind game.
 This package installs the Windows executable and a launcher that uses Wine
 or Mono when available.
"@ | Set-Content -LiteralPath (Join-Path $debControl "DEBIAN\control") -Encoding ASCII

@"
#!/bin/sh
set -e
APP="/opt/mastermind-gui/Mastermind GUI.exe"
if command -v wine >/dev/null 2>&1; then
  exec wine "`$APP" "`$@"
fi
if command -v mono >/dev/null 2>&1; then
  exec mono "`$APP" "`$@"
fi
echo "Mastermind GUI is a Windows Forms .NET Framework app. Install Wine or Mono to run it." >&2
exit 1
"@ | Set-Content -LiteralPath (Join-Path $debData "usr\bin\mastermind-gui") -Encoding ASCII

@"
[Desktop Entry]
Name=Mastermind GUI
Comment=Play Mastermind
Exec=mastermind-gui
Terminal=false
Type=Application
Categories=Game;LogicGame;
"@ | Set-Content -LiteralPath (Join-Path $debData "usr\share\applications\mastermind-gui.desktop") -Encoding ASCII

$debianBinary = Join-Path $debRoot "debian-binary"
$controlTar = Join-Path $debRoot "control.tar.gz"
$dataTar = Join-Path $debRoot "data.tar.gz"
$debPath = Join-Path $outputRoot "mastermind-gui_${Version}_all.deb"

"2.0`n" | Set-Content -LiteralPath $debianBinary -NoNewline -Encoding ASCII
New-TarGzArchive -OutputPath $controlTar -Entries @(
    @{ Name = "control"; Source = (Join-Path $debControl "DEBIAN\control"); Mode = 420; Type = "File" }
)

New-TarGzArchive -OutputPath $dataTar -Entries @(
    @{ Name = "."; Mode = 493; Type = "Directory" },
    @{ Name = "./opt"; Mode = 493; Type = "Directory" },
    @{ Name = "./opt/mastermind-gui"; Mode = 493; Type = "Directory" },
    @{ Name = "./opt/mastermind-gui/Mastermind GUI.exe"; Source = (Join-Path $debData "opt\mastermind-gui\Mastermind GUI.exe"); Mode = 420; Type = "File" },
    @{ Name = "./opt/mastermind-gui/Mastermind GUI.exe.config"; Source = (Join-Path $debData "opt\mastermind-gui\Mastermind GUI.exe.config"); Mode = 420; Type = "File" },
    @{ Name = "./usr"; Mode = 493; Type = "Directory" },
    @{ Name = "./usr/bin"; Mode = 493; Type = "Directory" },
    @{ Name = "./usr/bin/mastermind-gui"; Source = (Join-Path $debData "usr\bin\mastermind-gui"); Mode = 493; Type = "File" },
    @{ Name = "./usr/share"; Mode = 493; Type = "Directory" },
    @{ Name = "./usr/share/applications"; Mode = 493; Type = "Directory" },
    @{ Name = "./usr/share/applications/mastermind-gui.desktop"; Source = (Join-Path $debData "usr\share\applications\mastermind-gui.desktop"); Mode = 420; Type = "File" }
)

New-ArArchive -OutputPath $debPath -InputFiles @($debianBinary, $controlTar, $dataTar)

$macRoot = Join-Path $workRoot "macos"
$appBundle = Join-Path $macRoot "Mastermind GUI.app"
Remove-Item -Recurse -Force -LiteralPath $macRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path `
    (Join-Path $appBundle "Contents\MacOS"),
    (Join-Path $appBundle "Contents\Resources") | Out-Null
Copy-Item -LiteralPath $appExe -Destination (Join-Path $appBundle "Contents\Resources\Mastermind GUI.exe")
Copy-Item -LiteralPath $appConfig -Destination (Join-Path $appBundle "Contents\Resources\Mastermind GUI.exe.config")

@"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>mastermind-gui</string>
  <key>CFBundleIdentifier</key>
  <string>local.mastermind-gui</string>
  <key>CFBundleName</key>
  <string>Mastermind GUI</string>
  <key>CFBundleShortVersionString</key>
  <string>$Version</string>
  <key>CFBundleVersion</key>
  <string>$Version</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.13</string>
</dict>
</plist>
"@ | Set-Content -LiteralPath (Join-Path $appBundle "Contents\Info.plist") -Encoding UTF8

@"
#!/bin/sh
APP_DIR="`$(cd "`$(dirname "`$0")/.." && pwd)"
EXE="`$APP_DIR/Resources/Mastermind GUI.exe"
if command -v wine >/dev/null 2>&1; then
  exec wine "`$EXE" "`$@"
fi
if command -v mono >/dev/null 2>&1; then
  exec mono "`$EXE" "`$@"
fi
osascript -e 'display dialog "Mastermind GUI is a Windows Forms .NET Framework app. Install Wine or Mono to run it." buttons {"OK"} default button "OK"'
exit 1
"@ | Set-Content -LiteralPath (Join-Path $appBundle "Contents\MacOS\mastermind-gui") -Encoding ASCII

$macZip = Join-Path $outputRoot "Mastermind-GUI-$Version-macos-app.zip"
Remove-Item -Force -LiteralPath $macZip -ErrorAction SilentlyContinue
Compress-Archive -Path $appBundle -DestinationPath $macZip

Write-Host "Built:"
Write-Host "  $msiPath"
Write-Host "  $debPath"
Write-Host "  $macZip"
Write-Host "A true .dmg requires macOS hdiutil. Run this on macOS after copying the .app bundle:"
Write-Host "  hdiutil create -volname 'Mastermind GUI' -srcfolder '$appBundle' -ov -format UDZO 'Mastermind-GUI-$Version-macos.dmg'"
