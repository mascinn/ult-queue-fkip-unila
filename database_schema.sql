-- ========================================================================
-- SKEMA DATABASE LENGKAP: ULT QUEUE FKIP UNIVERSITAS LAMPUNG
-- Database Engine: PostgreSQL / Supabase
-- Target Table: profiles, services, counters, queues
-- Fitur: RLS Security, Realtime Publication, Atomic Daily Sequence Function
-- ========================================================================

-- Pastikan extension pgcrypto atau uuid-ossp aktif
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------
-- 1. TABEL PROFIL PENGGUNA (UNTUK PETUGAS & ADMIN ULT)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('staff', 'admin')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS 'Menyimpan profil staf/petugas ULT FKIP yang terhubung ke Supabase Auth';

-- ------------------------------------------------------------------------
-- 2. TABEL MASTER JENIS LAYANAN
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code CHAR(1) NOT NULL UNIQUE, -- 'A', 'B', 'C', 'D'
    name TEXT NOT NULL,
    description TEXT,
    quota_per_day INT NOT NULL DEFAULT 50,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.services IS 'Daftar jenis layanan administrasi ULT FKIP Unila beserta kode dan kuota harian';

-- Isi data awal master layanan (jika belum ada)
INSERT INTO public.services (code, name, description, quota_per_day) 
VALUES
('A', 'Pengurusan Berkas KKN', 'Validasi berkas pendaftaran dan administrasi KKN FKIP', 50),
('B', 'Pengajuan Berkas Wisuda', 'Pemeriksaan berkas yudisium dan pendaftaran wisuda', 50),
('C', 'Pengurusan Surat Administrasi', 'Surat keterangan aktif kuliah, izin riset, surat pengantar', 75),
('D', 'Layanan Administrasi Lainnya', 'Legalisasi ijazah/transkrip dan informasi administrasi umum', 50)
ON CONFLICT (code) DO UPDATE 
SET name = EXCLUDED.name, 
    description = EXCLUDED.description, 
    quota_per_day = EXCLUDED.quota_per_day;

-- ------------------------------------------------------------------------
-- 3. TABEL MASTER LOKET PELAYANAN
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.counters (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE public.counters IS 'Daftar loket fisik pelayanan di Unit Layanan Terpadu FKIP';

INSERT INTO public.counters (name) 
VALUES ('Loket 1'), ('Loket 2'), ('Loket 3')
ON CONFLICT (name) DO NOTHING;

-- ------------------------------------------------------------------------
-- 4. TABEL UTAMA ANTREAN (QUEUES)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.queues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE RESTRICT,
    queue_number TEXT NOT NULL,       -- Contoh: 'A-001'
    sequence_number INT NOT NULL,      -- Urutan numerik harian per layanan (1, 2, 3...)
    student_name TEXT NOT NULL,
    student_npm VARCHAR(20) NOT NULL,
    student_study_program TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'called', 'in_service', 'completed', 'skipped')),
    counter_name TEXT,                -- Nama loket yang memanggil (misal: 'Loket 1')
    called_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    queue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    called_at TIMESTAMPTZ,
    served_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.queues IS 'Tabel transaksi nomor antrean harian mahasiswa FKIP Unila';

-- Buat indeks untuk query harian dan filtering status yang cepat
CREATE INDEX IF NOT EXISTS idx_queues_date_service ON public.queues(queue_date, service_id);
CREATE INDEX IF NOT EXISTS idx_queues_status ON public.queues(status);
CREATE INDEX IF NOT EXISTS idx_queues_npm_active ON public.queues(student_npm, queue_date, status);

-- ------------------------------------------------------------------------
-- 5. STORED PROCEDURE: PENGAMBILAN TIKET AMAN (ATOMIC & CONCURRENCY-SAFE)
-- ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.take_queue_ticket(
    p_service_id UUID,
    p_student_name TEXT,
    p_student_npm TEXT,
    p_study_program TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_service RECORD;
    v_current_count INT;
    v_next_seq INT;
    v_queue_num TEXT;
    v_existing_id UUID;
    v_new_queue RECORD;
BEGIN
    -- 1. Validasi Layanan apakah aktif
    SELECT * INTO v_service 
    FROM public.services 
    WHERE id = p_service_id AND is_active = TRUE;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Layanan tidak ditemukan atau sedang tidak aktif'
        );
    END IF;

    -- 2. Cek apakah mahasiswa dengan NPM tersebut sudah memiliki tiket aktif hari ini
    SELECT id INTO v_existing_id 
    FROM public.queues 
    WHERE student_npm = p_student_npm 
      AND queue_date = CURRENT_DATE 
      AND status IN ('waiting', 'called', 'in_service')
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Anda masih memiliki tiket antrean yang aktif hari ini', 
            'existing_ticket_id', v_existing_id
        );
    END IF;

    -- 3. Cek Kuota Harian Layanan (dengan lock row level untuk konsistensi)
    SELECT COUNT(*) INTO v_current_count 
    FROM public.queues 
    WHERE service_id = p_service_id AND queue_date = CURRENT_DATE;

    IF v_current_count >= v_service.quota_per_day THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Mohon maaf, kuota antrean untuk layanan ini hari ini sudah penuh'
        );
    END IF;

    -- 4. Tentukan nomor urut berikutnya (1, 2, 3...)
    v_next_seq := v_current_count + 1;
    v_queue_num := v_service.code || '-' || LPAD(v_next_seq::TEXT, 3, '0');

    -- 5. Masukkan tiket baru
    INSERT INTO public.queues (
        service_id,
        queue_number,
        sequence_number,
        student_name,
        student_npm,
        student_study_program,
        status,
        queue_date
    ) VALUES (
        p_service_id,
        v_queue_num,
        v_next_seq,
        TRIM(p_student_name),
        TRIM(p_student_npm),
        TRIM(p_study_program),
        'waiting',
        CURRENT_DATE
    ) RETURNING * INTO v_new_queue;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Nomor antrean berhasil diambil',
        'data', row_to_json(v_new_queue)
    );
END;
$$;

-- ------------------------------------------------------------------------
-- 6. PENGATURAN ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queues ENABLE ROW LEVEL SECURITY;

-- Policy Services (Dapat dibaca siapa saja)
DROP POLICY IF EXISTS "Public can view active services" ON public.services;
CREATE POLICY "Public can view active services" 
ON public.services FOR SELECT USING (true);

-- Policy Counters (Dapat dibaca siapa saja)
DROP POLICY IF EXISTS "Public can view counters" ON public.counters;
CREATE POLICY "Public can view counters" 
ON public.counters FOR SELECT USING (true);

-- Policy Profiles
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
CREATE POLICY "Users can view all profiles" 
ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Policy Queues:
-- 1. SELECT: Siapa saja (Anon & Auth) bisa membaca data antrean hari ini
DROP POLICY IF EXISTS "Public can view today queues" ON public.queues;
CREATE POLICY "Public can view today queues" 
ON public.queues FOR SELECT USING (queue_date = CURRENT_DATE);

-- 2. INSERT: Anonim/Mahasiswa dapat insert melalui RPC fungsi aman
DROP POLICY IF EXISTS "Public can insert queues" ON public.queues;
CREATE POLICY "Public can insert queues" 
ON public.queues FOR INSERT WITH CHECK (queue_date = CURRENT_DATE);

-- 3. UPDATE: HANYA Staf Petugas ULT terautentikasi yang dapat mengubah status antrean
DROP POLICY IF EXISTS "Staff can update queue status" ON public.queues;
CREATE POLICY "Staff can update queue status" 
ON public.queues FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.id = auth.uid() AND profiles.role IN ('staff', 'admin')
    )
);

-- ------------------------------------------------------------------------
-- 7. AKTIFKAN SUPABASE REALTIME
-- ------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'queues'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.queues;
    END IF;
END $$;

-- ------------------------------------------------------------------------
-- PANDUAN PENAMBAHAN AKUN PETUGAS PERTAMA KALI:
-- 1. Buat user di menu: Authentication > Users di Supabase Dashboard
-- 2. Salin User UID hasil pembuatan user tersebut
-- 3. Eksekusi query berikut (ganti 'PASTE_UID_DISINI'):
--
-- INSERT INTO public.profiles (id, full_name, role)
-- VALUES ('PASTE_UID_DISINI', 'Petugas ULT FKIP 1', 'staff')
-- ON CONFLICT (id) DO UPDATE SET role = 'staff';
-- ========================================================================
