# HDMI Cable Quality Tester

A comprehensive software suite for testing HDMI cable quality on Windows and WSL systems. This tool helps identify cable limitations, bandwidth capabilities, and signal integrity issues.

## Features

- **Display Detection**: Automatically detects connected displays and reads EDID information
- **Resolution Testing**: Tests support for various standard resolutions (720p, 1080p, 1440p, 4K, etc.)
- **Refresh Rate Testing**: Verifies support for different refresh rates (60Hz, 75Hz, 120Hz, 144Hz, 240Hz)
- **Bandwidth Analysis**: Calculates bandwidth requirements and HDMI version compatibility
- **Signal Stability Monitoring**: Monitors for disconnections and signal degradation
- **Detailed Reporting**: Generates comprehensive JSON reports with test results
- **Quality Assessment**: Provides an overall cable quality rating

## Components

### 1. Python Version (`hdmi_cable_tester.py`)

Cross-platform Python script that works on both Windows and WSL.

#### Requirements

**Windows:**
```bash
pip install pywin32 wmi pillow
```

**WSL/Linux:**
```bash
sudo apt-get install x11-xserver-utils
sudo apt install python3-pip
sudo apt install python3-pil
```

#### Usage

```bash
# Basic usage
python hdmi_cable_tester.py

# Or make it executable and run directly
chmod +x hdmi_cable_tester.py
./hdmi_cable_tester.py
```

#### Features
- Works on both Windows and WSL
- Automatic platform detection
- Interactive testing workflow
- JSON report generation
- Comprehensive bandwidth calculations

### 2. PowerShell Version (`Test-HDMICable.ps1`)

Native Windows PowerShell script with advanced Windows API integration.

#### Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later
- Administrator privileges (recommended for full functionality)

#### Usage

**Basic Usage:**
```powershell
.\Test-HDMICable.ps1
```

**With Auto-Save:**
```powershell
.\Test-HDMICable.ps1 -SaveReport
```

**Custom Report Path:**
```powershell
.\Test-HDMICable.ps1 -SaveReport -ReportPath "C:\Reports\hdmi_test.json"
```

**Custom Stability Test Duration:**
```powershell
.\Test-HDMICable.ps1 -StabilityTestDuration 20
```

#### Features
- Native Windows API integration
- Detailed EDID information extraction
- Real-time display mode enumeration
- Enhanced error detection
- Color-coded output

## How It Works

### 1. Display Detection

The tools detect connected displays using:
- **Windows**: WMI (Windows Management Instrumentation) queries and Windows Forms API
- **Linux/WSL**: xrandr and X11 utilities

### 2. Resolution Testing

Tests support for standard resolutions:
- 1280x720 (720p HD)
- 1920x1080 (1080p Full HD)
- 2560x1440 (1440p QHD)
- 3840x2160 (4K UHD)
- 2560x1080 (UltraWide)

### 3. Refresh Rate Testing

Verifies support for common refresh rates:
- 60Hz (Standard)
- 75Hz
- 120Hz
- 144Hz (Gaming)
- 165Hz
- 240Hz (High-end gaming)

### 4. Bandwidth Analysis

Calculates required bandwidth for various scenarios and determines HDMI version compatibility:

| Resolution | Refresh Rate | Bandwidth | Required HDMI Version |
|------------|--------------|-----------|----------------------|
| 1080p | 60Hz | ~4.5 Gbps | HDMI 1.4+ |
| 1080p | 144Hz | ~10.8 Gbps | HDMI 2.0+ |
| 1440p | 60Hz | ~8.0 Gbps | HDMI 1.4+ |
| 1440p | 144Hz | ~19.2 Gbps | HDMI 2.0+ |
| 4K | 60Hz | ~17.8 Gbps | HDMI 2.0+ |
| 4K | 120Hz | ~42.6 Gbps | HDMI 2.1+ |

### 5. Signal Stability

Monitors the display connection over time (default 10 seconds) to detect:
- Intermittent disconnections
- Signal dropouts
- Connection instability

## Understanding the Results

### Cable Quality Ratings

- **Excellent**: All tests passed, cable supports maximum capabilities
- **Good**: Most tests passed (80%+), minor limitations
- **Fair**: Moderate performance (50-80%), some features unsupported
- **Poor**: Significant issues detected (<50% pass rate)

### Common Issues and What They Mean

#### ❌ Resolution Not Supported
- **Possible Causes**:
  - Cable bandwidth limitation
  - Display doesn't support the resolution
  - Graphics card limitation
- **Solution**: Try a higher-quality cable (HDMI 2.0 or 2.1)

#### ❌ High Refresh Rate Failure
- **Possible Causes**:
  - Cable not rated for high bandwidth
  - HDMI 1.4 cable with 1440p/4K content
- **Solution**: Use HDMI 2.0+ certified cable for >60Hz at high resolutions

#### ❌ Signal Stability Issues
- **Possible Causes**:
  - Poor cable quality or damage
  - Loose connections
  - Electromagnetic interference
- **Solution**:
  - Check cable connections
  - Replace cable
  - Reduce cable length or use a repeater

#### ❌ Bandwidth Limitations
- **Possible Causes**:
  - Using HDMI 1.4 cable for 4K@60Hz or higher
  - Cable length too long (>15 feet for high bandwidth)
- **Solution**: Use certified HDMI 2.0 or 2.1 cable for high-resolution/high-refresh-rate content

## HDMI Version Reference

### HDMI 1.4
- Bandwidth: 10.2 Gbps
- Max: 4K@30Hz or 1080p@120Hz
- Released: 2009

### HDMI 2.0/2.0b
- Bandwidth: 18 Gbps
- Max: 4K@60Hz or 1080p@240Hz
- Supports HDR
- Released: 2013

### HDMI 2.1
- Bandwidth: 48 Gbps
- Max: 8K@60Hz or 4K@120Hz
- Supports Dynamic HDR, VRR, eARC
- Released: 2017

## Troubleshooting

### Windows Issues

**Problem**: "Not running as Administrator" warning
- **Solution**: Right-click PowerShell and select "Run as Administrator"

**Problem**: Python script can't detect displays
- **Solution**: Install required dependencies: `pip install pywin32 wmi`

**Problem**: "Get-DisplayMode not found"
- **Solution**: This is expected on some systems; the tool will use alternative methods

### WSL Issues

**Problem**: "No displays detected"
- **Solution**:
  - Ensure X server is running (VcXsrv, X410, or WSLg)
  - Set DISPLAY environment variable: `export DISPLAY=:0`
  - Install xrandr: `sudo apt-get install x11-xserver-utils`

**Problem**: "xrandr not found"
- **Solution**: `sudo apt-get install x11-xserver-utils`

### General Issues

**Problem**: All tests fail
- **Possible Causes**:
  - Display not properly connected
  - Graphics driver issues
  - Insufficient permissions
- **Solution**:
  - Check physical connections
  - Update graphics drivers
  - Run with administrator/sudo privileges

**Problem**: Inconsistent results
- **Solution**:
  - Close other applications using the display
  - Disable display power management during testing
  - Run test multiple times

## Advanced Usage

### Automated Testing

**PowerShell - Scheduled Testing:**
```powershell
# Create a scheduled task to run tests daily
$trigger = New-ScheduledTaskTrigger -Daily -At 3am
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Path\To\Test-HDMICable.ps1 -SaveReport"
Register-ScheduledTask -TaskName "HDMI Cable Test" -Trigger $trigger -Action $action
```

**Python - Batch Testing:**
```python
# Test multiple times and average results
for i in range(5):
    tester = HDMICableTester()
    results = tester.run_full_test()
    tester.save_report(f"test_run_{i}.json")
```

### Custom Testing

Both tools can be imported and used programmatically:

**Python:**
```python
from hdmi_cable_tester import HDMICableTester

tester = HDMICableTester()
displays = tester.detect_displays()
tester.test_resolution_support([(1920, 1080), (3840, 2160)])
results = tester.test_results
```

**PowerShell:**
```powershell
# Import functions
. .\Test-HDMICable.ps1

# Run specific tests
Get-DisplayInformation
Test-ResolutionSupport
$results = $script:TestResults
```

## Interpreting Bandwidth Requirements

### Formula

```
Bandwidth (Gbps) = (Width × Height × RefreshRate × BitsPerPixel × 1.25) / 1,000,000,000
```

Where:
- **Width × Height**: Total pixels
- **RefreshRate**: Frames per second
- **BitsPerPixel**: Color depth (typically 24 bits for 8-bit color)
- **1.25**: 25% overhead for blanking intervals and encoding

### Examples

**1080p@60Hz:**
```
(1920 × 1080 × 60 × 24 × 1.25) / 1,000,000,000 = 3.73 Gbps
```

**4K@120Hz:**
```
(3840 × 2160 × 120 × 24 × 1.25) / 1,000,000,000 = 35.83 Gbps
```

## Best Practices

1. **Use Certified Cables**: Look for official HDMI certification labels
2. **Consider Length**: Longer cables (>15ft/5m) may need active components for high bandwidth
3. **Regular Testing**: Test cables periodically, especially after physical stress
4. **Document Results**: Save test reports for warranty or troubleshooting purposes
5. **Compare Cables**: Test multiple cables to identify the best performer

## Limitations

### Software Limitations

- Cannot measure electrical signal quality directly
- Cannot detect physical damage (bent pins, etc.)
- Relies on OS and driver reporting (may be incomplete)
- Some tests require active display session
- WSL support is limited by X server configuration

### Hardware Limitations

- Results depend on graphics card capabilities
- Display must support tested resolutions/rates
- Some features require specific HDMI port versions
- Legacy hardware may not report full information

## Contributing

Found a bug or want to add a feature? Contributions are welcome!

## License

This software is provided as-is for testing and diagnostic purposes.

## FAQ

**Q: Will this damage my hardware?**
A: No, the software only reads information and tests display modes supported by your hardware. It doesn't force unsupported modes.

**Q: Why do results differ from cable specifications?**
A: Results show what your system can actually achieve, which may be limited by graphics card, display, or driver support, not just the cable.

**Q: Can this test DisplayPort or USB-C cables?**
A: No, this tool is specifically designed for HDMI connections.

**Q: How often should I test my cables?**
A: Test when you experience display issues, after moving equipment, or when upgrading displays/graphics cards.

**Q: What's the best HDMI cable to buy?**
A: For 4K@60Hz, use HDMI 2.0 or Premium High Speed certified cables. For 4K@120Hz or 8K, use HDMI 2.1 or Ultra High Speed certified cables.

## Support

For issues, questions, or contributions, please refer to the project documentation or contact the maintainer.

---

**Version**: 1.0
**Last Updated**: 2025-10-27
**Author**: Claude
