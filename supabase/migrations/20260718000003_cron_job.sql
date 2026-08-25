-- Enable pg_cron and pg_net extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule cron job to trigger the send-reminder Edge Function every minute
-- Note: Replace ptqsrehgftghnuhduqao with your actual Supabase project reference if it changes
SELECT cron.schedule(
  'send-reminder-every-minute',
  '* * * * *',
  $$
  SELECT net.http_post(
    url := 'https://ptqsrehgftghnuhduqao.supabase.co/functions/v1/send-reminder',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 5000
  )
  $$
);
