part of 'catalog_screens.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({required this.companyId, this.existing, super.key});
  final String companyId;
  final CustomerRecord? existing;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _contact = TextEditingController(
    text: widget.existing?.contactName,
  );
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  final _dirtyForm = DirtyFormController();
  var _busy = false;
  String? _error;

  bool get _isDirty =>
      _name.text.trim() != (widget.existing?.name ?? '') ||
      _contact.text.trim() != (widget.existing?.contactName ?? '') ||
      _email.text.trim() != (widget.existing?.email ?? '') ||
      _phone.text.trim() != (widget.existing?.phone ?? '');

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
    _contact.addListener(_refreshPopState);
    _email.addListener(_refreshPopState);
    _phone.addListener(_refreshPopState);
  }

  void _refreshPopState() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _email.dispose();
    _phone.dispose();
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
          .saveCustomer(
            companyId: widget.companyId,
            customerId: widget.existing?.id,
            name: _name.text,
            contactName: _contact.text,
            email: _email.text,
            phone: _phone.text,
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
          ? context.l10n.text('createCustomer')
          : context.l10n.text('editCustomer'),
      bottom: BusyButton(
        label: context.l10n.text('saveCustomer'),
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
              const SizedBox(height: 16),
              _FieldLabel(label: context.l10n.text('contactName')),
              TextFormField(
                controller: _contact,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: context.l10n.text('contactName'),
                ),
              ),
              const SizedBox(height: 16),
              _FieldLabel(label: context.l10n.text('phone')),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: context.l10n.text('phone'),
                ),
              ),
              const SizedBox(height: 16),
              _FieldLabel(label: context.l10n.text('email')),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: context.l10n.text('email'),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty || value.contains('@')
                    ? null
                    : context.l10n.text('invalidEmail'),
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
