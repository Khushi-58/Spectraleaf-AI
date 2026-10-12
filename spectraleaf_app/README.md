# SpectraLeaf AI — Flutter Android App

## Project Structure

```
spectraleaf_app/
├── pubspec.yaml                   # Dependencies (tflite_flutter, camera, etc.)
├── assets/
│   └── models/
│       ├── model_m2_int8.tflite        (4.67 MB — Standard Mode)
│       └── model_multitask_int8.tflite (5.61 MB — Spectrometer Mode)
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml         (Camera + NNAPI permissions)
└── lib/
    ├── main.dart                  # App entry point + dark theme
    ├── models/
    │   └── scan_result.dart       # ScanResult data model
    ├── services/
    │   └── inference_service.dart # TFLite inference wrapper (M2 + Multitask)
    └── screens/
        ├── home_screen.dart       # Landing page with mode selector
        ├── scan_screen.dart       # Camera / gallery image picker
        └── result_screen.dart     # Diagnosis output with SPAD + probability bars
```

## Setup Instructions

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (3.10+)
2. Install [Android Studio](https://developer.android.com/studio) with Android SDK
3. Connect an Android phone (USB debugging enabled) OR use the emulator

### Steps

```bash
# 1. Navigate to the app directory
cd e:\spectraleaf\spectraleaf_app

# 2. Install Flutter dependencies
flutter pub get

# 3. Check device is connected
flutter devices

# 4. Run in debug mode (hot reload available)
flutter run

# 5. Build release APK for deployment
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## App Flow

```
Home Screen
  ├── Standard Scan (M2 INT8 — 4.67 MB)
  │     └── Gallery / Camera → Inference → Result Screen
  └── Spectrometer Mode (Multitask INT8 — 5.61 MB)
        └── Gallery / Camera → Inference → Result Screen

Result Screen
  ├── Deficiency Label + Confidence Bar
  ├── SPAD Dial (regression head or RGB proxy)
  ├── Probability Bars (N / Fe / Mg / K / Healthy)
  └── Fertilizer Recommendation Card
```

## Model Specifications (Bundled in App)

| Model                   | Format | Size    | Classes         | Inputs              |
|-------------------------|--------|---------|-----------------|---------------------|
| M2 (RGB-Only)           | INT8   | 4.67 MB | N, Fe, Mg, K, H | RGB image (224×224) |
| Multitask (RGB+Spectral)| INT8   | 5.61 MB | N, Fe, Mg, K, H | RGB + 672-dim vector|

## Important Notes

- The `inference_service.dart` uses `tflite_flutter ^0.10.4` — ensure the NDK is set up.
- Android Gradle: set `minSdkVersion 24` and `targetSdkVersion 34` in `build.gradle`.
- For TFLite NNAPI GPU delegate, add to `android/app/build.gradle`:
  ```gradle
  dependencies {
      implementation 'org.tensorflow:tensorflow-lite-gpu:2.14.0'
  }
  ```
- The spectral vector in Spectrometer Mode is currently mocked.
  To use real spectral data, implement `extract_672_vector()` from `phase3_deployment_roadmap.md` → Section 2.1.
