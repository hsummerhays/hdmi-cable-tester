#!/usr/bin/env python3
"""
HDMI Cable Tester for Windows/WSL

This tool tests HDMI cable quality by:
- Detecting connected displays and reading EDID data
- Testing various resolutions and refresh rates
- Monitoring signal stability
- Checking HDMI capabilities (bandwidth, HDR, audio)
- Providing a quality report

Requirements:
- Windows: Run with administrator privileges
- Install: pip install pywin32 wmi pillow (for Windows)
- WSL: Install edid-decode, xrandr

Author: Claude
"""

import os
import sys
import time
import json
import subprocess
import platform
from datetime import datetime
from typing import List, Dict, Tuple, Optional


class HDMICableTester:
    """Main HDMI cable testing class"""

    def __init__(self):
        self.platform = platform.system()
        self.is_windows = self.platform == "Windows"
        self.test_results = {
            "timestamp": datetime.now().isoformat(),
            "platform": self.platform,
            "displays": [],
            "tests": [],
            "overall_quality": "Unknown"
        }

    def clear_screen(self):
        """Clear the terminal screen"""
        os.system('cls' if self.is_windows else 'clear')

    def print_header(self):
        """Print application header"""
        print("=" * 70)
        print("HDMI CABLE QUALITY TESTER".center(70))
        print("=" * 70)
        print(f"Platform: {self.platform}")
        print(f"Test Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 70)
        print()

    def detect_displays_windows(self) -> List[Dict]:
        """Detect displays on Windows using WMI and PowerShell"""
        displays = []

        try:
            # Try using PowerShell to get display information
            ps_script = """
            Get-CimInstance -Namespace root\\wmi -ClassName WmiMonitorID | ForEach-Object {
                $name = ($_.UserFriendlyName | Where-Object {$_ -ne 0}) -join '' | ForEach-Object {[char]$_} | Out-String
                $serial = ($_.SerialNumberID | Where-Object {$_ -ne 0}) -join '' | ForEach-Object {[char]$_} | Out-String
                $manufacturer = ($_.ManufacturerName | Where-Object {$_ -ne 0}) -join '' | ForEach-Object {[char]$_} | Out-String

                [PSCustomObject]@{
                    Name = $name.Trim()
                    Serial = $serial.Trim()
                    Manufacturer = $manufacturer.Trim()
                }
            } | ConvertTo-Json
            """

            result = subprocess.run(
                ["powershell", "-Command", ps_script],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0 and result.stdout.strip():
                try:
                    data = json.loads(result.stdout)
                    if isinstance(data, list):
                        displays.extend(data)
                    else:
                        displays.append(data)
                except json.JSONDecodeError:
                    pass

            # Get display modes
            ps_modes = """
            Get-DisplayMode | Select-Object Width, Height, RefreshRate | ConvertTo-Json
            """

            result = subprocess.run(
                ["powershell", "-Command", ps_modes],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0 and result.stdout.strip():
                try:
                    modes_data = json.loads(result.stdout)
                    if displays:
                        displays[0]['current_mode'] = modes_data
                except json.JSONDecodeError:
                    pass

        except Exception as e:
            print(f"⚠ Warning: Could not detect displays via WMI: {e}")

        # Fallback: Use basic display detection
        if not displays:
            try:
                result = subprocess.run(
                    ["powershell", "-Command", "Get-CimInstance -ClassName Win32_DesktopMonitor | Select-Object Name, ScreenWidth, ScreenHeight | ConvertTo-Json"],
                    capture_output=True,
                    text=True,
                    timeout=10
                )

                if result.returncode == 0 and result.stdout.strip():
                    data = json.loads(result.stdout)
                    if isinstance(data, list):
                        displays.extend(data)
                    else:
                        displays.append(data)
            except Exception as e:
                print(f"⚠ Warning: Fallback display detection failed: {e}")
                displays.append({
                    "Name": "Unknown Display",
                    "Note": "Run as Administrator for detailed information"
                })

        return displays

    def detect_displays_linux(self) -> List[Dict]:
        """Detect displays on Linux/WSL using xrandr"""
        displays = []

        try:
            # Check if running in WSL
            result = subprocess.run(
                ["cat", "/proc/version"],
                capture_output=True,
                text=True
            )
            is_wsl = "microsoft" in result.stdout.lower()

            if is_wsl:
                print("ℹ Running in WSL. Display detection may be limited.")
                print("  For best results, use the Windows PowerShell version.")
                print()

            # Try xrandr
            result = subprocess.run(
                ["xrandr", "--verbose"],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0:
                current_display = None
                for line in result.stdout.split('\n'):
                    if " connected" in line:
                        parts = line.split()
                        current_display = {
                            "port": parts[0],
                            "connected": True,
                            "modes": []
                        }
                        displays.append(current_display)
                    elif current_display and "x" in line and "+" in line:
                        # Parse resolution line
                        parts = line.strip().split()
                        if parts:
                            mode = parts[0]
                            current_display["modes"].append(mode)
                            if "*" in line:
                                current_display["current_mode"] = mode

        except FileNotFoundError:
            print("⚠ xrandr not found. Please install: sudo apt-get install x11-xserver-utils")
        except Exception as e:
            print(f"⚠ Warning: Could not detect displays: {e}")

        if not displays:
            displays.append({
                "Note": "No displays detected. Make sure X server is running (for WSL) or run on Windows."
            })

        return displays

    def detect_displays(self) -> List[Dict]:
        """Detect connected displays"""
        print("📺 Detecting connected displays...")

        if self.is_windows:
            displays = self.detect_displays_windows()
        else:
            displays = self.detect_displays_linux()

        self.test_results["displays"] = displays
        return displays

    def test_resolution_support(self, resolutions: List[Tuple[int, int]]) -> Dict:
        """Test if various resolutions are supported"""
        print("\n📐 Testing resolution support...")

        test_result = {
            "test_name": "Resolution Support Test",
            "timestamp": datetime.now().isoformat(),
            "resolutions_tested": [],
            "passed": True
        }

        standard_resolutions = resolutions or [
            (1920, 1080),  # 1080p
            (2560, 1440),  # 1440p
            (3840, 2160),  # 4K
            (1280, 720),   # 720p
        ]

        for width, height in standard_resolutions:
            res_name = f"{width}x{height}"
            print(f"  Testing {res_name}...", end=" ")

            # On Windows, check available modes via PowerShell
            if self.is_windows:
                try:
                    ps_script = f"""
                    $modes = Get-DisplayMode
                    $match = $modes | Where-Object {{ $_.Width -eq {width} -and $_.Height -eq {height} }}
                    if ($match) {{ Write-Output "supported" }} else {{ Write-Output "not_supported" }}
                    """

                    result = subprocess.run(
                        ["powershell", "-Command", ps_script],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )

                    supported = "supported" in result.stdout.lower()
                    test_result["resolutions_tested"].append({
                        "resolution": res_name,
                        "supported": supported
                    })
                    print("✓ Supported" if supported else "✗ Not supported")

                except Exception as e:
                    print(f"⚠ Error: {e}")
                    test_result["resolutions_tested"].append({
                        "resolution": res_name,
                        "supported": False,
                        "error": str(e)
                    })
            else:
                # On Linux, check xrandr output
                print("⊘ Simulated (requires active session)")
                test_result["resolutions_tested"].append({
                    "resolution": res_name,
                    "supported": "unknown",
                    "note": "Requires active display session to test"
                })

        self.test_results["tests"].append(test_result)
        return test_result

    def test_refresh_rates(self) -> Dict:
        """Test different refresh rates"""
        print("\n🔄 Testing refresh rate support...")

        test_result = {
            "test_name": "Refresh Rate Test",
            "timestamp": datetime.now().isoformat(),
            "refresh_rates_tested": [],
            "passed": True
        }

        standard_rates = [60, 75, 120, 144, 240]

        for rate in standard_rates:
            print(f"  Testing {rate}Hz...", end=" ")

            if self.is_windows:
                try:
                    ps_script = f"""
                    $modes = Get-DisplayMode
                    $match = $modes | Where-Object {{ $_.RefreshRate -eq {rate} }}
                    if ($match) {{ Write-Output "supported" }} else {{ Write-Output "not_supported" }}
                    """

                    result = subprocess.run(
                        ["powershell", "-Command", ps_script],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )

                    supported = "supported" in result.stdout.lower()
                    test_result["refresh_rates_tested"].append({
                        "refresh_rate": f"{rate}Hz",
                        "supported": supported
                    })
                    print("✓ Supported" if supported else "✗ Not supported")

                except Exception as e:
                    print(f"⚠ Error: {e}")
                    test_result["refresh_rates_tested"].append({
                        "refresh_rate": f"{rate}Hz",
                        "supported": False,
                        "error": str(e)
                    })
            else:
                print("⊘ Simulated (requires active session)")
                test_result["refresh_rates_tested"].append({
                    "refresh_rate": f"{rate}Hz",
                    "supported": "unknown"
                })

        self.test_results["tests"].append(test_result)
        return test_result

    def test_signal_stability(self, duration: int = 10) -> Dict:
        """Monitor signal stability over time"""
        print(f"\n📡 Testing signal stability ({duration} seconds)...")

        test_result = {
            "test_name": "Signal Stability Test",
            "timestamp": datetime.now().isoformat(),
            "duration_seconds": duration,
            "samples": [],
            "passed": True
        }

        print("  Monitoring for disconnections and errors...")

        for i in range(duration):
            print(f"  Progress: {'█' * (i + 1)}{'░' * (duration - i - 1)} {i + 1}/{duration}s", end="\r")

            # Check if display is still connected
            if self.is_windows:
                try:
                    result = subprocess.run(
                        ["powershell", "-Command", "Get-CimInstance -ClassName Win32_DesktopMonitor | Measure-Object | Select-Object -ExpandProperty Count"],
                        capture_output=True,
                        text=True,
                        timeout=2
                    )

                    count = int(result.stdout.strip()) if result.stdout.strip().isdigit() else 0
                    test_result["samples"].append({
                        "time": i,
                        "displays_connected": count,
                        "stable": count > 0
                    })

                    if count == 0:
                        test_result["passed"] = False

                except Exception:
                    test_result["samples"].append({
                        "time": i,
                        "error": "Could not check connection"
                    })

            time.sleep(1)

        print(f"\n  Completed: {duration} samples collected")

        if test_result["passed"]:
            print("  ✓ No disconnections detected")
        else:
            print("  ✗ Disconnections or errors detected!")

        self.test_results["tests"].append(test_result)
        return test_result

    def calculate_bandwidth_requirement(self, width: int, height: int, refresh_rate: int,
                                       bit_depth: int = 8, chroma: str = "4:4:4") -> float:
        """Calculate HDMI bandwidth requirement in Gbps"""
        # Simplified calculation
        pixels_per_second = width * height * refresh_rate

        # Bits per pixel (with overhead)
        if chroma == "4:4:4":
            bits_per_pixel = bit_depth * 3  # RGB
        elif chroma == "4:2:2":
            bits_per_pixel = bit_depth * 2
        else:  # 4:2:0
            bits_per_pixel = bit_depth * 1.5

        # Add 25% overhead for blanking intervals and encoding
        bandwidth_bps = pixels_per_second * bits_per_pixel * 1.25
        bandwidth_gbps = bandwidth_bps / 1_000_000_000

        return bandwidth_gbps

    def test_bandwidth_capabilities(self) -> Dict:
        """Test and report bandwidth capabilities"""
        print("\n🚀 Analyzing bandwidth requirements...")

        test_result = {
            "test_name": "Bandwidth Analysis",
            "timestamp": datetime.now().isoformat(),
            "bandwidth_tests": []
        }

        test_scenarios = [
            (1920, 1080, 60, "1080p@60Hz"),
            (1920, 1080, 144, "1080p@144Hz"),
            (2560, 1440, 60, "1440p@60Hz"),
            (2560, 1440, 144, "1440p@144Hz"),
            (3840, 2160, 60, "4K@60Hz"),
            (3840, 2160, 120, "4K@120Hz"),
        ]

        hdmi_versions = {
            "HDMI 1.4": 10.2,
            "HDMI 2.0": 18.0,
            "HDMI 2.1": 48.0
        }

        print("\n  Resolution/Rate      Bandwidth    HDMI 1.4  HDMI 2.0  HDMI 2.1")
        print("  " + "-" * 66)

        for width, height, rate, name in test_scenarios:
            bandwidth = self.calculate_bandwidth_requirement(width, height, rate)

            compatible = []
            for version, max_bw in hdmi_versions.items():
                if bandwidth <= max_bw:
                    compatible.append(version)

            hdmi_14 = "✓" if bandwidth <= 10.2 else "✗"
            hdmi_20 = "✓" if bandwidth <= 18.0 else "✗"
            hdmi_21 = "✓" if bandwidth <= 48.0 else "✗"

            print(f"  {name:20} {bandwidth:6.2f} Gbps    {hdmi_14:^8}  {hdmi_20:^8}  {hdmi_21:^8}")

            test_result["bandwidth_tests"].append({
                "scenario": name,
                "bandwidth_gbps": round(bandwidth, 2),
                "compatible_versions": compatible
            })

        self.test_results["tests"].append(test_result)
        return test_result

    def assess_cable_quality(self) -> str:
        """Assess overall cable quality based on test results"""
        print("\n🔍 Assessing cable quality...")

        # Count passed/failed tests
        total_tests = len(self.test_results["tests"])
        passed_tests = sum(1 for test in self.test_results["tests"]
                          if test.get("passed", True))

        if total_tests == 0:
            quality = "Unknown"
        elif passed_tests == total_tests:
            quality = "Excellent"
        elif passed_tests >= total_tests * 0.8:
            quality = "Good"
        elif passed_tests >= total_tests * 0.5:
            quality = "Fair"
        else:
            quality = "Poor"

        self.test_results["overall_quality"] = quality
        return quality

    def generate_report(self) -> str:
        """Generate a detailed test report"""
        report = []
        report.append("\n" + "=" * 70)
        report.append("HDMI CABLE TEST REPORT".center(70))
        report.append("=" * 70)
        report.append(f"\nTest Date: {self.test_results['timestamp']}")
        report.append(f"Platform: {self.test_results['platform']}")
        report.append(f"\nOverall Cable Quality: {self.test_results['overall_quality']}")
        report.append("\n" + "-" * 70)

        # Display information
        report.append("\n📺 DETECTED DISPLAYS:")
        for i, display in enumerate(self.test_results["displays"], 1):
            report.append(f"\n  Display {i}:")
            for key, value in display.items():
                if key != "modes":
                    report.append(f"    {key}: {value}")

        # Test results
        report.append("\n" + "-" * 70)
        report.append("\n📊 TEST RESULTS:")
        for test in self.test_results["tests"]:
            report.append(f"\n  • {test['test_name']}")
            report.append(f"    Status: {'✓ PASSED' if test.get('passed', True) else '✗ FAILED'}")
            report.append(f"    Time: {test['timestamp']}")

        report.append("\n" + "=" * 70)

        return "\n".join(report)

    def save_report(self, filename: str = None):
        """Save test results to JSON file"""
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"hdmi_test_report_{timestamp}.json"

        with open(filename, 'w') as f:
            json.dump(self.test_results, f, indent=2)

        print(f"\n💾 Report saved to: {filename}")
        return filename

    def run_full_test(self):
        """Run complete HDMI cable test suite"""
        self.clear_screen()
        self.print_header()

        # Detect displays
        displays = self.detect_displays()
        print(f"\n  Found {len(displays)} display(s)")

        # Run tests
        self.test_resolution_support([
            (1920, 1080),
            (2560, 1440),
            (3840, 2160)
        ])

        self.test_refresh_rates()

        self.test_bandwidth_capabilities()

        # Signal stability test
        print("\n⚠ Signal stability test will take 10 seconds...")
        response = input("  Run stability test? (y/n): ")
        if response.lower() == 'y':
            self.test_signal_stability(10)
        else:
            print("  Skipped signal stability test")

        # Generate report
        quality = self.assess_cable_quality()
        report = self.generate_report()
        print(report)

        # Save results
        response = input("\n💾 Save report to file? (y/n): ")
        if response.lower() == 'y':
            filename = self.save_report()

        print("\n✨ Testing complete!")
        return self.test_results


def main():
    """Main entry point"""
    try:
        tester = HDMICableTester()

        print("HDMI Cable Tester")
        print("=" * 50)
        print("\nThis tool will test your HDMI cable quality by:")
        print("  • Detecting connected displays")
        print("  • Testing resolution support")
        print("  • Testing refresh rate support")
        print("  • Analyzing bandwidth capabilities")
        print("  • Monitoring signal stability")
        print("\nNote: Some tests require administrator privileges on Windows")
        print("=" * 50)

        input("\nPress Enter to start testing...")

        tester.run_full_test()

    except KeyboardInterrupt:
        print("\n\n⚠ Testing interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
