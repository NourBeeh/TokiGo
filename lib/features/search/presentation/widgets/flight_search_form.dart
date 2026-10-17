import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/features/search/application/providers/search_providers.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

class FlightSearchForm extends ConsumerStatefulWidget {
  final String? initialOrigin;
  final String? initialDestination;
  final DateTime? initialDeparture;
  final void Function(String origin, String destination)? onRouteChanged;
  final VoidCallback? onSearchStarted;

  const FlightSearchForm({
    super.key,
    this.initialOrigin,
    this.initialDestination,
    this.initialDeparture,
    this.onRouteChanged,
    this.onSearchStarted,
  });

  @override
  ConsumerState<FlightSearchForm> createState() => _FlightSearchFormState();
}

class _FlightSearchFormState extends ConsumerState<FlightSearchForm> {
  late final TextEditingController _originCtrl;
  late final TextEditingController _destCtrl;
  late DateTime _departure;

  static const List<(String, String)> _popularRoutes = [
    ('Cairo', 'Dubai'),
    ('Jeddah', 'Cairo'),
    ('London', 'Paris'),
    ('Riyadh', 'Dubai'),
    ('Istanbul', 'Cairo'),
  ];

  @override
  void initState() {
    super.initState();
    _originCtrl = TextEditingController(text: widget.initialOrigin ?? '');
    _destCtrl = TextEditingController(text: widget.initialDestination ?? '');
    _departure = widget.initialDeparture ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  void _notifyRoute() =>
      widget.onRouteChanged?.call(_originCtrl.text, _destCtrl.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Origin Field
        _buildField(
          icon: Icons.flight_takeoff,
          child: TextField(
            controller: _originCtrl,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'From where?',
              hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => _notifyRoute(),
            onSubmitted: (_) => _search(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Destination Field
        _buildField(
          icon: Icons.flight_land,
          child: TextField(
            controller: _destCtrl,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Where to?',
              hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => _notifyRoute(),
            onSubmitted: (_) => _search(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Departure date field
        _buildField(
          icon: Icons.calendar_today_outlined,
          child: GestureDetector(
            onTap: _pickDate,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Departure',
                          style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                      Text(DateFormat('EEE, MMM d').format(_departure),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D1D1F))),
                    ],
                  ),
                ),
                const Icon(Icons.expand_more, size: 18, color: Color(0xFF8E8E93)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Search button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search, size: 20),
            label: const Text('Search Flights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),

        // Popular routes chips
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _popularRoutes.map((route) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _applyRoute(route.$1, route.$2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text('${route.$1} → ${route.$2}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildField({required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  void _applyRoute(String from, String to) {
    setState(() {
      _originCtrl.text = from;
      _destCtrl.text = to;
    });
    _notifyRoute();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _departure,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _departure = picked);
  }

  void _search() {
    widget.onSearchStarted?.call();
    final params = FlightSearchParams(
      origin: _originCtrl.text,
      destination: _destCtrl.text,
      departureDate: _departure,
    );
    ref.read(flightSearchControllerProvider.notifier).search(params);
  }
}
