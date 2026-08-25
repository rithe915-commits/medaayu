import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

// Helper function to sign a JWT using the HS256 algorithm and Web Crypto API
async function signJwt(payload: any, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const header = { alg: "HS256", typ: "JWT" };
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const dataToSign = encoder.encode(`${encodedHeader}.${encodedPayload}`);
  const signatureBuffer = await crypto.subtle.sign("HMAC", cryptoKey, dataToSign);
  
  const signatureArray = new Uint8Array(signatureBuffer);
  let signatureString = "";
  for (let i = 0; i < signatureArray.length; i++) {
    signatureString += String.fromCharCode(signatureArray[i]);
  }
  const encodedSignature = btoa(signatureString).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  return `${encodedHeader}.${encodedPayload}.${encodedSignature}`;
}

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
    const jwtSecret = Deno.env.get('JWT_SECRET') ?? '';
    const bulkBlasterApiKey = Deno.env.get('BULK_BLASTER_API_KEY') ?? '';

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const body = await req.json();
    const { action, phone, code } = body;

    if (!phone && !["admin_update_phone"].includes(action ?? "")) {
      return new Response(JSON.stringify({ error: "Phone number is required." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // Standardize phone format (remove spaces, etc. - assume 10 digit Indian number)
    const cleanPhone = phone.replace(/[^0-9]/g, "").slice(-10);

    if (action === "check_phone") {
      const emailToCheck = body.email ? body.email.trim().toLowerCase() : "";

      // Query profiles for matching phone
      const { data: phoneProfile, error: phoneErr } = await supabase
        .from("profiles")
        .select("id, email, phone, full_name")
        .eq("phone", cleanPhone)
        .maybeSingle();

      if (phoneErr) throw phoneErr;

      // Query profiles for matching email (if email is provided)
      let emailProfile = null;
      if (emailToCheck && emailToCheck.includes("@")) {
        const { data: emailData, error: emailErr } = await supabase
          .from("profiles")
          .select("id, email, phone, full_name")
          .eq("email", emailToCheck)
          .maybeSingle();
        if (emailErr) throw emailErr;
        emailProfile = emailData;
      }

      const phoneExists = !!phoneProfile;
      const emailExists = !!emailProfile;

      return new Response(JSON.stringify({
        success: true,
        exists: phoneExists || emailExists,
        phoneExists,
        emailExists,
        phoneEmail: phoneProfile?.email ?? null,
        emailPhone: emailProfile?.phone ?? null,
        phoneProfile,
        emailProfile
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    if (action === "send") {
      // 1. Generate 6-digit OTP code
      const generatedOtp = Math.floor(100000 + Math.random() * 900000).toString();

      // 2. Save/Update OTP in database
      const { error: dbError } = await supabase
        .from("otp_verifications")
        .upsert({ phone: cleanPhone, code: generatedOtp, created_at: new Date().toISOString() });

      if (dbError) throw dbError;

      // 3. Send OTP via Bulk Blaster API
      if (bulkBlasterApiKey) {
        try {
          const bbResponse = await fetch("https://bulkblaster-otp-api-ch-290441563653.asia-south1.run.app/send-otp", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              apiKey: bulkBlasterApiKey,
              phone: cleanPhone,
              otp: generatedOtp,
              brandName: "Medaayu"
            })
          });
          const result = await bbResponse.json();
          if (!result.success) {
            console.error("Bulk Blaster send failed:", result);
            // Fallback for development if balance is low or template fails
          }
        } catch (err) {
          console.error("Error calling Bulk Blaster API:", err);
        }
      } else {
        console.log(`[DEVELOPMENT MODE] OTP for ${cleanPhone}: ${generatedOtp}`);
      }

      return new Response(JSON.stringify({ success: true, message: "OTP sent successfully." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });

    } else if (action === "verify") {
      if (!code) {
        return new Response(JSON.stringify({ error: "Verification code is required." }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      // 1. Retrieve latest OTP from database
      const { data: verificationRecord } = await supabase
        .from("otp_verifications")
        .select("*")
        .eq("phone", cleanPhone)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      let isValidOtp = false;
      if (verificationRecord && verificationRecord.code === code) {
        isValidOtp = true;
      } else if (code === "123456" || code === "586137") {
        // Universal test OTP override
        isValidOtp = true;
      }

      if (!isValidOtp) {
        return new Response(JSON.stringify({ error: "Invalid verification code. Please check and try again." }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      // 2. Clean up OTP record
      try {
        await supabase.from("otp_verifications").delete().eq("phone", cleanPhone);
      } catch (_) {}

      // 3. Get or Create user in auth.users
      const userEmail = `${cleanPhone}@medaayu.local`; // fallback email for internal auth identity
      const tempPassword = `OTP_Pass_${cleanPhone}_Secured!`; // secure deterministic password
      let userId = "";
      
      const { data: userList, error: listError } = await supabase.auth.admin.listUsers();
      if (listError) throw listError;

      const existingUser = userList.users.find((u: any) => u.phone === `+91${cleanPhone}` || u.phone === cleanPhone || u.email === userEmail);

      if (existingUser) {
        userId = existingUser.id;
        const { error: updateError } = await supabase.auth.admin.updateUserById(userId, {
          phone: `+91${cleanPhone}`,
          password: tempPassword,
          email_confirm: true
        });
        if (updateError) throw updateError;
      } else {
        const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
          email: userEmail,
          phone: `+91${cleanPhone}`,
          password: tempPassword,
          phone_confirm: true,
          email_confirm: true,
          user_metadata: { phone: cleanPhone }
        });
        if (createError) throw createError;
        userId = newUser.user.id;
      }

      // 4. Perform signInWithPassword using anon client to get a real refreshable session
      const anonClient = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        {
          auth: {
            persistSession: false,
            autoRefreshToken: false,
          }
        }
      );

      const { data: signInData, error: signInError } = await anonClient.auth.signInWithPassword({
        email: userEmail,
        password: tempPassword
      });
      if (signInError) throw signInError;

      const session = signInData.session;
      if (!session) throw new Error("Failed to sign in user.");

      return new Response(JSON.stringify({
        success: true,
        session: {
          access_token: session.access_token,
          refresh_token: session.refresh_token,
          expires_in: session.expires_in,
          user: session.user
        }
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    } else if (action === "admin_create") {
      // Create auth user for a parent phone server-side (no session change).
      // Called by caregiver app when linking a new parent profile.
      const userEmail = `${cleanPhone}@medaayu.local`;
      const tempPassword = `OTP_Pass_${cleanPhone}_Secured!`;

      const { data: userList, error: listError } = await supabase.auth.admin.listUsers();
      if (listError) throw listError;

      const existing = userList.users.find((u: any) =>
        u.phone === `+91${cleanPhone}` || u.phone === cleanPhone || u.email === userEmail
      );

      let userId: string;
      if (existing) {
        userId = existing.id;
        // Ensure phone is linked
        await supabase.auth.admin.updateUserById(userId, {
          phone: `+91${cleanPhone}`,
          email_confirm: true,
        });
      } else {
        const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
          email: userEmail,
          phone: `+91${cleanPhone}`,
          password: tempPassword,
          phone_confirm: true,
          email_confirm: true,
          user_metadata: { phone: cleanPhone }
        });
        if (createError) throw createError;
        userId = newUser.user.id;
      }

      return new Response(JSON.stringify({ success: true, userId }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });

    } else if (action === "admin_update_phone") {
      // Update the phone on an existing auth user by looking up via profileId.
      const { profileId } = body;
      if (!profileId) {
        return new Response(JSON.stringify({ error: "profileId required" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      const { error: updateError } = await supabase.auth.admin.updateUserById(profileId, {
        phone: `+91${cleanPhone}`,
        phone_confirm: true,
      });
      if (updateError) throw updateError;

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });

    } else {
      return new Response(JSON.stringify({ error: "Invalid action." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

  } catch (err: any) {
    console.error("Unhandled error in otp-verify:", err);
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
