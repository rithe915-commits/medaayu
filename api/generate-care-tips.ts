import type { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'authorization, x-client-info, apikey, content-type');
  if (req.method === 'OPTIONS') {
    return res.status(200).send('ok');
  }

  try {
    const supabaseUrl = process.env.SUPABASE_URL || 'https://ysuwnlvmipgfgesdpqdn.supabase.co';
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || 'sb_publishable_IBq3dRoeAggLMh7BWGqYSg_KAuL_BoD';
    const meshApiKey = process.env.MESH_API_KEY || '';
    const geminiApiKey = process.env.GEMINI_API_KEY || '';

    const body = req.body || {};
    const { profileId, profile_id, action } = body;
    const targetProfileId = profileId || profile_id;

    if (action === 'test_mesh' || action === 'test') {
      if (meshApiKey) {
        const meshRes = await fetch("https://api.meshapi.ai/v1/chat/completions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${meshApiKey}`
          },
          body: JSON.stringify({
            model: "google/gemini-2.5-flash-lite",
            messages: [
              { role: "system", content: "You are a helpful assistant." },
              { role: "user", content: "Say hello from Gemini 2.5 Flash Lite on MedAayu (Vercel)!" }
            ]
          })
        });

        const meshData = await meshRes.json();
        return res.status(200).json({
          success: meshRes.ok,
          provider: "Mesh API (google/gemini-2.5-flash-lite)",
          response: meshData
        });
      }
    }

    if (!targetProfileId) {
      return res.status(400).json({ error: "profileId is required." });
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Fetch profile
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", targetProfileId)
      .maybeSingle();

    if (profileError) throw profileError;
    if (!profile) {
      return res.status(200).json({ success: false, message: "Profile not found, skipped." });
    }

    // 2. Fetch medicines
    const { data: medicines } = await supabase
      .from("medicines")
      .select("*")
      .eq("profile_id", targetProfileId);

    const medString = (medicines && medicines.length > 0)
      ? medicines.map((m: any) => `- ${m.name} (${m.form}, ${m.frequency}, ${m.food_instruction})`).join("\n")
      : "No active medications.";

    const userLang = (profile.language || 'english').toLowerCase();
    const prompt = `You are a professional elder-care assistant. Write 3 short wellness tips for:
Name: ${profile.full_name}
Age: ${profile.age ?? 'Not specified'}
Gender: ${profile.gender ?? 'Not specified'}
Active Medications:
${medString}

RULES:
1. Write the tips completely in the language: ${userLang}.
2. Keep the tips extremely concise (under 25 words each).
3. DO NOT provide any medical diagnosis or suggest what medical conditions they might have.
4. DO NOT advise modifying dosages, changing medication times, or adjusting treatments.
5. Focus on general wellness: hydration, gentle movement/stretching, diet/nutrition, safety (avoiding falls), and sleep.
6. You MUST end the text with a professional disclaimer in ${userLang} advising to consult a doctor before making any changes.

Provide the output as plain text.`;

    let careTipsText = "";

    // 3. Call Mesh API (google/gemini-2.5-flash-lite)
    if (meshApiKey) {
      try {
        const meshRes = await fetch("https://api.meshapi.ai/v1/chat/completions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${meshApiKey}`
          },
          body: JSON.stringify({
            model: "google/gemini-2.5-flash-lite",
            messages: [
              { role: "system", content: "You are a professional elder-care assistant." },
              { role: "user", content: prompt }
            ],
            temperature: 0.7
          })
        });

        if (meshRes.ok) {
          const meshData = await meshRes.json();
          careTipsText = meshData.choices?.[0]?.message?.content || "";
        }
      } catch (e) {
        console.warn("Mesh API error:", e);
      }
    }

    // Fallback template tips
    if (!careTipsText) {
      const fallbackTipsMap: Record<string, string> = {
        english: `1. Hydration: Drink plenty of water throughout the day.\n2. Mobility: Perform light stretching or short walks daily.\n3. Fall Prevention: Keep home pathways clear.\nConsult a healthcare professional before making any healthcare routine changes.`,
        hindi: `1. हाइड्रेशन: दिन भर खूब पानी पिएं।\n2. गतिशीलता: रोजाना हल्की स्ट्रेचिंग करें।\n3. सुरक्षा: घर में रास्ते साफ रखें।\nकृपया अपनी दवा में बदलाव करने से पहले डॉक्टर से सलाह लें।`,
        marathi: `1. हायड्रेशन: दिवसभरात भरपूर पाणी प्या।\n2. हालचाल: रोज हलके स्ट्रेचिंग करा।\n3. सुरक्षितता: घरातील रस्ते मोकळे ठेवा।\nकृपया औषध बदलण्यापूर्वी डॉक्टरांचा सल्ला घ्या.`
      };
      careTipsText = fallbackTipsMap[userLang] || fallbackTipsMap.english;
    }

    // Save to profile
    await supabase
      .from("profiles")
      .update({
        care_tips: careTipsText,
        care_tips_updated_at: new Date().toISOString()
      })
      .eq("id", targetProfileId);

    return res.status(200).json({
      success: true,
      care_tips: careTipsText
    });

  } catch (err: any) {
    return res.status(500).json({ error: err.message || "Internal server error" });
  }
}
