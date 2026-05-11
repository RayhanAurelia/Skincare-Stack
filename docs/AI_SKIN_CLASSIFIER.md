# Dokumentasi AI Skin Classifier — Skincare Stack

## Daftar Isi
1. [Gambaran Umum](#1-gambaran-umum)
2. [Arsitektur Model](#2-arsitektur-model)
3. [Struktur File](#3-struktur-file)
4. [Cara Melatih Model (Google Colab)](#4-cara-melatih-model-google-colab)
5. [Cara Menggunakan di Flutter](#5-cara-menggunakan-di-flutter)
6. [API Reference — SkinAIService](#6-api-reference--skinaiservice)
7. [API Reference — SkinAnalysisResult](#7-api-reference--skinanalysisresult)
8. [Alur Data (End-to-End)](#8-alur-data-end-to-end)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Gambaran Umum

Skincare Stack mengintegrasikan model **TensorFlow Lite** berbasis **MobileNetV2** untuk menganalisis jenis kulit wajah langsung di perangkat Android (on-device inference). Tidak ada data gambar yang dikirim ke server.

| Aspek | Detail |
|---|---|
| Task | Klasifikasi jenis kulit (3 kelas) |
| Kelas | `dry` (Kering), `normal` (Normal), `oily` (Berminyak) |
| Input gambar | 224 × 224 piksel, RGB |
| Output | Probabilitas softmax untuk tiap kelas |
| Framework | TensorFlow Lite via `tflite_flutter: 0.10.1` |
| Quantization | Float16 (ukuran model lebih kecil, akurasi terjaga) |

---

## 2. Arsitektur Model

```
Input: [1, 224, 224, 3]
   ↓
MobileNetV2 (pre-trained ImageNet, weights frozen di Phase 1)
   ↓
GlobalAveragePooling2D
   ↓
BatchNormalization
   ↓
Dense(256, relu) → Dropout(0.4)
   ↓
Dense(128, relu) → Dropout(0.3)
   ↓
Dense(3, softmax)   ← output 3 probabilitas
   ↓
Output: [1, 3]  →  [dry_prob, normal_prob, oily_prob]
```

### Proses Training

| Fase | Epoch | Learning Rate | Yang Dilatih |
|---|---|---|---|
| Phase 1 | 20 | `1e-3` | Custom head saja (base frozen) |
| Phase 2 | 15 | `1e-5` | Top 100+ layer MobileNetV2 + head |

### Augmentasi Data

- Rotasi ±25°
- Shift horizontal & vertikal ±10%
- Horizontal flip
- Zoom ±20%
- Shear ±10%
- Brightness 0.8–1.2×

---

## 3. Struktur File

```
skincare_stack/
├── assets/
│   └── models/
│       ├── skin_classifier.tflite   ← model TFLite (dihasilkan dari Colab)
│       └── skin_labels.txt          ← label kelas (dry, normal, oily)
├── model/
│   └── train_skin_model.ipynb       ← notebook training (Google Colab)
├── lib/
│   ├── services/
│   │   └── skin_ai_service.dart     ← service utama AI
│   └── pages/home/
│       ├── skin_journal_page.dart        ← trigger analisis
│       └── skin_analysis_result_page.dart ← tampilkan hasil
└── docs/
    └── AI_SKIN_CLASSIFIER.md        ← file ini
```

### Isi `skin_labels.txt`

```
dry
normal
oily
```

Urutan baris harus sesuai dengan urutan output neuron model.

---

## 4. Cara Melatih Model (Google Colab)

### Langkah-langkah

**1. Buka notebook**
Buka file `model/train_skin_model.ipynb` di Google Colab.

**2. Siapkan dataset**
Dataset yang digunakan: [Oily-Dry-Normal Skin Types — Kaggle](https://www.kaggle.com/datasets/shakyadissanayake/oily-dry-and-normal-skin-types-dataset)

Upload ke Google Drive atau langsung ke Colab dengan Kaggle API:
```python
# Di Colab
!pip install kaggle
!kaggle datasets download -d shakyadissanayake/oily-dry-and-normal-skin-types-dataset
!unzip oily-dry-and-normal-skin-types-dataset.zip -d /content/dataset
```

**3. Jalankan semua cell secara berurutan**
- Cell 1–3: Install dependencies, import library
- Cell 4–5: Load dan augmentasi dataset
- Cell 6–7: Definisi model, Phase 1 training
- Cell 8: Phase 2 fine-tuning
- Cell 9: Konversi ke TFLite (float16)
- Cell 10: Download file hasil

**4. Salin file hasil ke project**
Setelah training selesai, download dua file dan letakkan di:
```
skincare_stack/assets/models/skin_classifier.tflite
skincare_stack/assets/models/skin_labels.txt
```

---

## 5. Cara Menggunakan di Flutter

### Inisialisasi (opsional, otomatis)

`SkinAIService` akan otomatis inisialisasi saat pertama kali `analyze()` dipanggil. Tapi bisa juga dipanggil lebih awal, misalnya di `main.dart`, agar tidak ada jeda saat user pertama kali analisis:

```dart
// di main.dart atau initState halaman awal
await SkinAIService().initialize();
```

### Analisis gambar

```dart
import 'dart:io';
import 'package:skincare_stack/services/skin_ai_service.dart';

Future<void> analyzeImage(File imageFile) async {
  try {
    final result = await SkinAIService().analyze(imageFile);

    print('Jenis Kulit : ${result.displayName}');
    print('Confidence  : ${(result.confidence * 100).toStringAsFixed(1)}%');
    print('Probabilitas: ${result.probabilities}');
    // { dry: 0.05, normal: 0.12, oily: 0.83 }
  } catch (e) {
    print('Error analisis: $e');
  }
}
```

### Mengambil gambar lalu analisis (pola di app ini)

```dart
// Dari skin_journal_page.dart
Future<void> _analyzeWithAI(File imageFile) async {
  // 1. Tampilkan loading
  showDialog(context: context, builder: (_) => const LoadingDialog());

  // 2. Jalankan inferensi
  final result = await SkinAIService().analyze(imageFile);

  // 3. Tutup loading
  Navigator.of(context).pop();

  // 4. Navigasi ke halaman hasil
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => SkinAnalysisResultPage(
      result: result,
      imageFile: imageFile,
    ),
  ));
}
```

### Cek apakah model tersedia

```dart
if (SkinAIService().isModelAvailable) {
  // Model sudah siap, bisa langsung analisis
}
```

### Melepas resource (lifecycle)

```dart
@override
void dispose() {
  SkinAIService().dispose();
  super.dispose();
}
```

---

## 6. API Reference — SkinAIService

File: `lib/services/skin_ai_service.dart`

`SkinAIService` menggunakan pola **singleton** — satu instance dipakai di seluruh app.

### Constructor

```dart
SkinAIService()   // selalu mengembalikan instance yang sama
```

### Properties

| Property | Tipe | Keterangan |
|---|---|---|
| `isModelAvailable` | `bool` | `true` jika model sudah ter-load dan siap digunakan |

### Methods

#### `initialize()` → `Future<void>`

Memuat model TFLite dan file label dari assets. Dipanggil otomatis oleh `analyze()`. Aman dipanggil berkali-kali (idempotent).

```dart
await SkinAIService().initialize();
```

#### `analyze(File imageFile)` → `Future<SkinAnalysisResult>`

Pipeline lengkap: baca gambar → resize → normalisasi → inferensi → kembalikan hasil.

| Parameter | Tipe | Keterangan |
|---|---|---|
| `imageFile` | `File` | File gambar (JPG/PNG) dari kamera atau galeri |

Throws `Exception` jika gambar tidak dapat dibaca.

```dart
final result = await SkinAIService().analyze(imageFile);
```

#### `dispose()` → `void`

Menutup interpreter TFLite dan mereset state. Panggil saat widget utama di-dispose.

```dart
SkinAIService().dispose();
```

---

## 7. API Reference — SkinAnalysisResult

File: `lib/services/skin_ai_service.dart`

Object yang dikembalikan oleh `SkinAIService.analyze()`.

### Constructor

```dart
const SkinAnalysisResult({
  required String skinType,
  required double confidence,
  required Map<String, double> probabilities,
})
```

### Fields

| Field | Tipe | Contoh nilai |
|---|---|---|
| `skinType` | `String` | `'oily'`, `'dry'`, `'normal'` |
| `confidence` | `double` | `0.83` (83% yakin) |
| `probabilities` | `Map<String, double>` | `{'dry': 0.05, 'normal': 0.12, 'oily': 0.83}` |

### Computed Properties

| Property | Tipe | Keterangan | Contoh |
|---|---|---|---|
| `displayName` | `String` | Nama bahasa Indonesia | `'Kulit Berminyak'` |
| `emoji` | `String` | Ikon representasi | `'💧'` |
| `description` | `String` | Deskripsi kondisi kulit | `'Kulit kamu cenderung...'` |
| `recommendations` | `List<String>` | Daftar saran skincare (5 item) | `['Gunakan foaming cleanser...', ...]` |

---

## 8. Alur Data (End-to-End)

```
[User tap "Analisis AI"]
        ↓
[skin_journal_page.dart]
  _analyzeWithAI(File imageFile)
        ↓
[skin_ai_service.dart]
  SkinAIService().analyze(imageFile)
        ↓
  1. Baca bytes dari file
  2. Decode image (package:image)
  3. Resize → 224×224
  4. Normalisasi piksel /255.0
  5. Build tensor [1, 224, 224, 3]
  6. _interpreter.run(input, output)
  7. Baca output [1, 3] → probabilitas
  8. Cari index max → skinType
  9. Return SkinAnalysisResult
        ↓
[skin_analysis_result_page.dart]
  Tampilkan: jenis kulit, confidence,
  bar probabilitas, deskripsi, rekomendasi
```

---

## 9. Troubleshooting

### Model tidak ditemukan saat build

**Gejala:** `Unable to load asset: assets/models/skin_classifier.tflite`

**Solusi:** Pastikan file `.tflite` sudah ada dan `pubspec.yaml` sudah mendaftarkan foldernya:
```yaml
flutter:
  assets:
    - assets/models/
```

---

### Build error: `Namespace not specified` (tflite_flutter)

**Gejala:**
```
Namespace not specified ... tflite_flutter-0.10.1\android\build.gradle
```

**Solusi:** Tambahkan `namespace` ke build.gradle package di pub cache:
```
C:\Users\<nama>\AppData\Local\Pub\Cache\hosted\pub.dev\tflite_flutter-0.10.1\android\build.gradle
```
Tambahkan di dalam blok `android { }`:
```gradle
namespace 'org.tensorflow.tflite_flutter'
```

---

### Build error: `UnmodifiableUint8ListView` tidak ditemukan

**Gejala:**
```
Error: The method 'UnmodifiableUint8ListView' isn't defined for the type 'Tensor'.
```

**Penyebab:** `UnmodifiableUint8ListView` dihapus di Dart 3.x.

**Solusi:** Edit file di pub cache:
```
...\tflite_flutter-0.10.1\lib\src\tensor.dart  (baris 57)
```
Ganti:
```dart
return UnmodifiableUint8ListView(
    data.asTypedList(tfliteBinding.TfLiteTensorByteSize(_tensor)));
```
Dengan:
```dart
return data.asTypedList(tfliteBinding.TfLiteTensorByteSize(_tensor));
```

---

### Gradle crash saat build

**Gejala:** `Gradle build daemon disappeared unexpectedly` / Out of Memory

**Solusi:** Kurangi heap Gradle di `android/gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=512m
```

---

### Hasil analisis tidak akurat

**Kemungkinan penyebab:**
- Pencahayaan gambar kurang (terlalu gelap/terang)
- Sudut foto bukan frontal wajah
- Model belum di-fine-tune dengan data yang cukup representatif

**Saran:**
- Ambil foto wajah dengan cahaya yang merata
- Pastikan seluruh wajah terlihat jelas dalam frame
- Latih ulang model dengan data yang lebih beragam
