-- Private bucket for KHS (study result card) uploads.
-- Files live at khs/<user_id>/<file>. Readable only by the owner and admins.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'khs', 'khs', false, 5242880,
  array['application/pdf', 'image/png', 'image/jpeg']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "khs owner upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'khs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "khs owner or admin read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'khs'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or public.is_admin()
    )
  );

create policy "khs owner delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'khs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
