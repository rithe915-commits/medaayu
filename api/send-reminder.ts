import type { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';

const translationMap: Record<string, { reminderText: string; beforeFood: string; afterFood: string; withFood: string; noInstruction: string }> = {
  english: {
    reminderText: "Hello! This is a medicine reminder from Medaayu. It's time to take your {{medicine_name}}. Please take {{dosage}} as prescribed by your doctor. Thank you for choosing Medaayu. Stay healthy and have a wonderful day!",
    beforeFood: "before food",
    afterFood: "after food",
    withFood: "with food",
    noInstruction: "now"
  },
  hindi: {
    reminderText: "नमस्ते! Medaayu की ओर से आपकी दवा लेने का समय हो गया है। कृपया अपनी {{medicine_name}} की {{dosage}} अभी लें, जैसा आपके डॉक्टर ने बताया है। Medaayu का उपयोग करने के लिए धन्यवाद। स्वस्थ रहें और आपका दिन शुभ हो!",
    beforeFood: "खाने से पहले",
    afterFood: "खाने के बाद",
    withFood: "खाने के साथ",
    noInstruction: "अभी"
  },
  marathi: {
    reminderText: "नमस्कार! Medaayu कडून आपल्या औषधाची आठवण करून देत आहोत. आता {{medicine_name}} हे औषध {{dosage}} प्रमाणे घेण्याची वेळ झाली आहे. कृपया डॉक्टरांनी सांगितल्याप्रमाणे औषध घ्या. Medaayu वापरल्याबद्दल धन्यवाद. निरोगी रहा आणि आपला दिवस आनंददायी जावो!",
    beforeFood: "जेवणापूर्वी",
    afterFood: "जेवणानंतर",
    withFood: "जेवणासोबत",
    noInstruction: "आता"
  }
};

const languageCodeMap: Record<string, string> = {
  english: "EN",
  hindi: "HI",
  marathi: "MR"
};

function normalizeTimeHHMM(raw: string): string {
  if (!raw) return "";
  const s = raw.trim().toUpperCase();
  if (s.includes("AM") || s.includes("PM")) {
    const isPM = s.includes("PM");
    const clean = s.replace(/(AM|PM)/g, "").trim();
    const parts = clean.split(":");
    let h = parseInt(parts[0], 10);
    const m = parseInt(parts[1], 10) || 0;
    if (isPM && h < 12) h += 12;
    if (!isPM && h === 12) h = 0;
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
  }
  const parts = s.split(":");
  const h = parseInt(parts[0], 10) || 0;
  const m = parseInt(parts[1], 10) || 0;
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'authorization, x-client-info, apikey, content-type');
  if (req.method === 'OPTIONS') {
    return res.status(200).send('ok');
  }

  try {
    const supabaseUrl = process.env.SUPABASE_URL || 'https://ysuwnlvmipgfgesdpqdn.supabase.co';
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || 'sb_publishable_IBq3dRoeAggLMh7BWGqYSg_KAuL_BoD';
    const ringTtsApiKey = process.env.RING_TTS_API_KEY || '8747441113063529';
    const ringTtsUrl = process.env.RING_TTS_URL || 'https://tts-api-4-bussinesse-290441563653.asia-south1.run.app/api/tts/send';

    const body = req.body || {};
    const { action, phone, userName, medicineName, language, dosage, doseTime } = body;

    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Handle instant manual trigger
    if (action === 'trigger_voice_call' || action === 'test_call') {
      if (!phone) {
        return res.status(400).json({ error: "Phone number required" });
      }
      const cleanPhone = phone.toString().replace(/[^0-9]/g, "");
      const formattedPhone = cleanPhone.startsWith("91") ? cleanPhone : `91${cleanPhone}`;
      const lang = (language || 'english').toLowerCase();
      const translator = translationMap[lang] || translationMap.english;
      const medVal = medicineName || "Paracetamol 650 mg";
      const dosageVal = dosage || "1 tablet";

      // 5-minute deduplication check to prevent duplicate calls from app + cron
      if (action === 'trigger_voice_call') {
        const fiveMinsAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
        const { data: recentLogs } = await supabase
          .from("reminder_logs")
          .select("id")
          .eq("channel", "voice")
          .gte("created_at", fiveMinsAgo)
          .limit(1);

        if (recentLogs && recentLogs.length > 0) {
          console.log(`[Vercel] Voice call recently sent. Skipping duplicate.`);
          return res.status(200).json({ success: true, message: "Recently dispatched. Skipped duplicate." });
        }
      }

      const langCode = languageCodeMap[lang] || "EN";
      const ttsPayload = {
        templateText: translator.reminderText,
        recipients: [
          {
            phone: formattedPhone,
            variables: {
              medicine_name: medVal,
              dosage: dosageVal,
              "Medicine Name": medVal,
              "Dosage": dosageVal,
              user_name: userName || "User",
              item: medVal,
              time: dosageVal
            }
          }
        ],
        language: langCode
      };

      console.log(`[Vercel] Voice Call Request to ${formattedPhone} (Language: ${lang})`);

      const ttsRes = await fetch(ringTtsUrl, {
        method: "POST",
        headers: {
          "X-API-Key": ringTtsApiKey,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(ttsPayload)
      });

      const responseText = await ttsRes.text();

      // Log dispatch to prevent duplicate calls
      try {
        await supabase.from("reminder_logs").insert({
          profile_id: body.profileId || null,
          channel: 'voice',
          status: ttsRes.ok ? 'sent' : 'failed',
          scheduled_time: doseTime || 'manual',
          scheduled_date: new Date().toISOString().split('T')[0]
        });
      } catch (_) {}

      return res.status(200).json({
        success: ttsRes.ok,
        status: ttsRes.status,
        ttsResponseBody: responseText
      });
    }

    // 2. Automated 1-minute Cron Check
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get current IST time (UTC + 5:30)
    const now = new Date();
    const utcTime = now.getTime() + (now.getTimezoneOffset() * 60000);
    const istDate = new Date(utcTime + (3600000 * 5.5));
    const currentHour = istDate.getHours().toString().padStart(2, '0');
    const currentMinute = istDate.getMinutes().toString().padStart(2, '0');
    const timeHHMM = `${currentHour}:${currentMinute}`;

    console.log(`[Vercel Cron] Checking reminders for IST time: ${timeHHMM}`);

    // Query all medicines
    const { data: allMedicines, error: medError } = await supabase
      .from("medicines")
      .select("*");

    if (medError) throw medError;

    // Filter by matching dose_time
    const scheduledMedicines = (allMedicines || []).filter((m: any) => {
      if (!m.dose_time) return false;
      const normalizedDose = normalizeTimeHHMM(m.dose_time.toString());
      return normalizedDose === timeHHMM;
    });

    if (!scheduledMedicines || scheduledMedicines.length === 0) {
      return res.status(200).json({ success: true, message: "No reminders for this minute.", time: timeHHMM });
    }

    const todayStr = istDate.toISOString().split('T')[0];

    // Check which medicines have already been called today to prevent duplicate calling
    const { data: alreadyCalledLogs } = await supabase
      .from("reminder_logs")
      .select("medicine_id")
      .eq("scheduled_date", todayStr)
      .eq("scheduled_time", timeHHMM)
      .eq("channel", "voice");

    const calledIds = new Set((alreadyCalledLogs || []).map((l: any) => l.medicine_id));

    // Filter out already called medicines for this time slot
    const uncalledMedicines = scheduledMedicines.filter((m: any) => !calledIds.has(m.id));

    if (uncalledMedicines.length === 0) {
      return res.status(200).json({ success: true, message: "Reminders for this minute have already been dispatched.", time: timeHHMM });
    }

    // Fetch corresponding profiles
    const profileIds = [...new Set(uncalledMedicines.map((m: any) => m.profile_id))];
    const { data: profilesList } = await supabase
      .from("profiles")
      .select("*")
      .in("id", profileIds);

    const profileMap = new Map((profilesList || []).map((p: any) => [p.id, p]));

    const dialResults = [];

    // Trigger voice calls for uncalled medicines
    for (const med of uncalledMedicines) {
      const profile = profileMap.get(med.profile_id);
      if (!profile || !profile.phone || profile.phone.length < 10) continue;

      const cleanP = profile.phone.toString().replace(/[^0-9]/g, "");
      const formattedPhone = cleanP.startsWith("91") ? cleanP : `91${cleanP}`;
      const userLang = (profile.language || 'english').toLowerCase();
      const translator = translationMap[userLang] || translationMap.english;

      const ttsPayload = {
        templateText: translator.reminderText,
        recipients: [
          {
            phone: formattedPhone,
            variables: {
              medicine_name: med.name,
              dosage: "1 dose",
              "Medicine Name": med.name,
              "Dosage": "1 dose",
              user_name: profile.full_name || "User",
              item: med.name,
              time: med.dose_time
            }
          }
        ],
        language: languageCodeMap[userLang] || "EN"
      };

      try {
        const callRes = await fetch(ringTtsUrl, {
          method: "POST",
          headers: {
            "X-API-Key": ringTtsApiKey,
            "Content-Type": "application/json"
          },
          body: JSON.stringify(ttsPayload)
        });

        // Log call into reminder_logs to prevent duplicate dialing
        try {
          await supabase.from("reminder_logs").insert({
            profile_id: med.profile_id,
            medicine_id: med.id,
            channel: 'voice',
            status: callRes.ok ? 'sent' : 'failed',
            scheduled_time: timeHHMM,
            scheduled_date: todayStr
          });
        } catch (_) {}

        dialResults.push({ medicine: med.name, phone: formattedPhone, status: callRes.status });
      } catch (err: any) {
        dialResults.push({ medicine: med.name, error: err.message });
      }
    }

    return res.status(200).json({
      success: true,
      time: timeHHMM,
      dispatched: dialResults
    });

  } catch (err: any) {
    console.error("[Vercel] Error in send-reminder:", err);
    return res.status(500).json({ error: err.message || "Internal server error" });
  }
}
