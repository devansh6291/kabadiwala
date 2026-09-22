class NewsItem {
  String title;
  String source;
  DateTime date;
  String snippet;
  String? url;

  NewsItem({
    required this.title,
    required this.source,
    required this.date,
    required this.snippet,
    this.url,
  });
}
