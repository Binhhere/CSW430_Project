part of 'asset_screens.dart';

class AssetImportPage extends ConsumerStatefulWidget {
  const AssetImportPage({required this.companyId, super.key});

  final String companyId;

  @override
  ConsumerState<AssetImportPage> createState() => _AssetImportPageState();
}

class _AssetImportPageState extends ConsumerState<AssetImportPage> {
  final _service = AssetImportService();
  final _batchKey = const Uuid().v4();
  AssetImportDecodedFile? _decoded;
  AssetImportPreviewResult? _preview;
  AssetImportPreviewContext? _previewContext;
  List<AssetImportBatchRowResult> _results = const [];
  Uint8List? _bytes;
  String? _fileName;
  String? _fileHash;
  String? _error;
  Map<int, String?> _mappingOverrides = const {};
  Map<int, Map<String, String?>> _valueOverrides = const {};
  Set<int> _confirmedRows = const {};
  var _contextLoading = true;
  var _busy = false;

  bool get _readyToCommit {
    final preview = _preview;
    if (preview == null || preview.globalIssues.isNotEmpty) return false;
    if (preview.validRowCount == 0 && preview.confirmationRowCount == 0) {
      return false;
    }
    return preview.rows
        .where(
          (row) =>
              row.status == AssetImportPreviewRowStatus.requiresConfirmation,
        )
        .every((row) => _confirmedRows.contains(row.rowNumber));
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreviewContext());
  }

  Future<List<LocationRecord>> _loadAllLocations() async {
    final repository = ref.read(catalogRepositoryProvider);
    final result = <LocationRecord>[];
    LocationRecord? after;
    while (true) {
      final page = await repository.locations(
        companyId: widget.companyId,
        after: after,
      );
      result.addAll(page);
      if (page.length < 10) return result;
      after = page.last;
    }
  }

  Future<List<AssetRecord>> _loadAllAssets() async {
    final repository = ref.read(assetCatalogRepositoryProvider);
    final result = <AssetRecord>[];
    AssetRecord? after;
    while (true) {
      final page = await repository.assets(
        companyId: widget.companyId,
        after: after,
      );
      result.addAll(page);
      if (page.length < 10) return result;
      after = page.last;
    }
  }

  Future<void> _loadPreviewContext() async {
    try {
      final loaded = await Future.wait<Object>([
        _loadAllLocations(),
        _loadAllAssets(),
      ]);
      if (!mounted) return;
      final locations = loaded[0] as List<LocationRecord>;
      final assets = loaded[1] as List<AssetRecord>;
      setState(() {
        _previewContext = AssetImportPreviewContext(
          warehouses: [
            for (final location in locations)
              if (location.type == LocationType.warehouse)
                AssetImportWarehouseOption(name: location.name),
          ],
          otherLocationNames: [
            for (final location in locations)
              if (location.type != LocationType.warehouse) location.name,
          ],
          existingAssets: [
            for (final asset in assets)
              AssetImportExistingAsset(
                type: asset.isSerialized
                    ? AssetImportType.serialized
                    : AssetImportType.bulk,
                name: asset.name,
                warehouse: asset.locationName,
                serialCode: asset.serialNumber,
                quantity: asset.quantity,
              ),
          ],
        );
        _contextLoading = false;
        _error = null;
      });
      _rebuildPreview();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _contextLoading = false;
        _error = context.l10n.text('importContextFailed');
      });
    }
  }

  Future<void> _downloadTemplate() async {
    final template = _service.generateTemplate(
      locale: Localizations.localeOf(context).languageCode,
    );
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: context.l10n.text('downloadTemplate'),
        fileName: template.fileName,
        bytes: Uint8List.fromList(template.bytes),
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('importTemplateSaved'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('importTemplateSaveFailed'))),
      );
    }
  }

  Future<void> _chooseFile() async {
    if (_busy) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _error = context.l10n.text('importCouldNotRead'));
        return;
      }
      final decoded = _service.decode(
        AssetImportRequest(
          bytes: bytes,
          fileName: file.name,
          locale: Localizations.localeOf(context).languageCode,
        ),
      );
      setState(() {
        _bytes = bytes;
        _fileName = file.name;
        _fileHash = sha256.convert(bytes).toString();
        _decoded = decoded;
        _preview = null;
        _mappingOverrides = const {};
        _valueOverrides = const {};
        _confirmedRows = const {};
        _results = const [];
        _error = null;
      });
      _rebuildPreview();
    } on AssetImportException catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageForImportError(error.code));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.text('importCouldNotRead'));
    }
  }

  String _messageForImportError(String code) => switch (code) {
    'file_too_large' => context.l10n.text('importFileTooLarge'),
    'too_many_rows' => context.l10n.text('importTooManyRows'),
    'unsupported_file_type' => context.l10n.text('importUnsupportedFile'),
    _ => context.l10n.text('importCouldNotRead'),
  };

  void _rebuildPreview() {
    final decoded = _decoded;
    final previewContext = _previewContext;
    if (decoded == null || previewContext == null || !mounted) return;
    final preview = _service.preview(
      AssetImportPreviewRequest(
        decoded: decoded,
        context: previewContext,
        mappingOverrides: _mappingOverrides,
        valueOverrides: _valueOverrides,
      ),
    );
    setState(() {
      _preview = preview;
      _confirmedRows = {
        for (final row in _confirmedRows)
          if (preview.rows.any((candidate) => candidate.rowNumber == row)) row,
      };
    });
  }

  void _setMapping(int columnIndex, String? fieldKey) {
    setState(() {
      _mappingOverrides = {..._mappingOverrides, columnIndex: fieldKey};
    });
    _rebuildPreview();
  }

  void _toggleConfirmation(int rowNumber, bool value) {
    setState(() {
      final rows = {..._confirmedRows};
      if (value) {
        rows.add(rowNumber);
      } else {
        rows.remove(rowNumber);
      }
      _confirmedRows = rows;
    });
  }

  Future<void> _editRow(AssetImportPreviewRow row) async {
    if (_busy) return;
    final values = await showDialog<Map<String, String?>>(
      context: context,
      builder: (_) => _AssetImportRowEditor(
        rowNumber: row.rowNumber,
        initialValues: row.canonicalValues,
      ),
    );
    if (values == null || !mounted) return;
    setState(() {
      _valueOverrides = {..._valueOverrides, row.rowNumber: values};
    });
    _rebuildPreview();
  }

  Future<void> _commit() async {
    final preview = _preview;
    final bytes = _bytes;
    final fileName = _fileName;
    final fileHash = _fileHash;
    if (!_readyToCommit ||
        preview == null ||
        bytes == null ||
        fileName == null) {
      return;
    }
    if (_busy) return;
    final rows = [
      for (final row in preview.rows)
        if (row.status == AssetImportPreviewRowStatus.valid ||
            _confirmedRows.contains(row.rowNumber))
          row.toBatchRow(
            confirmBulkMerge: _confirmedRows.contains(row.rowNumber),
          ),
    ];
    if (rows.isEmpty || fileHash == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await _service.commit(
        AssetImportBatchCommitRequest(
          companyId: widget.companyId,
          fileName: fileName,
          fileHash: fileHash,
          fileSizeBytes: bytes.length,
          batchKey: _batchKey,
          rows: rows,
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _results = results;
      });
      final failed = results.where((row) => row.status != 'SUCCEEDED').length;
      if (failed == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.text('importCompleted'))),
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.l10n.text('requestCouldNotComplete');
      });
    }
  }

  String _fieldLabel(String? key) {
    if (key == null) return context.l10n.text('unmapped');
    final resources = AssetImportLocaleResources.forLocale(
      Localizations.localeOf(context).languageCode,
    );
    return resources.labels[key] ?? key;
  }

  List<AssetImportFieldDefinition> get _fields => AssetImportSchemas.unified(
    AssetImportLocaleResources.forLocale(
      Localizations.localeOf(context).languageCode,
    ),
  ).fields;

  @override
  Widget build(BuildContext context) => LedgerPage(
    title: context.l10n.text('importAssetsTitle'),
    leading: IconButton(
      tooltip: context.l10n.text('back'),
      onPressed: _busy ? null : () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back),
    ),
    child: _body(context),
  );

  Widget _body(BuildContext context) {
    final preview = _preview;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Text(
          context.l10n.text('importAssetsBody'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 22),
        _step(
          context,
          1,
          context.l10n.text('importFileReady'),
          _fileSelector(),
        ),
        if (_contextLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: RelayNotice(message: _error!, kind: RelayNoticeKind.danger),
          ),
        if (_decoded != null && !_decoded!.isTemplate)
          _step(context, 2, context.l10n.text('importMapping'), _mapping()),
        if (_decoded != null && _decoded!.isTemplate)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: RelayNotice(
              message: context.l10n.text('relayTemplateRecognized'),
              kind: RelayNoticeKind.info,
            ),
          ),
        if (preview != null)
          _step(
            context,
            _decoded?.isTemplate == true ? 2 : 3,
            context.l10n.text('importPreview'),
            _previewBody(),
          ),
        if (preview != null && !_contextLoading)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: BusyButton(
              label: _busy
                  ? context.l10n.text('importingRows')
                  : context.l10n.text('importRows'),
              icon: Icons.file_download_done_outlined,
              busy: _busy,
              onPressed: _readyToCommit ? _commit : null,
            ),
          ),
        if (_results.isNotEmpty) _resultBody(),
      ],
    );
  }

  Widget _step(BuildContext context, int number, String title, Widget child) =>
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.relay.actionPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 24,
                    child: Center(
                      child: Text(
                        '$number',
                        style: TextStyle(color: context.relay.onActionPrimary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _fileSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.text('importFileTypes'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _downloadTemplate,
            icon: const Icon(Icons.download_outlined),
            label: Text(context.l10n.text('downloadTemplate')),
          ),
          FilledButton.icon(
            onPressed: _busy || _contextLoading ? null : _chooseFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              context.l10n.text(
                _fileName == null ? 'chooseImportFile' : 'replaceImportFile',
              ),
            ),
          ),
        ],
      ),
      if (_fileName != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.relay.surfaceSubtle,
            border: Border.all(color: context.relay.structuralLine),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.description_outlined, color: context.relay.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${_bytes?.length ?? 0} B'),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _mapping() {
    final decoded = _decoded!;
    return LedgerSection(
      title: context.l10n.text('importMapping'),
      uppercaseTitle: false,
      children: [
        for (final mapping in decoded.mappings)
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final field =
                    _mappingOverrides.containsKey(mapping.sourceColumnIndex)
                    ? _mappingOverrides[mapping.sourceColumnIndex]
                    : mapping.canonicalKey;
                final control = RelaySingleSelectMenuButton<String?>(
                  label: _fieldLabel(field),
                  selectedValue: field,
                  active: field != null,
                  options: [
                    RelayMenuOption<String?>(
                      value: null,
                      label: context.l10n.text('unmapped'),
                    ),
                    for (final option in _fields)
                      RelayMenuOption<String?>(
                        value: option.key,
                        label: option.label,
                      ),
                  ],
                  onSelected: (value) =>
                      _setMapping(mapping.sourceColumnIndex, value),
                );
                return constraints.maxWidth < 440
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            mapping.sourceHeader,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          control,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: Text(mapping.sourceHeader)),
                          const SizedBox(width: 16),
                          control,
                        ],
                      );
              },
            ),
          ),
      ],
    );
  }

  Widget _previewBody() {
    final preview = _preview!;
    final summary = context.l10n
        .text('importRowsSummary')
        .replaceAll('{valid}', '${preview.validRowCount}')
        .replaceAll('{invalid}', '${preview.invalidRowCount}')
        .replaceAll('{confirmation}', '${preview.confirmationRowCount}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(summary, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        LedgerSection(
          title: context.l10n.text('importPreview'),
          uppercaseTitle: false,
          children: [for (final row in preview.rows) _previewRow(row)],
        ),
        if (preview.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.text('importNoValidRows')),
          ),
      ],
    );
  }

  Widget _previewRow(AssetImportPreviewRow row) {
    final isInvalid = row.status == AssetImportPreviewRowStatus.invalid;
    final needsConfirmation =
        row.status == AssetImportPreviewRowStatus.requiresConfirmation;
    final hasFailedResult = _results.any(
      (result) =>
          result.sourceRowNumber == row.rowNumber &&
          result.status != 'SUCCEEDED',
    );
    final name = row.canonicalValues['name']?.trim();
    final detail = row.type == AssetImportType.serialized
        ? row.canonicalValues['serial_code']
        : row.canonicalValues['quantity'];
    final issues = row.issues.map((issue) => issue.message).join(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isInvalid
                ? Icons.error_outline
                : needsConfirmation
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: isInvalid
                ? context.relay.danger
                : needsConfirmation
                ? context.relay.warning
                : context.relay.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${row.rowNumber}  ${name?.isNotEmpty == true ? name : '-'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${detail ?? '-'}  ·  ${row.canonicalValues['warehouse'] ?? '-'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (issues.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(issues, style: TextStyle(color: context.relay.danger)),
                ],
                if (needsConfirmation) ...[
                  const SizedBox(height: 4),
                  Text(issues, style: TextStyle(color: context.relay.warning)),
                ],
              ],
            ),
          ),
          if (needsConfirmation)
            Checkbox(
              value: _confirmedRows.contains(row.rowNumber),
              onChanged: _busy
                  ? null
                  : (value) =>
                        _toggleConfirmation(row.rowNumber, value == true),
            ),
          if (isInvalid || needsConfirmation || hasFailedResult)
            IconButton(
              tooltip: context.l10n.text('editImportRow'),
              onPressed: _busy ? null : () => _editRow(row),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
    );
  }

  Widget _resultBody() {
    final succeeded = _results.where((row) => row.status == 'SUCCEEDED').length;
    final failed = _results.length - succeeded;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RelayNotice(
            message: failed == 0
                ? context.l10n.text('importCompleted')
                : context.l10n.text('importPartial'),
            kind: failed == 0
                ? RelayNoticeKind.success
                : RelayNoticeKind.warning,
          ),
          const SizedBox(height: 10),
          LedgerSection(
            title: context.l10n.text('importResult'),
            uppercaseTitle: false,
            children: [
              for (final result in _results)
                ListTile(
                  dense: true,
                  leading: Icon(
                    result.status == 'SUCCEEDED'
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: result.status == 'SUCCEEDED'
                        ? context.relay.success
                        : context.relay.danger,
                  ),
                  title: Text('#${result.sourceRowNumber}'),
                  subtitle: Text(
                    result.status == 'SUCCEEDED'
                        ? (result.action ??
                              context.l10n.text('importResultCreated'))
                        : (result.errorMessage ??
                              context.l10n.text('importResultFailed')),
                  ),
                ),
            ],
          ),
          if (failed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(context.l10n.text('importRetry')),
            ),
          Text(
            '$succeeded / ${_results.length}',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _AssetImportRowEditor extends StatefulWidget {
  const _AssetImportRowEditor({
    required this.rowNumber,
    required this.initialValues,
  });

  final int rowNumber;
  final Map<String, String?> initialValues;

  @override
  State<_AssetImportRowEditor> createState() => _AssetImportRowEditorState();
}

class _AssetImportRowEditorState extends State<_AssetImportRowEditor> {
  late final TextEditingController _name;
  late final TextEditingController _warehouse;
  late final TextEditingController _mode;
  late final TextEditingController _detail;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialValues['name'] ?? '');
    _warehouse = TextEditingController(
      text: widget.initialValues['warehouse'] ?? '',
    );
    _mode = TextEditingController(text: widget.initialValues['mode'] ?? '');
    final isSerialized =
        _mode.text.trim().toUpperCase() == 'SERIALIZED' ||
        (widget.initialValues['serial_code']?.trim().isNotEmpty ?? false);
    final detailKey = isSerialized ? 'serial_code' : 'quantity';
    _detail = TextEditingController(
      text: widget.initialValues[detailKey] ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _warehouse.dispose();
    _mode.dispose();
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSerialized = _mode.text.trim().toUpperCase() == 'SERIALIZED';
    return AlertDialog(
      title: Text('${context.l10n.text('editImportRow')} #${widget.rowNumber}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.text('importEditRowBody'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.l10n.text('name'),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _mode.text.isEmpty ? null : _mode.text,
                decoration: InputDecoration(
                  labelText: context.l10n.text('importMode'),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'SERIALIZED',
                    child: Text('SERIALIZED'),
                  ),
                  DropdownMenuItem(value: 'BULK', child: Text('BULK')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _mode.text = value;
                    _detail.clear();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detail,
                decoration: InputDecoration(
                  labelText: context.l10n.text(
                    isSerialized ? 'serialNumber' : 'physicalQuantity',
                  ),
                ),
                keyboardType: isSerialized
                    ? TextInputType.text
                    : TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _warehouse,
                decoration: InputDecoration(
                  labelText: context.l10n.text('warehouse'),
                ),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.text('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
            'name': _name.text,
            'mode': _mode.text,
            if (isSerialized) 'serial_code': _detail.text,
            if (!isSerialized) 'quantity': _detail.text,
            'warehouse': _warehouse.text,
          }),
          child: Text(context.l10n.text('applyImportEdit')),
        ),
      ],
    );
  }
}
