# Stelliform by Dobrak Mandiri

**Stelliform by Dobrak Mandiri** adalah aplikasi Enterprise Resource Planning (ERP) berbasis mobile yang dirancang khusus untuk digitalisasi operasional toko bahan bangunan (retail, rantai pasok, logistik pengiriman, hingga manajemen keuangan toko). 

Aplikasi ini dibangun menggunakan framework **Flutter (Dart)** dengan pendekatan arsitektur **Feature-First Clean Architecture** dan terintegrasi dengan **RESTful API Backend** serta basis data relasional (PostgreSQL / MySQL).

---

## 🌟 Fitur Utama (Berdasarkan Modul & Role RBAC)

Aplikasi ini mendukung **Role-Based Access Control (RBAC)** untuk 5 peran utama pengguna:

### 1. 🛒 Modul Cashier / Point of Sale (POS)
* **Katalog & Pencarian Material:** Pencarian cepat bahan bangunan berdasarkan nama, SKU, kategori, atau scan barcode.
* **Konversi Multi-Satuan (Multi-Unit):** Penanganan fleksibel varian satuan produk toko bangunan (misal: Sak, Meter, Kubik, Biji, Dus, Batang).
* **Mode Transaksi & Opsi Pembayaran:**
  * Metode Pembayaran: *Cash*, *Bank Transfer*, *QRIS*, dan *Tempo/Kredit* (Piutang Usaha dengan tanggal jatuh tempo).
  * Saklar Opsi Pengiriman: Pilihan *Ambil Langsung* vs *Kirim Menggunakan Kurir Toko*.
* **Otomasi Task Logistik:** Opsi *Kirim Menggunakan Kurir Toko* secara otomatis memicu pembuatan tugas pengiriman (*Delivery Task*) ke modul SCM.
* **Cetak Struk:** Pencetakan struk transaksi Bluetooth thermal dan pembuatan struk digital (PDF/WhatsApp).

### 2. 🚚 Modul Supply Chain Management (SCM) & Logistik
* **Penerimaan Barang Masuk (Purchase Receipt):** Pencatatan dan pencocokan stok masuk dari *supplier*.
* **Stok Opname & Adjustment:** Penyesuaian stok berkala serta pencatatan barang rusak/hilang (*wastage*).
* **Manajemen Antrean Pengiriman:** Alokasi driver (kurir), plat nomor armada, dan pengajuan uang jalan operasional.
* **Driver Mobile POD (Proof of Delivery):**
  * Pembaruan status pengiriman secara *real-time* (`Pending` → `In Transit` → `Delivered`).
  * Unggah foto bukti penerimaan barang di lokasi tujuan (*Camera/Gallery Image Picker*).
  * Tanda tangan digital penerima langsung di layar perangkat (*Digital Signature Canvas*).
* **Alert Stok Kritis:** Notifikasi otomatis saat stok bahan bangunan berada di bawah *reorder point threshold*.

### 3. 💰 Modul Finance & Accounting
* **Agregasi Omset Penjualan:** Pencatatan pendapatan bersih otomatis yang bersumber dari transaksi POS.
* **Manajemen Uang Jalan:** Approval pengeluaran uang jalan driver (bensin, tol, retribusi) yang terhubung ke ID Pengiriman SCM.
* **Pencatatan OPEX:** Dokumentasi beban operasional toko (listrik, perawatan armada, sewa, perlengkapan).
* **Penggajian Karyawan (Payroll):** Perhitungan gaji pokok, insentif pengantaran barang, dan potongan kasbon.
* **Laporan Keuangan Ringkas:** Visualisasi Laba Rugi (*Profit & Loss*), Arus Kas (*Cash Flow*), serta Neraca.

### 4. 👑 Modul Owner & Executive Management
* **Executive Dashboard Analytics:** Pemantauan KPI bisnis secara *real-time* (Omset harian/bulanan, laba bersih, barang terlaris, piutang jatuh tempo, dan performa armada kurir).
* **User & Role Management (RBAC):** Pembuatan, pengeditan, dan penonaktifan akun karyawan untuk 5 role.
* **Audit Trail & Activity Logs:** Laporan histori tindakan sensitif karyawan (perubahan harga manual, penyesuaian stok, atau pembatalan transaksi).
* **Master Data Control:** Pengaturan katalog barang, HPP (COGS), margin harga jual, dan hirarki kategori.

---

## 🎨 Tampilan UI & Pengalaman Pengguna (UI/UX)

* **Dual Theme Engine:** Mendukung **Light Mode** (Off-white clean) dan **Dark Mode** (Modern Obsidian & Emerald Dark).
* **Modern Minimalist SaaS UI:** Desain bersih tanpa *nested card* menumpuk, menggunakan garis pembatas tipis (*subtle 1px border*), sudut melengkung halus (`BorderRadius.circular(12)`), dan elevasi datar (*flat elevation*).
* **Responsif & Bebas Overflow:** Tata letak fleksibel yang adaptif di berbagai ukuran layar HP Android dan iOS.

---

## 🏗️ Arsitektur Proyek & Struktur Folder

Aplikasi menggunakan pendekatan **Feature-First Clean Architecture**:

```text
lib/
├── app/
│   ├── config/          # Warna (app_colors.dart), Tema (app_theme.dart), & Routing (routes.dart)
│   └── utils/           # Helper Formatter (Mata Uang Rp, Date Formatter)
├── core/
│   ├── network/         # Dio API Client, API Endpoints, Interceptor (JWT Auth & Error Handler)
│   └── widgets/         # Component UI Reusable (Custom Button, Custom TextField, Loading, Footer)
├── features/
│   ├── auth/            # Login Screen, Splash Screen, Auth Controller & Repository
│   ├── cashier/         # Modul POS (Katalog, Checkout, Struk, Controller & Repository)
│   ├── scm/             # Modul SCM (Stok Opname, Dispatch, Driver POD, Controller & Repository)
│   ├── finance/         # Modul Keuangan (Form Expense, Payroll, Report PnL, Controller & Repository)
│   └── owner/           # Modul Owner (Executive Dashboard, User Management, Controller & Repository)
└── main.dart            # Entry point aplikasi & MultiProvider setup
