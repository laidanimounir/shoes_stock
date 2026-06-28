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
      barrierColor: Colors.black54,
      backgroundColor: const Color(0xFF13131F),
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

  static const _bgCard = Color(0xFF13131F);
  static const _bgInput = Color(0xFF1E1E2E);
  static const _borderDefault = Color(0xFF1E1E35);
  static const _accentGold = Color(0xFFF0A500);
  static const _textPrimary = Color(0xFFEEEEFF);
  static const _textSecondary = Color(0xFF9090A8);
  static const _textMuted = Color(0xFF606078);
  static const _bgPage = Color(0xFF0A0A14);

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
              Text(S.t('action_filter'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary)),
              const Spacer(),
              if (widget.onReset != null)
                TextButton(
                  onPressed: () {
                    widget.onReset!();
                    Navigator.pop(context);
                  },
                  child: Text(S.t('log_reset_filters'),
                      style: const TextStyle(color: _textSecondary)),
                ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon:
                    const Icon(Icons.close, color: _textMuted),
              ),
            ],
          ),
          const Divider(color: _borderDefault, thickness: 1),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children:
                    widget.fields.map((f) => _buildField(f)).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_dateRange != null) {
                  _filters['date_from'] =
                      _dateRange!.start.toIso8601String();
                  _filters['date_to'] =
                      _dateRange!.end.toIso8601String();
                }
                widget.onApply(_filters);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGold,
                foregroundColor: _bgPage,
                elevation: 0,
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
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
    final inputDec = InputDecoration(
      labelText: field.label,
      labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
      filled: true,
      fillColor: _bgInput,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _accentGold),
      ),
      isDense: true,
    );

    switch (field.type) {
      case FilterFieldType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            cursorColor: _accentGold,
            style:
                const TextStyle(color: _textPrimary, fontSize: 14),
            decoration: inputDec,
            onChanged: (v) =>
                _filters[field.id] = v.isEmpty ? null : v,
          ),
        );
      case FilterFieldType.dropdown:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: _filters[field.id] as String?,
            dropdownColor: _bgCard,
            style:
                const TextStyle(color: _textPrimary, fontSize: 14),
            icon:
                const Icon(Icons.keyboard_arrow_down, color: _textMuted),
            decoration: inputDec,
            items: [
              DropdownMenuItem<String>(
                  value: null, child: Text(S.t('filter_all_select'))),
              if (field.options != null)
                ...field.options!.map(
                  (o) => DropdownMenuItem<String>(
                      value: o, child: Text(o)),
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
              Text(field.label,
                  style: const TextStyle(
                      fontSize: 13, color: _textMuted)),
              const SizedBox(height: 4),
              if (field.options != null)
                Wrap(
                  spacing: 6,
                  children: field.options!.map((o) {
                    final selected = _filters[field.id] == o;
                    return FilterChip(
                      label: Text(o,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? _bgPage
                                  : _textPrimary)),
                      selected: selected,
                      backgroundColor: _bgInput,
                      selectedColor: _accentGold,
                      checkmarkColor: _bgPage,
                      side: BorderSide(
                        color: selected
                            ? _accentGold
                            : _borderDefault,
                      ),
                      onSelected: (_) => setState(() =>
                          _filters[field.id] =
                              selected ? null : o),
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
              decoration: inputDec.copyWith(
                labelText: field.label,
              ),
              child: Text(
                _dateRange != null
                    ? '${_dateRange!.start.toLocal().toString().substring(0, 10)} → ${_dateRange!.end.toLocal().toString().substring(0, 10)}'
                    : S.t('filter_select_period'),
                style: const TextStyle(
                    color: _textSecondary, fontSize: 14),
              ),
            ),
          ),
        );
    }
  }
}
