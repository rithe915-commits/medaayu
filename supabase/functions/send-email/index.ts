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
    const resendApiKey = Deno.env.get('RESEND_API_KEY') ?? '';
    const body = await req.json();
    const { to, type, name, addonName, activationDate } = body;

    if (!to) {
      return new Response(JSON.stringify({ error: "Recipient email 'to' is required." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const userName = name || "User";
    const dateStr = activationDate || new Date().toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' });

    let subject = "";
    let htmlContent = "";

    if (type === "welcome") {
      subject = "Welcome to MedAayu – Your Healthcare Companion";
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1F2937; line-height: 1.6;">
          <h2 style="color: #3A86F0;">Welcome to MedAayu! 💚</h2>
          <p>Hi <strong>${userName}</strong>,</p>
          <p>Thank you for creating your MedAayu account. We're delighted to have you with us on your journey toward better health management.</p>
          <p><strong>With MedAayu, you can:</strong></p>
          <ul>
            <li>💊 Add medicines and schedule smart reminders</li>
            <li>📞 Receive automated reminder calls (Premium)</li>
            <li>👨‍👩‍👧 Manage medicines for yourself and your family</li>
            <li>🧪 Store and organize medical records, prescriptions, lab reports, scans, and test results in one secure place</li>
            <li>📊 Track your medication history and adherence</li>
            <li>🚨 Access emergency SOS features</li>
            <li>🌐 Use MedAayu in English, Hindi, or Marathi</li>
          </ul>
          <h3>Get Started</h3>
          <ol>
            <li>Complete your profile.</li>
            <li>Add your first medicine.</li>
            <li>Upload your medical records and prescriptions.</li>
            <li>Enable notifications so you never miss a medicine.</li>
          </ol>
          <p>Your health information is securely stored and accessible whenever you need it.</p>
          <p>If you ever need assistance, simply reply to this email—we're always happy to help.</p>
          <p>Thank you for choosing MedAayu.</p>
          <p>Stay Healthy,<br><strong>Team MedAayu</strong><br><small style="color: #6B7280;">Smart Medicine Reminders • Family Healthcare • Medical Records</small></p>
        </div>
      `;
    } else if (type === "plan_basic") {
      subject = "Welcome to MedAayu Basic Plan";
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1F2937; line-height: 1.6;">
          <h2 style="color: #00B894;">Welcome to MedAayu Free Plan 💚</h2>
          <p>Hi <strong>${userName}</strong>,</p>
          <p>Thank you for choosing the <strong>MedAayu Free Plan</strong>!</p>
          <p>Your subscription has been activated successfully.</p>
          <h3>Your Free Plan includes:</h3>
          <ul>
            <li>💊 Unlimited medicine reminders</li>
            <li>⏰ Alarm & notification reminders</li>
            <li>👨‍👩‍👧 Manage medicines for yourself and your family</li>
            <li>🧪 Securely store prescriptions, lab reports, medical tests, and health records</li>
            <li>📊 Medication history and adherence tracking</li>
            <li>🌐 Available in English, Hindi, and Marathi</li>
          </ul>
          <p>You can upgrade to a paid plan anytime to unlock WhatsApp reminders and automated reminder calls.</p>
          <p>Thank you for choosing MedAayu.</p>
          <p>Stay Healthy,<br><strong>Team MedAayu</strong></p>
        </div>
      `;
    } else if (type === "plan_standard") {
      subject = "Your MedAayu Standard Plan is Active";
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1F2937; line-height: 1.6;">
          <h2 style="color: #3A86F0;">Your MedAayu Standard Plan is Active 🎉</h2>
          <p>Hi <strong>${userName}</strong>,</p>
          <p>Thank you for subscribing to the <strong>MedAayu Standard Plan</strong>!</p>
          <p>Your subscription is now active.</p>
          <h3>Your Standard Plan includes everything in the Free Plan, plus:</h3>
          <ul>
            <li>💬 WhatsApp medicine reminders</li>
            <li>💊 Smart medicine scheduling</li>
            <li>👨‍👩‍👧 Family medicine management</li>
            <li>🧪 Secure storage of prescriptions, reports, and medical records</li>
            <li>📊 Medication adherence tracking</li>
            <li>🌐 Support for English, Hindi, and Marathi</li>
          </ul>
          <p>Thank you for trusting MedAayu to help you stay on track with your medicines.</p>
          <p>Stay Healthy,<br><strong>Team MedAayu</strong></p>
        </div>
      `;
    } else if (type === "plan_premium") {
      subject = "Welcome to MedAayu Premium";
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1F2937; line-height: 1.6;">
          <h2 style="color: #6C5CE7;">Welcome to MedAayu Premium 🎉</h2>
          <p>Hi <strong>${userName}</strong>,</p>
          <p>Congratulations!</p>
          <p>Your <strong>MedAayu Premium</strong> subscription has been activated successfully.</p>
          <h3>Your Premium Benefits include:</h3>
          <ul>
            <li>📞 Automated medicine reminder calls</li>
            <li>💬 WhatsApp medicine reminders</li>
            <li>💊 Smart medicine reminders and scheduling</li>
            <li>👨‍👩‍👧 Family medicine management</li>
            <li>🧪 Store prescriptions, lab reports, scans, and all medical records securely</li>
            <li>📊 Advanced medication adherence tracking and history</li>
            <li>🚨 Priority access to premium healthcare features</li>
            <li>🌐 Available in English, Hindi, and Marathi</li>
          </ul>
          <p>Thank you for choosing MedAayu Premium. We're committed to helping you and your loved ones never miss an important medicine.</p>
          <p>Stay Healthy,<br><strong>Team MedAayu</strong></p>
        </div>
      `;
    } else if (type === "addon") {
      subject = "Your MedAayu Add-on Has Been Activated";
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1F2937; line-height: 1.6;">
          <h2 style="color: #6C5CE7;">Your MedAayu Add-on Has Been Activated 🎉</h2>
          <p>Hi <strong>${userName}</strong>,</p>
          <p>Thank you for purchasing a <strong>MedAayu Add-on</strong>!</p>
          <p>Your add-on has been activated successfully and is now available on your account.</p>
          <h3>Add-on Details</h3>
          <ul>
            <li><strong>Add-on:</strong> ${addonName || 'Extra Medication Call Reminder'}</li>
            <li><strong>Plan:</strong> Premium</li>
            <li><strong>Status:</strong> Active</li>
            <li><strong>Activated On:</strong> ${dateStr}</li>
          </ul>
          <p>Your add-on has been added to your existing Premium subscription and is ready to use immediately.</p>
          <p>You can view or manage your subscription and add-ons anytime from <strong>Settings → Subscription</strong> in the MedAayu app.</p>
          <p>If you have any questions or need assistance, simply reply to this email—we're always happy to help.</p>
          <p>Thank you for choosing MedAayu.</p>
          <p>Stay Healthy,<br><strong>Team MedAayu</strong></p>
        </div>
      `;
    } else {
      return new Response(JSON.stringify({ error: "Invalid email type specified." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    if (resendApiKey) {
      try {
        const resendRes = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${resendApiKey}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            from: "MedAayu <onboarding@resend.dev>",
            to: [to],
            subject: subject,
            html: htmlContent
          })
        });

        const resData = await resendRes.json();
        console.log(`Resend Email dispatch status (${resendRes.status}):`, resData);

        return new Response(JSON.stringify({ success: resendRes.ok, details: resData }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      } catch (err: any) {
        console.error("Resend API dispatch error:", err);
        return new Response(JSON.stringify({ error: err.message || "Failed to dispatch email via Resend API" }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
    } else {
      console.log(`[DEV MODE Email Mock] To: ${to} | Subject: "${subject}"`);
      return new Response(JSON.stringify({ success: true, mocked: true, subject }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

  } catch (err: any) {
    console.error("Unhandled error in send-email:", err);
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
