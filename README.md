# ULT Queue FKIP Universitas Lampung (Android APK)

Aplikasi Antrean Pelayanan Administrasi Unit Layanan Terpadu (ULT) Fakultas Keguruan dan Ilmu Pendidikan, Universitas Lampung berbasis Flutter dan Supabase.

---

## 🌟 Fitur Utama

### 1. Sisi Mahasiswa (Tanpa Perlu Login)
- **Splash Screen**: Identitas dan logo ULT FKIP Unila.
- **Beranda Informatif**: Status jam operasional (Senin–Jumat, 08:00–15:00 WIB), sapaan ramah, dan tombol aksi cepat.
- **Pengambilan Tiket Antrean**:
  - Pilihan 4 kategori layanan:
    - **A**: Pengurusan Berkas KKN
    - **B**: Pengajuan Berkas Wisuda
    - **C**: Pengurusan Surat Administrasi
    - **D**: Layanan Administrasi Lainnya
  - Form data diri: Nama Lengkap, NPM, dan Program Studi.
  - Validasi tiket aktif harian per NPM (mencegah duplikasi).
- **Pemantauan Antrean Realtime**:
  - Live nomor antrean aktif di tiap loket via Supabase Websocket.
  - Jumlah antrean yang menunggu di depan mahasiswa.
  - Indikator status: *Menunggu*, *Dipanggil*, *Sedang Dilayani*, *Selesai*.
  - Notifikasi suara **Text-to-Speech (TTS)** & getar otomatis saat nomor mahasiswa dipanggil menuju loket tertentu.

### 2. Sisi Petugas ULT FKIP
- **Login Petugas**: Menggunakan email dan password terautentikasi di Supabase Auth.
- **Dashboard Petugas**:
  - Pemilihan loket dinas (Loket 1, Loket 2, Loket 3).
  - Filter antrean berdasarkan jenis layanan.
  - Panggilan antrean berikutnya secara sekuensial.
  - Pembaruan status dinamis: *Dipanggil* ➔ *Sedang Dilayani* ➔ *Selesai* atau *Dilewati (No-show)*.

---

## 🛠️ Teknologi & Arsitektur

- **Frontend**: Flutter (Dart)
- **Backend / Database**: Supabase (PostgreSQL 15+)
- **Security**: PostgreSQL Row Level Security (RLS)
- **State & Realtime**: Supabase Realtime Channels (`postgres_changes`)
- **Penyimpanan Lokal**: `shared_preferences`
- **Audio & TTS**: `flutter_tts`, `audioplayers`, `vibration`
- **CI/CD**: GitHub Actions (`build-apk.yml`)

---

## ⚙️ Konfigurasi Supabase

1. Buka dashboard proyek Supabase Anda.
2. Masuk ke **SQL Editor** dan jalankan seluruh isi berkas [`database_schema.sql`](database_schema.sql).
3. Pastikan tabel `queues` sudah masuk dalam `supabase_realtime` publication.
4. Buat akun petugas di menu **Authentication > Users**, lalu daftarkan UID-nya ke tabel `profiles`:
   ```sql
   INSERT INTO public.profiles (id, full_name, role)
   VALUES ('USER_UID_DARI_AUTH', 'Nama Petugas ULT', 'staff');
   ```

---

## 🚀 Menjalankan Aplikasi Secara Lokal

```bash
# 1. Unduh dependensi
flutter pub get

# 2. Jalankan di emulator atau perangkat fisik Android
flutter run
```

Untuk menyuntikkan kredensial custom melalui `--dart-define`:
```bash
flutter run \
  --dart-define=SUPABASE_URL="https://xtrluwtwqkjretavurzc.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="sb_publishable_Osjrt36ieg9VRSaMJp1AIA_GJq3YTMz"
```

---

## 📦 Build APK Release

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL="https://xtrluwtwqkjretavurzc.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="sb_publishable_Osjrt36ieg9VRSaMJp1AIA_GJq3YTMz"
```
Hasil file APK akan berada di: `build/app/outputs/flutter-apk/app-release.apk`.
