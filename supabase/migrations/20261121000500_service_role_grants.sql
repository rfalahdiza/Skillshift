-- Newer Supabase projects no longer grant table privileges to the API roles
-- automatically. Edge Functions use the service_role (bypasses RLS but still
-- needs SQL privileges), so grant it explicitly, now and for future objects.
-- anon/authenticated grants stay as defined in 20261121000300_rls.sql.

grant usage on schema public to service_role;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;
alter default privileges in schema public grant execute on functions to service_role;
