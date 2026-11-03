# OpenLeaf

OpenLeaf is a Flutter ebook library for discovering public-domain books, reading EPUBs, saving favorites and downloads, and keeping a personal reading shelf.

## Features

- Discover public-domain ebooks through the Gutendex / Project Gutenberg catalog.
- Search by book title, author, and subject, with popularity/title/newest sorting.
- Browse featured books, categories, and recently added titles.
- Read EPUB books using the integrated Iridium reader.
- Search the catalog as you type, with debounced requests and stale-request cancellation.
- Save favorites and cache downloaded EPUBs locally for faster offline reopening.
- Import EPUB and PDF files into a persistent local library.
- Use reader bookmarks, highlights, saved reading position, and persisted font/theme settings.
- Continue reading from the last saved EPUB location and view books, sessions, and reading-day statistics.
- Light and dark themes with an editorial forest-green visual identity.

## Run in VS Code

1. Install Flutter and the Android SDK.
2. Open this folder in VS Code.
3. Run `flutter pub get`.
4. Connect an Android device or start an emulator.
5. Run `flutter run`.

The app uses Project Gutenberg's public-domain catalog via Gutendex. Catalog availability and EPUB formats vary by title. Reading history, imported books, cached EPUBs, reader preferences, and annotations are stored locally on the device. Imported files are copied into app-managed storage; removing an imported book from the library deletes that copy.
