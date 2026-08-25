import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

// Translations for reminder texts in English, Hindi, and Marathi matching Ring TTS API placeholders
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

// Map languages to ISO 2-letter codes for TTS API (default to EN if not matched)
const languageCodeMap: Record<string, string> = {
  english: "EN",
  hindi: "HI",
  marathi: "MR"
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('MY_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    
    const gonumsApiKey = Deno.env.get('GONUMS_API_KEY') ?? '';
    const gonumsWhatsappUrl = Deno.env.get('GONUMS_WHATSAPP_URL') ?? 'https://my.gonums.com/dev/bulkV2';
    const gonumsTemplateName = Deno.env.get('GONUMS_TEMPLATE_NAME') ?? 'medaayu_reminder';
    
    const ringTtsApiKey = Deno.env.get('RING_TTS_API_KEY') ?? '';
    const ringTtsUrl = Deno.env.get('RING_TTS_URL') ?? 'https://tts-api-4-bussinesse-290441563653.asia-south1.run.app/api/tts/send';

    // Parse JSON body if present
    let body: any = {};
    try {
      body = await req.json();
    } catch (_) {}

    const { action, phone, userName, medicineName, language, doseTime } = body;

    // Handle instant manual triggers
    if (action === 'trigger_voice_call' || action === 'test_call') {
      if (!phone) {
        return new Response(JSON.stringify({ error: "Phone number required" }), {
          status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
      const cleanPhone = phone.replace(/[^0-9]/g, "");
      const formattedPhone = cleanPhone.startsWith("91") ? cleanPhone : `91${cleanPhone}`;
      const lang = (language || 'english').toLowerCase();
      const translator = translationMap[lang] || translationMap.english;
      const medVal = medicineName || "Paracetamol 650 mg";
      const dosageVal = body.dosage || "1 tablet";

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

      console.log(`Instant Voice Call Request to ${formattedPhone} (TTS template: ${translator.reminderText})`);

      if (!ringTtsApiKey) {
        console.log(`[Mock TTS Call] Status: success`);
        return new Response(JSON.stringify({ success: true, mock: true }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      const response = await fetch(ringTtsUrl, {
        method: "POST",
        headers: {
          "X-API-Key": ringTtsApiKey,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(ttsPayload)
      });

      const responseText = await response.text();
      console.log(`TTS Response: ${response.status}, body: ${responseText}`);
      return new Response(JSON.stringify({ success: response.ok, status: response.status, ttsResponseBody: responseText }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Helper to normalize any time string ("15:30", "03:30 PM", "3:30 pm", "15:30:00") to 24-hour "HH:MM"
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

    // Get current time in Indian Standard Time (IST - UTC + 5:30)
    const now = new Date();
    const utcTime = now.getTime() + (now.getTimezoneOffset() * 60000);
    const istOffset = 5.5; // IST = UTC + 5:30
    const istDate = new Date(utcTime + (3600000 * istOffset));
    
    const currentHour = istDate.getHours().toString().padStart(2, '0');
    const currentMinute = istDate.getMinutes().toString().padStart(2, '0');
    const timeHHMM = `${currentHour}:${currentMinute}`;

    console.log(`Checking reminders for IST time: ${timeHHMM}`);

    // 1. Query medicines scheduled for today
    const { data: allMedicines, error: medError } = await supabase
      .from("medicines")
      .select(`
        *,
        profiles!inner(*)
      `);

    if (medError) throw medError;

    // Filter by dose_time matching current hour and minute in TypeScript to avoid SQL syntax/format errors
    const scheduledMedicines = (allMedicines || []).filter((m: any) => {
      if (!m.dose_time) return false;
      const normalizedDose = normalizeTimeHHMM(m.dose_time.toString());
      return normalizedDose === timeHHMM;
    });

    if (!scheduledMedicines || scheduledMedicines.length === 0) {
      return new Response(JSON.stringify({ success: true, message: "No reminders for this minute." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // 1.5. Query today's intake logs to filter out already-taken medicines (IST day bounds in UTC ISO format)
    const istStartUtc = new Date(Date.UTC(istDate.getFullYear(), istDate.getMonth(), istDate.getDate(), 0, 0, 0) - (5.5 * 3600 * 1000));
    const istEndUtc = new Date(Date.UTC(istDate.getFullYear(), istDate.getMonth(), istDate.getDate(), 23, 59, 59) - (5.5 * 3600 * 1000));

    const todayStartIso = istStartUtc.toISOString();
    const todayEndIso = istEndUtc.toISOString();
    
    const { data: takenLogs, error: logsError } = await supabase
      .from("intake_logs")
      .select("medicine_id")
      .gte("taken_at", todayStartIso)
      .lte("taken_at", todayEndIso);

    if (logsError) {
      console.error("Error fetching intake logs for filtering:", logsError);
    }

    const takenMedIds = new Set((takenLogs || []).map((l: any) => l.medicine_id));
    const pendingMedicines = scheduledMedicines.filter((m: any) => !takenMedIds.has(m.id));

    console.log(`Found ${scheduledMedicines.length} medicines scheduled. Pending after filtering taken ones: ${pendingMedicines.length}`);

    if (pendingMedicines.length === 0) {
      return new Response(JSON.stringify({ success: true, message: "All scheduled medicines for this minute have already been taken." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // 2. Group medicines by profile ID
    const profileReminders: Record<string, { profile: any; medicines: any[] }> = {};
    for (const med of pendingMedicines) {
      const profile = med.profiles;
      const profileId = profile.id;
      if (!profileReminders[profileId]) {
        profileReminders[profileId] = { profile, medicines: [] };
      }
      profileReminders[profileId].medicines.push(med);
    }

    // 3. Process reminders per profile according to their active tier
    for (const profileId of Object.keys(profileReminders)) {
      const { profile, medicines } = profileReminders[profileId];
      
      let tier = profile.plan_tier;
      let language = (profile.language || 'english').toLowerCase();
      
      let targetPhone: string = profile.phone || "";
      let targetName: string = profile.full_name || "User";

      // Fallback: If targetPhone is missing/invalid, check owner's phone
      if (!targetPhone || targetPhone.length < 10) {
        if (profile.owner_id) {
          const { data: ownerProfile } = await supabase
            .from("profiles")
            .select("phone, full_name")
            .eq("id", profile.owner_id)
            .maybeSingle();
          if (ownerProfile?.phone && ownerProfile.phone.length >= 10) {
            targetPhone = ownerProfile.phone;
          }
        }
      }

      if (profile.role === "parent" && profile.owner_id) {
        // Inherit caregiver's upgraded plan tier if better
        const { data: ownerProfile } = await supabase
          .from("profiles")
          .select("plan_tier")
          .eq("id", profile.owner_id)
          .single();
        if (ownerProfile?.plan_tier) {
          if (ownerProfile.plan_tier === "premium" || (ownerProfile.plan_tier === "standard" && tier !== "premium")) {
            tier = ownerProfile.plan_tier;
          }
        }
        // Parent's own phone is already set as targetPhone above

      } else if (profile.role === "self") {
        if (profile.phone && profile.phone.length >= 10) {
          targetPhone = profile.phone;
        }
        targetName = profile.full_name || "User";
      }

      const translator = translationMap[language] || translationMap.english;

      // Format batched medicines text
      const medNames = medicines.map(m => m.name).join(", ");
      
      // Batch food instructions: if all are the same, use it, else generic instructions
      const foodInstKeys = medicines.map(m => m.food_instruction);
      const uniqueFoodInstKeys = [...new Set(foodInstKeys)];
      let foodInstructionText = "";
      if (uniqueFoodInstKeys.length === 1) {
        const key = uniqueFoodInstKeys[0];
        foodInstructionText = key === 'before_food' ? translator.beforeFood 
                            : key === 'after_food' ? translator.afterFood 
                            : key === 'with_food' ? translator.withFood 
                            : translator.noInstruction;
      } else {
        foodInstructionText = medicines.map(m => {
          const instText = m.food_instruction === 'before_food' ? translator.beforeFood 
                          : m.food_instruction === 'after_food' ? translator.afterFood 
                          : m.food_instruction === 'with_food' ? translator.withFood 
                          : '';
          return `${m.name} (${instText})`;
        }).filter(t => t !== '').join(", ");
      }

      const firstMed = medicines[0];
      const defaultDosage = (firstMed && firstMed.form) ? `1 ${firstMed.form}` : "1 tablet";

      // Generate localized text script (for logging only, actual call uses template variables)
      let customizedText = translator.reminderText
        .replace("{{medicine_name}}", medNames)
        .replace("{{dosage}}", defaultDosage);

      console.log(`Processing: ${targetName} → phone: ${targetPhone} (tier: ${tier})`);

      let logStatus = "failed";

      if (tier === "basic") {
        // Basic tier is delivered locally on device. No server API dispatch is required.
        console.log(`Skipping server dispatch for Basic tier user: ${profile.full_name}`);
        continue;
      }

      // Helper function to send WhatsApp via Gonums GET API (English: 11344, Hindi: 11347, Marathi: 11348)
      async function sendGonumsWhatsapp(): Promise<boolean> {
        if (!gonumsApiKey) {
          console.log(`[DEV WhatsApp Mock] → ${targetPhone}: "${customizedText}"`);
          return true;
        }
        try {
          const cleanPhone = targetPhone.replace(/[^0-9]/g, "");
          const formattedPhone = cleanPhone.startsWith("91") ? cleanPhone : `91${cleanPhone}`;

          const messageIdMap: Record<string, string> = {
            english: "11344",
            hindi: "11347",
            marathi: "11348",
          };
          const messageId = messageIdMap[language.toLowerCase()] || "11344";

          const firstMed = medicines[0];
          const dosageStr = firstMed ? `1 ${firstMed.form || 'Tablet'}` : "1 Dose";
          
          // Format 12-hour time
          const rawTime = firstMed?.dose_time || currentTimeString;
          const parts = rawTime.split(":");
          let hour = parseInt(parts[0]) || 8;
          const min = parseInt(parts[1]) || 0;
          const ampm = hour >= 12 ? "PM" : "AM";
          const displayHour = hour > 12 ? hour - 12 : (hour === 0 ? 12 : hour);
          const timeStr = `${displayHour.toString().padStart(2, '0')}:${min.toString().padStart(2, '0')} ${ampm}`;

          // Var1: Name | Var2: Medicine Name | Var3: Dosage | Var4: Time
          const varsCombined = `${targetName}|${medNames}|${dosageStr}|${timeStr}`;

          const requestUrl = `https://my.gonums.com/dev/whatsapp?authorization=${encodeURIComponent(gonumsApiKey)}&message_id=${messageId}&numbers=${formattedPhone}&variables_values=${encodeURIComponent(varsCombined)}`;

          console.log(`Dispatching Gonums WhatsApp GET request (${language}): ${requestUrl}`);

          const response = await fetch(requestUrl, { method: "GET" });
          console.log(`WhatsApp (${language} / msg_id: ${messageId}) → ${formattedPhone} status: ${response.status}`);
          return response.ok;
        } catch (err) {
          console.error("WhatsApp dispatch error:", err);
          return false;
        }
      }

      // Helper function to send Automated Voice Call via Ring TTS API
      async function sendVoiceCall(): Promise<boolean> {
        if (!ringTtsApiKey) {
          console.log(`[DEV TTS Call Mock] Initiated phone call to ${targetPhone}: "${customizedText}"`);
          return true;
        }
        try {
          const cleanPhone = targetPhone.replace(/[^0-9]/g, "");
          const formattedPhone = cleanPhone.startsWith("91") ? cleanPhone : `91${cleanPhone}`;
          const langCode = languageCodeMap[language] || "EN";

          const ttsPayload = {
            templateText: translator.reminderText,
            recipients: [
              {
                phone: formattedPhone,
                variables: {
                  medicine_name: medNames,
                  dosage: defaultDosage,
                  "Medicine Name": medNames,
                  "Dosage": defaultDosage,
                  user_name: targetName,
                  item: medNames,
                  time: defaultDosage
                }
              }
            ],
            language: langCode
          };

          const response = await fetch(ringTtsUrl, {
            method: "POST",
            headers: {
              "X-API-Key": ringTtsApiKey,
              "Content-Type": "application/json"
            },
            body: JSON.stringify(ttsPayload)
          });

          console.log(`TTS Call → ${formattedPhone} status: ${response.status}`);
          return response.ok;
        } catch (err) {
          console.error("TTS Call dispatch error:", err);
          return false;
        }
      }

      // All users receive Automated Voice Calling reminders
      console.log(`Executing Automated Voice Call for ${targetName}...`);
      const callOk = await sendVoiceCall();
      if (callOk) logStatus = "success";

      // Log the reminder attempt in reminder_logs for each medicine in this batch
      for (const med of medicines) {
        await supabase.from("reminder_logs").insert({
          medicine_id: med.id,
          channel: "tts_call",
          status: logStatus,
          sent_at: new Date().toISOString()
        });
        
        // Optionally decrement pills_left
        if (med.pills_left !== null && med.pills_left > 0) {
          await supabase.from("medicines")
            .update({ pills_left: med.pills_left - 1 })
            .eq("id", med.id);
        }
      }
    }

    return new Response(JSON.stringify({ success: true, count: scheduledMedicines.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (err: any) {
    console.error("Unhandled error in send-reminder:", err);
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
