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
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get the calling user's JWT to identify owner
    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace('Bearer ', '');
    if (!token) {
      return new Response(JSON.stringify({ error: 'No auth token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    if (userError || !user) {
      console.error('Auth error:', userError?.message);
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    const ownerId = user.id;

    const body = await req.json();
    const {
      action,
      fullName, phone, age, gender, bloodGroup,
      planTier, language, sosAction,
      sosContact, sosContact2, email,
      profileId, newPhone, role
    } = body;

    // Clean phone helper
    const cleanPhone10 = (p: string) => {
      const digits = p.replace(/[^0-9]/g, '');
      return digits.slice(-10);
    };

    // ── ACTION: create ──────────────────────────────────────────────────────────
    if (action === 'create') {
      if (!fullName || !phone) {
        return new Response(JSON.stringify({ error: 'fullName and phone required' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const cleanedPhone = cleanPhone10(phone);
      const userEmail = `${cleanedPhone}@medaayu.local`;
      const tempPassword = `OTP_Pass_${cleanedPhone}_Secured!`;

      // 1. Get or create auth user for this phone (server-side, no session change)
      let parentAuthId: string;
      const { data: userList } = await supabase.auth.admin.listUsers();
      const existing = userList?.users?.find((u: any) =>
        u.phone === `+91${cleanedPhone}` || u.phone === cleanedPhone || u.email === userEmail
      );

      if (existing) {
        parentAuthId = existing.id;
        await supabase.auth.admin.updateUserById(parentAuthId, {
          phone: `+91${cleanedPhone}`,
          email_confirm: true,
        });
      } else {
        const { data: newUser, error: createErr } = await supabase.auth.admin.createUser({
          email: userEmail,
          phone: `+91${cleanedPhone}`,
          password: tempPassword,
          phone_confirm: true,
          email_confirm: true,
          user_metadata: { phone: cleanedPhone }
        });
        if (createErr) throw createErr;
        parentAuthId = newUser.user.id;
      }

      // 2. Upsert profile row
      const profileData = {
        id: parentAuthId,
        owner_id: ownerId,
        role: role || 'parent',
        full_name: fullName,
        phone: cleanedPhone,
        age: age ?? null,
        gender: gender ?? null,
        blood_group: bloodGroup ?? null,
        plan_tier: planTier ?? 'basic',
        language: language ?? 'english',
        sos_action: sosAction ?? 'notify',
        sos_contact_phone: sosContact ?? null,
        sos_contact_phone_2: sosContact2 ?? null,
        email: email ?? null,
      };

      const { error: upsertErr } = await supabase.from('profiles').upsert(profileData);
      if (upsertErr) throw upsertErr;

      return new Response(JSON.stringify({ success: true, profileId: parentAuthId, phone: cleanedPhone }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // ── ACTION: update_phone ────────────────────────────────────────────────────
    if (action === 'update_phone') {
      if (!profileId || !newPhone) {
        return new Response(JSON.stringify({ error: 'profileId and newPhone required' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const cleanedPhone = cleanPhone10(newPhone);

      // Update DB profile phone
      const { error: dbErr } = await supabase
        .from('profiles')
        .update({ phone: cleanedPhone })
        .eq('id', profileId);
      if (dbErr) throw dbErr;

      // Update auth user phone
      const { error: authErr } = await supabase.auth.admin.updateUserById(profileId, {
        phone: `+91${cleanedPhone}`,
        phone_confirm: true,
      });
      // Don't throw on auth update failure (profile row is more important)
      if (authErr) console.error('Auth phone update error (non-fatal):', authErr.message);

      return new Response(JSON.stringify({ success: true, phone: cleanedPhone }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // ── ACTION: delete ──────────────────────────────────────────────────────────
    if (action === 'delete') {
      if (!profileId) {
        return new Response(JSON.stringify({ error: 'profileId required' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Verify ownership
      const { data: targetProfile, error: getErr } = await supabase
        .from('profiles')
        .select('owner_id')
        .eq('id', profileId)
        .single();
        
      if (getErr || !targetProfile) {
        throw new Error('Profile not found.');
      }
      
      if (targetProfile.owner_id !== ownerId && profileId !== ownerId) {
        return new Response(JSON.stringify({ error: 'Unauthorized to delete this profile' }), {
          status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Delete public profile row
      const { error: dbErr } = await supabase
        .from('profiles')
        .delete()
        .eq('id', profileId);
      if (dbErr) throw dbErr;

      // Delete auth user (if not caregiver account deletion)
      if (profileId !== ownerId) {
        const { error: authErr } = await supabase.auth.admin.deleteUser(profileId);
        if (authErr) console.error('Auth user delete error (non-fatal):', authErr.message);
      }

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ error: 'Invalid action. Use create, update_phone, or delete.' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (err: any) {
    console.error('manage-parent error:', err);
    return new Response(JSON.stringify({ error: err.message || 'Internal server error' }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
