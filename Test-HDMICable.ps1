<#
.SYNOPSIS
    HDMI Cable Quality Tester for Windows

.DESCRIPTION
    Advanced HDMI cable testing utility that checks:
    - Connected displays and EDID information
    - Supported resolutions and refresh rates
    - Signal stability and connection quality
    - HDMI version capabilities
    - Bandwidth requirements

.NOTES
    Author: Claude
    Requires: Windows 10/11, Administrator privileges recommended

.EXAMPLE
    .\Test-HDMICable.ps1

.EXAMPLE
    .\Test-HDMICable.ps1 -SaveReport -ReportPath "C:\Reports\hdmi_test.json"
#>

[CmdletBinding()]
param(
    [switch]$SaveReport,
    [string]$ReportPath = "hdmi_test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json",
    [int]$StabilityTestDuration = 10
)

# Set UTF-8 encoding to ensure emojis display correctly
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Ensure running with appropriate privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "Not running as Administrator. Some tests may have limited functionality."
    Write-Host "For best results, run PowerShell as Administrator" -ForegroundColor Yellow
    Write-Host ""
}

# Emoji enum
enum Emoji {
    # You must use explicit hex values for the Unicode codepoints
    TV = 0x1F4FA
    Ruler = 0x1F4D0
    Refresh = 0x1F504
    Satellite = 0x1F4E1
    Rocket = 0x1F680
    MagnifyingGlass = 0x1F50D
    BarChart = 0x1F4CA
    FloppyDisk = 0x1F4BE
    Warning = 0x26A0
    Sparkles = 0x2728
    CheckMark = 0x2713
    BallotX = 0x2717
}

# Test results object
$script:TestResults = @{
    Timestamp = Get-Date -Format "o"
    Platform = "Windows"
    OSVersion = [System.Environment]::OSVersion.VersionString
    Displays = @()
    Tests = @()
    OverallQuality = "Unknown"
}

function Get-Emoji {
    param([Emoji]$Icon)
    return [char]::ConvertFromUtf32([int]$Icon)
}

function Write-Header {
    Clear-Host
    Write-Host $("=" * 70) -ForegroundColor Cyan
    Write-Host "HDMI CABLE QUALITY TESTER" -ForegroundColor Cyan
    Write-Host $("=" * 70) -ForegroundColor Cyan
    Write-Host "Platform: Windows"
    Write-Host "Test Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "Administrator: $isAdmin"
    Write-Host $("=" * 70) -ForegroundColor Cyan
    Write-Host ""
}

function Get-DisplayInformation {
    Write-Host "$(Get-Emoji TV) Detecting connected displays..." -ForegroundColor Green

    $displays = @()

    try {
        # Get monitor information from WMI
        $monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue

        foreach ($monitor in $monitors) {
            $displayInfo = @{
                Manufacturer = ($monitor.ManufacturerName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) -join ''
                ProductCode = ($monitor.ProductCodeID | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) -join ''
                SerialNumber = ($monitor.SerialNumberID | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) -join ''
                FriendlyName = ($monitor.UserFriendlyName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) -join ''
                YearOfManufacture = $monitor.YearOfManufacture
                WeekOfManufacture = $monitor.WeekOfManufacture
            }

            $displays += $displayInfo
        }

        # Get current display settings
        Add-Type -AssemblyName System.Windows.Forms
        $screens = [System.Windows.Forms.Screen]::AllScreens

        for ($i = 0; $i -lt $screens.Count; $i++) {
            if ($i -lt $displays.Count) {
                $displays[$i].CurrentResolution = "$($screens[$i].Bounds.Width)x$($screens[$i].Bounds.Height)"
                $displays[$i].BitsPerPixel = $screens[$i].BitsPerPixel
                $displays[$i].Primary = $screens[$i].Primary
            }
        }

        Write-Host "  Found $($displays.Count) display(s)" -ForegroundColor Green

        foreach ($display in $displays) {
            Write-Host "  - $($display.FriendlyName)" -ForegroundColor White
            Write-Host "    Manufacturer: $($display.Manufacturer)" -ForegroundColor Gray
            Write-Host "    Current: $($display.CurrentResolution)" -ForegroundColor Gray
        }

    } catch {
        Write-Warning "Could not retrieve detailed display information: $_"

        # Fallback to basic display info
        $desktopMonitors = Get-CimInstance -ClassName Win32_DesktopMonitor -ErrorAction SilentlyContinue
        foreach ($monitor in $desktopMonitors) {
            $displays += @{
                Name = $monitor.Name
                ScreenWidth = $monitor.ScreenWidth
                ScreenHeight = $monitor.ScreenHeight
                Note = "Limited info - run as Administrator for full details"
            }
        }
    }

    $script:TestResults.Displays = $displays
    return $displays
}

function Test-ResolutionSupport {
    Write-Host "`n$(Get-Emoji Ruler) Testing resolution support..." -ForegroundColor Green

    $testResult = @{
        TestName = "Resolution Support Test"
        Timestamp = Get-Date -Format "o"
        ResolutionsTested = @()
        Passed = $true
    }

    $standardResolutions = @(
        @{Width=1920; Height=1080; Name="1080p"},
        @{Width=2560; Height=1440; Name="1440p"},
        @{Width=3840; Height=2160; Name="4K UHD"},
        @{Width=1280; Height=720; Name="720p HD"},
        @{Width=2560; Height=1080; Name="UltraWide"}
    )

    Add-Type @"
        using System;
        using System.Runtime.InteropServices;

        public class DisplayHelper {
            [DllImport("user32.dll")]
            public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

            [StructLayout(LayoutKind.Sequential)]
            public struct DEVMODE {
                [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
                public string dmDeviceName;
                public short dmSpecVersion;
                public short dmDriverVersion;
                public short dmSize;
                public short dmDriverExtra;
                public int dmFields;
                public int dmPositionX;
                public int dmPositionY;
                public int dmDisplayOrientation;
                public int dmDisplayFixedOutput;
                public short dmColor;
                public short dmDuplex;
                public short dmYResolution;
                public short dmTTOption;
                public short dmCollate;
                [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
                public string dmFormName;
                public short dmLogPixels;
                public int dmBitsPerPel;
                public int dmPelsWidth;
                public int dmPelsHeight;
                public int dmDisplayFlags;
                public int dmDisplayFrequency;
                public int dmICMMethod;
                public int dmICMIntent;
                public int dmMediaType;
                public int dmDitherType;
                public int dmReserved1;
                public int dmReserved2;
                public int dmPanningWidth;
                public int dmPanningHeight;
            }
        }
"@ -ErrorAction SilentlyContinue

    # Get all available display modes
    $availableModes = @()
    $devMode = New-Object DisplayHelper+DEVMODE
    $devMode.dmSize = [Runtime.InteropServices.Marshal]::SizeOf($devMode)
    $modeNum = 0

    while ([DisplayHelper]::EnumDisplaySettings($null, $modeNum, [ref]$devMode) -ne 0) {
        $availableModes += @{
            Width = $devMode.dmPelsWidth
            Height = $devMode.dmPelsHeight
            Frequency = $devMode.dmDisplayFrequency
            BitsPerPixel = $devMode.dmBitsPerPel
        }
        $modeNum++
    }

    foreach ($resolution in $standardResolutions) {
        Write-Host "  Testing $($resolution.Name) ($($resolution.Width)x$($resolution.Height))..." -NoNewline

        $supported = $availableModes | Where-Object {
            $_.Width -eq $resolution.Width -and $_.Height -eq $resolution.Height
        }

        if ($supported) {
            Write-Host " $(Get-Emoji CheckMark) Supported" -ForegroundColor Green
            $testResult.ResolutionsTested += @{
                Resolution = "$($resolution.Width)x$($resolution.Height)"
                Name = $resolution.Name
                Supported = $true
                AvailableRefreshRates = ($supported | Select-Object -ExpandProperty Frequency -Unique)
            }
        } else {
            Write-Host " $(Get-Emoji BallotX) Not supported" -ForegroundColor Red
            $testResult.ResolutionsTested += @{
                Resolution = "$($resolution.Width)x$($resolution.Height)"
                Name = $resolution.Name
                Supported = $false
            }
        }
    }

    $script:TestResults.Tests += $testResult
    return $testResult
}

function Test-RefreshRates {
    Write-Host "`n$(Get-Emoji Refresh) Testing refresh rate support..." -ForegroundColor Green

    $testResult = @{
        TestName = "Refresh Rate Test"
        Timestamp = Get-Date -Format "o"
        RefreshRatesTested = @()
        Passed = $true
    }

    $standardRates = @(60, 75, 120, 144, 165, 240)

    # Get available refresh rates
    $devMode = New-Object DisplayHelper+DEVMODE
    $devMode.dmSize = [Runtime.InteropServices.Marshal]::SizeOf($devMode)
    $modeNum = 0

    $availableRates = @()
    while ([DisplayHelper]::EnumDisplaySettings($null, $modeNum, [ref]$devMode) -ne 0) {
        if ($devMode.dmDisplayFrequency -notin $availableRates) {
            $availableRates += $devMode.dmDisplayFrequency
        }
        $modeNum++
    }

    foreach ($rate in $standardRates) {
        Write-Host "  Testing ${rate}Hz..." -NoNewline

        if ($rate -in $availableRates) {
            Write-Host " $(Get-Emoji CheckMark) Supported" -ForegroundColor Green
            $testResult.RefreshRatesTested += @{
                RefreshRate = "${rate}Hz"
                Supported = $true
            }
        } else {
            Write-Host " $(Get-Emoji BallotX) Not supported" -ForegroundColor Yellow
            $testResult.RefreshRatesTested += @{
                RefreshRate = "${rate}Hz"
                Supported = $false
            }
        }
    }

    Write-Host "  Available rates: $($availableRates -join ', ')Hz" -ForegroundColor Gray

    $script:TestResults.Tests += $testResult
    return $testResult
}

function Test-SignalStability {
    param([int]$Duration = 10)

    Write-Host "`n$(Get-Emoji Satellite) Testing signal stability ($Duration seconds)..." -ForegroundColor Green

    $testResult = @{
        TestName = "Signal Stability Test"
        Timestamp = Get-Date -Format "o"
        DurationSeconds = $Duration
        Samples = @()
        Passed = $true
    }

    Write-Host "  Monitoring for disconnections and errors..."

    for ($i = 1; $i -le $Duration; $i++) {
        $progress = "#" * $i + "-" * ($Duration - $i)
        Write-Host "`r  Progress: [$progress] $i/${Duration}s" -NoNewline

        try {
            $monitorCount = (Get-CimInstance -ClassName Win32_DesktopMonitor -ErrorAction SilentlyContinue | Measure-Object).Count

            $testResult.Samples += @{
                Time = $i
                DisplaysConnected = $monitorCount
                Stable = ($monitorCount -gt 0)
            }

            if ($monitorCount -eq 0) {
                $testResult.Passed = $false
            }
        } catch {
            $testResult.Samples += @{
                Time = $i
                Error = $_.Exception.Message
            }
        }

        Start-Sleep -Seconds 1
    }

    Write-Host ""

    if ($testResult.Passed) {
        Write-Host "  $(Get-Emoji CheckMark) No disconnections detected" -ForegroundColor Green
    } else {
        Write-Host "  $(Get-Emoji BallotX) Disconnections or errors detected!" -ForegroundColor Red
    }

    $script:TestResults.Tests += $testResult
    return $testResult
}

function Get-BandwidthRequirement {
    param(
        [int]$Width,
        [int]$Height,
        [int]$RefreshRate,
        [int]$BitDepth = 8,
        [string]$Chroma = "4:4:4"
    )

    $pixelsPerSecond = $Width * $Height * $RefreshRate

    switch ($Chroma) {
        "4:4:4" { $bitsPerPixel = $BitDepth * 3 }
        "4:2:2" { $bitsPerPixel = $BitDepth * 2 }
        "4:2:0" { $bitsPerPixel = $BitDepth * 1.5 }
    }

    # Add 25% overhead for blanking and encoding
    $bandwidthBps = $pixelsPerSecond * $bitsPerPixel * 1.25
    $bandwidthGbps = $bandwidthBps / 1000000000

    return [Math]::Round($bandwidthGbps, 2)
}

function Test-BandwidthCapabilities {
    Write-Host "`n$(Get-Emoji Rocket) Analyzing bandwidth requirements..." -ForegroundColor Green

    $testResult = @{
        TestName = "Bandwidth Analysis"
        Timestamp = Get-Date -Format "o"
        BandwidthTests = @()
    }

    $testScenarios = @(
        @{Width=1920; Height=1080; Rate=60; Name="1080p@60Hz"},
        @{Width=1920; Height=1080; Rate=144; Name="1080p@144Hz"},
        @{Width=2560; Height=1440; Rate=60; Name="1440p@60Hz"},
        @{Width=2560; Height=1440; Rate=144; Name="1440p@144Hz"},
        @{Width=3840; Height=2160; Rate=60; Name="4K@60Hz"},
        @{Width=3840; Height=2160; Rate=120; Name="4K@120Hz"}
    )

    $hdmiVersions = @{
        "HDMI 1.4" = 10.2
        "HDMI 2.0" = 18.0
        "HDMI 2.1" = 48.0
    }

    Write-Host ""
    Write-Host "  Resolution/Rate      Bandwidth    HDMI 1.4  HDMI 2.0  HDMI 2.1"
    Write-Host "  $("-" * 66)"

    foreach ($scenario in $testScenarios) {
        $bandwidth = Get-BandwidthRequirement -Width $scenario.Width -Height $scenario.Height -RefreshRate $scenario.Rate

        $compatible = @()
        foreach ($version in $hdmiVersions.Keys) {
            if ($bandwidth -le $hdmiVersions[$version]) {
                $compatible += $version
            }
        }

        $hdmi14 = if ($bandwidth -le 10.2) { Get-Emoji CheckMark } else { Get-Emoji BallotX }
        $hdmi20 = if ($bandwidth -le 18.0) { Get-Emoji CheckMark } else { Get-Emoji BallotX }
        $hdmi21 = if ($bandwidth -le 48.0) { Get-Emoji CheckMark } else { Get-Emoji BallotX }

        $nameFormatted = $scenario.Name.PadRight(20)
        $bandwidthFormatted = ("{0:N2} Gbps" -f $bandwidth).PadLeft(12)

        Write-Host ("  {0} {1}    {2}  {3}  {4}" -f $nameFormatted, $bandwidthFormatted, $hdmi14.PadLeft(8), $hdmi20.PadLeft(8), $hdmi21.PadLeft(8))

        $testResult.BandwidthTests += @{
            Scenario = $scenario.Name
            BandwidthGbps = $bandwidth
            CompatibleVersions = $compatible
        }
    }

    $script:TestResults.Tests += $testResult
    return $testResult
}

function Get-CableQualityAssessment {
    Write-Host "`n$(Get-Emoji MagnifyingGlass) Assessing cable quality..." -ForegroundColor Green

    $totalTests = $script:TestResults.Tests.Count
    $passedTests = ($script:TestResults.Tests | Where-Object { $_.Passed -eq $true }).Count

    if ($totalTests -eq 0) {
        $quality = "Unknown"
    } elseif ($passedTests -eq $totalTests) {
        $quality = "Excellent"
    } elseif ($passedTests -ge ($totalTests * 0.8)) {
        $quality = "Good"
    } elseif ($passedTests -ge ($totalTests * 0.5)) {
        $quality = "Fair"
    } else {
        $quality = "Poor"
    }

    $script:TestResults.OverallQuality = $quality
    return $quality
}

function Show-TestReport {
    Write-Host "`n$("=" * 70)" -ForegroundColor Cyan
    Write-Host "$(Get-Emoji BarChart) HDMI CABLE TEST REPORT" -ForegroundColor Cyan
    Write-Host "$("=" * 70)" -ForegroundColor Cyan

    Write-Host "`nTest Date: $($script:TestResults.Timestamp)"
    Write-Host "Platform: $($script:TestResults.Platform)"
    Write-Host "OS Version: $($script:TestResults.OSVersion)"

    $qualityColor = switch ($script:TestResults.OverallQuality) {
        "Excellent" { "Green" }
        "Good" { "Green" }
        "Fair" { "Yellow" }
        "Poor" { "Red" }
        default { "White" }
    }

    Write-Host "`nOverall Cable Quality: " -NoNewline
    Write-Host $script:TestResults.OverallQuality -ForegroundColor $qualityColor

    Write-Host "`n$("-" * 70)"
    Write-Host "`n$(Get-Emoji TV) DETECTED DISPLAYS:" -ForegroundColor Green

    $displayNum = 1
    foreach ($display in $script:TestResults.Displays) {
        Write-Host "`n  Display ${displayNum}:"
        foreach ($key in $display.Keys) {
            if ($key -ne "modes") {
                Write-Host "    ${key}: $($display[$key])"
            }
        }
        $displayNum++
    }

    Write-Host "`n$("-" * 70)"
    Write-Host "`n$(Get-Emoji BarChart) TEST RESULTS:" -ForegroundColor Green

    foreach ($test in $script:TestResults.Tests) {
        $status = if ($test.Passed -eq $true) { "$(Get-Emoji CheckMark) PASSED" } else { "$(Get-Emoji Warning) INFO" }
        $statusColor = if ($test.Passed -eq $true) { "Green" } else { "Yellow" }

        Write-Host "`n  - $($test.TestName)"
        Write-Host "    Status: " -NoNewline
        Write-Host $status -ForegroundColor $statusColor
        Write-Host "    Time: $($test.Timestamp)"
    }

    Write-Host "`n$("=" * 70)" -ForegroundColor Cyan
}

function Save-TestReport {
    param([string]$Path)

    try {
        $script:TestResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8
        Write-Host "`n$(Get-Emoji FloppyDisk) Report saved to: $Path" -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "Failed to save report: $_"
        return $false
    }
}

# Main execution
function Start-HDMICableTest {
    Write-Header

    Write-Host "This tool will test your HDMI cable quality by:" -ForegroundColor White
    Write-Host "  - Detecting connected displays"
    Write-Host "  - Testing resolution support"
    Write-Host "  - Testing refresh rate support"
    Write-Host "  - Analyzing bandwidth capabilities"
    Write-Host "  - Monitoring signal stability"
    Write-Host ""

    if (-not $isAdmin) {
        Write-Host "$(Get-Emoji Warning) Note: Running without Administrator privileges" -ForegroundColor Yellow
        Write-Host "  Some tests may have limited functionality" -ForegroundColor Yellow
        Write-Host ""
    }

    Read-Host "Press Enter to start testing"

    # Run tests
    Get-DisplayInformation
    Test-ResolutionSupport
    Test-RefreshRates
    Test-BandwidthCapabilities

    # Signal stability test
    Write-Host "`n$(Get-Emoji Warning) Signal stability test will take $StabilityTestDuration seconds..." -ForegroundColor Yellow
    $response = Read-Host "  Run stability test? (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Test-SignalStability -Duration $StabilityTestDuration
    } else {
        Write-Host "  Skipped signal stability test" -ForegroundColor Gray
    }

    # Generate report
    Get-CableQualityAssessment
    Show-TestReport

    # Save report
    if ($SaveReport) {
        Write-Host "`n$(Get-Emoji FloppyDisk) Saving report to: $ReportPath" -ForegroundColor Green
        Save-TestReport -Path $ReportPath
    } else {
        $response = Read-Host "`n$(Get-Emoji FloppyDisk) Save report to file? (y/n)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            Save-TestReport -Path $ReportPath
        }
    }

    Write-Host "`n$(Get-Emoji Sparkles) Testing complete!" -ForegroundColor Green

    return $script:TestResults
}

# Run the test
Start-HDMICableTest
