import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/relay_ui.dart';
import '../../app/theme.dart';
import '../../l10n/relay_localizations.dart';
import '../../shared/async_ui_controller.dart';
import '../../shared/ledger_widgets.dart';
import '../../shared/relay_failure.dart';
import '../../shared/relay_image_editor.dart';
import '../access/access_models.dart';
import 'transfer_evidence_repository.dart';
import 'transfer_evidence_models.dart';
import 'transfer_models.dart';

typedef EvidenceImagePicker = Future<XFile?> Function(ImageSource source);

enum _EvidenceOperation { idle, loading, adding }

class TransferEvidencePage extends ConsumerStatefulWidget {
  const TransferEvidencePage({
    required this.company,
    required this.transfer,
    required this.phase,
    required this.allowCapture,
    this.pickImage,
    this.editImage,
    super.key,
  });

  final RelayCompany company;
  final TransferRecord transfer;
  final EvidencePhase phase;
  final bool allowCapture;
  final EvidenceImagePicker? pickImage;
  final RelayImageEdit? editImage;

  @override
  ConsumerState<TransferEvidencePage> createState() =>
      _TransferEvidencePageState();
}

class _TransferEvidencePageState extends ConsumerState<TransferEvidencePage>
    with AppResumeRefreshMixin<TransferEvidencePage> {
  final _picker = ImagePicker();
  final _items = <TransferEvidenceRecord>[];
  final _requests = LatestRequestGate();
  var _operation = _EvidenceOperation.idle;
  var _hasMore = true;
  String? _error;

  bool get _loading => _operation == _EvidenceOperation.loading;
  bool get _adding => _operation == _EvidenceOperation.adding;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false, bool preserveItems = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final request = _requests.begin();
    final after = reset || _items.isEmpty ? null : _items.last;
    setState(() {
      _operation = _EvidenceOperation.loading;
      _error = null;
      if (reset) {
        if (!preserveItems) _items.clear();
        _hasMore = true;
      }
    });
    try {
      final page = await ref
          .read(transferEvidenceRepositoryProvider)
          .list(
            transferId: widget.transfer.id,
            phase: widget.phase,
            after: after,
          );
      if (!mounted || !_requests.isCurrent(request)) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page);
        _hasMore = page.length == 10;
      });
    } catch (error) {
      if (mounted && _requests.isCurrent(request)) {
        setState(
          () => _error = RelayFailure.from(error).message(
            l10n: context.l10n,
            fallback: context.l10n.text('evidenceLoadFailed'),
          ),
        );
      }
    } finally {
      if (mounted && _requests.isCurrent(request)) {
        setState(() => _operation = _EvidenceOperation.idle);
      }
    }
  }

  Future<void> _choose(TransferLineRecord line) async {
    if (_adding) return;
    final source = await showRelaySheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(context.l10n.text('takePhoto')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.text('choosePhoto')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted || _adding) return;

    setState(() {
      _operation = _EvidenceOperation.adding;
      _error = null;
    });
    try {
      final image = widget.pickImage == null
          ? await _picker.pickImage(source: source)
          : await widget.pickImage!(source);
      if (image == null || !mounted) return;
      if (image.mimeType != null && image.mimeType != 'image/jpeg') {
        setState(() => _error = context.l10n.text('jpegOnly'));
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() => _error = context.l10n.text('imageTooLarge'));
        return;
      }
      // Existing picker injections are test seams and already provide the
      // final bytes; production picker flows go through the editor.
      final edited = widget.editImage == null && widget.pickImage != null
          ? bytes
          : await (widget.editImage ?? editRelayImage)(context, bytes);
      if (edited == null || !mounted) return;
      await _upload(line, edited);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = RelayFailure.from(error).message(
            l10n: context.l10n,
            fallback: context.l10n.text('evidenceUploadFailed'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _operation = _EvidenceOperation.idle);
    }
  }

  Future<void> _upload(TransferLineRecord line, Uint8List bytes) async {
    await ref
        .read(transferEvidenceRepositoryProvider)
        .upload(
          companyId: widget.company.id,
          transferId: widget.transfer.id,
          lineId: line.id,
          phase: widget.phase,
          bytes: bytes,
        );
    if (!mounted) return;
    await _load(reset: true, preserveItems: true);
  }

  @override
  Future<void> refreshAfterAppResume() async {
    if (_adding) return;
    await _load(reset: true, preserveItems: true);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.phase == EvidencePhase.departure
        ? context.l10n.text('departureEvidence')
        : context.l10n.text('arrivalEvidence');
    return PopScope(
      canPop: !_adding,
      child: LedgerPage(
        title: title,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            RelayNotice(
              message: context.l10n.text(
                widget.allowCapture
                    ? 'evidenceOptional60Days'
                    : 'evidenceReadOnly60Days',
              ),
              kind: RelayNoticeKind.info,
            ),
            const SizedBox(height: 18),
            for (final line in widget.transfer.lines) ...[
              _LineEvidenceSection(
                line: line,
                evidence: _items
                    .where((item) => item.lineId == line.id)
                    .toList(),
                canAdd:
                    widget.allowCapture &&
                    !_adding &&
                    _items
                            .where(
                              (item) =>
                                  item.lineId == line.id && !item.isExpired,
                            )
                            .length <
                        7,
                onAdd: () => _choose(line),
              ),
              const Divider(height: 28),
            ],
            if (_error != null)
              RelayNotice(message: _error!, kind: RelayNoticeKind.danger),
            if (_loading || _adding)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loading && !_adding && _items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  context.l10n.text('noEvidenceYet'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.relay.textSecondary),
                ),
              ),
            if (_hasMore && !_loading && !_adding)
              OutlinedButton(
                onPressed: _load,
                child: Text(context.l10n.text('loadMore')),
              ),
          ],
        ),
      ),
    );
  }
}

class _LineEvidenceSection extends ConsumerWidget {
  const _LineEvidenceSection({
    required this.line,
    required this.evidence,
    required this.canAdd,
    required this.onAdd,
  });
  final TransferLineRecord line;
  final List<TransferEvidenceRecord> evidence;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(line.asset.name, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 2),
      Text(
        context.l10n
            .text('evidencePhotoCount')
            .replaceFirst('{count}', '${evidence.length}'),
        style: TextStyle(color: context.relay.textSecondary),
      ),
      const SizedBox(height: 10),
      if (evidence.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in evidence) _EvidenceThumbnail(evidence: item),
          ],
        ),
      if (canAdd)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(context.l10n.text('addEvidencePhoto')),
          ),
        ),
    ],
  );
}

class _EvidenceThumbnail extends ConsumerWidget {
  const _EvidenceThumbnail({required this.evidence});
  final TransferEvidenceRecord evidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (evidence.isExpired) {
      return _thumbnailFrame(
        context,
        const Icon(Icons.history_toggle_off_outlined),
      );
    }
    return InkWell(
      onTap: () => Navigator.of(context).push(
        relayRoute(builder: (_) => _EvidenceImagePage(evidence: evidence)),
      ),
      child: FutureBuilder<Uint8List>(
        future: ref
            .read(transferEvidenceRepositoryProvider)
            .thumbnailBytes(evidence),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                snapshot.data!,
                width: 82,
                height: 82,
                fit: BoxFit.cover,
              ),
            );
          }
          return _thumbnailFrame(
            context,
            const CircularProgressIndicator(strokeWidth: 2),
          );
        },
      ),
    );
  }

  Widget _thumbnailFrame(BuildContext context, Widget child) => Container(
    width: 82,
    height: 82,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: context.relay.structuralLine),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}

class _EvidenceImagePage extends ConsumerWidget {
  const _EvidenceImagePage({required this.evidence});
  final TransferEvidenceRecord evidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LedgerPage(
    title: evidence.assetName,
    child: Center(
      child: FutureBuilder<Uint8List>(
        future: ref
            .read(transferEvidenceRepositoryProvider)
            .fullBytes(evidence),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return InteractiveViewer(child: Image.memory(snapshot.data!));
          }
          if (snapshot.hasError) {
            return Text(context.l10n.text('evidenceImageUnavailable'));
          }
          return const CircularProgressIndicator();
        },
      ),
    ),
  );
}
