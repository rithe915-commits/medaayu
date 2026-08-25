# MedAayu — Medicine Reminder & Elder-Care App

MedAayu is a cross-platform mobile application (built in Flutter, targeting Android) backed by Supabase. It enables caregivers to coordinate medical reminders and emergency safety features for elderly parents or themselves.

---

## Technical Stack
- **Mobile Client**: Flutter (Stable), using `provider` for state management, `android_alarm_manager_plus` for exact alarms, `sensors_plus` for fall detection, `google_mlkit_text_recognition` for on-device OCR, and `geolocator` for safety GPS coordinates.
- **Backend & Database**: Supabase (PostgreSQL with RLS, Auth, and Edge Functions written in TypeScript/Deno).
- **Communication APIs**:
  - **OTP**: Bulk Blaster OTP API
  - **WhatsApp**: Gonums Transactional WhatsApp API
  - **TTS Calls**: Ring TTS Voice API by Bulk Blaster

---

## Features Matrix (Implemented vs. Stubbed/Configurable)

| Feature | Delivery Channel / Tech | Status | Configuration / Mock Fallback |
| :--- | :--- | :--- | :--- |
| **Welcome / Login** | Phone number input with 6-digit OTP | **Fully Implemented** | Uses Bulk Blaster OTP API. If no `BULK_BLASTER_API_KEY` is set, it logs the generated code directly to Deno console for dry-run testing. |
| **Basic Plan** | Local push notifications & exact daily alarms | **Fully Implemented** | Registers OS-level exact alarm clocks using Android's `AlarmManager`. Works even on silent mode/Do Not Disturb. |
| **Standard Plan** | WhatsApp notification updates | **Fully Implemented** | Dispatched server-side via Supabase Edge Functions. Calls Gonums template endpoint. Falls back to mock logging if API keys are missing. |
| **Premium Plan** | Text-to-speech voice phone calls | **Fully Implemented** | Dispatched server-side via Edge Functions. Batches same-time medicines into a single voice call via Ring TTS API. Falls back to mock logging if keys are missing. |
| **Prescription OCR** | Scanner to extract details | **Fully Implemented** | Uses on-device `google_mlkit_text_recognition`. If running on emulator without Play Services, it automatically falls back to a mock prescription text parser to allow complete end-to-end testing. |
| **SOS Emergency** | Big circular red trigger | **Fully Implemented** | Inserts event logs, fetches real-time GPS coordinates, fires backup SMS via Gonums, triggers phone call to emergency contact, and routes maps emergency searches. |
| **Fall Detection** | Accelerometer state-machine | **Fully Implemented** | Detects sequence of Free-fall -> Ground Impact -> Stillness. Triggers a 20-second warning countdown with system sound & haptic vibration before firing SOS. Foreground-only in v1 (notice shown in UI). |
| **SOS Home Widget** | Native circular Android Widget | **Fully Implemented** | Circular widget placed on the home screen. On tap, it launches the app with a custom action intent, reads locally cached credentials, and launches directly into the emergency SOS flow. |

---

## Third-Party Credentials Needed

To enable real messaging, configure the following secrets in your Supabase Project Settings (under Database -> Edge Functions -> Variables) or via Supabase CLI:

```bash
# Bulk Blaster OTP Credentials (For login OTPs)
BULK_BLASTER_API_KEY="your_bulk_blaster_api_key"

# Gonums WhatsApp Credentials (For Standard Plan)
GONUMS_API_KEY="your_gonums_api_key"
GONUMS_WHATSAPP_URL="https://my.gonums.com/dev/bulkV2"
GONUMS_TEMPLATE_NAME="your_approved_whatsapp_template_name"

# Ring TTS Credentials (For Premium Plan calls)
RING_TTS_API_KEY="your_ring_tts_api_key"
RING_TTS_URL="https://tts-api-4-bussinesse-290441563653.asia-south1.run.app/api/send-tts-call"

# Gemini API Credentials (For AI Care tips)
GEMINI_API_KEY="your_gemini_api_key"
```

---

## Local Setup & Deployment

### 1. Database Setup
1. Create a new Supabase Project.
2. Go to the **SQL Editor** in the Supabase Dashboard.
3. Open and copy the contents of `supabase/migrations/20260718000000_init_schema.sql` into the SQL Editor and execute. This initializes the tables, triggers, and Row Level Security (RLS) policies.

### 2. Deploy Edge Functions
If you have Supabase CLI installed:
```bash
supabase functions deploy otp-verify
supabase functions deploy notify-sos
supabase functions deploy send-reminder
supabase functions deploy generate-care-tips
```
If you do not have the CLI, you can write these Deno scripts directly as custom endpoints or test them using local Deno configurations.

---

## Running the Mobile App (Android)

To run a debug build on your physical Android phone (no signing keys required):

1. **Enable Developer Options** on your phone:
   - Go to *Settings -> About Phone*.
   - Tap *Build Number* 7 times.
   - Go back to *Settings -> System -> Developer Options* and enable **USB Debugging**.
2. **Connect Phone**:
   - Plug your phone into your computer via a USB cable.
   - Select "Transfer Files" or "MTP" mode.
   - Accept the "Allow USB Debugging" prompt on your phone screen.
3. **Execute Build**:
   - Verify your device is recognized by running:
     ```bash
     flutter devices
     ```
   - Build and run the app directly:
     ```bash
     flutter run
     ```
   - To build a standalone debug APK to copy and share:
     ```bash
     flutter build apk --debug
     ```
     The output file will be saved at: `build/app/outputs/flutter-apk/app-debug.apk`.
