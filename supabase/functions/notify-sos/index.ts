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
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const gonumsApiKey = Deno.env.get('GONUMS_API_KEY') ?? '';

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const body = await req.json();
    const { profileId, eventId, latitude, longitude } = body;

    if (!profileId || !eventId) {
      return new Response(JSON.stringify({ error: "profileId and eventId are required." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // 1. Fetch elder profile and caretaker details
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", profileId)
      .single();

    if (profileError || !profile) {
      throw new Error("Elder profile not found.");
    }

    const sosContacts = [profile.sos_contact_phone, profile.sos_contact_phone_2].filter(Boolean);
    if (sosContacts.length === 0) {
      return new Response(JSON.stringify({ success: true, message: "No emergency contacts configured. SMS skipped." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // 2. Format the emergency message
    const elderName = profile.full_name;
    const mapLink = (latitude && longitude) 
      ? `https://maps.google.com/?q=${latitude},${longitude}`
      : "Location unavailable";
    
    const smsText = `EMERGENCY ALERT: ${elderName} has triggered an SOS. Live Location: ${mapLink}. Please check on them immediately!`;

    // 3. Send SMS via Gonums Transactional API for each contact
    let allSent = true;
    const results = [];

    async function sendGonumsSms(apiKey: string, rawPhone: string, message: string): Promise<boolean> {
      try {
        const cleanContact = rawPhone.replace(/[^0-9]/g, "");
        const formattedContact = cleanContact.startsWith("91") ? cleanContact : `91${cleanContact}`;

        const params = new URLSearchParams();
        params.append("route", "q");
        params.append("message", message);
        params.append("mobile", formattedContact);

        const response = await fetch("https://my.gonums.com/dev/bulkV2", {
          method: "POST",
          headers: {
            "Authorization": apiKey,
            "Content-Type": "application/x-www-form-urlencoded"
          },
          body: params.toString()
        });

        const resText = await response.text();
        console.log(`Gonums SOS SMS API Response for ${formattedContact}:`, resText);
        return response.ok;
      } catch (err) {
        console.error(`Error sending SOS SMS to ${rawPhone} via Gonums API:`, err);
        return false;
      }
    }

    for (const contact of sosContacts) {
      console.log(`Sending SOS SMS to ${contact}: "${smsText}"`);
      if (gonumsApiKey) {
        const ok = await sendGonumsSms(gonumsApiKey, contact, smsText);
        if (!ok) allSent = false;
        results.push({ contact, success: ok });
      } else {
        console.log(`[DEVELOPMENT MODE] SOS SMS sent to ${contact} (Mocked success)`);
        results.push({ contact, success: true });
      }
    }

    return new Response(JSON.stringify({
      success: allSent,
      message: allSent ? "SOS Backup SMS dispatched." : "Failed to send SMS to some contacts.",
      details: results
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (err: any) {
    console.error("Unhandled error in notify-sos:", err);
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
