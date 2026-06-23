import 'package:flutter/material.dart';
import '../../core/app_strings.dart';

class FilterField {
  final String id;
  final String label;
  final FilterFieldType type;
  final List<String>? options;

  const FilterField({
    required this.id,
    required this.label,
    this.type = FilterFieldType.text,
    this.options,
  });
}

enum FilterFieldType { text, dropdown, chip, dateRange }

class FilterBottomSheet extends StatefulWidget {
  final List<FilterField> fields;
  final Map<String, dynamic> initialFilters;
  final ValueChanged<Map<String, dynamic>> onApply;
  final VoidCallback? onReset;

  const FilterBottomSheet({
    super.key,
    required this.fields,
    this.initialFilters = const {},
    required this.onApply,
    this.onReset,
  });

  static Future<void> show({
    required BuildContext context,
    required List<FilterField> fields,
    Map<String, dynamic> initialFilters = const {},
    required ValueChanged<Map<String, dynamic>> onApply,
    VoidCallback? onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => FilterBottomSheet(
        fields: fields,
        initialFilters: initialFilters,
        onApply: onApply,
        onReset: onReset,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Map<String, dynamic> _filters;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _filters = Map<String, dynamic>.from(widget.initialFilters);
    final fromStr = _filters['date_from'] as String?;
    final toStr = _filters['date_to'] as String?;
    if (fromStr != null && toStr != null) {
      final from = DateTime.tryParse(fromStr);
      final to = DateTime.tryParse(toStr);
      if (from != null && to != null) {
        _dateRange = DateTimeRange(start: from, end: to);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(S.t('action_filter'), style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (widget.onReset != null)
                TextButton(
                  onPressed: () { widget.onReset!(); Navigator.pop(context); },
                  child: Text(S.t('log_reset_filters')),
                ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: widget.fields.map((f) => _buildField(f)).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_dateRange != null) {
                  _filters['date_from'] = _dateRange!.start.toIso8601String();
                  _filters['date_to'] = _dateRange!.end.toIso8601String();
                }
                widget.onApply(_filters);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(S.t('action_apply')),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildField(FilterField field) {
    switch (field.type) {
      case FilterFieldType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => _filters[field.id] = v.isEmpty ? null : v,
          ),
        );
      case FilterFieldType.dropdown:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: _filters[field.id] as String?,
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem<String>(value: null, child: Text(S.t('filter_all_select'))),
              if (field.options != null)
                ...field.options!.map(
                  (o) => DropdownMenuItem<String>(value: o, child: Text(o)),
                ),
            ],
            onChanged: (v) => _filters[field.id] = v,
          ),
        );
      case FilterFieldType.chip:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 4),
              if (field.options != null)
                Wrap(
                  spacing: 6,
                  children: field.options!.map((o) {
                    final selected = _filters[field.id] == o;
                    return FilterChip(
                      label: Text(o, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (_) => setState(() => _filters[field.id] = selected ? null : o),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      case FilterFieldType.dateRange:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                initialDateRange: _dateRange,
              );
              if (picked != null) setState(() => _dateRange = picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: field.label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              child: Text(
                _dateRange != null
                    ? '${_dateRange!.start.toLocal().toString().substring(0, 10)} → ${_dateRange!.end.toLocal().toString().substring(0, 10)}'
                    : S.t('filter_select_period'),
              ),
            ),
          ),
        );
    }
  }
}
