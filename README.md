# 🚗 RoadSafe AI - Driver Drowsiness Detection System

<div align="center">

![RoadSafe AI Banner](https://img.shields.io/badge/RoadSafe-AI-blue?style=for-the-badge&logo=flutter)
![Flutter](https://img.shields.io/badge/Flutter-3.24.5-02569B?style=for-the-badge&logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![ESP32](https://img.shields.io/badge/ESP32-CAM-E7352C?style=for-the-badge&logo=espressif)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**AI-powered real-time drowsiness detection system to prevent road accidents**

[Features](#-features) • [Demo](#-demo) • [Installation](#-installation) • [Hardware Setup](#-hardware-setup) • [Usage](#-usage) • [Contributing](#-contributing)

</div>

---

## 📋 Table of Contents

- [About](#-about)
- [Features](#-features)
- [Demo](#-demo)
- [Technology Stack](#-technology-stack)
- [System Architecture](#-system-architecture)
- [Installation](#-installation)
- [Hardware Setup](#-hardware-setup)
- [Configuration](#%EF%B8%8F-configuration)
- [Usage](#-usage)
- [API Integration](#-api-integration)
- [Analytics](#-analytics)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)
- [Contact](#-contact)

---

## 🎯 About

**RoadSafe AI** is an intelligent driver drowsiness detection system that uses computer vision and machine learning to monitor driver alertness in real-time. The system detects signs of drowsiness (eye closure, yawning) and provides immediate alerts through continuous vibration patterns to prevent accidents.

### Why RoadSafe AI?

- 💀 **1.35 million** road traffic deaths occur globally each year
- 😴 **20-30%** of all road accidents are caused by drowsy driving
- ⚠️ Drowsy driving is as dangerous as drunk driving
- 🚨 Most drowsiness-related accidents occur during late-night hours

RoadSafe AI provides an affordable, accessible solution to combat this critical safety issue.

---

## ✨ Features

### 🎥 Real-Time Monitoring

- Live MJPEG video streaming from ESP32-CAM
- 25-30 FPS camera feed
- QVGA (320x240) resolution optimized for performance

### 🤖 AI-Powered Detection

- **YOLOv8 Model** via Roboflow API
- **94.3% accuracy** in drowsiness detection
- **0.8 second latency** for real-time processing
- Detects:
  - Closed eyes (>1.5 seconds)
  - Yawning
  - Eye opening percentage
  - Drowsiness patterns

### 🚨 Multi-Pattern Alerts

- **Continuous vibration** until user acknowledgment
- 4 distinct vibration patterns:
  - Long intense burst (2.5s)
  - Triple pulse (urgent)
  - SOS emergency pattern
  - Final warning burst
- Visual on-screen alerts with drowsiness details

### 📊 Comprehensive Analytics

- **Trip History**: Complete log of all driving sessions
- **Safety Score**: 0-100 rating based on alert frequency
- **Performance Trends**: Weekly improvement tracking
- **Time-of-Day Analysis**: Identify high-risk driving periods
- **Achievement System**: Gamified safety milestones
- **Personalized Recommendations**: AI-driven safety tips

### 🔧 Easy Setup

- In-app WiFi configuration for ESP32-CAM
- Automatic device discovery on local network
- Camera positioning guide with live preview
- One-time setup, persistent connection

### 📱 Modern UI/UX

- Glass-morphism design
- Gradient color schemes
- Smooth animations
- Dark/Light mode support (planned)
- Responsive layouts

---

## 🎬 Demo

### Screenshots

<div align="center">

| Home Screen                   | Live Camera                       | Analytics                               |
| ----------------------------- | --------------------------------- | --------------------------------------- |
| ![Home](docs/images/home.png) | ![Camera](docs/images/camera.png) | ![Analytics](docs/images/analytics.png) |

| Device Setup                    | Alert Dialog                    | Trip History                        |
| ------------------------------- | ------------------------------- | ----------------------------------- |
| ![Setup](docs/images/setup.png) | ![Alert](docs/images/alert.png) | ![History](docs/images/history.png) |

</div>

### Video Demo

[![RoadSafe AI Demo](https://img.youtube.com/vi/YOUR_VIDEO_ID/0.jpg)](https://www.youtube.com/watch?v=YOUR_VIDEO_ID)

---

## 🛠 Technology Stack

### Mobile Application

- **Framework**: Flutter 3.24.5
- **Language**: Dart 3.5.4
- **State Management**: Provider / setState
- **UI Components**: Custom Glass-morphism widgets
- **Fonts**: Google Fonts (Poppins)

### Backend & Services

- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth
- **Storage**: SharedPreferences (local caching)
- **Analytics**: Firebase Analytics (planned)

### AI & Computer Vision

- **Model**: YOLOv8 (Roboflow)
- **Detection Types**: Eye state, yawning, drowsiness
- **Confidence Threshold**: 25%
- **Processing**: Cloud-based via Roboflow API

### Hardware

- **Camera**: ESP32-CAM (AI-Thinker)
- **Microcontroller**: ESP32 (Dual-core, WiFi enabled)
- **Camera Sensor**: OV2640
- **Resolution**: QVGA (320x240)
- **Frame Rate**: 25-30 FPS
- **Streaming**: MJPEG over HTTP

### Networking

- **Protocol**: HTTP/REST
- **Streaming**: MJPEG (Motion JPEG)
- **Discovery**: Local network scanning
- **Communication**: WiFi 2.4GHz

---

## 🏗 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ROADSAFE AI SYSTEM                      │
└─────────────────────────────────────────────────────────────┘

┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│              │  MJPEG  │              │  Frame  │              │
│  ESP32-CAM   │────────▶│ Flutter App  │────────▶│  Roboflow    │
│  (Hardware)  │ Stream  │  (Mobile)    │  API    │  (AI Model)  │
│              │◀────────│              │◀────────│              │
└──────────────┘  WiFi   └──────────────┘ Result  └──────────────┘
      │                         │                         │
      │                         │                         │
      ▼                         ▼                         ▼
  ┌─────────┐            ┌─────────┐              ┌─────────┐
  │ Camera  │            │ UI/UX   │              │ YOLOv8  │
  │ Sensor  │            │ Alerts  │              │ Model   │
  │ OV2640  │            │ Storage │              │ 94.3%   │
  └─────────┘            └─────────┘              └─────────┘
                               │
                               ▼
                        ┌──────────────┐
                        │   Firebase   │
                        │  Firestore   │
                        │  (Analytics) │
                        └──────────────┘
```

### Data Flow

1. **Capture**: ESP32-CAM captures video frames (30 FPS)
2. **Stream**: MJPEG stream sent to Flutter app via WiFi
3. **Process**: App extracts frames every 1.5 seconds
4. **Analyze**: Frames sent to Roboflow YOLOv8 model
5. **Detect**: AI detects eye state, yawning, drowsiness
6. **Alert**: If drowsy (2+ consecutive frames), trigger vibration
7. **Log**: Save trip data to Firebase Firestore
8. **Display**: Show real-time analytics and insights

---

## 📥 Installation

### Prerequisites

- **Flutter SDK**: 3.24.5 or higher
- **Dart SDK**: 3.5.4 or higher
- **Android Studio** / **VS Code** with Flutter extensions
- **Android Device**: Android 10+ (for testing)
- **Firebase Account**: For backend services
- **Roboflow Account**: For AI model API
- **ESP32-CAM Module**: AI-Thinker board

### Clone Repository

```bash
git clone https://github.com/yourusername/roadsafe-ai.git
cd roadsafe-ai
```

### Install Dependencies

```bash
flutter pub get
```

### Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Add Android app to your Firebase project
3. Download `google-services.json`
4. Place in `android/app/` directory
5. Enable **Firestore Database** and **Authentication**

### Roboflow Setup

1. Sign up at [Roboflow](https://roboflow.com)
2. Get your API key from workspace settings
3. Update in `lib/services/drowsiness_service.dart`:

```dart
static const String API_KEY = "YOUR_ROBOFLOW_API_KEY";
static const String MODEL_ID = "drowsiness-driver/1";
```

---

## 🔌 Hardware Setup

### Required Components

| Component                | Quantity | Approximate Cost |
| ------------------------ | -------- | ---------------- |
| ESP32-CAM (AI-Thinker)   | 1        | $10              |
| USB to Serial Programmer | 1        | $5               |
| Jumper Wires             | 5-10     | $2               |
| Power Supply (5V 2A)     | 1        | $5               |
| Car Dashboard Mount      | 1        | $8               |
| **Total**                | -        | **~$30**         |

### ESP32-CAM Pinout (AI-Thinker)

```
┌─────────────────────────────────┐
│           ESP32-CAM             │
│                                 │
│  5V  GND  U0R  U0T  GPIO16  GND │
│   ●   ●   ●    ●     ●      ●  │
│                                 │
│  [●●●●●●●]  ← Camera Sensor     │
│                                 │
│   ●   ●   ●    ●     ●      ●  │
│  3V3  GND  IO14 IO15 IO13  IO12│
└─────────────────────────────────┘
```

### Wiring Diagram

```
ESP32-CAM          USB-to-Serial
─────────────────────────────────
5V        ────────▶  5V
GND       ────────▶  GND
U0R (RX)  ────────▶  TX
U0T (TX)  ────────▶  RX
GPIO0     ────────▶  GND (for flashing)
```

### Upload Arduino Code

1. **Install Arduino IDE** (1.8.19 or higher)
2. **Add ESP32 Board Support**:
   - Go to `File` → `Preferences`
   - Add to Additional Board Manager URLs:

```
     https://dl.espressif.com/dl/package_esp32_index.json
```

- Go to `Tools` → `Board` → `Boards Manager`
- Search "ESP32" and install

3. **Select Board**:
   - `Tools` → `Board` → `ESP32 Arduino` → `AI Thinker ESP32-CAM`

4. **Configure Settings**:

```
   Board: "AI Thinker ESP32-CAM"
   CPU Frequency: "240MHz"
   Flash Frequency: "80MHz"
   Flash Mode: "QIO"
   Partition Scheme: "Huge APP (3MB No OTA)"
```

5. **Open Code**: `hardware/esp32_cam/esp32_cam.ino`

6. **Upload**:
   - Connect GPIO0 to GND (programming mode)
   - Click Upload
   - After upload completes, disconnect GPIO0 from GND
   - Press RESET button

### Verify Installation

1. Open Serial Monitor (115200 baud)
2. Press RESET button on ESP32-CAM
3. Should see:

```
   ========================================
   ROADSAFE AI - ESP32-CAM
   ========================================
   SETUP MODE ACTIVE
   AP SSID: RoadSafe-AI-Setup
   AP IP: 192.168.4.1
   ========================================
```

---

## ⚙️ Configuration

### App Configuration

Edit `lib/config/app_config.dart`:

```dart
class AppConfig {
  // API Keys
  static const String roboflowApiKey = 'YOUR_API_KEY';
  static const String roboflowModelId = 'drowsiness-driver/1';

  // Detection Settings
  static const Duration detectionInterval = Duration(milliseconds: 1500);
  static const int alertThreshold = 2; // consecutive drowsy frames
  static const double confidenceThreshold = 0.25;

  // Camera Settings
  static const int cameraFps = 30;
  static const String cameraResolution = '320x240';

  // Network Settings
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const int maxRetries = 3;
}
```

### Firebase Security Rules

Update Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Trips collection
    match /trips/{tripId} {
      allow read: if request.auth != null &&
                     resource.data.userId == request.auth.uid;
      allow create, update: if request.auth != null &&
                               request.resource.data.userId == request.auth.uid;
      allow delete: if false; // Preserve data integrity
    }

    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null &&
                            request.auth.uid == userId;
    }
  }
}
```

### Android Permissions

Ensure `android/app/src/main/AndroidManifest.xml` has:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.VIBRATE"/>

<application
    android:usesCleartextTraffic="true"
    ...>
```

---

## 📖 Usage

### First-Time Setup

1. **Launch App**

```bash
   flutter run
```

2. **Sign In/Sign Up** (Firebase Authentication)

3. **Device Setup**:
   - Tap "Device Setup" on home page
   - Connect phone to "RoadSafe-AI-Setup" WiFi (password: 12345678)
   - Disable mobile data
   - App opens browser to configure ESP32
   - Select your home WiFi and enter password
   - Wait for ESP32 to connect
   - Reconnect phone to home WiFi
   - App automatically finds ESP32

4. **Camera Positioning**:
   - Mount ESP32-CAM on dashboard
   - Use live preview to position camera
   - Ensure face is clearly visible
   - Adjust angle (15-30° downward recommended)

### Starting Monitoring

1. **Connect**: Tap "Live Camera" on home page
2. **Verify Stream**: Ensure video feed is working
3. **Start Monitoring**: Tap green "Start Monitoring" button
4. **Drive Safely**: System monitors drowsiness in real-time
5. **Stop When Done**: Tap red "Stop Monitoring" button

### Alert Response

When drowsiness is detected:

1. **Phone vibrates continuously**
2. **Alert dialog appears on screen**
3. **Press "I'm Awake" to stop vibration**
4. **Pull over safely if tired**
5. **Take a 15-20 minute break**

### Viewing Analytics

1. **Open Analytics** from home page
2. **Overview Tab**: View statistics and charts
3. **History Tab**: See all past trips
4. **Insights Tab**: Check achievements and recommendations

---

## 🔗 API Integration

### Roboflow API

**Endpoint**: `https://detect.roboflow.com/{model_id}`

**Request**:

```http
POST https://detect.roboflow.com/drowsiness-driver/1?api_key=YOUR_KEY&confidence=0.20
Content-Type: application/x-www-form-urlencoded

[BASE64_ENCODED_IMAGE]
```

**Response**:

```json
{
  "predictions": [
    {
      "x": 160.5,
      "y": 120.3,
      "width": 80.2,
      "height": 60.1,
      "class": "closed_eyes",
      "confidence": 0.89
    },
    {
      "x": 160.5,
      "y": 180.7,
      "width": 40.3,
      "height": 30.2,
      "class": "yawn",
      "confidence": 0.76
    }
  ]
}
```

### Detection Classes

| Class                    | Description        | Alert Trigger |
| ------------------------ | ------------------ | ------------- |
| `closed_eyes` / `closed` | Eyes closed        | ✅ Yes        |
| `open_eyes` / `open`     | Eyes open          | ❌ No         |
| `yawn`                   | Yawning detected   | ✅ Yes        |
| `drowsy` / `sleepy`      | General drowsiness | ✅ Yes        |

---

## 📊 Analytics

### Safety Score Calculation

```dart
safetyScore = max(0, 100 - (alertCount × 5))
```

**Ranges**:

- **90-100**: Excellent (Low Risk)
- **75-89**: Good (Moderate Risk)
- **60-74**: Fair
- **40-59**: Poor
- **0-39**: Critical (High Risk)

### Metrics Tracked

| Metric               | Description                               | Storage    |
| -------------------- | ----------------------------------------- | ---------- |
| Total Trips          | Number of completed sessions              | Firestore  |
| Total Driving Time   | Cumulative minutes                        | Firestore  |
| Total Alerts         | Drowsiness alerts triggered               | Firestore  |
| Alert Frequency      | Alerts per hour                           | Calculated |
| Current Streak       | Consecutive trips without alerts          | Calculated |
| Weekly Improvement   | % change in safety score                  | Calculated |
| Time-of-Day Patterns | Alerts by Morning/Afternoon/Evening/Night | Calculated |

### Data Structure

**Firestore Document** (`trips` collection):

```json
{
  "userId": "abc123",
  "startTime": "2026-01-21T10:30:00Z",
  "endTime": "2026-01-21T11:15:00Z",
  "durationMinutes": 45,
  "totalDetections": 90,
  "alertCount": 3,
  "yawnCount": 1,
  "safetyScore": 85.0,
  "isActive": false,
  "metadata": {
    "appVersion": "1.0.0",
    "platform": "android"
  }
}
```

---

## 🐛 Troubleshooting

### Common Issues

#### 1. ESP32-CAM Not Found

**Symptoms**: App can't discover ESP32 on network

**Solutions**:

- ✅ Ensure phone and ESP32 on same WiFi network
- ✅ Check router allows device-to-device communication
- ✅ Disable AP Isolation in router settings
- ✅ Use "Enter IP Manually" option
- ✅ Check ESP32 serial monitor for IP address
- ✅ Ensure 2.4GHz WiFi (ESP32 doesn't support 5GHz)

#### 2. Camera Stream Not Loading

**Symptoms**: Black screen or "Loading camera stream..." stuck

**Solutions**:

- ✅ Check ESP32 is powered on
- ✅ Verify stream URL: `http://[ESP32_IP]/stream`
- ✅ Test in browser first
- ✅ Restart ESP32-CAM
- ✅ Check WiFi signal strength
- ✅ Ensure firewall not blocking connection

#### 3. Detection Not Working

**Symptoms**: No bounding boxes, no alerts

**Solutions**:

- ✅ Verify Roboflow API key is correct
- ✅ Check internet connection (API requires internet)
- ✅ Look for errors in console logs
- ✅ Ensure face is clearly visible in camera
- ✅ Improve lighting conditions
- ✅ Check API quota hasn't been exceeded

#### 4. Vibration Not Working

**Symptoms**: Alert shows but phone doesn't vibrate

**Solutions**:

- ✅ Check device has vibration motor
- ✅ Enable vibration in Android settings
- ✅ Grant vibration permission to app
- ✅ Test with "Test Vibration" button
- ✅ Check "Do Not Disturb" mode is off

#### 5. Analytics Not Showing

**Symptoms**: "No Analytics Data" despite completed trips

**Solutions**:

- ✅ Check Firebase Firestore connection
- ✅ Verify user is signed in
- ✅ Check Firestore security rules
- ✅ Look for console errors
- ✅ Use "Debug: Check Database" button
- ✅ Verify trips collection has data

### Debug Mode

Enable detailed logging:

```dart
// In main.dart
void main() {
  debugPrint = (String? message, {int? wrapWidth}) {
    print('[DEBUG] $message');
  };
  runApp(MyApp());
}
```

### Getting Help

1. **Check Console Logs**: Most issues show errors in console
2. **GitHub Issues**: [Report bugs here](https://github.com/yourusername/roadsafe-ai/issues)
3. **Documentation**: See `/docs` folder for detailed guides
4. **Discord Community**: [Join our server](https://discord.gg/YOUR_INVITE)

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Ways to Contribute

- 🐛 **Report Bugs**: Open an issue with details
- ✨ **Suggest Features**: Share your ideas
- 📝 **Improve Documentation**: Fix typos, add examples
- 💻 **Submit Code**: Fix bugs, add features
- 🎨 **Design**: Improve UI/UX
- 🌍 **Translate**: Add language support

### Development Setup

1. **Fork the repository**
2. **Create a feature branch**:

```bash
   git checkout -b feature/amazing-feature
```

3. **Make your changes**
4. **Test thoroughly**
5. **Commit with descriptive message**:

```bash
   git commit -m "Add amazing feature"
```

6. **Push to your fork**:

```bash
   git push origin feature/amazing-feature
```

7. **Open a Pull Request**

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use meaningful variable names
- Add comments for complex logic
- Write unit tests for new features
- Update documentation

### Commit Message Convention

```
type(scope): subject

body

footer
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Example**:

```
feat(analytics): add weekly improvement chart

- Calculate weekly safety score trends
- Display improvement percentage
- Add visual chart with fl_chart

Closes #123
```

---

## 🗺 Roadmap

### Version 1.1 (Q2 2026)

- [ ] iOS support
- [ ] Offline detection (on-device ML)
- [ ] Voice alerts
- [ ] Multi-language support (Spanish, French, Hindi)
- [ ] Dark mode
- [ ] Export analytics to PDF

### Version 1.2 (Q3 2026)

- [ ] Driver profile management
- [ ] Family sharing (monitor multiple drivers)
- [ ] Integration with car OBD-II
- [ ] Speed limit warnings
- [ ] Emergency contact auto-dial
- [ ] Cloud backup & sync

### Version 2.0 (Q4 2026)

- [ ] AI model improvements (98%+ accuracy)
- [ ] Emotion detection (stress, anger)
- [ ] Predictive alerts (before drowsiness)
- [ ] Smart scheduling (optimal driving times)
- [ ] Insurance integration
- [ ] Fleet management dashboard

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2026 RoadSafe AI Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙏 Acknowledgments

- **Roboflow**: For providing the AI model API
- **Firebase**: For backend infrastructure
- **Flutter Team**: For the amazing framework
- **ESP32 Community**: For hardware documentation
- **Contributors**: All our amazing contributors
- **Testers**: Beta testers who helped improve the app

---

## 📧 Contact

### Project Maintainers

- **Lead Developer**: Your Name
  - GitHub: [@yourusername](https://github.com/yourusername)
  - Email: your.email@example.com

### Project Links

- **Website**: [roadsafe-ai.com](https://roadsafe-ai.com) (coming soon)
- **Documentation**: [docs.roadsafe-ai.com](https://docs.roadsafe-ai.com)
- **Issue Tracker**: [GitHub Issues](https://github.com/yourusername/roadsafe-ai/issues)
- **Discord**: [Join Community](https://discord.gg/YOUR_INVITE)
- **Twitter**: [@RoadSafeAI](https://twitter.com/roadsafeai)

---

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/roadsafe-ai&type=Date)](https://star-history.com/#yourusername/roadsafe-ai&Date)

---

## 🎖 Badges

![Build Status](https://img.shields.io/github/workflow/status/yourusername/roadsafe-ai/CI)
![Coverage](https://img.shields.io/codecov/c/github/yourusername/roadsafe-ai)
![Version](https://img.shields.io/github/v/release/yourusername/roadsafe-ai)
![Downloads](https://img.shields.io/github/downloads/yourusername/roadsafe-ai/total)
![Contributors](https://img.shields.io/github/contributors/yourusername/roadsafe-ai)
![Last Commit](https://img.shields.io/github/last-commit/yourusername/roadsafe-ai)

---

<div align="center">

**Made with ❤️ for road safety**

If this project helps you, please consider giving it a ⭐!

[⬆ Back to Top](#-roadsafe-ai---driver-drowsiness-detection-system)

</div>
