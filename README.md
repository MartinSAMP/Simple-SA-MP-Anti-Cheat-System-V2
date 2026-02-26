# SA:MP Anti-Cheat System v2

Sistem anti-cheat sisi server untuk SA:MP yang ditulis dalam Pawn. Versi 2 dengan deteksi yang lebih akurat, *false positive* lebih rendah.

## Fitur Utama

### Deteksi Gerakan
- **Speed Hack** : Deteksi kecepatan berjalan, berlari, dan mengendarai dengan ambang batas adaptif.
- **Teleport Hack** : Deteksi lompatan posisi abnormal dengan validasi interior/*virtual world*.
- **Fly Hack** : Deteksi terbang ilegal dengan perbandingan ketinggian tanah (ColAndreas).
- **Underground Hack** : Deteksi posisi di bawah permukaan tanah yang wajar.
- **Vehicle Speed Hack** : Deteksi kecepatan kendaraan dengan batas berbeda per tipe (darat, udara, sepeda).

### Deteksi *Combat*
- **Rapid Fire** : Deteksi tembakan terlalu cepat menggunakan callback `OnPlayerWeaponShot`.
- **Damage Hack** : Validasi jarak tembakan dan besar *damage* per senjata.
- **Weapon Hack** : Deteksi ID senjata tidak valid dan amunisi melebihi batas tipe senjata.
- **Godmode** : Deteksi regenerasi *health* instan/ilegal.

### Keamanan Kendaraan
- **Seat Hack** : Mencegah teleportasi ke kursi pengemudi yang sudah ditempati.
- **Vehicle Tracking** : Pelacakan pengemudi yang valid per kendaraan.

## Instalasi

### Persyaratan
- Plugin ColAndreas (untuk deteksi tanah yang akurat).
- *Include* sscanf2 (untuk penguraian perintah).

### Langkah Instalasi
1. Simpan skrip sebagai `anticheat.pwn`.
2. Sertakan dalam gamemode Anda:
   ```pawn
   #include <anticheat>
   ```
3. Pastikan plugin ColAndreas terpasang di `server.cfg`:
   ```
   plugins ColAndreas
   ```
4. Sesuaikan konfigurasi di bagian *define*:
   ```pawn
   #define MAX_SPEED_FOOT        25.0    // Kecepatan maksimum berjalan (m/s)
   #define MAX_SPEED_VEHICLE     40.0    // Kecepatan maksimum kendaraan darat
   #define MAX_SPEED_AIR         60.0    // Kecepatan maksimum kendaraan udara
   #define MAX_TP_DIST           40.0    // Jarak teleport maksimum (meter)
   #define MAX_HP                100.0   // Health maksimum normal
   #define MAX_ARMOR             100.0   // Armor maksimum normal
   #define MAX_AMMO              9999    // Batas amunisi global
   #define MAX_FLY_HEIGHT        25.0    // Ketinggian maksimum tanpa jetpack/parasut
   #define UNDERGROUND_Z         -50.0   // Batas bawah koordinat Z
   #define GODMODE_THRESHOLD     5       // Threshold deteksi godmode
   #define RAPID_FIRE_THRESHOLD  150     // Interval tembakan minimum (ms)
   #define DELAY_KICK            300     // Delay sebelum kick (ms)
   #define CHECK_INTERVAL        500     // Interval pemeriksaan (ms)
   #define WARN_RESET_TIME       10000   // Reset peringatan setiap (ms)
   #define MAX_WARNINGS          3       // Jumlah peringatan sebelum kick
   ```

## Cara Kerja

### Sistem Pemeriksaan
- *Timer* berjalan setiap 500 ms per pemain setelah *spawn*.
- Menggunakan struktur data `enum` untuk pelacakan status yang efisien.
- *Auto-reset* peringatan setiap 10 detik untuk mencegah akumulasi *false positive*.
- Perlindungan *spawn* aktif selama 3 detik pertama setelah *spawn*.

### Validasi Kecepatan
- Membandingkan posisi saat ini dengan posisi sebelumnya.
- Menghitung kecepatan riil berdasarkan delta waktu.
- Batas berbeda untuk: jalan, berlari, menunduk, di air, jetpack, kendaraan.
- Pengecualian untuk parasut dan aksi khusus lainnya.

### Validasi *Combat*
- *Callback* `OnPlayerWeaponShot` untuk deteksi *rapid fire*.
- *Callback* `OnPlayerGiveDamage` untuk validasi jumlah *damage*.
- *Callback* `OnPlayerTakeDamage` untuk validasi jarak tembakan.
- Pemindaian slot senjata 0–12 untuk validasi amunisi per tipe senjata.

### Validasi Posisi
- Menggunakan ColAndreas untuk mendapatkan ketinggian tanah yang akurat.
- Deteksi air untuk pengecualian berenang.
- Validasi *interior* dan *virtual world*.
- Pelacakan perubahan status kendaraan.

## Perubahan dari v1

### Peningkatan Deteksi
- **Lebih Akurat** : Integrasi ColAndreas untuk deteksi tanah.
- **Lebih Cepat** : Interval pemeriksaan 500 ms (dari 800 ms).
- **Lebih Aman** : Perlindungan *spawn* dan *auto-reset* peringatan.
- ***Combat Detection*** : Tambahan deteksi *rapid fire* dan validasi *damage*.

### Peningkatan Stabilitas
- Struktur data `enum` untuk menghindari larik terpisah.
- Sistem penundaan *kick* yang lebih kokoh.
- Pemeriksaan status pemain yang lebih komprehensif.
- Penanganan *reconnect* dan *disconnect* yang lebih baik.

### Fitur Baru
- Deteksi kecepatan kendaraan dengan kategori tipe kendaraan.
- Deteksi *godmode* melalui analisis regenerasi *health*.
- Pencegahan *seat hack*.

## Keterbatasan
- Membutuhkan plugin ColAndreas untuk deteksi terbang/tanah yang optimal.
- Tidak mendeteksi kecurangan visual (wallhack, radar hack, *no-recoil* visual).
- Tidak mendeteksi modifikasi *handling* kendaraan di klien.
- Tidak mendeteksi teleport menuju *interior* tanpa perubahan koordinat yang drastis.
- Masih memerlukan validasi sisi server untuk mekanika game kritis (uang, item, dll.).

## Rekomendasi Keamanan Tambahan
Untuk perlindungan maksimal, kombinasikan dengan:
- **Plugin Anti-Cheat** : SAC (Southclaw's Anti-Cheat), DACE, atau CAC.
- **Validasi Server-Side** : Semua transaksi ekonomi, *inventory*, dan statistik.
- **Enkripsi Jaringan** : Plugin Pawn.RakNet untuk validasi paket.
- **Pencatatan (Logging)** : Sistem catatan menyeluruh untuk analisis pasca-insiden.
- **Pembatasan Laju (Rate Limiting)** : Batasi perintah dan aksi per detik per pemain.

## Catatan Penting
- Selalu uji ambang batas pada server spesifik Anda sebelum penggunaan.
- Sesuaikan `MAX_SPEED_*` berdasarkan peta dan mekanik server Anda.
- Pantau catatan secara berkala untuk menyesuaikan sensitivitas.
- *Backup* data pemain secara rutin.
- Pertimbangkan *whitelist* untuk acara khusus yang memerlukan kecepatan tinggi.


*Ini adalah file README.md dalam format Markdown. Silakan disalin dan digunakan.*
```
