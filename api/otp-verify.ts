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
    const bulkBlasterApiKey = process.env.BULK_BLASTER_API_KEY || '';

    const body = req.body || {};
    const { action, phone, code } = body;

    if (!phone && action !== 'admin_update_phone') {
      return res.status(400).json({ error: "Phone number is required." });
    }

    const cleanPhone = (phone || '').toString().replace(/[^0-9]/g, "");
    const tenDigit = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Send OTP
    if (action === 'send' || !action) {
      const generatedCode = Math.floor(100000 + Math.random() * 900000).toString();

      // Upsert into otp_verifications
      await supabase
        .from('otp_verifications')
        .upsert({
          phone: tenDigit,
          code: generatedCode,
          created_at: new Date().toISOString()
        });

      // Send SMS via Bulk Blaster if configured
      if (bulkBlasterApiKey) {
        try {
          await fetch(`https://bulkblaster.in/api/send?apikey=${bulkBlasterApiKey}&mobile=${tenDigit}&msg=Your MedAayu OTP is ${generatedCode}`);
        } catch (smsErr) {
          console.warn("SMS dispatch error:", smsErr);
        }
      }

      return res.status(200).json({
        success: true,
        message: "OTP sent successfully.",
        phone: tenDigit
      });
    }

    // 2. Verify OTP
    if (action === 'verify') {
      const { data: record } = await supabase
        .from('otp_verifications')
        .select('*')
        .eq('phone', tenDigit)
        .maybeSingle();

      if (!record || record.code !== code) {
        return res.status(400).json({ success: false, error: "Invalid OTP code." });
      }

      return res.status(200).json({
        success: true,
        verified: true,
        phone: tenDigit
      });
    }

    // 3. Check Phone Existence
    if (action === 'check_phone') {
      const { data: profile } = await supabase
        .from('profiles')
        .select('id, full_name, phone')
        .eq('phone', tenDigit)
        .maybeSingle();

      return res.status(200).json({
        exists: !!profile,
        profile: profile || null
      });
    }

    return res.status(400).json({ error: "Unknown action" });

  } catch (err: any) {
    return res.status(500).json({ error: err.message || "Internal server error" });
  }
}
