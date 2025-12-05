# LearnLynk – Technical Assessment 

Thanks for taking the time to complete this assessment. The goal is to understand how you think about problems and how you structure real project work. This is a small, self-contained exercise that should take around **2–3 hours**. It’s completely fine if you don’t finish everything—just note any assumptions or TODOs.

We use:

- **Supabase Postgres**
- **Supabase Edge Functions (TypeScript)**
- **Next.js + TypeScript**

You may use your own free Supabase project.

---

## Overview

There are four technical tasks:

1. Database schema — `backend/schema.sql`  
2. RLS policies — `backend/rls_policies.sql`  
3. Edge Function — `backend/edge-functions/create-task/index.ts`  
4. Next.js page — `frontend/pages/dashboard/today.tsx`  

There is also a short written question about Stripe in this README.

Feel free to use Supabase/PostgreSQL docs, or any resource you normally use.

---

## Task 1 — Database Schema

File: `backend/schema.sql`

Create the following tables:

- `leads`  
- `applications`  
- `tasks`  

Each table should include standard fields:

```sql
id uuid primary key default gen_random_uuid(),
tenant_id uuid not null,
created_at timestamptz default now(),
updated_at timestamptz default now()
```

Additional requirements:

- `applications.lead_id` → FK to `leads.id`  
- `tasks.application_id` → FK to `applications.id`  
- `tasks.type` should only allow: `call`, `email`, `review`  
- `tasks.due_at >= tasks.created_at`  
- Add reasonable indexes for typical queries:  
  - Leads: `tenant_id`, `owner_id`, `stage`  
  - Applications: `tenant_id`, `lead_id`  
  - Tasks: `tenant_id`, `due_at`, `status`  

---

## Task 2 — Row-Level Security

File: `backend/rls_policies.sql`

We want:

- Counselors can see:
  - Leads they own, or  
  - Leads assigned to any team they belong to  
- Admins can see all leads belonging to their tenant

Assume the existence of:

```
users(id, tenant_id, role)
teams(id, tenant_id)
user_teams(user_id, team_id)
```

JWT contains:

- `user_id`
- `role`
- `tenant_id`

Tasks:

1. Enable RLS on `leads`  
2. Write a **SELECT** policy enforcing the rules above  
3. Write an **INSERT** policy that allows counselors/admins to add leads under their tenant  

---

## Task 3 — Edge Function: create-task

File: `backend/edge-functions/create-task/index.ts`

Write a simple POST endpoint that:

### Input:
```json
{
  "application_id": "uuid",
  "task_type": "call",
  "due_at": "2025-01-01T12:00:00Z"
}
```

### Requirements:
- Validate:
  - `task_type` is `call`, `email`, or `review`
  - `due_at` is a valid *future* timestamp  
- Insert a row into `tasks` using the service role key  
- Return:

```json
{ "success": true, "task_id": "..." }
```

On validation error → return **400**  
On internal errors → return **500**

---

## Task 4 — Frontend Page: `/dashboard/today`

File: `frontend/pages/dashboard/today.tsx`

Build a small page that:

- Fetches tasks due **today** (status ≠ completed)  
- Uses the provided Supabase client  
- Displays:  
  - type  
  - application_id  
  - due_at  
  - status  
- Adds a “Mark Complete” button that updates the task in Supabase  

---

## Task 5 — Stripe Checkout (Written Answer)

Add a section titled:

```
## Stripe Answer
```

Write **8–12 lines** describing how you would implement a Stripe Checkout flow for an application fee, including:

- When you insert a `payment_requests` row  
- When you call Stripe  
- What you store from the checkout session  
- How you handle webhooks  
- How you update the application after payment succeeds  

---

## Submission

1. Push your work to a public GitHub repo.  
2. Add your Stripe answer at the bottom of this file.  
3. Share the link.

Good luck.

---

## Implementation Status

### Section 1 - Database Schema (`backend/schema.sql`)
- Created 3 tables: leads, applications, tasks
- All tables include: id, tenant_id, created_at, updated_at
- applications.lead_id → FK to leads(id) with cascade delete
- tasks.application_id → FK to applications(id) with cascade delete
- Check constraint: tasks.type IN ('call', 'email', 'review')
- Check constraint: tasks.due_at >= created_at
- Indexes for leads: tenant_id, owner_id, stage, created_at, compound indexes
- Indexes for applications: tenant_id, lead_id, stage, compound indexes
- Indexes for tasks: tenant_id, due_at, status, compound indexes

### Section 2 - RLS Policies (`backend/rls_policies.sql`)
- Supporting tables created: users, teams, user_teams
- RLS enabled on leads table
- Helper functions for JWT claims (user_id, role, tenant_id)
- SELECT policy: Counselors see leads they own OR leads in their team, Admins see all
- INSERT policy: Counselors and admins can insert leads for their tenant

### Section 3 - Edge Function (`backend/edge-functions/create-task/index.ts`)
- POST endpoint accepting application_id, task_type, due_at
- Validates task_type is one of: call, email, review
- Validates due_at is valid ISO 8601 format
- Validates due_at is in the future
- Verifies application exists
- Inserts task into tasks table using Supabase client with service role
- Emits Realtime broadcast event "task.created"
- Returns {success: true, task_id: "..."}
- Proper error handling with status codes (400, 404, 500, 200)

### Section 4 - Frontend Dashboard (`frontend/pages/dashboard/today.tsx`)
- Next.js page at /dashboard/today
- Fetches tasks due today from Supabase
- Filters out completed tasks
- Displays in table format
- Shows: type, application_id, due_at, status
- "Mark Complete" button for each task
- Updates task status via supabase.from("tasks").update()
- Optimistic UI update (removes from list immediately)
- Loading state handling
- Error state handling

### Section 5 - Stripe Integration (Written explanation below)

### Additional Files
- `backend/seed_data.sql` - Sample data for testing (5 tasks due today, 2 leads, 2 applications)

---

## Stripe Answer

To implement a Stripe Checkout flow for an application fee:

1. **Create payment_request row**: When a counselor initiates payment for an application, insert a record in `payment_requests` table with `application_id`, `amount`, `status: 'pending'`, and `created_at`.

2. **Create Checkout Session**: Call `stripe.checkout.sessions.create()` with the amount, success/cancel URLs, and metadata containing `payment_request_id` and `application_id`. Store the returned `session_id` and `checkout_url` in the `payment_requests` row.

3. **Store session data**: Update `payment_requests` with `stripe_session_id`, `stripe_session_url`, and set `status: 'awaiting_payment'`. Redirect user to the checkout URL.

4. **Handle webhooks**: Listen for `checkout.session.completed` webhook. Verify signature using `stripe.webhooks.constructEvent()`. Extract `payment_intent_id` and metadata from the event, then update `payment_requests` with `stripe_payment_intent_id`, `status: 'paid'`, and `paid_at` timestamp.

5. **Update application**: In the webhook handler, after confirming payment, update the related application's `status` to `'payment_received'` and `stage` to the next phase (e.g., `'document_submission'`). Optionally trigger email notifications to the student and counselor, and create a timeline entry documenting the payment completion.