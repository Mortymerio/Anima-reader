# 🌑 Anima Reader

> **The ultra-minimalist, distraction-free book reader designed for E-ink screens and ultimate reading comfort.**

Anima is a lightweight electronic book reader built for people who value pure reading utility. It treats your own **GitHub Private Repository** as a free, secure, and self-hosted cloud to store your library and synchronize your reading progress across all your devices—completely offline-first, private, and telemetry-free.

---

## 📸 App Preview

![Anima Reader interface](assets/screenshots/app_preview.png)
*(Minimalist library setup, books list, and fluid reading experience)*

---

## ⚡ Core Philosophy: Pure Focus & Comfort

Anima strips away the bloat of modern reading applications. No recommendations, no social feeds, no tracking, and no flashing UI animations. Just your books, rendered with maximum contrast, optimized for paper-like screens.

*   **Absolute Minimalism**: A pristine, layout-first interface that gets out of your way the moment you open a book.
*   **Maximum Screen Utility**: Adjust or completely remove margins to occupy 100% of the screen.
*   **E-ink Native**: Zero transition animations, no slide scrolling, and a built-in anti-ghosting double-flash refresh.
*   **Private Cloud Sync**: All your progress is stored in a simple `sync.json` file in your repository. You own your data.

---

## ✨ Features

*   📖 **Smart Reflow & Multi-format**:
    *   **EPUB**: Fluid typography, native chapter-by-chapter rendering, and inline images.
    *   **PDF (Reflow Mode)**: Instant text extraction with dynamic word wrapping and font scaling.
    *   **PDF (Page-Image Mode)**: Fallback image renderer with **intelligent automatic margin-cropping** that crops document borders to maximize readability.
*   📐 **Real-time Margin Controls**: Change the layout density on the fly. Choose between **None (0px)**, **Small (8px)**, **Medium (16px)**, or **Large (24px)** horizontal padding.
*   ☀️ **Eye-Care Themes**:
    *   `Normal`: High-contrast black and white for E-ink screens.
    *   `Dark`: Soft dark mode to prevent night-reading eye strain.
    *   `Warm`: Solarized sepia tones mimicking book paper, perfect for LCD/desktop reading.
*   🔄 **Anti-Ghosting Refresh**: Automatically flashes the screen every N page turns (configurable) to clear E-ink residue.
*   🌐 **Offline-First Cache**: Downloads your books once from your GitHub repository and caches them locally for uninterrupted offline reading.
*   🔍 **Discrete Font Controls**: Real-time font size adjustments using discrete click targets instead of slide bars.

---

## 🚀 Setting Up Your Private Library (Step by Step)

To use Anima, you just need a free GitHub account to act as your cloud server.

### Step 1: Create Your Private Book Repository
1. Log in to [GitHub](https://github.com).
2. Create a new repository (e.g., `my-books`).
3. Set the visibility to **Private** to comply with book copyright.
4. **Important**: Check **Add a README file** (this initializes the repository structure so the app can read it).

### Step 2: Generate a Personal Access Token (PAT)
1. Go to your GitHub **Settings** → **Developer Settings** → **Personal Access Tokens** → **Tokens (classic)**.
2. Click **Generate new token (classic)**.
3. Check only the **`repo`** scope.
4. Click generate, and **copy the token** immediately (GitHub will only show it once).

### Step 3: Upload Your Files
1. Go to your book repository on GitHub.
2. Click **Add file** → **Upload files**.
3. Drag and drop your `.epub` and `.pdf` files directly into the **root** of the repository (do not place them inside folders).
4. Click **Commit changes**.

### Step 4: Connect Anima
Launch Anima and input:
- **GitHub PAT**: The token from Step 2.
- **Username**: Your GitHub username.
- **Repository Name**: The exact name of your book repository.

Press **Connect Library** and you're ready to read!

---

## 🛠️ Local Development

Ensure you have the Flutter SDK installed.

```powershell
# Clone the repository
git clone https://github.com/Mortymerio/Anima-reader.git
cd Anima-reader

# Get dependencies
flutter pub get

# Run on Windows Desktop
flutter run -d windows

# Build Android APK (optimized for E-ink devices)
flutter build apk --release
```

---

## 📖 Project Architecture

```
lib/
├── main.dart                      # App entry and theme controller
├── constants/
│   └── strings.dart               # Centralized UI copy & localized text
├── models/
│   ├── book.dart                  # Book representation model
│   ├── reading_progress.dart      # Reading progress data model
│   └── app_exception.dart         # Custom user-friendly error handler
├── services/
│   ├── github_service.dart        # GitHub API repository sync & files loader
│   ├── book_parser.dart           # PDF/EPUB parsing, rendering, and auto-cropping
│   ├── book_cache_service.dart    # Offline files caching
│   ├── epub_sanitizer.dart        # Sanitizes EPUB content encoding errors
│   └── sync_service.dart          # Synchronization and cloud-saving manager
└── ui/
    ├── theme.dart                 # High-contrast & Warm eye-care design system
    ├── screens/
    │   ├── home_screen.dart       # Credentials login form & library list
    │   ├── reader_screen.dart     # Minimalist reader view (controls, font, margins)
    │   └── settings_screen.dart   # Default preferences & refresh cycles
    └── widgets/
        ├── eink_flash.dart        # Double-black E-ink screen refresher
        ├── empty_library.dart     # Empty state widget
        ├── loading_indicator.dart # E-ink safe text loading indicator
        └── reading_progress_bar.dart # Kindle-style bottom progress line
```

---
*Created with focus and simplicity for the reading community.*
