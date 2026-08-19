import 'package:flutter/foundation.dart';

class SelectionController<ID> extends ChangeNotifier {
  final Set<ID> _selectedIds = <ID>{};
  bool _selecting = false;

  bool get selecting => _selecting;
  Set<ID> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;
  bool contains(ID id) => _selectedIds.contains(id);

  void start(ID id) {
    _selecting = true;
    _selectedIds.add(id);
    notifyListeners();
  }

  void begin() {
    if (_selecting) return;
    _selecting = true;
    notifyListeners();
  }

  void toggle(ID id) {
    if (!_selectedIds.add(id)) _selectedIds.remove(id);
    if (_selectedIds.isEmpty) _selecting = false;
    notifyListeners();
  }

  void cancel() {
    _selecting = false;
    _selectedIds.clear();
    notifyListeners();
  }

  void clearMissing(Iterable<ID> visibleIds) {
    final visible = visibleIds.toSet();
    final before = _selectedIds.length;
    _selectedIds.removeWhere((id) => !visible.contains(id));
    final changed = before != _selectedIds.length;
    if (_selectedIds.isEmpty && _selecting) _selecting = false;
    if (changed) notifyListeners();
  }
}
