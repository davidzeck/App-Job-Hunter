import 'package:flutter/foundation.dart';

/// Holds an optional company filter that the Jobs screen reads reactively.
///
/// Flow: CompaniesScreen sets [filterByCompany] → navigates to /jobs →
/// JobsScreen listener fires → reloads with [companySlug] passed to the API.
class JobsFilterProvider extends ChangeNotifier {
  String? _companySlug;
  String? _companyName;

  String? get companySlug => _companySlug;
  String? get companyName => _companyName;
  bool get hasCompanyFilter => _companySlug != null;

  void filterByCompany(String slug, String name) {
    _companySlug = slug;
    _companyName = name;
    notifyListeners();
  }

  void clearCompanyFilter() {
    _companySlug = null;
    _companyName = null;
    notifyListeners();
  }
}
