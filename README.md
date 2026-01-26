# RoadSafe AI

**AI-powered real-time drowsiness detection system to prevent road accidents**

![Flutter](https://img.shields.io/badge/Flutter-3.24.5-02569B?style=flat-square&logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black)
![ESP32](https://img.shields.io/badge/ESP32--CAM-E7352C?style=flat-square&logo=espressif)

---

## Overview

RoadSafe AI monitors driver alertness using computer vision and machine learning. It detects drowsiness signs (closed eyes, yawning) through an ESP32-CAM and triggers immediate vibration alerts to help prevent accidents.

**The Problem:**

- 1.35 million road deaths occur globally each year
- 20-30% of accidents are caused by drowsy driving

**Our Solution:**

- Real-time monitoring with 94.3% detection accuracy
- Continuous vibration alerts until driver responds
- Comprehensive analytics to track driving patterns

---

## How It Works

```
ESP32-CAM → WiFi Stream → Flutter App → Roboflow AI → Alert System
                                ↓
                          Firebase Analytics
```

1. **ESP32-CAM** captures live video at 30 FPS
2. **Flutter App** receives the stream and extracts frames every 1.5 seconds
3. **YOLOv8 Model** (via Roboflow) analyzes frames for drowsiness indicators
4. **Alert System** triggers continuous vibration when drowsiness is detected
5. **Firebase** stores trip data and analytics

---

## Features

| Feature             | Description                                           |
| ------------------- | ----------------------------------------------------- |
| **Live Monitoring** | Real-time MJPEG video stream from ESP32-CAM           |
| **AI Detection**    | Detects closed eyes, yawning, and drowsiness patterns |
| **Smart Alerts**    | Continuous vibration until user acknowledges          |
| **Trip Analytics**  | Safety scores, trip history, and performance trends   |
| **Easy Setup**      | In-app WiFi configuration and device discovery        |

---

## Tech Stack

| Layer          | Technology                            |
| -------------- | ------------------------------------- |
| **Mobile App** | Flutter 3.24.5, Dart 3.5.4            |
| **Backend**    | Firebase (Auth, Firestore)            |
| **AI Model**   | YOLOv8 via Roboflow API               |
| **Hardware**   | ESP32-CAM (AI-Thinker), OV2640 sensor |

---

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── pages/
│   ├── home_page.dart        # Main dashboard
│   ├── live_camera_page.dart # Camera streaming & monitoring
│   ├── analytics_page.dart   # Trip history & statistics
│   ├── device_setup_page.dart# ESP32 configuration
│   └── ...
├── services/
│   ├── drowsiness_service.dart  # AI detection & alerts
│   ├── camera_service.dart      # ESP32 connection
│   ├── data_service.dart        # Session & Firestore management
│   └── analytics_service.dart   # Stats calculation
├── models/
│   └── trip_session.dart     # Data models
├── widgets/                  # Reusable UI components
└── theme/                    # App styling
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.24.5+
- Firebase project (Firestore + Auth enabled)
- Roboflow API key
- ESP32-CAM module

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/roadsafe-ai.git
cd roadsafe-ai

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Configuration

1. **Firebase**: Add `google-services.json` to `android/app/`
2. **Roboflow**: Update API key in `lib/services/drowsiness_service.dart`

```dart
static const String API_KEY = "YOUR_ROBOFLOW_API_KEY";
```

---

## Hardware Setup

**Components (~$30 total):**

- ESP32-CAM (AI-Thinker) - $10
- USB to Serial Programmer - $5
- Power supply & mount - $15

**Quick Start:**

1. Flash ESP32-CAM with Arduino code from `hardware/esp32_cam/`
2. Power on ESP32 - it creates "RoadSafe-AI-Setup" WiFi network
3. Use the app to configure WiFi credentials
4. Mount camera on dashboard facing the driver

---

## Usage

1. **Sign in** with your account
2. **Setup device** - Connect ESP32-CAM to your WiFi
3. **Start monitoring** - Tap "Live Camera" and press "Start Monitoring"
4. **Drive safely** - System alerts you if drowsiness is detected
5. **Review analytics** - Check your safety scores and trip history

---

## Safety Score

```
Score = 100 - (alerts × 5)
```

| Score  | Rating    |
| ------ | --------- |
| 90-100 | Excellent |
| 75-89  | Good      |
| 60-74  | Fair      |
| 40-59  | Poor      |
| 0-39   | Critical  |

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Contact

**Developer:** Lahiru Senadheera
**GitHub:** [@Senadheera-eng](https://github.com/Senadheera-eng)
**Email:** lahiru.senadheera2002@gmail.com

---

<p align="center">Made for road safety</p>
