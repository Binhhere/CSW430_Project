import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/relay_ui.dart';
import '../../app/theme.dart';
import '../../l10n/relay_localizations.dart';
import '../../shared/async_ui_controller.dart';
import '../../shared/company_list_scope_state.dart';
import '../../shared/dirty_form_guard.dart';
import '../../shared/entity_lifecycle.dart';
import '../../shared/entity_lifecycle_widgets.dart';
import '../../shared/ledger_widgets.dart';
import '../../shared/paged_load_controller.dart';
import '../../shared/paged_list_body.dart';
import '../../shared/selection_controller.dart';
import '../../shared/relay_failure.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';
import 'catalog_actions.dart';

part 'customer_list_page.dart';
part 'location_list_page.dart';
part 'customer_detail_page.dart';
part 'location_detail_page.dart';
part 'customer_form_page.dart';
part 'location_form_page.dart';
part 'catalog_widgets.dart';
