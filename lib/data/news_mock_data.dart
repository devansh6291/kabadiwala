import '../models/news_item.dart';

/// TEMPORARY placeholder market/policy news. These are illustrative
/// examples only, NOT real news — never present them to end users as
/// real, current events. TODO(backend-team): replace with a real feed.
class NewsMockData {
  static List<NewsItem> latest() {
    final now = DateTime.now();
    return [
      NewsItem(
        title: 'Sample: EPR e-waste collection targets under review',
        source: 'Placeholder — wire a real feed',
        date: now.subtract(const Duration(days: 2)),
        snippet:
            'Example placeholder item showing where policy update summaries would appear once a real news source is connected.',
      ),
      NewsItem(
        title: 'Sample: Copper and PCB scrap rates trending this week',
        source: 'Placeholder — wire a real feed',
        date: now.subtract(const Duration(days: 4)),
        snippet:
            'Example placeholder item for market-rate commentary — replace with real aggregated pricing/news content.',
      ),
      NewsItem(
        title:
            'Sample: State pollution board notification on authorized recyclers',
        source: 'Placeholder — wire a real feed',
        date: now.subtract(const Duration(days: 6)),
        snippet:
            'Example placeholder item for regulatory notices relevant to authorized recycler status.',
      ),
    ];
  }
}
