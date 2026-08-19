import 'package:flutter_riverpod/legacy.dart';

import 'entity_lifecycle.dart';

enum CompanyListScopeKey { customer, location, asset }

final companyListArchiveScopeProvider =
    StateProvider.family<ArchiveScope, CompanyListScopeKey>(
      (ref, key) => ArchiveScope.working,
    );
