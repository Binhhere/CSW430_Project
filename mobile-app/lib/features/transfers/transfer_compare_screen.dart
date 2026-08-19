import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/relay_ui.dart';
import '../../app/theme.dart';
import '../../l10n/relay_localizations.dart';
import '../../shared/ledger_widgets.dart';
import '../access/access_models.dart';
import 'transfer_evidence_repository.dart';
import 'transfer_evidence_models.dart';
import 'transfer_models.dart';

class TransferCompareAssetPage extends StatelessWidget {
  const TransferCompareAssetPage({
    required this.company,
    required this.transfer,
    super.key,
  });

  final RelayCompany company;
  final TransferRecord transfer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Align(
        alignment: Alignment.centerLeft,
        child: Text(context.l10n.text('compareEvidence')),
      ),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          Text(
            context.l10n.text('chooseCompareAsset'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < transfer.lines.length; index++) ...[
            _CompareAssetRow(
              line: transfer.lines[index],
              onTap: () => Navigator.of(context).push(
                relayRoute(
                  builder: (_) => TransferComparePage(
                    company: company,
                    transfer: transfer,
                    line: transfer.lines[index],
                  ),
                ),
              ),
            ),
            if (index < transfer.lines.length - 1) const Divider(height: 1),
          ],
          if (transfer.lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                context.l10n.text('noCompareAssets'),
                style: TextStyle(color: context.relay.textSecondary),
              ),
            ),
        ],
      ),
    ),
  );
}

class _CompareAssetRow extends StatelessWidget {
  const _CompareAssetRow({required this.line, required this.onTap});

  final TransferLineRecord line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: line.asset.name,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.relay.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: context.relay.textSecondary,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  line.asset.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(Icons.chevron_right, color: context.relay.textSecondary),
            ],
          ),
        ),
      ),
    ),
  );
}

class TransferComparePage extends ConsumerStatefulWidget {
  const TransferComparePage({
    required this.company,
    required this.transfer,
    required this.line,
    super.key,
  });

  final RelayCompany company;
  final TransferRecord transfer;
  final TransferLineRecord line;

  @override
  ConsumerState<TransferComparePage> createState() =>
      _TransferComparePageState();
}

class _TransferComparePageState extends ConsumerState<TransferComparePage> {
  final _thumbnailFutures = <String, Future<Uint8List>>{};
  final _fullImageFutures = <String, Future<Uint8List>>{};
  var _loading = true;
  var _request = 0;
  String? _error;
  List<TransferEvidenceRecord> _departure = const [];
  List<TransferEvidenceRecord> _arrival = const [];
  TransferEvidenceRecord? _selectedDeparture;
  TransferEvidenceRecord? _selectedArrival;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _loadPhase(EvidencePhase.departure),
        _loadPhase(EvidencePhase.arrival),
      ]);
      if (!mounted || request != _request) return;
      setState(() {
        _departure = results[0];
        _arrival = results[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = context.l10n.text('compareLoadFailed');
      });
    }
  }

  Future<List<TransferEvidenceRecord>> _loadPhase(EvidencePhase phase) async {
    final repository = ref.read(transferEvidenceRepositoryProvider);
    final result = <TransferEvidenceRecord>[];
    TransferEvidenceRecord? after;
    while (true) {
      final page = await repository.list(
        transferId: widget.transfer.id,
        phase: phase,
        after: after,
      );
      result.addAll(
        page.where((item) => item.lineId == widget.line.id && !item.isExpired),
      );
      if (page.length < 10) break;
      final next = page.last;
      if (after?.id == next.id && after?.createdAt == next.createdAt) {
        throw StateError('Evidence pagination did not advance');
      }
      after = next;
    }
    return result;
  }

  Future<Uint8List> _thumbnail(TransferEvidenceRecord evidence) =>
      _thumbnailFutures[evidence.id] ??= ref
          .read(transferEvidenceRepositoryProvider)
          .thumbnailBytes(evidence);

  Future<Uint8List> _fullImage(TransferEvidenceRecord evidence) =>
      _fullImageFutures[evidence.id] ??= ref
          .read(transferEvidenceRepositoryProvider)
          .fullBytes(evidence);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Align(
        alignment: Alignment.centerLeft,
        child: Text(context.l10n.text('compareEvidence')),
      ),
    ),
    body: SafeArea(
      top: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  Text(
                    widget.line.asset.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 18),
                  if (_error != null) ...[
                    RelayNotice(message: _error!, kind: RelayNoticeKind.danger),
                    const SizedBox(height: 16),
                  ],
                  _ComparePreview(
                    departure: _selectedDeparture,
                    arrival: _selectedArrival,
                    fullImage: _fullImage,
                    emptyLabel: context.l10n.text('compareSelectPhoto'),
                  ),
                  const SizedBox(height: 24),
                  _EvidenceRail(
                    phase: EvidencePhase.departure,
                    items: _departure,
                    selected: _selectedDeparture,
                    thumbnail: _thumbnail,
                    onSelected: (value) =>
                        setState(() => _selectedDeparture = value),
                  ),
                  const Divider(height: 28),
                  _EvidenceRail(
                    phase: EvidencePhase.arrival,
                    items: _arrival,
                    selected: _selectedArrival,
                    thumbnail: _thumbnail,
                    onSelected: (value) =>
                        setState(() => _selectedArrival = value),
                  ),
                ],
              ),
            ),
    ),
  );
}

class _ComparePreview extends StatelessWidget {
  const _ComparePreview({
    required this.departure,
    required this.arrival,
    required this.fullImage,
    required this.emptyLabel,
  });

  final TransferEvidenceRecord? departure;
  final TransferEvidenceRecord? arrival;
  final Future<Uint8List> Function(TransferEvidenceRecord) fullImage;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _CompareSlot(
          label: context.l10n.text('departure'),
          evidence: departure,
          fullImage: fullImage,
          emptyLabel: emptyLabel,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _CompareSlot(
          label: context.l10n.text('arrival'),
          evidence: arrival,
          fullImage: fullImage,
          emptyLabel: emptyLabel,
        ),
      ),
    ],
  );
}

class _CompareSlot extends StatelessWidget {
  const _CompareSlot({
    required this.label,
    required this.evidence,
    required this.fullImage,
    required this.emptyLabel,
  });

  final String label;
  final TransferEvidenceRecord? evidence;
  final Future<Uint8List> Function(TransferEvidenceRecord) fullImage;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.relay.textSecondary,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: RelayMotion.micro,
        child: evidence == null
            ? _CompareEmpty(key: const ValueKey('empty'), label: emptyLabel)
            : _CompareImage(
                key: ValueKey(evidence!.id),
                evidence: evidence!,
                fullImage: fullImage,
              ),
      ),
    ],
  );
}

class _CompareEmpty extends StatelessWidget {
  const _CompareEmpty({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: .82,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: context.relay.structuralLine),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              color: context.relay.textMuted,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.relay.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CompareImage extends StatelessWidget {
  const _CompareImage({
    required this.evidence,
    required this.fullImage,
    super.key,
  });

  final TransferEvidenceRecord evidence;
  final Future<Uint8List> Function(TransferEvidenceRecord) fullImage;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: .82,
    child: FutureBuilder<Uint8List>(
      future: fullImage(evidence),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(snapshot.data!, fit: BoxFit.cover),
          );
        }
        if (snapshot.hasError) {
          return _CompareEmpty(
            label: context.l10n.text('evidenceImageUnavailable'),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    ),
  );
}

class _EvidenceRail extends StatelessWidget {
  const _EvidenceRail({
    required this.phase,
    required this.items,
    required this.selected,
    required this.thumbnail,
    required this.onSelected,
  });

  final EvidencePhase phase;
  final List<TransferEvidenceRecord> items;
  final TransferEvidenceRecord? selected;
  final Future<Uint8List> Function(TransferEvidenceRecord) thumbnail;
  final ValueChanged<TransferEvidenceRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedCount = selected == null ? 0 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                phase.wireValue,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.relay.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              context.l10n
                  .text('selectedCount')
                  .replaceAll('{count}', '$selectedCount'),
              style: TextStyle(color: context.relay.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(
            context.l10n.text('noEvidenceYet'),
            style: TextStyle(color: context.relay.textSecondary),
          )
        else
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final evidence = items[index];
                return _EvidenceChoice(
                  evidence: evidence,
                  selected: evidence.id == selected?.id,
                  thumbnail: thumbnail,
                  onTap: () => onSelected(evidence),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EvidenceChoice extends StatelessWidget {
  const _EvidenceChoice({
    required this.evidence,
    required this.selected,
    required this.thumbnail,
    required this.onTap,
  });

  final TransferEvidenceRecord evidence;
  final bool selected;
  final Future<Uint8List> Function(TransferEvidenceRecord) thumbnail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: context.l10n.text(selected ? 'selectedPhoto' : 'selectPhoto'),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            width: 82,
            height: 82,
            padding: EdgeInsets.all(selected ? 2 : 0),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? context.relay.selectedContent
                    : context.relay.structuralLine,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FutureBuilder<Uint8List>(
                future: thumbnail(evidence),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Image.memory(snapshot.data!, fit: BoxFit.cover);
                  }
                  if (snapshot.hasError) {
                    return Icon(
                      Icons.broken_image_outlined,
                      color: context.relay.textMuted,
                    );
                  }
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: 3,
              bottom: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.relay.selectedContent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 18,
                  color: context.relay.onActionPrimary,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
