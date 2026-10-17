import 'package:flutter/material.dart';
import 'package:tokigo/features/search/domain/sort_option.dart';

class SortSelector extends StatelessWidget {
  final SortOption selected;
  final ValueChanged<SortOption> onChanged;
  const SortSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sort results',
      child: DropdownButton<SortOption>(
        value: selected,
        items: SortOption.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }
}
