-- LearnLynk Tech Test - Task 2: RLS Policies on leads

-- Supporting tables for RLS (create these first)
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  role text not null check (role in ('admin', 'counselor')),
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_teams (
  user_id uuid not null references public.users(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, team_id)
);

create index if not exists idx_users_tenant_id on public.users(tenant_id);
create index if not exists idx_teams_tenant_id on public.teams(tenant_id);
create index if not exists idx_user_teams_user_id on public.user_teams(user_id);
create index if not exists idx_user_teams_team_id on public.user_teams(team_id);

-- Enable RLS on leads
alter table public.leads enable row level security;

-- Helper function to get JWT claims
create or replace function public.current_user_id() returns uuid as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'user_id', '')::uuid;
$$ language sql stable security definer;

create or replace function public.current_user_role() returns text as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'role', '');
$$ language sql stable security definer;

create or replace function public.current_user_tenant_id() returns uuid as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id', '')::uuid;
$$ language sql stable security definer;

-- SELECT policy for leads
-- Counselors can see leads they own OR leads assigned to their team
-- Admins can see all leads in their tenant
create policy "leads_select_policy"
on public.leads
for select
using (
  -- Check tenant_id matches JWT
  tenant_id = public.current_user_tenant_id()
  and
  (
    -- Admins can see all leads in their tenant
    public.current_user_role() = 'admin'
    or
    -- Counselors can see leads they own
    (public.current_user_role() = 'counselor' and owner_id = public.current_user_id())
    or
    -- Counselors can see leads assigned to their teams
    (
      public.current_user_role() = 'counselor'
      and exists (
        select 1
        from user_teams ut
        inner join teams t on t.id = ut.team_id
        where ut.user_id = public.current_user_id()
        and t.id in (
          select team_id
          from user_teams
          where user_id = leads.owner_id
        )
      )
    )
  )
);

-- INSERT policy for leads
-- Counselors and admins can insert leads for their tenant
create policy "leads_insert_policy"
on public.leads
for insert
with check (
  -- User must be counselor or admin
  public.current_user_role() in ('counselor', 'admin')
  and
  -- tenant_id must match JWT tenant_id
  tenant_id = public.current_user_tenant_id()
);
