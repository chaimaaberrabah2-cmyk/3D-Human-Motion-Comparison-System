# 🚀 Running Motion AI Home Page

## ✅ Home Page UI Complete!

The home page has been created with:
- ✅ Responsive design (Desktop, Tablet, Mobile)
- ✅ Dark theme with exact colors
- ✅ Sidebar navigation
- ✅ Search & filter functionality
- ✅ Exercise grid with cards
- ✅ Mock data (6 exercises)

---

## 📱 How to Run on Different Platforms

### Prerequisites
Make sure Flutter is installed:
```bash
flutter doctor
```

### 1️⃣ Desktop (macOS)
```bash
cd frontend
flutter run -d macos
```

### 2️⃣ Web (Chrome)
```bash
cd frontend
flutter run -d chrome
```

### 3️⃣ Mobile (iOS Simulator)
```bash
cd frontend
flutter run -d ios
```

### 4️⃣ Mobile (Android Emulator)
```bash
cd frontend
flutter run -d android
```

---

## 🎨 Current Features

### Responsive Breakpoints
- **Desktop** (>1200px): Sidebar + 3 column grid
- **Tablet** (600-1200px): Sidebar collapse + 2 column grid  
- **Mobile** (<600px): Drawer + 1 column grid

### Functional Features
- ✅ Search exercises by name
- ✅ Filter by category (All, Strength, Mobility, BodyWeight, Rehab)
- ✅ Click play button (shows snackbar for now)
- ✅ Start New Analysis button (shows snackbar for now)

---

## 📸 Adding Exercise Images (Optional)

If you want to replace the placeholder icons with real images:

1. Add images to `frontend/assets/exercises/`:
   - `squat.png`
   - `pushup.png`
   - `lateral_raise.png`
   - `curl.png`
   - `stretch.png`
   - `shoulder_press.png`

2. Images will automatically load (placeholders show if images not found)

---

## 🎯 What's Next?

After visualizing on all platforms, we can:
1. Add more exercises
2. Create exercise detail page
3. Implement authentication
4. Connect to backend API
5. Add SMPL-X 3D visualization

---

## 🐛 Troubleshooting

### If Flutter is not installed:
```bash
brew install --cask flutter
flutter doctor
```

### If you see errors:
```bash
cd frontend
flutter clean
flutter pub get
flutter run -d [platform]
```

### Check available devices:
```bash
flutter devices
```
