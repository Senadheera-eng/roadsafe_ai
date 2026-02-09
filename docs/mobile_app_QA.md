# RoadSafeAI — Mobile App Questions & Answers

This document contains likely questions and concise answers you can use during the mobile app demonstration.

## Quick Overview

Q: What is RoadSafeAI?
A: RoadSafeAI is a cross-platform mobile app that streams an ESP32 camera, performs on-device or edge analytics (including drowsiness detection), logs trip sessions, and syncs telemetry to Firebase for analytics and persistence.

Q: Which platforms are supported?
A: The app targets Android, iOS, web, Windows, macOS, and Linux (Flutter multi-platform).

Q: What are the core features?
A: Live MJPEG camera viewing, device setup/wifi config for ESP32, drowsiness and driver-state analytics, trip session recording (`trip_session` model), Firebase auth and telemetry, user profile/settings, and an analytics dashboard.

## Device & Stream

Q: How do I connect the ESP32 camera?
A: Open the Device Setup or Wi‑Fi Config page, enter the ESP32's SSID and password (or follow AP setup in the ESP32 firmware), then provide the MJPEG stream URL (http://<esp32-ip>/stream). The app's `camera_service` handles stream access.

Q: What stream formats are supported?
A: The app displays MJPEG streams using the included `mjpeg_viewer` widget. Other stream formats would need additional handling.

Q: What happens if the stream disconnects?
A: The viewer tries to reconnect; the app logs the event and shows an error card. Check network connectivity and ESP32 health.

## Analytics & Detection

Q: How does drowsiness detection work?
A: The app uses `drowsiness_service` to analyze frames or metadata from the stream (edge or on-device). It flags long eye closures, yawns, or head nodding events and emits alerts.

Q: Can sensitivity be adjusted?
A: Yes — open Settings to tune detection thresholds and alert frequency.

Q: Where are analytics stored?
A: Trip summaries and analytics are saved to Firebase (Realtime/Firestore) via `data_service`/`analytics_service` for later review.

## Privacy & Security

Q: Is video stored in the cloud?
A: By default, the app streams video for live viewing only. Only analytics metadata and trip summaries are persisted to Firebase. Video storage can be added but requires explicit consent and configuration.

Q: How is user data protected?
A: The app uses Firebase Authentication for user access control; data rules should be configured in Firebase to restrict reads/writes to authenticated users.

## Authentication & Accounts

Q: How do users sign in?
A: Use the Login page; `auth_service` manages sign-in, sign-up, and sign-out. Firebase handles auth backend.

Q: Are there different user roles?
A: The demo supports basic users. Role-based access (admin, viewer) can be implemented via Firebase claims and enforced in app logic.

## Demo-specific Questions

Q: What should we show in the demo?
A: 1) Device setup and connecting an ESP32 stream, 2) Live camera feed with detection alerts, 3) Start and stop a trip session and show saved analytics, 4) Show settings and profile, 5) Visit Analytics dashboard with graphs.

Q: What network conditions are required for live demo?
A: A stable local Wi‑Fi for the ESP32 and the demo device. If using Firebase, the demo device needs Internet access.

Q: How to reproduce a drowsiness alert for demo?
A: Simulate long eye closure or use prerecorded frames that trigger the `drowsiness_service`. You can also lower sensitivity in settings for easier triggering.

## Troubleshooting

Q: The app can’t find the ESP32 — what to check?
A: Verify ESP32 is powered, connected to the same Wi‑Fi, check IP via router, confirm firmware is running and streaming on expected port.

Q: Authentication failures?
A: Ensure `firebase_options.dart` is configured for your Firebase project and network access is available. Check console logs for error messages.

Q: Stream is laggy or high latency?
A: Use a local Wi‑Fi network with good signal; reduce camera resolution in the ESP32 firmware or lower frame rate.

## Developer / Tech Questions

Q: Where is the camera logic implemented?
A: See `services/camera_service.dart` and `widgets/mjpeg_viewer.dart`.

Q: Where are trip records modeled?
A: The trip model is in `models/trip_session.dart` and persisted via `data_service.dart`.

Q: How can I add another camera type?
A: Add a new stream handler and viewer widget supporting that protocol, then integrate detection frames into the `drowsiness_service` pipeline.

## Support & Next Steps

Q: How can I get support or report bugs?
A: Use the in-app Help & Support page or contact via the `contact_service`. For code issues, open an issue with logs and reproduction steps.

Q: How do I prepare for the final demo?
A: 1) Ensure `firebase_options.dart` points to the demo project, 2) pre-connect the ESP32 to the demo Wi‑Fi, 3) run through the demo steps above, and 4) have a local fallback video or recorded stream if the device fails.

---

If you'd like, I can convert this to a PDF for you here, or add company/logo header/footer and a one‑page speaker cheat sheet for the demo. Tell me which you prefer.
