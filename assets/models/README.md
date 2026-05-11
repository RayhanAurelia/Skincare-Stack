# AI Model Files

Place the following files here after running the Colab training notebook:

- `skin_classifier.tflite` — trained MobileNetV2 model (download from Colab)
- `skin_labels.txt` — class labels (already provided, or download from Colab)

## How to get the model:
1. Open `model/train_skin_model.ipynb` in Google Colab
2. Run all cells from top to bottom
3. Download `skin_classifier.tflite` from the last cell
4. Copy it to this folder (`assets/models/`)
5. Run `flutter pub get` then `flutter run`
