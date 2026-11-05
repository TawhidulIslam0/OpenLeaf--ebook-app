# OpenLeaf Feature Audit

This report distinguishes existing functionality, changes made in this task,
and gaps that remain. The library stays empty on first launch; no example books
or collections are seeded.

## Status

| Area | Status | Notes |
|---|---|---|
| Gutendex / Project Gutenberg catalog | Implemented | Existing live catalog integration is preserved. |
| Search | Implemented | Search is debounced, duplicate in-flight submissions are reused, old-query requests are canceled, and matching books from the in-memory catalog cache appear while the server is searched or if it times out. EPUB availability is checked in returned results; comma-formatted author names are normalized; results are paginated and capped with language/sort filters. |
| Explore refresh | Implemented | Pull-to-refresh invalidates the displayed Explore and genre feed caches. Every genre request starts concurrently so a slow response cannot delay later sections from starting; each section displays independently as its response arrives. |
| Genre pagination | Implemented | Scroll pagination retains existing results on failure and offers a retry action. |
| Surprise Me | Implemented | Chooses a random result from a live Gutendex page. |
| Download lifecycle | Implemented | EPUB files use app-private support storage, HTTPS Gutenberg-only redirects, progress, cancellation, retry, cleanup, and ZIP/EPUB structural validation. Cached files reopen offline. |
| Download storage | Partially implemented | The Downloads screen reports cached-file sizes and can delete files independently of library history. A multi-book download queue is not implemented. |
| EPUB reader | Partially implemented | Iridium's TOC, page navigation, bookmarks, highlights, font family/size, margins, line height, and saved locator remain. Warm theme, app brightness, landscape mode, selected-text speech, and persisted reader settings were added. Dictionary lookup and full-book/chapter speech are not implemented. |
| EPUB/PDF imports | Partially implemented | Imported documents are copied to private storage; EPUB imports use the structural validator and PDF reading position persists. PDF validation currently checks the PDF signature rather than fully parsing the document before import. |
| Personal library | Partially implemented | Continue Reading, statuses, custom collections, ratings/reviews, title-based duplicate confirmation, recent history, and offline access are present. Portable export/restore is not implemented. |
| Reading statistics | Partially implemented | Daily goals, streaks, completed-book counts, session time, and weekly/monthly time aggregation are stored locally. Page counts currently track PDF forward-page movement; EPUB pages, activity calendar UI, and richer reports remain. |
| Discovery | Partially implemented | Subject/genre browsing and author results exist; search adds language filtering and pagination. Similar-subject recommendations and broader filters are not implemented. |
| Reliability / accessibility | Partially implemented | Offline and HTTP/timeout errors are surfaced in search/download flows; cache deletion preserves library records. Cover caching uses the existing image cache. Reminders, database migration/backup protection, and a dedicated accessibility settings screen remain. |
| Free product / empty first run | Implemented | No ads, purchases, subscriptions, paywalls, demo books, or seeded collections were added. |

## Validation

Focused EPUB-cache and reading-shelf tests cover archive validation, empty
first-run state, library metadata, progress, and statistics. The repository's
previously commented-out widget-test scaffold was replaced with a real empty
search-state test. `flutter test` passes all 13 tests. `flutter analyze` reports
zero errors but exits non-zero with 45 diagnostics (lint infos and two
dependency-manifest warnings). The debug APK builds successfully from an
isolated workspace copy; building in the OneDrive workspace can fail because
Gradle cannot clean files locked by Windows.

The Riverpod generated notifier output was updated to match its source; code
generation itself could not be verified because the installed Dart SDK lacks
the `frontend_server.dart.snapshot` required by the current build-runner setup.
