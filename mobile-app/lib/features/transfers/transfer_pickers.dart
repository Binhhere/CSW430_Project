part of 'transfer_screens.dart';

class _FormData {
  const _FormData(this.members);
  final List<RelayMember> members;
}

class _ReadOnlyField extends StatefulWidget {
  const _ReadOnlyField({
    required this.label,
    required this.placeholder,
    required this.trailingIcon,
    required this.enabled,
    required this.onTap,
    this.value,
  });

  final String label;
  final String? value;
  final String placeholder;
  final IconData trailingIcon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  State<_ReadOnlyField> createState() => _ReadOnlyFieldState();
}

class _ReadOnlyFieldState extends State<_ReadOnlyField> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.relay;
    final hasValue = widget.value?.isNotEmpty == true;
    final contentColor = !widget.enabled
        ? palette.disabledContent
        : hasValue
        ? palette.textPrimary
        : palette.textMuted;

    return Semantics(
      button: widget.enabled,
      enabled: widget.enabled,
      label: '${widget.label}: ${widget.value ?? widget.placeholder}',
      child: InkWell(
        onTap: widget.enabled ? widget.onTap : null,
        onFocusChange: (focused) => setState(() => _focused = focused),
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          isFocused: _focused,
          isEmpty: !hasValue,
          decoration: InputDecoration(
            enabled: widget.enabled,
            fillColor: widget.enabled
                ? palette.surface
                : palette.disabledSurface,
            labelText: widget.label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            suffixIcon: Icon(widget.trailingIcon, size: 22),
          ),
          child: Text(
            hasValue ? widget.value! : widget.placeholder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: contentColor),
          ),
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final String? value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _ReadOnlyField(
    label: label,
    value: value,
    placeholder: context.l10n.text('selectValue').replaceAll('{label}', label),
    trailingIcon: Icons.search,
    enabled: enabled,
    onTap: onTap,
  );
}

typedef _PickerLoader<T> = Future<List<T>> Function(String query, T? after);
typedef _PickerCreator<T> = Future<T?> Function(BuildContext context);

class _PagedPickerPage<T> extends StatefulWidget {
  const _PagedPickerPage({
    required this.title,
    required this.searchHint,
    required this.emptyLabel,
    required this.load,
    required this.titleFor,
    required this.subtitleFor,
    this.createLabel,
    this.onCreate,
    this.enabled,
    this.paginated = true,
  });

  final String title;
  final String searchHint;
  final String emptyLabel;
  final _PickerLoader<T> load;
  final String Function(T item) titleFor;
  final String? Function(T item) subtitleFor;
  final String? createLabel;
  final _PickerCreator<T>? onCreate;
  final bool Function(T item)? enabled;
  final bool paginated;

  @override
  State<_PagedPickerPage<T>> createState() => _PagedPickerPageState<T>();
}

class _PagedPickerPageState<T> extends State<_PagedPickerPage<T>> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _debouncer = SearchDebouncer(const Duration(milliseconds: 300));
  late final PagedLoadController<T> _page;
  var _creating = false;
  String? _createError;

  List<T> get _items => _page.items;
  bool get _loading => _page.loading;
  bool get _hasMore => _page.hasMore;
  String? get _error =>
      _createError ??
      (_page.error == null ? null : context.l10n.text('pickerLoadFailed'));

  @override
  void initState() {
    super.initState();
    _page = PagedLoadController<T>(
      paginated: widget.paginated,
      loadPage: ({required after, required offset}) =>
          widget.load(_search.text, after),
    )..addListener(_pageChanged);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 240) _load();
    });
    _load(reset: true);
  }

  void _pageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _page.dispose();
    _search.dispose();
    _scroll.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_createError != null) setState(() => _createError = null);
    await _page.load(reset: reset);
  }

  Future<void> _create() async {
    if (widget.onCreate == null || _creating) return;
    setState(() => _creating = true);
    try {
      final created = await widget.onCreate!(context);
      if (!mounted) return;
      if (created != null) {
        Navigator.pop(context, created);
        return;
      }
      setState(() => _creating = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _creating = false;
          _createError = context.l10n.text('pickerCreateFailed');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => LedgerPage(
    title: widget.title,
    actions: widget.onCreate == null
        ? null
        : [
            TextButton(
              onPressed: _creating ? null : _create,
              child: _creating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.createLabel!),
            ),
          ],
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: RelaySearchField(
            controller: _search,
            hintText: widget.searchHint,
            autofocus: true,
            onChanged: (_) => _debouncer(() => _load(reset: true)),
            onCleared: () => _load(reset: true),
            clearTooltip: context.l10n.text('clear'),
          ),
        ),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh),
          label: Text(_error!),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(widget.emptyLabel, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      controller: _scroll,
      itemCount: _items.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          if (_error != null) {
            return TextButton(onPressed: _load, child: Text(_error!));
          }
          if (_loading && _hasMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _hasMore
              ? const SizedBox(height: 56)
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text(context.l10n.text('endOfResults'))),
                );
        }
        final item = _items[index];
        final enabled = widget.enabled?.call(item) ?? true;
        final subtitle = widget.subtitleFor(item);
        return ListTile(
          enabled: enabled,
          title: Text(widget.titleFor(item)),
          subtitle: subtitle == null || subtitle.isEmpty
              ? null
              : Text(subtitle),
          trailing: enabled
              ? const Icon(Icons.chevron_right)
              : const Icon(Icons.check),
          onTap: enabled ? () => Navigator.pop(context, item) : null,
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _ReadOnlyField(
    label: label,
    value: value == null ? null : _shortDate(context, value!),
    placeholder: context.l10n.text('selectDate'),
    trailingIcon: Icons.calendar_today_outlined,
    enabled: true,
    onTap: onTap,
  );
}

class _DirectionNotice extends StatelessWidget {
  const _DirectionNotice({required this.origin, required this.destination});
  final LocationRecord? origin;
  final LocationRecord? destination;
  @override
  Widget build(BuildContext context) {
    final isIncomplete = origin == null || destination == null;
    final isToCustomer =
        origin?.type == LocationType.warehouse &&
        destination?.type == LocationType.deliveryPlace;
    final isToWarehouse =
        origin?.type == LocationType.deliveryPlace &&
        destination?.type == LocationType.warehouse;
    final isValid = isToCustomer || isToWarehouse;
    final direction = isIncomplete
        ? context.l10n.text('selectEndpoints')
        : isToCustomer
        ? context.l10n.text('toCustomer')
        : isToWarehouse
        ? context.l10n.text('toWarehouse')
        : context.l10n.text('endpointsMustMatch');
    final color = isIncomplete
        ? context.relay.textSecondary
        : isValid
        ? context.relay.textPrimary
        : context.relay.danger;
    final background = isValid || isIncomplete
        ? context.relay.surfaceSubtle
        : context.relay.dangerContainer;
    final borderColor = isValid || isIncomplete
        ? context.relay.structuralLine
        : context.relay.danger;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              direction,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
