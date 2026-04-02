-- =============================================================================
-- Migration: initial_schema
-- Description: Full initial schema for the Client Profitability Tracker
-- =============================================================================


-- =============================================================================
-- EXTENSIONS
-- =============================================================================



-- =============================================================================
-- ENUMS
-- =============================================================================

create type project_status as enum ('active', 'on_hold', 'completed', 'archived');
create type payment_type   as enum ('otp', 'subscription');
create type client_status  as enum ('active', 'archived');
create type user_role      as enum ('owner', 'member');
create type plan_type      as enum ('free', 'starter', 'pro');
create type sub_status     as enum ('active', 'trialing', 'past_due', 'canceled', 'incomplete');


-- =============================================================================
-- ORGANIZATIONS
-- Top-level tenant. Every piece of data belongs to one organization.
-- =============================================================================

create table organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text not null unique,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);


-- =============================================================================
-- USERS
-- Mirrors Supabase Auth (auth.users). One user belongs to one organization.
-- The id here matches the Supabase Auth user id exactly.
-- =============================================================================

create table users (
  id               uuid primary key references auth.users(id) on delete cascade,
  organization_id  uuid not null references organizations(id) on delete cascade,
  email            text not null,
  role             user_role not null default 'owner',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index idx_users_organization_id on users(organization_id);


-- =============================================================================
-- SUBSCRIPTIONS
-- One record per organization. Tracks Stripe billing state.
-- Updated automatically via Stripe webhook.
-- =============================================================================

create table subscriptions (
  id                      uuid primary key default gen_random_uuid(),
  organization_id         uuid not null unique references organizations(id) on delete cascade,
  plan                    plan_type not null default 'free',
  status                  sub_status not null default 'active',
  stripe_customer_id      text unique,
  stripe_subscription_id  text unique,
  current_period_end      timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create index idx_subscriptions_organization_id on subscriptions(organization_id);
create index idx_subscriptions_stripe_customer_id on subscriptions(stripe_customer_id);


-- =============================================================================
-- CLIENTS
-- An agency's clients. Revenue and profit are aggregated from projects.
-- =============================================================================

create table clients (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references organizations(id) on delete cascade,
  name             text not null,
  notes            text,
  status           client_status not null default 'active',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index idx_clients_organization_id on clients(organization_id);
create index idx_clients_status on clients(status);


-- =============================================================================
-- PROJECTS
-- A client can have multiple projects. This is the core unit of profitability.
-- payment_type: 'otp' = one-time payment, 'subscription' = monthly retainer.
-- =============================================================================

create table projects (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid not null references clients(id) on delete cascade,
  name         text not null,
  notes        text,
  payment_type payment_type not null default 'otp',
  status       project_status not null default 'active',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_projects_client_id on projects(client_id);
create index idx_projects_status on projects(status);


-- =============================================================================
-- PROJECT MONTHS
-- Each row = one month of activity on a project.
-- For OTP projects: always exactly one row (month = project start month).
-- For subscription projects: one row per month, enabling month-by-month view.
-- revenue: what the client paid for this month / for the OTP project.
-- =============================================================================

create table project_months (
  id          uuid primary key default gen_random_uuid(),
  project_id  uuid not null references projects(id) on delete cascade,
  month       text not null,  -- format: 'YYYY-MM' e.g. '2024-03'
  revenue     numeric(12, 2) not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  -- one row per month per project
  unique(project_id, month)
);

create index idx_project_months_project_id on project_months(project_id);
create index idx_project_months_month on project_months(month);


-- =============================================================================
-- TEAM MEMBERS
-- Agency employees whose time can be logged against projects.
-- Either monthly_salary or hourly_rate (or both) can be set.
-- cost_per_hour is derived: monthly_salary / productive_hours_per_month.
-- =============================================================================

create table team_members (
  id                          uuid primary key default gen_random_uuid(),
  organization_id             uuid not null references organizations(id) on delete cascade,
  name                        text not null,
  monthly_salary              numeric(10, 2),
  hourly_rate                 numeric(8, 2),
  productive_hours_per_month  int not null default 160,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),

  -- at least one of salary or hourly rate must be set
  constraint chk_team_member_rate check (
    monthly_salary is not null or hourly_rate is not null
  )
);

create index idx_team_members_organization_id on team_members(organization_id);


-- =============================================================================
-- HOURS LOGS
-- Time logged against a project month.
-- team_member_id is nullable: allows logging total hours without assigning
-- to a specific employee (FR-04.1).
-- hourly_rate_snapshot: captures the rate at time of logging so historical
-- calculations remain accurate even if the team member's rate changes later.
-- =============================================================================

create table hours_logs (
  id                    uuid primary key default gen_random_uuid(),
  project_month_id      uuid not null references project_months(id) on delete cascade,
  team_member_id        uuid references team_members(id) on delete set null,
  hours                 numeric(6, 2) not null check (hours > 0),
  hourly_rate_snapshot  numeric(8, 2) not null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index idx_hours_logs_project_month_id on hours_logs(project_month_id);
create index idx_hours_logs_team_member_id on hours_logs(team_member_id);


-- =============================================================================
-- PROJECT COSTS
-- Individual cost line items for a project month.
-- cost_type: a flexible label (e.g. 'hours_worked', 'fb_ads', 'overhead',
-- 'software', 'travel', 'other') — not a rigid enum, per the mockups.
-- Hours Worked costs are typically auto-generated from hours_logs,
-- but can also be entered manually.
-- =============================================================================

create table project_costs (
  id                uuid primary key default gen_random_uuid(),
  project_month_id  uuid not null references project_months(id) on delete cascade,
  cost_type         text not null,   -- flexible: 'hours_worked', 'fb_ads', 'overhead', etc.
  label             text not null,   -- display label shown in the UI
  amount            numeric(12, 2) not null check (amount >= 0),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index idx_project_costs_project_month_id on project_costs(project_month_id);


-- =============================================================================
-- UPDATED_AT TRIGGER
-- Automatically updates the updated_at column on every row update.
-- =============================================================================

create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_organizations_updated_at
  before update on organizations
  for each row execute function update_updated_at();

create trigger trg_users_updated_at
  before update on users
  for each row execute function update_updated_at();

create trigger trg_subscriptions_updated_at
  before update on subscriptions
  for each row execute function update_updated_at();

create trigger trg_clients_updated_at
  before update on clients
  for each row execute function update_updated_at();

create trigger trg_projects_updated_at
  before update on projects
  for each row execute function update_updated_at();

create trigger trg_project_months_updated_at
  before update on project_months
  for each row execute function update_updated_at();

create trigger trg_team_members_updated_at
  before update on team_members
  for each row execute function update_updated_at();

create trigger trg_hours_logs_updated_at
  before update on hours_logs
  for each row execute function update_updated_at();

create trigger trg_project_costs_updated_at
  before update on project_costs
  for each row execute function update_updated_at();


-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- Enforces data isolation at the database level (FR-08).
-- Every user can only access data belonging to their organization.
-- =============================================================================

-- Enable RLS on all tables
alter table organizations   enable row level security;
alter table users           enable row level security;
alter table subscriptions   enable row level security;
alter table clients         enable row level security;
alter table projects        enable row level security;
alter table project_months  enable row level security;
alter table team_members    enable row level security;
alter table hours_logs      enable row level security;
alter table project_costs   enable row level security;


-- Helper function: returns the organization_id for the currently logged-in user.
-- Used in all RLS policies below.
create or replace function auth_organization_id()
returns uuid as $$
  select organization_id
  from users
  where id = auth.uid()
$$ language sql security definer stable;


-- ORGANIZATIONS
-- Users can only see and update their own organization.
create policy "users can view own organization"
  on organizations for select
  using (id = auth_organization_id());

create policy "users can update own organization"
  on organizations for update
  using (id = auth_organization_id());


-- USERS
-- Users can view and update members of their own organization.
create policy "users can view own org users"
  on users for select
  using (organization_id = auth_organization_id());

create policy "users can update own profile"
  on users for update
  using (id = auth.uid());


-- SUBSCRIPTIONS
create policy "users can view own subscription"
  on subscriptions for select
  using (organization_id = auth_organization_id());


-- CLIENTS
create policy "users can select own clients"
  on clients for select
  using (organization_id = auth_organization_id());

create policy "users can insert own clients"
  on clients for insert
  with check (organization_id = auth_organization_id());

create policy "users can update own clients"
  on clients for update
  using (organization_id = auth_organization_id());

create policy "users can delete own clients"
  on clients for delete
  using (organization_id = auth_organization_id());


-- PROJECTS
-- Access is derived through the client → organization chain.
create policy "users can select own projects"
  on projects for select
  using (
    client_id in (
      select id from clients where organization_id = auth_organization_id()
    )
  );

create policy "users can insert own projects"
  on projects for insert
  with check (
    client_id in (
      select id from clients where organization_id = auth_organization_id()
    )
  );

create policy "users can update own projects"
  on projects for update
  using (
    client_id in (
      select id from clients where organization_id = auth_organization_id()
    )
  );

create policy "users can delete own projects"
  on projects for delete
  using (
    client_id in (
      select id from clients where organization_id = auth_organization_id()
    )
  );


-- PROJECT MONTHS
create policy "users can select own project months"
  on project_months for select
  using (
    project_id in (
      select p.id from projects p
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );

create policy "users can insert own project months"
  on project_months for insert
  with check (
    project_id in (
      select p.id from projects p
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );

create policy "users can update own project months"
  on project_months for update
  using (
    project_id in (
      select p.id from projects p
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );

create policy "users can delete own project months"
  on project_months for delete
  using (
    project_id in (
      select p.id from projects p
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );


-- TEAM MEMBERS
create policy "users can select own team members"
  on team_members for select
  using (organization_id = auth_organization_id());

create policy "users can insert own team members"
  on team_members for insert
  with check (organization_id = auth_organization_id());

create policy "users can update own team members"
  on team_members for update
  using (organization_id = auth_organization_id());

create policy "users can delete own team members"
  on team_members for delete
  using (organization_id = auth_organization_id());


-- HOURS LOGS
create policy "users can select own hours logs"
  on hours_logs for select
  using (
    project_month_id in (
      select pm.id from project_months pm
      join projects p on p.id = pm.project_id
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );

create policy "users can insert own hours logs"
  on hours_logs for insert
  with check (
    project_month_id in (
      select pm.id from project_months pm
      join projects p on p.id = pm.project_id
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );

create policy "users can update own hours logs"
  on hours_logs for update
  using (
    project_month_id in (
      select pm.id from project_months pm
      join projects p on p.id = pm.project_id
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );

create policy "users can delete own hours logs"
  on hours_logs for delete
  using (
    project_month_id in (
      select pm.id from project_months pm
      join projects p on p.id = pm.project_id
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );


-- PROJECT COSTS
create policy "users can select own project costs"
  on project_costs for select
  using (
    project_month_id in (
      select pm.id from project_months pm
      join projects p on p.id = pm.project_id
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );

create policy "users can insert own project costs"
  on project_costs for insert
  with check (
    project_month_id in (
      select pm.id from project_months pm
      join projects p on p.id = pm.project_id
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );

create policy "users can update own project costs"
  on project_costs for update
  using (
    project_month_id in (
      select pm.id from project_months pm
      join projects p on p.id = pm.project_id
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );

create policy "users can delete own project costs"
  on project_costs for delete
  using (
    project_month_id in (
      select pm.id from project_months pm
      join projects p on p.id = pm.project_id
      join clients c on c.id = p.client_id
      where c.organization_id = auth_organization_id()
    )
  );


-- =============================================================================
-- AUTO-CREATE SUBSCRIPTION ON NEW ORGANIZATION
-- When a new organization is created, automatically insert a free-plan
-- subscription record so there's always a subscription row to check against.
-- =============================================================================

create or replace function create_default_subscription()
returns trigger as $$
begin
  insert into subscriptions (organization_id, plan, status)
  values (new.id, 'free', 'active');
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_create_default_subscription
  after insert on organizations
  for each row execute function create_default_subscription();