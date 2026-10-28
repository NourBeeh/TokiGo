enum SearchViewMode { list, map }

extension SearchViewModeExt on SearchViewMode {
  String get label => name[0].toUpperCase() + name.substring(1);
  String get icon => this == SearchViewMode.list ? 'list' : 'map';
}
