# ARCore Patch

This is an attempt to patch ARCore (Preview 2) to run on currently unsupported devices.

## Findings

Although not directly obvious to users, ARCore Preview 2 seems to have gone through huge changes compared to Preview 1. Thus, the approach from https://github.com/tomthecarrot/arcore-for-all is not directly applicable anymore.

Device compatibility related functionality has been moved from the `aar` packaged in apps to the `arcore-preview2.apk`. This apk now contains a native library called `libdevice_profile_loader.so` which is responsible for loading a profile for the device. In the following, memory addresses are specified as virtual addresses for the arm64-v8a version of this library.

Devices are hard-coded inside this library and are identified by an enum (just an int value) called `device_provider::DeviceType`. Luckily, there a function included that converts this value to a readable string called `device_provider::ToString(const device_provider::DeviceType &)` (at `0x00048ea0`). See [device_type_strings.txt](device_type_strings.txt) for possible strings (starting at `0x00157e5c`). Here are some examples for values with corresponding strings (incomplete list):

| DeviceType | String               |
| ---------- | -------------------- |
| 0          | kUnknownDevice       |
| 1          | kPeanut              |
| 4          | kYellowstoneDVT2     |
| 5          | kYellowstoneDVT3     |
| 6          | kYellowstonePVT      |
| 7          | kYellowstoneRangeEnd |
| 8          | kTwizzler            |
| 9          | kRubicon             |
| 10         | kSimulation          |
| 11         | kCoconut             |
| 12         | kPistachio           |
| 13         | kLucid               |
| 1000       | kLeTangoStart        |
| 1001       | kMarlin              |
| 1002       | kSailfish            |
| 1003       | kMuskie              |
| 1004       | kWalleye             |
| 1005       | kTaimen              |
| 1006       | kAngler              |
| 1007       | kLucyevzwLucye       |
| 1008       | kLucyesprusLucye     |
| 1009       | kLucyeattusLucye     |
| 1011       | kDukl09Hwduk         |
| 1012       | kOneplus5Oneplus5    |
| 1013       | kG3123G3123          |
| 1014       | kG8142G8142          |

Obviously, `kMarlin` corresponds to the Pixel, `kSailfish` to the Pixel XL and so on. What is especially interesting here is that there are way more devices than the ones officially supported!
~~There are also some values that I cannot make sense of yet, such as `kPeanut`, `kCoconut` and so on. Just a very wild guess: Maybe `Peanut` is the codename for Android 9 and this value makes the library load the profile from the system itself instead of hard-coding anything?~~ Peanut refers to Project Tango Peanut.

For many of the listed devices, the apk then contains protobuf files (for some reason in text form, not the usual binary representation) in `assets` containing the profile data with exact calibration values for camera and IMU. Format definitions for these files recovered using [pbtk](https://github.com/marin-m/pbtk) are contained in this repository inside [proto](proto).

Unfortunately, I do not own any of these devices (the closest I have is a Nexus 5X), so I cannot test what happens when this is run on one of them. The `DeviceType` for the current device is determined inside the function `device_provider::InferDeviceTypeFromAndroidProperties(const std::string &)` (at `0x000496a4`). This function can be patched to always return a constant value.

One idea to get ARCore fully working on unsupported devices would be to patch this function for a specific value and modify the corresponding protobuf with values fitting for the device.

Running the Hello AR demo from google on my Nexus 5X crashes with many of the values, but with some (such as `kAngler`) it shows a camera image (upside down, which is a common issue with the Nexus 5X), but it is not able to track anything. Logcat gives valuable info on what goes wrong, but I have not investigated further yet.

## Patch

This repo includes a small bash script called [patch_apk.sh](patch_apk.sh) that can be used to patch the original `arcore-preview2.apk` to always assume a specific `DeviceType` as described above.

### Requirements

The script requires the following tools to be present in `PATH`:

- [apktool](https://ibotpeaches.github.io/Apktool/)
- [radare2](https://github.com/radare/radare2) (install from git, NOT any outdated distribution packages!)
- keytool
- zipalign and apksigner (from the Android SDK build tools)

### Patching

Download the original apk next to `patch_apk.sh`:
```
wget https://github.com/google-ar/arcore-android-sdk/releases/download/sdk-preview2/arcore-preview2.apk
```

Run the script in the same directory:
```
./patch_apk.sh [device-type]
```
Replace `[device-type]` with the device type you want, for example `1006` for Nexus 6P.

You should get an apk called `arcore-preview2-patched-signed.apk` that you can install to your device:
```
adb install -r arcore-preview2-patched-signed.apk
```

If have the original apk installed already, it is necessary to manually uninstall that before, since it is signed with a different key:
```
adb uninstall com.google.ar.core
```