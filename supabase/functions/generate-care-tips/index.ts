import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

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
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY') ?? '';

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const body = await req.json();
    const { profileId, profile_id } = body;
    const targetProfileId = profileId || profile_id;

    if (!targetProfileId) {
      return new Response(JSON.stringify({ error: "profileId is required." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // 1. Fetch profile
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", targetProfileId)
      .maybeSingle();

    if (profileError) {
      console.error("Error fetching profile:", profileError);
      return new Response(JSON.stringify({ error: "Database error fetching profile." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    if (!profile) {
      console.warn(`Profile ${targetProfileId} not found — skipping care tips generation.`);
      return new Response(JSON.stringify({ success: false, message: "Profile not found, skipped." }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // 2. Fetch medicines
    const { data: medicines, error: medError } = await supabase
      .from("medicines")
      .select("*")
      .eq("profile_id", targetProfileId);

    if (medError) throw medError;

    const medString = (medicines && medicines.length > 0)
      ? medicines.map(m => `- ${m.name} (${m.form}, ${m.frequency}, ${m.food_instruction})`).join("\n")
      : "No active medications.";

    // 3. Call LLM (Gemini API) if key is set, otherwise use high-quality template tips
    let careTipsText = "";

    const userLang = (profile.language || 'english').toLowerCase();

    if (geminiApiKey) {
      try {
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

        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`;
        const response = await fetch(geminiUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{
              parts: [{ text: prompt }]
            }]
          })
        });

        const data = await response.json();
        const generatedText = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (generatedText) {
          careTipsText = generatedText;
        } else {
          console.error("Gemini API structure error:", data);
        }
      } catch (err) {
        console.error("Error communicating with Gemini API:", err);
      }
    }

    // Fallback if Gemini key is missing or failed
    if (!careTipsText) {
      const fallbackTipsMap: Record<string, string> = {
        english: `1. Hydration: Drink plenty of water throughout the day.
2. Mobility: Perform light stretching or taking short walks daily to maintain joint flexibility.
3. Fall Prevention: Clear pathways in the home and verify non-slip mats are secure.
Please consult a doctor or healthcare professional before making any changes to your medication or healthcare routine.`,
        hindi: `1. हाइड्रेशन: दिन भर खूब पानी पिएं।
2. गतिशीलता: जोड़ों की लचीलापन बनाए रखने के लिए रोजाना हल्की स्ट्रेचिंग करें या छोटी सैर करें।
3. गिरने से बचाव: घर में रास्ते साफ रखें और सुनिश्चित करें कि नॉन-स्लिप मैट सुरक्षित हैं।
कृपया अपने डॉक्टर या स्वास्थ्य पेशेवर से परामर्श किए बिना अपनी दवा या स्वास्थ्य दिनचर्या में कोई बदलाव न करें।`,
        marathi: `1. हायड्रेशन: दिवसभरात भरपूर पाणी प्या।
2. गतिशीलता: सांध्यांची लवचिकता टिकवून ठेवण्यासाठी रोज हलके स्ट्रेचिंग करा किंवा लहान फेरफटका मारा।
3. पडण्यापासून प्रतिबंध: घरातील रस्ते मोकळे ठेवा आणि नॉन-स्लिप मॅट्स सुरक्षित असल्याची खात्री करा।
कृपया आपल्या डॉक्टरांचा किंवा आरोग्य व्यावसायिकांचा सल्ला घेतल्याशिवाय आपल्या औषधात किंवा आरोग्य दिनचर्येत कोणताही बदल करू नका।`
      };
      careTipsText = fallbackTipsMap[userLang] || fallbackTipsMap.english;
    }

    // 4. Update profile care_tips in the database
    const { error: updateError } = await supabase
      .from("profiles")
      .update({
        care_tips: careTipsText,
        care_tips_updated_at: new Date().toISOString()
      })
      .eq("id", targetProfileId);

    if (updateError) throw updateError;

    return new Response(JSON.stringify({
      success: true,
      care_tips: careTipsText
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (err: any) {
    console.error("Unhandled error in generate-care-tips:", err);
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
