import 'package:flutter/foundation.dart';

typedef PagedLoader<T> =
    Future<List<T>> Function({required T? after, required int offset});

class PagedLoadController<T> extends ChangeNotifier {
  PagedLoadController({
    required this.loadPage,
    this.pageSize = 10,
    this.paginated = true,
  });

  final PagedLoader<T> loadPage;
  final int pageSize;
  final bool paginated;
  final List<T> _items = [];

  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  int _generation = 0;
  bool _disposed = false;

  List<T> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  Object? get error => _error;

  Future<void> load({bool reset = false, bool preserveItems = false}) async {
    if (!reset && (_loading || !_hasMore)) return;

    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (reset) {
      if (!preserveItems) _items.clear();
      _hasMore = true;
    }
    notifyListeners();

    try {
      final page = await loadPage(
        after: reset || _items.isEmpty ? null : _items.last,
        offset: reset ? 0 : _items.length,
      );
      if (_disposed || generation != _generation) return;

      if (reset) _items.clear();
      _items.addAll(page);
      _hasMore = paginated && page.length == pageSize;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = error;
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
