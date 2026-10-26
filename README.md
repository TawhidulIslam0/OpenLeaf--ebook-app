# 📖 OpenLeaf (Flutter eBook App)

A simple Flutter app to Read and Download books. The Books included in the app
are from the [Public Domain](https://en.wikipedia.org/wiki/Public_domain)
(Expired Copyright and completely free).

Books are fetched from the [Gutendex API](https://gutendex.com/), which provides
catalog data and EPUB downloads for public-domain books from Project Gutenberg.
<br>

On a book's detail page, **Read in app** opens the EPUB reader using a temporary
app-cache copy; it does not add the book to Downloads. **Download** saves a
persistent copy that can be reopened from the Downloads tab.

## 💻 Requirements

- Any Operating System (ie. MacOS X, Linux, Windows)
- Any IDE with Flutter SDK installed (ie. IntelliJ, Android Studio, VSCode etc)
- A little knowledge of Dart and Flutter

## ✨ Features

- [x] Download eBooks.
- [x] Read eBooks.
- [x] Favorites.
- [x] Dark Mode
- [x] Swipe to delete downloads.
- [x] Recently opened genres and author feeds are cached briefly for faster repeat visits.


## 🔌 Plugins

| Name                                                                   | Usage                                         |
| ---------------------------------------------------------------------- | --------------------------------------------- |
| [**Riverpod**](https://pub.dev/packages/flutter_riverpod)              | State Management                              |
| [**Sembast**](https://pub.dev/packages/sembast)                        | NoSQL database to store Favorites & Downloads |
| [**DIO**](https://pub.dev/packages/dio)                                | Network calls and File Download               |
| [**Iridium Reader**](https://github.com/Mantano/iridium_reader_widget) | Plug and play reader widget for epubs         |
