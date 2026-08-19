part of 'asset_screens.dart';

class AssetFormPage extends ConsumerStatefulWidget {
  const AssetFormPage({
    required this.companyId,
    this.existing,
    this.editImage,
    super.key,
  });
  final String companyId;
  final AssetRecord? existing;
  final RelayImageEdit? editImage;

  @override
  ConsumerState<AssetFormPage> createState() => _AssetFormPageState();
}

class _AssetFormPageState extends ConsumerState<AssetFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _serial = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _picker = ImagePicker();
  String? _saveRequestKey;
  String? _saveRequestPayload;
  String? _mergeRequestKey;
  String? _mergeRequestPayload;
  AssetMode _mode = AssetMode.serialized;
  String? _warehouseId;
  Uint8List? _cover;
  var _removeCover = false;
  String? _error;
  final _dirtyForm = DirtyFormController();
  var _busy = false;
  late Future<List<LocationRecord>> _warehouses;
  late final AssetMode _initialMode;
  late final String _initialName;
  late final String _initialSerial;
  late final String _initialQuantity;
  String? _initialWarehouseId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _mode = existing.mode;
      _name.text = existing.name;
      _serial.text = existing.serialNumber ?? '';
      _quantity.text = (existing.quantity ?? 1).toString();
      _warehouseId = existing.locationId;
    }
    _loadWarehouses();
    _initialMode = _mode;
    _initialName = _name.text.trim();
    _initialSerial = _serial.text.trim();
    _initialQuantity = _quantity.text.trim();
    _initialWarehouseId = _warehouseId;
    _name.addListener(_refreshPopState);
    _serial.addListener(_refreshPopState);
    _quantity.addListener(_refreshPopState);
  }

  void _loadWarehouses() {
    _warehouses = ref
        .read(catalogRepositoryProvider)
        .locations(companyId: widget.companyId, type: LocationType.warehouse);
  }

  bool get _isDirty =>
      _mode != _initialMode ||
      _name.text.trim() != _initialName ||
      _serial.text.trim() != _initialSerial ||
      _quantity.text.trim() != _initialQuantity ||
      _warehouseId != _initialWarehouseId ||
      _cover != null ||
      _removeCover;

  void _refreshPopState() {
    if (mounted) setState(() {});
  }

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
  void dispose() {
    _name.dispose();
    _serial.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source);
      if (image == null) return;
      if (image.mimeType != null && image.mimeType != 'image/jpeg') {
        if (mounted) setState(() => _error = context.l10n.text('jpegOnly'));
        return;
      }
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          setState(() => _error = context.l10n.text('imageTooLarge'));
        }
        return;
      }
      // The page remains mounted while the editor route is open.
      // ignore: use_build_context_synchronously
      final edited = await (widget.editImage ?? editRelayImage)(context, bytes);
      if (edited == null) return;
      if (mounted) {
        setState(() {
          _cover = edited;
          _removeCover = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = context.l10n.text('photoSelectionFailed'));
      }
    }
  }

  Future<void> _choosePhoto() async {
    await showRelaySheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(context.l10n.text('takePhoto')),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.text('choosePhoto')),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _keyFor({required bool confirmBulkMerge}) {
    final payload = [
      widget.existing?.id,
      _mode.wireValue,
      _name.text.trim(),
      _warehouseId,
      _mode == AssetMode.serialized ? _serial.text.trim() : null,
      _mode == AssetMode.bulk ? int.tryParse(_quantity.text) : null,
      confirmBulkMerge,
    ].join('|');
    if (confirmBulkMerge) {
      if (_mergeRequestKey == null || _mergeRequestPayload != payload) {
        _mergeRequestKey = const Uuid().v4();
        _mergeRequestPayload = payload;
      }
      return _mergeRequestKey!;
    }
    if (_saveRequestKey == null || _saveRequestPayload != payload) {
      _saveRequestKey = const Uuid().v4();
      _saveRequestPayload = payload;
    }
    return _saveRequestKey!;
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate() || _warehouseId == null) {
      if (_warehouseId == null) {
        setState(() => _error = context.l10n.text('selectWarehouse'));
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(assetCatalogRepositoryProvider);
      var result = await repository.saveAsset(
        companyId: widget.companyId,
        assetId: widget.existing?.id,
        mode: _mode,
        name: _name.text,
        locationId: _warehouseId!,
        serialNumber: _mode == AssetMode.serialized ? _serial.text : null,
        quantity: _mode == AssetMode.bulk ? int.tryParse(_quantity.text) : null,
        requestKey: _keyFor(confirmBulkMerge: false),
      );
      if (result.needsMergeConfirmation) {
        if (!mounted) return;
        final merge = await showRelayDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.text('addBulkQuantity')),
            content: Text(
              '${context.l10n.text('bulkMergeBody')} '
              '${result.currentQuantity} → ${result.newQuantity}\n\n'
              '${context.l10n.text('bulkMergeKeepsPhoto')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.text('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.text('addQuantity')),
              ),
            ],
          ),
        );
        if (merge != true) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        if (!mounted) return;
        result = await repository.saveAsset(
          companyId: widget.companyId,
          assetId: widget.existing?.id,
          mode: _mode,
          name: _name.text,
          locationId: _warehouseId!,
          serialNumber: _mode == AssetMode.serialized ? _serial.text : null,
          quantity: _mode == AssetMode.bulk
              ? int.tryParse(_quantity.text)
              : null,
          confirmBulkMerge: true,
          requestKey: _keyFor(confirmBulkMerge: true),
        );
      }

      final coverBytes = _cover;
      final coverOperation = coverBytes != null
          ? AssetCoverOperation.upload
          : _removeCover && widget.existing?.storagePath != null
          ? AssetCoverOperation.remove
          : AssetCoverOperation.none;
      final workflow = await runAssetCoverWorkflow(
        companyId: widget.companyId,
        saved: result,
        coverOperation: coverOperation,
        coverBytes: coverBytes,
        uploadCover: () => repository.uploadCover(
          companyId: widget.companyId,
          assetId: result.assetId,
          bytes: coverBytes!,
        ),
        removeCover: () => repository.removeCover(
          companyId: widget.companyId,
          assetId: result.assetId,
        ),
        loadAsset: (assetId) => repository.asset(widget.companyId, assetId),
      );

      if (!mounted) return;
      _dirtyForm.allowPop();
      Navigator.pop(context, workflow);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.text('couldNotSave');
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
          ? context.l10n.text('createAsset')
          : context.l10n.text('editAsset'),
      bottom: BusyButton(
        label: context.l10n.text('saveAsset'),
        busy: _busy,
        onPressed: _save,
        icon: Icons.save_outlined,
      ),
      child: FutureBuilder<List<LocationRecord>>(
        future: _warehouses,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _AssetRetry(
              message: context.l10n.text('couldNotLoad'),
              onRetry: () => setState(_loadWarehouses),
            );
          }
          final warehouses = snapshot.data!;
          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  RelayNotice(message: _error!, kind: RelayNoticeKind.danger),
                  const SizedBox(height: 16),
                ],
                _AssetFieldLabel(label: context.l10n.text('assetMode')),
                _AssetModeOption(
                  label: context.l10n.text('serialized'),
                  detail: context.l10n.text('serializedModeBody'),
                  selected: _mode == AssetMode.serialized,
                  enabled: widget.existing == null,
                  onTap: () => setState(() => _mode = AssetMode.serialized),
                ),
                const SizedBox(height: 8),
                _AssetModeOption(
                  label: context.l10n.text('bulk'),
                  detail: context.l10n.text('bulkModeBody'),
                  selected: _mode == AssetMode.bulk,
                  enabled: widget.existing == null,
                  onTap: () => setState(() => _mode = AssetMode.bulk),
                ),
                const SizedBox(height: 24),
                _AssetFieldLabel(label: context.l10n.text('name')),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.l10n.text('requiredName')
                      : null,
                ),
                const SizedBox(height: 16),
                if (_mode == AssetMode.serialized) ...[
                  _AssetFieldLabel(label: context.l10n.text('serialNumber')),
                  TextFormField(
                    controller: _serial,
                    enabled: widget.existing == null,
                    decoration: const InputDecoration(),
                    validator: (value) =>
                        _mode == AssetMode.serialized &&
                            (value == null || value.trim().isEmpty)
                        ? context.l10n.text('requiredSerial')
                        : null,
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  _AssetFieldLabel(
                    label: context.l10n.text('physicalQuantity'),
                  ),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(),
                    validator: (value) =>
                        int.tryParse(value ?? '') == null ||
                            int.parse(value!) < 0
                        ? context.l10n.text('validQuantity')
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                _AssetFieldLabel(label: context.l10n.text('warehouse')),
                DropdownButtonFormField<String>(
                  initialValue: _warehouseId,
                  isExpanded: true,
                  decoration: const InputDecoration(),
                  selectedItemBuilder: (context) => [
                    for (final location in warehouses)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          location.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  items: [
                    for (final location in warehouses)
                      DropdownMenuItem(
                        value: location.id,
                        child: Text(
                          location.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _warehouseId = value),
                ),
                const SizedBox(height: 24),
                _AssetFieldLabel(label: context.l10n.text('coverPhoto')),
                const SizedBox(height: 8),
                if (_cover == null &&
                    !_removeCover &&
                    widget.existing?.storagePath != null) ...[
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _AssetCover(
                      storagePath: widget.existing!.storagePath,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _choosePhoto,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.text('replacePhoto')),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _removeCover = true),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(context.l10n.text('removePhoto')),
                  ),
                ] else if (_cover == null)
                  OutlinedButton.icon(
                    onPressed: _choosePhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(context.l10n.text('addCoverPhoto')),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_cover!, fit: BoxFit.cover),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _choosePhoto,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.l10n.text('replacePhoto')),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
