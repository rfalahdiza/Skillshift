-- =============================================================================
-- SkillShift seed data. ALL OF THIS IS FAKE TEST DATA.
-- Names follow the Figma designs; NIMs and emails are invented.
-- Every seeded account uses the reserved, undeliverable domain
-- @seed.skillshift.test and has profiles.is_test_data = true.
-- Seeded accounts have NO password here. To sign in with them, set
-- DEMO_PASSWORD in .env and run `dart run tool/gen_demo_seed.dart`, which
-- writes the gitignored supabase/seed.local.sql.
-- Session times are relative to the day you run the seed (Asia/Jakarta).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Courses (Indonesian names, as used at UB)
-- ---------------------------------------------------------------------------
insert into public.courses (id, code, name) values
  ('e0000000-0000-4000-8000-000000000001', 'MAT61001', 'Kalkulus 1'),
  ('e0000000-0000-4000-8000-000000000002', 'CIF61002', 'Pemrograman Dasar'),
  ('e0000000-0000-4000-8000-000000000003', 'CIF61003', 'Matematika Komputasi'),
  ('e0000000-0000-4000-8000-000000000004', 'FIS61001', 'Fisika Dasar'),
  ('e0000000-0000-4000-8000-000000000005', 'CIF62005', 'Struktur Data'),
  ('e0000000-0000-4000-8000-000000000006', 'CIF62006', 'Basis Data');

-- ---------------------------------------------------------------------------
-- Users. The on_auth_user_created trigger creates each profile row.
-- ---------------------------------------------------------------------------
create temporary table seed_people (
  id uuid primary key,
  email text not null,
  full_name text not null,
  role public.user_role not null,
  nim text,
  program text,
  cohort_year smallint,
  bio text,
  teaching_tags text[] default '{}'
);

insert into seed_people values
  -- Admin (verifier)
  ('a0000000-0000-4000-8000-000000000001', 'admin@seed.skillshift.test',
   'Admin SkillShift', 'admin', null, null, null, null, '{}'),

  -- Verified mentors (5)
  ('b0000000-0000-4000-8000-000000000001', 'raka.pratama@seed.skillshift.test',
   'Raka Pratama', 'mentor', '245150500111001', 'Informatika', 2024,
   'Second-year Informatika student. I like breaking calculus problems into small steps and checking each one together. Happy to meet in Gedung F or the library.',
   '{worked_examples,patient,step_by_step,limits,derivatives}'),
  ('b0000000-0000-4000-8000-000000000002', 'salsabila.hanum@seed.skillshift.test',
   'Salsabila Hanum', 'mentor', '235150400111002', 'Sistem Informasi', 2023,
   'I explain the idea first, then we try problems. Calm and patient, good for anyone who feels lost.',
   '{concept_first,patient,visual,databases}'),
  ('b0000000-0000-4000-8000-000000000003', 'dimas.aditya@seed.skillshift.test',
   'Dimas Aditya', 'mentor', '245150300111003', 'Teknik Komputer', 2024,
   'Practice-heavy sessions. We do many exam-style questions (never graded work) until it clicks.',
   '{practice_together,exam_prep,limits,derivatives,physics}'),
  ('b0000000-0000-4000-8000-000000000004', 'aulia.rahma@seed.skillshift.test',
   'Aulia Rahma', 'mentor', '235150200111004', 'Informatika', 2023,
   'Teaching assistant for Pemrograman Dasar. I debug with you line by line.',
   '{worked_examples,coding,debugging,step_by_step}'),
  ('b0000000-0000-4000-8000-000000000005', 'rizky.ramadhan@seed.skillshift.test',
   'Rizky Ramadhan', 'mentor', '225150700111005', 'Teknik Informatika', 2022,
   'Final-year student. Concept maps first, then practice. Fisika and logic are my favourites.',
   '{concept_first,practice_together,visual,physics,logic}'),

  -- Mentor applicants, not verified yet (pending / rejected)
  ('c0000000-0000-4000-8000-000000000001', 'fajar.nugroho@seed.skillshift.test',
   'Fajar Nugroho', 'mentor', '235150201111006', 'Informatika', 2023, null, '{}'),
  ('c0000000-0000-4000-8000-000000000002', 'intan.lestari@seed.skillshift.test',
   'Intan Lestari', 'mentor', '235150401111007', 'Sistem Informasi', 2023, null, '{}'),
  ('c0000000-0000-4000-8000-000000000003', 'bima.saputra@seed.skillshift.test',
   'Bima Saputra', 'mentor', '245150301111008', 'Teknik Komputer', 2024, null, '{}'),
  ('c0000000-0000-4000-8000-000000000004', 'yoga.prasetyo@seed.skillshift.test',
   'Yoga Prasetyo', 'mentor', '235150301111009', 'Teknik Komputer', 2023, null, '{}'),

  -- Learners (15 first-years)
  ('d0000000-0000-4000-8000-000000000001', 'nadia.putri@seed.skillshift.test',
   'Nadia Putri', 'learner', '265150200111010', 'Informatika', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000002', 'farhan.akbar@seed.skillshift.test',
   'Farhan Akbar', 'learner', '265150300111011', 'Teknik Komputer', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000003', 'bagas.wicaksono@seed.skillshift.test',
   'Bagas Wicaksono', 'learner', '265150200111012', 'Informatika', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000004', 'citra.maharani@seed.skillshift.test',
   'Citra Maharani', 'learner', '265150400111013', 'Sistem Informasi', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000005', 'dewi.anggraini@seed.skillshift.test',
   'Dewi Anggraini', 'learner', '265150200111014', 'Informatika', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000006', 'eko.saputro@seed.skillshift.test',
   'Eko Saputro', 'learner', '265150300111015', 'Teknik Komputer', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000007', 'fitri.handayani@seed.skillshift.test',
   'Fitri Handayani', 'learner', '265150400111016', 'Sistem Informasi', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000008', 'gilang.ramadhan@seed.skillshift.test',
   'Gilang Ramadhan', 'learner', '265150200111017', 'Informatika', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000009', 'hana.safira@seed.skillshift.test',
   'Hana Safira', 'learner', '265150700111018', 'Teknik Informatika', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000010', 'indra.kurniawan@seed.skillshift.test',
   'Indra Kurniawan', 'learner', '265150300111019', 'Teknik Komputer', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000011', 'jihan.aulia@seed.skillshift.test',
   'Jihan Aulia', 'learner', '265150400111020', 'Sistem Informasi', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000012', 'kevin.hartono@seed.skillshift.test',
   'Kevin Hartono', 'learner', '265150200111021', 'Informatika', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000013', 'laras.setyowati@seed.skillshift.test',
   'Laras Setyowati', 'learner', '265150700111022', 'Teknik Informatika', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000014', 'muhammad.iqbal@seed.skillshift.test',
   'Muhammad Iqbal', 'learner', '265150300111023', 'Teknik Komputer', 2026, null, '{}'),
  ('d0000000-0000-4000-8000-000000000015', 'nabila.zahra@seed.skillshift.test',
   'Nabila Zahra', 'learner', '265150200111024', 'Informatika', 2026, null, '{}');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000', sp.id, 'authenticated',
  'authenticated', sp.email, '', now(),
  jsonb_build_object('provider', 'email', 'providers', array['email'],
                     'is_test_data', true),
  jsonb_build_object('full_name', sp.full_name),
  now(), now(), '', '', '', ''
from seed_people sp;

insert into auth.identities (
  id, user_id, provider_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
select
  gen_random_uuid(), sp.id, sp.id::text,
  jsonb_build_object('sub', sp.id::text, 'email', sp.email,
                     'email_verified', true),
  'email', now(), now(), now()
from seed_people sp;

update public.profiles p
set role = sp.role,
    nim = sp.nim,
    program = sp.program,
    cohort_year = sp.cohort_year,
    bio = sp.bio,
    teaching_tags = sp.teaching_tags
from seed_people sp
where p.id = sp.id;

-- ---------------------------------------------------------------------------
-- Timetables (ISO day 1 = Monday). Nadia matches the T03 Figma frame.
-- ---------------------------------------------------------------------------
insert into public.timetable_entries
  (user_id, day_of_week, start_time, end_time, course_name, room)
values
  -- Nadia Putri (learner)
  ('d0000000-0000-4000-8000-000000000001', 1, '07:00', '09:30', 'Fisika Dasar', 'Gedung F 3.4'),
  ('d0000000-0000-4000-8000-000000000001', 1, '10:20', '12:00', 'Bahasa Inggris', 'Gedung G 1.2'),
  ('d0000000-0000-4000-8000-000000000001', 1, '13:00', '14:40', 'Pengantar TI', 'Gedung F 2.1'),
  ('d0000000-0000-4000-8000-000000000001', 2, '07:00', '09:30', 'Kalkulus 1', 'Gedung F 2.3'),
  ('d0000000-0000-4000-8000-000000000001', 2, '10:20', '12:00', 'Pemrograman Dasar', 'Gedung G Lab 1'),
  ('d0000000-0000-4000-8000-000000000001', 2, '13:00', '15:30', 'Matematika Komputasi', 'Gedung F 2.5'),
  ('d0000000-0000-4000-8000-000000000001', 3, '08:40', '11:10', 'Pemrograman Dasar (Praktikum)', 'Lab 2'),
  ('d0000000-0000-4000-8000-000000000001', 3, '13:00', '14:40', 'Pendidikan Pancasila', 'Gedung A 1.3'),
  ('d0000000-0000-4000-8000-000000000001', 4, '07:00', '09:30', 'Kalkulus 1', 'Gedung F 2.3'),
  ('d0000000-0000-4000-8000-000000000001', 4, '10:20', '12:50', 'Matematika Komputasi', 'Gedung F 2.5'),
  ('d0000000-0000-4000-8000-000000000001', 5, '07:00', '08:40', 'Bahasa Indonesia', 'Gedung A 2.1'),
  ('d0000000-0000-4000-8000-000000000001', 5, '09:30', '11:10', 'Pengantar TI', 'Gedung F 2.1'),

  -- Raka Pratama: free Tue 12:00-13:00, Thu 09:30-10:20, Fri from 13:00
  ('b0000000-0000-4000-8000-000000000001', 1, '07:00', '12:00', 'Struktur Data', 'Gedung F 4.1'),
  ('b0000000-0000-4000-8000-000000000001', 2, '07:00', '11:50', 'Basis Data', 'Gedung G 2.2'),
  ('b0000000-0000-4000-8000-000000000001', 2, '13:00', '15:30', 'Sistem Operasi', 'Gedung F 3.1'),
  ('b0000000-0000-4000-8000-000000000001', 4, '07:00', '09:30', 'Jaringan Komputer', 'Gedung G 3.3'),
  ('b0000000-0000-4000-8000-000000000001', 4, '10:20', '15:00', 'Rekayasa Perangkat Lunak', 'Gedung F 4.2'),
  ('b0000000-0000-4000-8000-000000000001', 5, '07:00', '12:30', 'Pemrograman Web', 'Gedung G Lab 3'),

  -- Salsabila Hanum: free Thu 09:30-10:20, Tue afternoon
  ('b0000000-0000-4000-8000-000000000002', 1, '08:00', '14:00', 'Analisis Proses Bisnis', 'Gedung E 1.1'),
  ('b0000000-0000-4000-8000-000000000002', 2, '07:00', '12:00', 'Manajemen Basis Data', 'Gedung E 2.3'),
  ('b0000000-0000-4000-8000-000000000002', 3, '07:00', '16:00', 'Kerja Praktik', 'Gedung E 3.2'),
  ('b0000000-0000-4000-8000-000000000002', 4, '07:00', '09:30', 'Sistem Informasi Manajemen', 'Gedung E 1.4'),
  ('b0000000-0000-4000-8000-000000000002', 4, '10:30', '15:00', 'Audit Sistem Informasi', 'Gedung E 2.1'),

  -- Dimas Aditya: free Wed 11:10-12:00, Mon 09:30-10:20
  ('b0000000-0000-4000-8000-000000000003', 1, '07:00', '09:30', 'Elektronika Digital', 'Gedung G Lab 2'),
  ('b0000000-0000-4000-8000-000000000003', 1, '10:20', '15:00', 'Arsitektur Komputer', 'Gedung G 2.4'),
  ('b0000000-0000-4000-8000-000000000003', 2, '07:00', '16:00', 'Praktikum Sistem Tertanam', 'Lab Embedded'),
  ('b0000000-0000-4000-8000-000000000003', 3, '07:00', '11:00', 'Sinyal dan Sistem', 'Gedung G 3.1'),
  ('b0000000-0000-4000-8000-000000000003', 3, '12:00', '16:00', 'Robotika', 'Lab Robotika'),

  -- Aulia Rahma
  ('b0000000-0000-4000-8000-000000000004', 1, '13:00', '16:00', 'Kecerdasan Buatan', 'Gedung F 4.3'),
  ('b0000000-0000-4000-8000-000000000004', 2, '07:00', '10:00', 'Asisten Pemrograman Dasar', 'Gedung G Lab 1'),
  ('b0000000-0000-4000-8000-000000000004', 3, '07:00', '08:40', 'Pembelajaran Mesin', 'Gedung F 3.3'),
  ('b0000000-0000-4000-8000-000000000004', 4, '13:00', '16:00', 'Grafika Komputer', 'Gedung F 2.2'),

  -- Rizky Ramadhan
  ('b0000000-0000-4000-8000-000000000005', 1, '07:00', '10:00', 'Skripsi Bimbingan', 'Ruang Dosen'),
  ('b0000000-0000-4000-8000-000000000005', 3, '13:00', '16:00', 'Etika Profesi', 'Gedung A 2.2'),
  ('b0000000-0000-4000-8000-000000000005', 5, '07:00', '09:00', 'Seminar', 'Gedung F 1.1');

-- Other learners: one of three first-year templates each.
insert into public.timetable_entries
  (user_id, day_of_week, start_time, end_time, course_name, room)
select sp.id, t.day_of_week, t.start_time, t.end_time, t.course_name, t.room
from seed_people sp
join (values
  (0, 1, '07:00'::time, '09:30'::time, 'Kalkulus 1', 'Gedung F 2.3'),
  (0, 2, '10:20', '12:00', 'Pemrograman Dasar', 'Gedung G Lab 1'),
  (0, 3, '07:00', '09:30', 'Fisika Dasar', 'Gedung F 3.4'),
  (0, 4, '13:00', '15:30', 'Matematika Komputasi', 'Gedung F 2.5'),
  (1, 1, '10:20', '12:50', 'Matematika Komputasi', 'Gedung F 2.5'),
  (1, 2, '07:00', '09:30', 'Kalkulus 1', 'Gedung F 2.3'),
  (1, 4, '08:40', '11:10', 'Pemrograman Dasar', 'Gedung G Lab 2'),
  (1, 5, '13:00', '15:30', 'Fisika Dasar', 'Gedung F 3.4'),
  (2, 1, '13:00', '15:30', 'Pemrograman Dasar', 'Gedung G Lab 1'),
  (2, 3, '10:20', '12:50', 'Kalkulus 1', 'Gedung F 2.3'),
  (2, 4, '07:00', '09:30', 'Fisika Dasar', 'Gedung F 3.4'),
  (2, 5, '07:00', '09:30', 'Basis Data', 'Gedung E 2.3')
) as t (template, day_of_week, start_time, end_time, course_name, room)
  on t.template = (right(sp.id::text, 2)::int % 3)
where sp.role = 'learner'
  and sp.id <> 'd0000000-0000-4000-8000-000000000001';

-- ---------------------------------------------------------------------------
-- Learner preferences (ai_tags as the Edge Function would produce them)
-- ---------------------------------------------------------------------------
insert into public.learner_preferences
  (user_id, course_id, learning_style, open_answer, ai_tags)
values
  ('d0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001',
   'worked_examples',
   'I get lost when limits turn into derivatives. Someone patient would help.',
   '{limits,derivatives,patient,step_by_step}'),
  ('d0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000001',
   'practice_together', 'Need practice for the midterm.', '{exam_prep,practice}'),
  ('d0000000-0000-4000-8000-000000000003', 'e0000000-0000-4000-8000-000000000002',
   'worked_examples', 'Loops and arrays confuse me.', '{coding,debugging}');

-- ---------------------------------------------------------------------------
-- Mentor applications and verified courses (prices Rp20.000 to Rp30.000).
-- KHS paths point at files that do not exist; the admin UI labels them SAMPLE.
-- ---------------------------------------------------------------------------
insert into public.mentor_applications
  (id, mentor_id, course_id, khs_path, proof_type, gpa, price_per_hour,
   agreed_no_graded_work, status, reject_reason, reviewed_by, reviewed_at,
   created_at)
values
  -- Approved (become mentor_courses below)
  ('f0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   'e0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001/sample-khs.pdf',
   'grade_a', 3.78, 25000, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '30 days', now() - interval '31 days'),
  ('f0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
   'e0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001/sample-khs.pdf',
   'grade_a', 3.78, 25000, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '30 days', now() - interval '31 days'),
  ('f0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000002',
   'e0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002/sample-khs.pdf',
   'gpa', 3.85, 30000, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '25 days', now() - interval '26 days'),
  ('f0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000002',
   'e0000000-0000-4000-8000-000000000006', 'b0000000-0000-4000-8000-000000000002/sample-khs.pdf',
   'gpa', 3.85, 30000, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '25 days', now() - interval '26 days'),
  ('f0000000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000003',
   'e0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000003/sample-khs.pdf',
   'grade_a', 3.52, 20000, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '20 days', now() - interval '21 days'),
  ('f0000000-0000-4000-8000-000000000006', 'b0000000-0000-4000-8000-000000000003',
   'e0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000003/sample-khs.pdf',
   'grade_a', 3.52, 20000, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '20 days', now() - interval '21 days'),
  ('f0000000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000004',
   'e0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000004/sample-khs.pdf',
   'grade_a', 3.66, 22000, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '15 days', now() - interval '16 days'),
  ('f0000000-0000-4000-8000-000000000008', 'b0000000-0000-4000-8000-000000000004',
   'e0000000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000004/sample-khs.pdf',
   'grade_a', 3.66, 22000, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '15 days', now() - interval '16 days'),
  ('f0000000-0000-4000-8000-000000000009', 'b0000000-0000-4000-8000-000000000005',
   'e0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000005/sample-khs.pdf',
   'gpa', 3.91, 27500, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '10 days', now() - interval '11 days'),
  ('f0000000-0000-4000-8000-000000000010', 'b0000000-0000-4000-8000-000000000005',
   'e0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000005/sample-khs.pdf',
   'gpa', 3.91, 27500, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '10 days', now() - interval '11 days'),
  ('f0000000-0000-4000-8000-000000000011', 'b0000000-0000-4000-8000-000000000005',
   'e0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000005/sample-khs.pdf',
   'gpa', 3.91, 27500, true, 'approved', null,
   'a0000000-0000-4000-8000-000000000001', now() - interval '10 days', now() - interval '11 days'),

  -- Open applications for the admin queue (AD02 / A02)
  ('f0000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000001',
   'e0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000001/sample-khs.pdf',
   'gpa', 3.71, 25000, true, 'pending', null, null, null, now() - interval '1 day'),
  ('f0000000-0000-4000-8000-000000000013', 'c0000000-0000-4000-8000-000000000002',
   'e0000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000002/sample-khs.pdf',
   'grade_a', null, 22000, true, 'pending', null, null, null, now() - interval '1 day'),
  -- GPA below 3.50: the admin UI shows "Needs check"
  ('f0000000-0000-4000-8000-000000000014', 'c0000000-0000-4000-8000-000000000003',
   'e0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000003/sample-khs.pdf',
   'gpa', 3.42, 20000, true, 'pending', null, null, null, now() - interval '2 days'),
  ('f0000000-0000-4000-8000-000000000015', 'c0000000-0000-4000-8000-000000000004',
   'e0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000004/sample-khs.pdf',
   'grade_a', null, 24000, true, 'rejected',
   'The grade column is blurry. Please upload a clearer scan or the PDF from SIAM.',
   'a0000000-0000-4000-8000-000000000001', now() - interval '3 days', now() - interval '4 days');

insert into public.mentor_courses
  (mentor_id, course_id, price_per_hour, verified_at, application_id)
select mentor_id, course_id, price_per_hour, reviewed_at, id
from public.mentor_applications
where status = 'approved';

-- ---------------------------------------------------------------------------
-- Bookings in different states, relative to the current week (WIB).
-- Payments are Midtrans SANDBOX records. Attendance rows fire the release
-- trigger, which marks bookings completed and creates SIMULATED payouts.
-- ---------------------------------------------------------------------------
do $$
declare
  tz constant text := 'Asia/Jakarta';
  this_mon date := date_trunc('week', now() at time zone 'Asia/Jakarta')::date;
  next_mon date := this_mon + 7;
  last_mon date := this_mon - 7;
  nadia constant uuid := 'd0000000-0000-4000-8000-000000000001';
  farhan constant uuid := 'd0000000-0000-4000-8000-000000000002';
  bagas constant uuid := 'd0000000-0000-4000-8000-000000000003';
  citra constant uuid := 'd0000000-0000-4000-8000-000000000004';
  dewi constant uuid := 'd0000000-0000-4000-8000-000000000005';
  raka constant uuid := 'b0000000-0000-4000-8000-000000000001';
  salsa constant uuid := 'b0000000-0000-4000-8000-000000000002';
  dimas constant uuid := 'b0000000-0000-4000-8000-000000000003';
  kalkulus constant uuid := 'e0000000-0000-4000-8000-000000000001';
  b uuid;
begin
  -- 1. Nadia's free trial with Raka, last week, completed (no payment).
  insert into public.bookings
    (learner_id, mentor_id, course_id, starts_at, duration_min, place,
     is_free_trial, status)
  values (nadia, raka, kalkulus, ((last_mon + 3) + time '09:30') at time zone tz,
          30, 'Gedung F, Lt. 2 study area', true, 'accepted')
  returning id into b;
  insert into public.attendance (booking_id, user_id) values (b, nadia), (b, raka);

  -- 2. Nadia + Raka, paid 60 min next Tuesday 12:00, accepted, payment held.
  insert into public.bookings
    (learner_id, mentor_id, course_id, starts_at, duration_min, place,
     is_free_trial, status)
  values (nadia, raka, kalkulus, ((next_mon + 1) + time '12:00') at time zone tz,
          60, 'Gedung F, Lt. 2 study area', false, 'accepted')
  returning id into b;
  insert into public.payments
    (booking_id, gross, platform_fee, mentor_net, midtrans_order_id, method,
     status, paid_at)
  values (b, 25000, 2500, 22500, 'SEED-' || left(b::text, 8), 'qris', 'held', now());

  -- 3. Farhan asks Raka for a free trial next Thursday 09:30 (requested).
  insert into public.bookings
    (learner_id, mentor_id, course_id, starts_at, duration_min, place,
     is_free_trial, status)
  values (farhan, raka, kalkulus, ((next_mon + 3) + time '09:30') at time zone tz,
          30, 'Perpustakaan UB, Lt. 3', true, 'requested');

  -- 4 & 5. Earlier paid sessions with Raka, both confirmed -> released.
  insert into public.bookings
    (learner_id, mentor_id, course_id, starts_at, duration_min, place,
     is_free_trial, status)
  values (bagas, raka, kalkulus, ((last_mon + 4) + time '13:00') at time zone tz,
          60, 'Gedung F, Lt. 2 study area', false, 'accepted')
  returning id into b;
  insert into public.payments
    (booking_id, gross, platform_fee, mentor_net, midtrans_order_id, method,
     status, paid_at)
  values (b, 25000, 2500, 22500, 'SEED-' || left(b::text, 8), 'va', 'held',
          now() - interval '8 days');
  insert into public.attendance (booking_id, user_id) values (b, bagas), (b, raka);

  insert into public.bookings
    (learner_id, mentor_id, course_id, starts_at, duration_min, place,
     is_free_trial, status)
  values (citra, raka, kalkulus, ((last_mon + 2) + time '12:00') at time zone tz,
          60, 'Perpustakaan UB, Lt. 3', false, 'accepted')
  returning id into b;
  insert into public.payments
    (booking_id, gross, platform_fee, mentor_net, midtrans_order_id, method,
     status, paid_at)
  values (b, 25000, 2500, 22500, 'SEED-' || left(b::text, 8), 'qris', 'held',
          now() - interval '10 days');
  insert into public.attendance (booking_id, user_id) values (b, citra), (b, raka);

  -- 6. Declined request (Dewi -> Salsabila).
  insert into public.bookings
    (learner_id, mentor_id, course_id, starts_at, duration_min, place,
     is_free_trial, status)
  values (dewi, salsa, kalkulus, ((next_mon + 3) + time '09:30') at time zone tz,
          30, 'Gedung E, Lt. 1', true, 'declined');

  -- 7. Cancelled paid session, refunded in sandbox (Farhan -> Dimas).
  insert into public.bookings
    (learner_id, mentor_id, course_id, starts_at, duration_min, place,
     is_free_trial, status)
  values (farhan, dimas, kalkulus, ((next_mon + 2) + time '11:10') at time zone tz,
          60, 'Gedung G, Lt. 1', false, 'cancelled')
  returning id into b;
  insert into public.payments
    (booking_id, gross, platform_fee, mentor_net, midtrans_order_id, method,
     status, paid_at)
  values (b, 20000, 2000, 18000, 'SEED-' || left(b::text, 8), 'qris', 'refunded',
          now() - interval '1 day');
end;
$$;

drop table seed_people;
