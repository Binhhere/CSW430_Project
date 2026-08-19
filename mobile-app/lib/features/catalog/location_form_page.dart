part of 'catalog_screens.dart';

class LocationFormPage extends ConsumerStatefulWidget {
  const LocationFormPage({
    required this.companyId,
    this.existing,
    this.initialType,
    super.key,
  });
  final String companyId;
  final LocationRecord? existing;
  final LocationType? initialType;

  @override
  ConsumerState<LocationFormPage> createState() => _LocationFormPageState();
}

class _LocationFormPageState extends ConsumerState<LocationFormPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late LocationType _type =
      widget.existing?.type ?? widget.initialType ?? LocationType.warehouse;
  final _dirtyForm = DirtyFormController();
  var _busy = false;
  String? _error;

  bool get _isDirty =>
      _name.text.trim() != (widget.existing?.name ?? '') ||
      _type !=
          (widget.existing?.type ??
              widget.initialType ??
              LocationType.warehouse);

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    await _dirtyForm.handlePopInvoked(
      context: context,
      didPop: didPop,
      busy: _busy,
      dirty: _isDirty,
      title: context.l10n.text('discardChangesTitle'),
      body: context.l10n.text('discardChangesBody'),
      discardLabel: context.l10n.text('discardChanges'),
      keepEditingLabel: context.l10n.text('keepEditing'),
      onDiscard: () => Navigator.pop(context),
    );
  }

  @override
  void initState() {
    super.initState();
    _name.addListener(_refreshPopState);
  }

  void _refreshPopState() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(catalogRepositoryProvider)
          .saveLocation(
            companyId: widget.companyId,
            locationId: widget.existing?.id,
            name: _name.text,
            type: _type,
          );
      if (!mounted) return;
      _dirtyForm.allowPop();
      Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = RelayFailure.from(error).message(
            l10n: context.l10n,
            fallback: context.l10n.text('couldNotSave'),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _dirtyForm.canPop(busy: _busy, dirty: _isDirty),
    onPopInvokedWithResult: _onPopInvoked,
    child: LedgerPage(
      title: widget.existing == null
          ? context.l10n.text('createLocation')
          : context.l10n.text('editLocation'),
      bottom: BusyButton(
        label: context.l10n.text('saveLocation'),
        busy: _busy,
        onPressed: _save,
        icon: Icons.save_outlined,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel(label: context.l10n.text('name')),
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: context.l10n.text('name'),
                ),
                validator: (value) => value?.trim().isEmpty != false
                    ? context.l10n.text('requiredName')
                    : null,
              ),
              const SizedBox(height: 24),
              _FieldLabel(label: context.l10n.text('type')),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: context.relay.controlBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: RadioGroup<LocationType>(
                  groupValue: _type,
                  onChanged: (LocationType? value) {
                    if (_busy || value == null) return;
                    setState(() => _type = value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<LocationType>(
                        value: LocationType.warehouse,
                        title: Text(context.l10n.text('warehouse')),
                        secondary: const Icon(Icons.warehouse_outlined),
                      ),
                      const Divider(height: 1),
                      RadioListTile<LocationType>(
                        value: LocationType.deliveryPlace,
                        title: Text(context.l10n.text('deliveryPlace')),
                        secondary: const Icon(Icons.place_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                RelayNotice(message: _error!, kind: RelayNoticeKind.danger),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
