# OpenLeaf

OpenLeaf is a Flutter ebook library for discovering public-domain books, reading EPUBs, saving favorites and downloads, and keeping a personal reading shelf.

## Features

- Discover public-domain ebooks through the Gutendex / Project Gutenberg catalog.
- Search by book title, author, and subject, with popularity/title/newest sorting.
- Browse featured books, categories, and recently added titles.
- Read EPUB books using the integrated Iridium reader.
- Save favorites and download books for offline reading.
- Keep a local reading history with one-tap reopen and removal controls.
- Light and dark themes with an editorial forest-green visual identity.

## Run in VS Code

1. Install Flutter and the Android SDK.
2. Open this folder in VS Code.
3. Run `flutter pub get`.
4. Connect an Android device or start an emulator.
5. Run `flutter run`.

The app uses Project Gutenberg's public-domain catalog via Gutendex. Catalog availability and EPUB formats vary by title. Reading history is stored locally on the device. The history tracks books opened; exact in-book page position restoration is not yet exposed by the integrated EPUB reader.
