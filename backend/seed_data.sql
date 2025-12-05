-- Sample data for testing the LearnLynk application
-- Run this after schema.sql and rls_policies.sql

-- Note: Replace these UUIDs with actual values from your auth system if needed
DO $$ 
DECLARE
  sample_tenant_id uuid := 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  sample_owner_id uuid := 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  sample_lead_id uuid;
  sample_app_id1 uuid;
  sample_app_id2 uuid;
BEGIN
  -- Insert sample lead 1
  INSERT INTO public.leads (tenant_id, owner_id, email, phone, full_name, stage, source)
  VALUES (sample_tenant_id, sample_owner_id, 'john.doe@example.com', '+1234567890', 'John Doe', 'qualified', 'website')
  RETURNING id INTO sample_lead_id;
  
  -- Insert sample application 1
  INSERT INTO public.applications (tenant_id, lead_id, stage, status)
  VALUES (sample_tenant_id, sample_lead_id, 'application', 'open')
  RETURNING id INTO sample_app_id1;
  
  -- Insert tasks due TODAY for application 1
  INSERT INTO public.tasks (tenant_id, application_id, title, type, status, due_at) VALUES
  (sample_tenant_id, sample_app_id1, 'Follow-up call with applicant', 'call', 'open', now() + interval '2 hours'),
  (sample_tenant_id, sample_app_id1, 'Send admission documents via email', 'email', 'open', now() + interval '4 hours'),
  (sample_tenant_id, sample_app_id1, 'Review application materials', 'review', 'open', now() + interval '6 hours');

  -- Insert sample lead 2
  INSERT INTO public.leads (tenant_id, owner_id, email, phone, full_name, stage, source)
  VALUES (sample_tenant_id, sample_owner_id, 'jane.smith@example.com', '+1234567891', 'Jane Smith', 'new', 'referral')
  RETURNING id INTO sample_lead_id;
  
  -- Insert sample application 2
  INSERT INTO public.applications (tenant_id, lead_id, stage, status)
  VALUES (sample_tenant_id, sample_lead_id, 'inquiry', 'open')
  RETURNING id INTO sample_app_id2;
  
  -- Insert tasks due TODAY for application 2
  INSERT INTO public.tasks (tenant_id, application_id, title, type, status, due_at) VALUES
  (sample_tenant_id, sample_app_id2, 'Initial consultation call', 'call', 'open', now() + interval '3 hours'),
  (sample_tenant_id, sample_app_id2, 'Send program information', 'email', 'open', now() + interval '5 hours');

  -- Insert some completed tasks (these should NOT show up on the dashboard)
  INSERT INTO public.tasks (tenant_id, application_id, title, type, status, due_at) VALUES
  (sample_tenant_id, sample_app_id1, 'Welcome email sent', 'email', 'completed', now() + interval '1 hour');

  -- Insert some future tasks (these should NOT show up on today's dashboard)
  INSERT INTO public.tasks (tenant_id, application_id, title, type, status, due_at) VALUES
  (sample_tenant_id, sample_app_id1, 'Follow-up meeting', 'call', 'open', CURRENT_DATE + interval '2 days'),
  (sample_tenant_id, sample_app_id2, 'Document review', 'review', 'open', CURRENT_DATE + interval '3 days');

END $$;

-- Verify the data was inserted
SELECT 'Leads created:' as info, count(*) as count FROM public.leads;
SELECT 'Applications created:' as info, count(*) as count FROM public.applications;
SELECT 'Total tasks created:' as info, count(*) as count FROM public.tasks;
SELECT 'Tasks due today (open):' as info, count(*) as count FROM public.tasks 
WHERE date(due_at) = CURRENT_DATE AND status = 'open';
