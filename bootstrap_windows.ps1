$ErrorActionPreference = "Stop"

Write-Host "Checking Flutter..."
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter SDK not found. Install Flutter and Android Studio, then reopen PowerShell."
}

Write-Host "Generating Android and iOS platform folders..."
flutter create --platforms=android,ios .

Write-Host "Downloading Tajik OCR model..."
New-Item -ItemType Directory -Force -Path "assets/tessdata" | Out-Null
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/tgk.traineddata" `
  -OutFile "assets/tessdata/tgk.traineddata"

Write-Host "Getting Flutter packages..."
flutter pub get

Write-Host "Building Android APK..."
flutter build apk --release

Write-Host "Done. APK: build/app/outputs/flutter-apk/app-release.apk"
