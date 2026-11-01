const String baseURL = 'https://gutendex.com';

String gutendexBooksUrl({
  String? sort,
  String? topic,
  String? search,
  int? page,
}) {
  final query = <String, String>{
    'languages': 'en',
    'copyright': 'false',
    'mime_type': 'application/epub+zip',
    if (sort != null) 'sort': sort,
    if (topic != null) 'topic': topic,
    if (search != null) 'search': search,
    if (page != null) 'page': '$page',
  };
  return Uri.https('gutendex.com', '/books/', query).toString();
}

final String popular = gutendexBooksUrl(sort: 'popular');
final String recent = gutendexBooksUrl(sort: 'descending');
final String shortStory = gutendexBooksUrl(topic: 'short stories');
final String sciFi = gutendexBooksUrl(topic: 'science fiction');
final String actionAdventure = gutendexBooksUrl(topic: 'adventure');
final String mystery = gutendexBooksUrl(topic: 'mystery');
final String romance = gutendexBooksUrl(topic: 'romance');
final String horror = gutendexBooksUrl(topic: 'horror');
final String history = gutendexBooksUrl(topic: 'history');
final String poetry = gutendexBooksUrl(topic: 'poetry');
final String children = gutendexBooksUrl(topic: 'children');
final String drama = gutendexBooksUrl(topic: 'drama');
