# RoadSafeAI — Mobile App Security Questions & Answers

This document lists likely security questions and concise answers you can use during the demo or Q&A.

Q: How is user authentication handled?
A: The app uses Firebase Authentication (email/password and provider options). Session tokens are issued by Firebase and should be stored securely using `flutter_secure_storage` or platform Keychain/Keystore.

Q: How is data protected in transit?
A: All network communication to Firebase uses HTTPS/TLS. For ESP32 streams, prefer serving MJPEG over HTTPS or tunnel via a secure proxy/VPN. Use certificate pinning for extra protection against MITM.

Q: How is sensitive data stored on the device?
A: No raw passwords or private keys are stored. Tokens and small secrets must be kept in secure storage (Keychain/Keystore). Avoid writing sensitive video to general storage; if needed, encrypt files with platform crypto APIs.

Q: Are credentials or API keys committed to the repo?
A: No — `firebase_options.dart` contains project config but not service account private keys. Secrets must be kept out of source control and injected via CI or environment variables for production.

Q: How are Firebase access rules configured?
A: Use Firestore/Realtime Database security rules to restrict reads/writes to authenticated users and apply granular validation (UID-based document ownership). Test rules with the Firebase emulator before deployment.

Q: How do you protect the ESP32 device and its stream?
A: Secure the ESP32 with a unique Wi‑Fi password, disable open AP mode where possible, use HTTPS (or at least local network only), and enable firmware authentication for OTA updates.

Q: What about firmware and OTA security?
A: Sign firmware images and validate signatures on-device before flashing. Use an authenticated OTA mechanism and limit update servers to trusted endpoints.

Q: How do you prevent unauthorized remote access to the stream?
A: Keep streams on a local network or behind authenticated endpoints. Use token-based access or short-lived signed URLs if you must expose streams remotely.

Q: How is logging handled to avoid leaking PII?
A: Avoid logging raw images or PII. Log only metadata (event type, timestamp, anonymized IDs). Ensure logs in Firebase or cloud storage have proper retention and access controls.

Q: How is user privacy respected (GDPR/CCPA)?
A: Provide clear consent prompts before capturing or uploading analytics, allow users to delete their data (implemented via `data_service`), and document retention policies. Anonymize data when possible.

Q: How are third-party libraries vetted?
A: Keep dependencies up-to-date, monitor vulnerability databases (e.g., Dependabot or Snyk), and limit permissions requested by packages. Run static analysis and dependency checks in CI.

Q: Is the app obfuscated for release builds?
A: For Android, enable R8/ProGuard; for iOS, enable bitcode and strip symbols. Obfuscation raises the bar against reverse engineering but is not a substitute for secure architecture.

Q: How are certificates and TLS handled for the ESP32?
A: Use valid TLS certificates (not self-signed) where possible. If self-signed, use certificate pinning in the app and rotate pins as needed. Prefer mTLS for stronger mutual authentication if infrastructure allows.

Q: How are secrets rotated and revoked?
A: Use short-lived tokens where possible. Implement a mechanism to revoke credentials (e.g., Firebase custom claims or revoke refresh tokens) and rotate keys used for signing/OTA.

Q: What permissions does the app request and why?
A: Minimal permissions: camera (if using device camera), storage (optional for local files), microphone (if voice alerts). Ask permissions at runtime with clear purpose strings and allow users to opt out of optional features.

Q: How to respond to a security incident?
A: Prepare an incident response playbook: contain (revoke keys/tokens), assess (logs, scope), remediate (patch firmware/app), notify affected users, and update policies.

Q: How can we harden the app further for production?
A: Use secure storage, certificate pinning, strict Firebase rules, signed firmware with OTA checks, dependency scanning in CI, runtime integrity checks, encrypted backups, and regular pen-testing.

Q: Developer tips for secure configuration?
A: Keep production `firebase_options` separate from demo/dev, use environment-specific configs, avoid checking secrets into the repo, and enforce pre-commit hooks that block accidental secret commits.

---

If you'd like, I can merge a summary of these security Q&As into `docs/mobile_app_QA.md`, produce a one-page security cheat sheet for the demo, or convert this file to PDF now. Which would you like?
