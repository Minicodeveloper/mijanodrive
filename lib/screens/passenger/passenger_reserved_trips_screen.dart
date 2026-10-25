import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../models/tariff_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';

class PassengerReservedTripsScreen extends StatefulWidget {
  const PassengerReservedTripsScreen({
    super.key,
    this.initialTripId,
    this.openCreateOnStart = false,
  });

  final String? initialTripId;
  final bool openCreateOnStart;

  @override
  State<PassengerReservedTripsScreen> createState() =>
      _PassengerReservedTripsScreenState();
}

class _PassengerReservedTripsScreenState
    extends State<PassengerReservedTripsScreen> {
  String _selectedFilter = 'activas'; // 'activas' | 'historial'

  @override
  void initState() {
    super.initState();
    if (widget.openCreateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openNewReservationSheet();
        }
      });
    }
  }

  void _openNewReservationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateReservationBottomSheet(),
    );
  }

  Future<void> _confirmCancelReservation(
    BuildContext context,
    String tripId,
    String destination,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '¿Cancelar reserva?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se cancelará tu viaje programado hacia "$destination". ¿Deseas continuar?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Volver',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId)
            .update({
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
            });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reserva cancelada correctamente.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo cancelar la reserva: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passengerId = AuthService.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text(
          'Mis Reservas',
          style: TextStyle(
            color: MijanoTheme.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: MijanoTheme.sol,
        elevation: 0,
        iconTheme: const IconThemeData(color: MijanoTheme.ink),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: MijanoTheme.ink,
                foregroundColor: MijanoTheme.sol,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _openNewReservationSheet,
              icon: const Icon(Icons.add_alarm, size: 18, color: MijanoTheme.sol),
              label: const Text(
                'Reservar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: MijanoTheme.sol,
                ),
              ),
            ),
          ),
        ],
      ),
      body: passengerId.isEmpty
          ? const Center(
              child: Text(
                'Inicia sesión para gestionar tus reservas.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                // APARTADO EXCLUSIVO SUPERIOR POSICIONADO AL INICIO
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFF9D408),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9D408).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: Color(0xFFF9D408),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Apartado Exclusivo de Reservas',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Programa tu motokar con anticipación desde hoy hasta por 7 días.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF9D408),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _openNewReservationSheet,
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          label: const Text(
                            'Crear nueva reserva ahora',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // SELECTOR DE PESTAÑAS (ACTIVAS / HISTORIAL)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FilterTabButton(
                          label: 'Reservas Activas',
                          icon: Icons.schedule,
                          selected: _selectedFilter == 'activas',
                          onTap: () => setState(() => _selectedFilter = 'activas'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FilterTabButton(
                          label: 'Finalizadas / Canceladas',
                          icon: Icons.history,
                          selected: _selectedFilter == 'historial',
                          onTap: () => setState(() => _selectedFilter = 'historial'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // LISTA DE RESERVAS EN TIEMPO REAL
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('trips')
                        .where('passengerId', isEqualTo: passengerId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'No se pudieron cargar tus viajes reservados.',
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: MijanoTheme.ink,
                          ),
                        );
                      }

                      final allReservations =
                          snapshot.data?.docs.where((doc) {
                            final data = doc.data();
                            return data['serviceType'] == 'Programar viaje' ||
                                data['scheduledAt'] is Timestamp;
                          }).toList() ??
                          [];

                      final filteredReservations = allReservations.where((doc) {
                        final status =
                            (doc.data()['status'] ?? 'pending')
                                .toString()
                                .toLowerCase();
                        final isFinished =
                            status == 'cancelled' ||
                            status == 'completed' ||
                            status == 'finalized';
                        return _selectedFilter == 'activas'
                            ? !isFinished
                            : isFinished;
                      }).toList();

                      filteredReservations.sort((a, b) {
                        if (a.id == widget.initialTripId) return -1;
                        if (b.id == widget.initialTripId) return 1;
                        final dateA = a.data()['scheduledAt'];
                        final dateB = b.data()['scheduledAt'];
                        if (dateA is Timestamp && dateB is Timestamp) {
                          return _selectedFilter == 'activas'
                              ? dateA.compareTo(dateB)
                              : dateB.compareTo(dateA);
                        }
                        return dateA is Timestamp
                            ? -1
                            : dateB is Timestamp
                            ? 1
                            : 0;
                      });

                      if (filteredReservations.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedFilter == 'activas'
                                      ? Icons.event_busy
                                      : Icons.history_toggle_off,
                                  size: 56,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedFilter == 'activas'
                                      ? 'No tienes reservas activas en este momento.'
                                      : 'No tienes reservas finalizadas ni canceladas.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                                if (_selectedFilter == 'activas') ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Usa el botón superior "Crear nueva reserva ahora" para programar tu próximo viaje.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: filteredReservations.length,
                        itemBuilder: (context, index) {
                          final doc = filteredReservations[index];
                          final data = doc.data();
                          final scheduledAt = data['scheduledAt'];
                          final scheduledDate = scheduledAt is Timestamp
                              ? scheduledAt.toDate()
                              : null;
                          final rawStatus =
                              data['status']?.toString() ?? 'pending';
                          final statusText = _statusLabel(rawStatus);
                          final statusColor = _statusColor(rawStatus);
                          final fare =
                              (num.tryParse(
                                        data['fareAmount']?.toString() ?? '',
                                      ) ??
                                      0)
                                  .toDouble();
                          final distanceKm =
                              (num.tryParse(
                                        data['distanceKm']?.toString() ?? '',
                                      ) ??
                                      0)
                                  .toDouble();
                          final durationText =
                              data['durationText']?.toString() ?? '';
                          final paymentMethod =
                              data['paymentMethod']?.toString() ?? 'Efectivo';
                          final carriesCargo = data['carriesCargo'] == true;
                          final isHighlighted = doc.id == widget.initialTripId;
                          final canCancel =
                              rawStatus.toLowerCase() == 'pending' ||
                              rawStatus.toLowerCase() == 'accepted';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isHighlighted
                                    ? const Color(0xFFF9D408)
                                    : Colors.black12,
                                width: isHighlighted ? 2 : 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9D408)
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.event_available,
                                          color: Colors.black87,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              scheduledDate == null
                                                  ? 'Fecha pendiente'
                                                  : '${MaterialLocalizations.of(context).formatMediumDate(scheduledDate)} · '
                                                        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledDate))}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: MijanoTheme.ink,
                                              ),
                                            ),
                                            if (scheduledDate != null)
                                              Text(
                                                _formatRelativeTime(
                                                  scheduledDate,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.14,
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: statusColor.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 22),
                                  _TripAddressRow(
                                    icon: Icons.trip_origin,
                                    iconColor: Colors.green,
                                    label: 'Origen',
                                    address:
                                        data['originAddress']?.toString() ??
                                        'Sin especificar',
                                  ),
                                  const SizedBox(height: 10),
                                  _TripAddressRow(
                                    icon: Icons.flag,
                                    iconColor: Colors.redAccent,
                                    label: 'Destino',
                                    address:
                                        data['destinationAddress']?.toString() ??
                                        'Sin especificar',
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _InfoChip(
                                        icon: Icons.payments_outlined,
                                        text:
                                            'S/ ${fare.toStringAsFixed(2)} ($paymentMethod)',
                                      ),
                                      if (distanceKm > 0)
                                        _InfoChip(
                                          icon: Icons.route_outlined,
                                          text:
                                              '${distanceKm.toStringAsFixed(1)} km${durationText.isNotEmpty ? ' · $durationText' : ''}',
                                        ),
                                      if (carriesCargo)
                                        const _InfoChip(
                                          icon: Icons.inventory_2_outlined,
                                          text: 'Con carga adicional',
                                        ),
                                    ],
                                  ),
                                  if (data['driverName'] != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: MijanoTheme.cream,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.person_pin,
                                            size: 18,
                                            color: MijanoTheme.ink,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Conductor asignado: ${data['driverName']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (canCancel) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(
                                            color: Colors.redAccent,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _confirmCancelReservation(
                                              context,
                                              doc.id,
                                              data['destinationAddress']
                                                      ?.toString() ??
                                                  'tu destino',
                                            ),
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Cancelar reserva',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  static String _formatRelativeTime(DateTime scheduledDate) {
    final now = DateTime.now();
    final diff = scheduledDate.difference(now);
    if (diff.isNegative) {
      return 'Horario programado cumplido';
    }
    if (diff.inHours < 1) {
      return 'Faltan ${diff.inMinutes.clamp(1, 59)} min';
    }
    if (diff.inHours < 24) {
      return 'Faltan ${diff.inHours} h';
    }
    return 'En ${diff.inDays} día(s)';
  }

  static String _statusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return 'Conductor asignado';
      case 'cancelled':
        return 'Cancelado';
      case 'completed':
      case 'finalized':
        return 'Completado';
      case 'pending':
        return 'Programado';
      default:
        return status ?? 'Programado';
    }
  }

  static Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.redAccent;
      case 'completed':
      case 'finalized':
        return Colors.blueGrey;
      case 'pending':
      default:
        return Colors.amber.shade900;
    }
  }
}

class _FilterTabButton extends StatelessWidget {
  const _FilterTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? MijanoTheme.ink : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? MijanoTheme.ink : Colors.black12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? MijanoTheme.sol : Colors.black54,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripAddressRow extends StatelessWidget {
  const _TripAddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: address),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateReservationBottomSheet extends StatefulWidget {
  const _CreateReservationBottomSheet();

  @override
  State<_CreateReservationBottomSheet> createState() =>
      _CreateReservationBottomSheetState();
}

class _CreateReservationBottomSheetState
    extends State<_CreateReservationBottomSheet> {
  static const String _apiKey = 'AIzaSyCMhmdJobdeH1aUJ87XLw3yRnqm-ufWLGc';

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  List<String> _originSuggestions = [];
  List<String> _destinationSuggestions = [];

  LatLng? _originLatLng;
  LatLng? _destinationLatLng;

  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));
  String _selectedPaymentMethod = 'Efectivo';
  bool _carriesCargo = false;
  bool _isCalculatingFare = false;
  bool _isSubmitting = false;

  PricingSettings _pricingSettings = PricingSettings.fromMap(null);
  StreamSubscription<PricingSettings>? _pricingSubscription;
  double _estimatedFare = 4.0;
  double _distanceKm = 0.0;
  double _durationMinutes = 0.0;
  String _durationText = '';

  @override
  void initState() {
    super.initState();
    _pricingSubscription = FirestoreService.instance
        .streamPricingSettings()
        .listen((settings) {
          if (!mounted) return;
          setState(() {
            _pricingSettings = settings;
            _updateQuoteFromSettings();
          });
        });
  }

  void _updateQuoteFromSettings() {
    if (_distanceKm > 0) {
      _estimatedFare = _pricingSettings
          .quote(
            category: VehicleCategory.moto,
            distanceKm: _distanceKm,
            durationMin: _durationMinutes,
            hour: _scheduledAt.hour,
          )
          .total;
    } else {
      _estimatedFare = _pricingSettings
          .tariffFor(VehicleCategory.moto)
          .minFare;
    }
  }

  @override
  void dispose() {
    _pricingSubscription?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query, {required bool isOrigin}) async {
    if (query.trim().isEmpty) {
      setState(() {
        if (isOrigin) {
          _originSuggestions = [];
        } else {
          _destinationSuggestions = [];
        }
      });
      return;
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_apiKey'
        '&language=es'
        '&components=country:pe',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List predictions = data['predictions'] ?? [];
        final results = predictions
            .map<String>((p) => p['description'].toString())
            .toList();
        if (mounted) {
          setState(() {
            if (isOrigin) {
              _originSuggestions = results;
            } else {
              _destinationSuggestions = results;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<LatLng?> _getLatLngFromAddress(String address) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          return LatLng(loc['lat'], loc['lng']);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openMapPicker({required bool isOrigin}) async {
    LatLng initialPoint = const LatLng(-6.4869, -76.3654);
    if (isOrigin && _originLatLng != null) {
      initialPoint = _originLatLng!;
    } else if (!isOrigin && _destinationLatLng != null) {
      initialPoint = _destinationLatLng!;
    } else {
      try {
        final pos = await LocationService.instance.current();
        initialPoint = LatLng(pos.latitude, pos.longitude);
      } catch (_) {}
    }

    if (!mounted) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => _MapLocationPickerScreen(
          isOrigin: isOrigin,
          initialPosition: initialPoint,
          apiKey: _apiKey,
        ),
      ),
    );

    if (result != null && mounted) {
      final LatLng pickedLatLng = result['latLng'] as LatLng;
      final String pickedAddress = result['address'] as String;
      setState(() {
        if (isOrigin) {
          _originLatLng = pickedLatLng;
          _originController.text = pickedAddress;
          _originSuggestions = [];
        } else {
          _destinationLatLng = pickedLatLng;
          _destinationController.text = pickedAddress;
          _destinationSuggestions = [];
        }
      });
      await _recalculateFare();
    }
  }

  Future<void> _recalculateFare() async {
    final destText = _destinationController.text.trim();
    if (destText.isEmpty && _destinationLatLng == null) return;

    setState(() => _isCalculatingFare = true);

    try {
      final originText = _originController.text.trim().isNotEmpty
          ? _originController.text.trim()
          : 'Mi ubicación actual';

      LatLng? originLatLng =
          _originLatLng ?? await _getLatLngFromAddress(originText);
      final LatLng? destLatLng =
          _destinationLatLng ?? await _getLatLngFromAddress(destText);

      if (originLatLng == null) {
        try {
          final pos = await LocationService.instance.current();
          originLatLng = LatLng(pos.latitude, pos.longitude);
        } catch (_) {}
      }

      if (originLatLng != null && destLatLng != null) {
        final directionsUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${originLatLng.latitude},${originLatLng.longitude}'
          '&destination=${destLatLng.latitude},${destLatLng.longitude}'
          '&mode=driving'
          '&key=$_apiKey',
        );
        final response = await http.get(directionsUrl);
        bool routeFound = false;
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            final route = data['routes'][0];
            if (route['legs'] != null && route['legs'].isNotEmpty) {
              final leg = route['legs'][0];
              final distanceMeters =
                  (leg['distance']?['value'] as num?)?.toDouble() ?? 0.0;
              final durationSeconds =
                  (leg['duration']?['value'] as num?)?.toDouble() ?? 0.0;
              final km = distanceMeters / 1000.0;
              final durationMin = durationSeconds / 60.0;

              if (mounted) {
                setState(() {
                  _distanceKm = km;
                  _durationMinutes = durationMin;
                  _durationText =
                      leg['duration']?['text'] ?? '${durationMin.round()} min';
                  _updateQuoteFromSettings();
                });
              }
              routeFound = true;
            }
          }
        }
        if (!routeFound && mounted) {
          final fallbackKm = LocationService.instance.distanceKm(
            originLatLng.latitude,
            originLatLng.longitude,
            destLatLng.latitude,
            destLatLng.longitude,
          );
          final km = fallbackKm > 0 ? fallbackKm : 2.5;
          final durationMin = (km * 3.0).clamp(3.0, 120.0);
          setState(() {
            _distanceKm = km;
            _durationMinutes = durationMin;
            _durationText = '${durationMin.round()} min';
            _updateQuoteFromSettings();
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isCalculatingFare = false);
      }
    }
  }

  Future<void> _submitReservation() async {
    if (_destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa el destino de tu reserva.'),
        ),
      );
      return;
    }

    if (!_scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una fecha y hora futura para la reserva.'),
        ),
      );
      return;
    }

    final user = AuthService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para reservar un viaje.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      LatLng? originCoords =
          _originLatLng ??
          await _getLatLngFromAddress(_originController.text.trim());
      final LatLng? destCoords =
          _destinationLatLng ??
          await _getLatLngFromAddress(_destinationController.text.trim());

      if (originCoords == null) {
        try {
          final currentPos = await LocationService.instance.current();
          originCoords = LatLng(currentPos.latitude, currentPos.longitude);
        } catch (_) {
          originCoords = const LatLng(-6.4869, -76.3654);
        }
      }

      final tripData = {
        'passengerId': user.uid,
        'passengerName': user.name,
        'passengerPhone': user.phone,
        'originAddress': _originController.text.trim().isNotEmpty
            ? _originController.text.trim()
            : 'Mi ubicación actual',
        'destinationAddress': _destinationController.text.trim(),
        'origin': GeoPoint(originCoords.latitude, originCoords.longitude),
        'destination': destCoords != null
            ? GeoPoint(destCoords.latitude, destCoords.longitude)
            : null,
        'fareAmount': _estimatedFare,
        'distanceKm': _distanceKm,
        'durationText': _durationText,
        'paymentMethod': _selectedPaymentMethod,
        'serviceType': 'Programar viaje',
        'carriesCargo': _carriesCargo,
        'scheduledAt': Timestamp.fromDate(_scheduledAt),
        'status': 'pending',
        'driverId': null,
        'completedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('trips').add(tripData);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('¡Tu reserva ha sido registrada con éxito!'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la reserva: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.event_available, color: Color(0xFFF9D408), size: 24),
                SizedBox(width: 10),
                Text(
                  'Programar Nueva Reserva',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ORIGEN
            TextField(
              controller: _originController,
              onChanged: (v) {
                _originLatLng = null;
                _searchPlaces(v, isOrigin: true);
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                hintText: 'Origen (vacío = Mi ubicación actual)',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.trip_origin,
                  color: Colors.greenAccent,
                  size: 18,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Seleccionar origen en el mapa',
                  icon: const Icon(
                    Icons.pin_drop_outlined,
                    color: Colors.greenAccent,
                  ),
                  onPressed: () => _openMapPicker(isOrigin: true),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_originSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _originSuggestions.length,
                  itemBuilder: (context, index) {
                    final item = _originSuggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.place,
                        color: Color(0xFFF9D408),
                        size: 18,
                      ),
                      title: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _originController.text = item;
                          _originLatLng = null;
                          _originSuggestions = [];
                        });
                        _recalculateFare();
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),

            // DESTINO
            TextField(
              controller: _destinationController,
              onChanged: (v) {
                _destinationLatLng = null;
                _searchPlaces(v, isOrigin: false);
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                hintText: '¿A dónde vas a viajar?',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.flag,
                  color: Colors.redAccent,
                  size: 18,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Seleccionar destino en el mapa',
                  icon: const Icon(
                    Icons.pin_drop_outlined,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _openMapPicker(isOrigin: false),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_destinationSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _destinationSuggestions.length,
                  itemBuilder: (context, index) {
                    final item = _destinationSuggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.place,
                        color: Color(0xFFF9D408),
                        size: 18,
                      ),
                      title: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _destinationController.text = item;
                          _destinationLatLng = null;
                          _destinationSuggestions = [];
                        });
                        _recalculateFare();
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // TARIFA SUGERIDA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF9D408)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tarifa estimada de reserva',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _distanceKm > 0
                            ? '${_distanceKm.toStringAsFixed(1)} km · $_durationText'
                            : 'Ingresa destino para calcular ruta',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  _isCalculatingFare
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFF9D408),
                          ),
                        )
                      : Text(
                          'S/ ${_estimatedFare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF9D408),
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // FECHA Y HORA
            const Text(
              'Fecha y hora programada:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFF9D408)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () async {
                      final today = DateTime.now();
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _scheduledAt,
                        firstDate: DateTime(today.year, today.month, today.day),
                        lastDate: DateTime(
                          today.year,
                          today.month,
                          today.day + 7,
                        ),
                        helpText: 'Selecciona el día del viaje',
                      );
                      if (selectedDate != null) {
                        setState(() {
                          _scheduledAt = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            _scheduledAt.hour,
                            _scheduledAt.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(_scheduledAt),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFF9D408)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () async {
                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_scheduledAt),
                        helpText: 'Selecciona la hora del viaje',
                      );
                      if (selectedTime != null) {
                        setState(() {
                          _scheduledAt = DateTime(
                            _scheduledAt.year,
                            _scheduledAt.month,
                            _scheduledAt.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );
                          _updateQuoteFromSettings();
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(
                      MaterialLocalizations.of(context).formatTimeOfDay(
                        TimeOfDay.fromDateTime(_scheduledAt),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // CARGA ADICIONAL
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _carriesCargo
                      ? const Color(0xFFF9D408)
                      : Colors.transparent,
                ),
              ),
              child: SwitchListTile(
                value: _carriesCargo,
                onChanged: (val) => setState(() => _carriesCargo = val),
                activeThumbColor: const Color(0xFFF9D408),
                title: const Text(
                  '¿Llevas carga adicional?',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: const Text(
                  'Maletas, cajas o compras grandes',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // MÉTODO DE PAGO
            const Text(
              'Método de pago:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Efectivo', 'Yape', 'Plin'].map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPaymentMethod = method),
                  child: Container(
                    width: 96,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF9D408)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          method == 'Efectivo'
                              ? Icons.money
                              : Icons.phone_android,
                          color: isSelected
                              ? const Color(0xFFF9D408)
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          method,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFF9D408)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            // BOTONES DE ACCIÓN
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9D408),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submitReservation,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isSubmitting
                          ? 'Guardando reserva...'
                          : 'Confirmar Reserva',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLocationPickerScreen extends StatefulWidget {
  const _MapLocationPickerScreen({
    required this.isOrigin,
    required this.initialPosition,
    required this.apiKey,
  });

  final bool isOrigin;
  final LatLng initialPosition;
  final String apiKey;

  @override
  State<_MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<_MapLocationPickerScreen> {
  GoogleMapController? _mapController;
  late LatLng _currentTarget;
  String _address = 'Obteniendo dirección...';
  bool _isLoadingAddress = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentTarget = widget.initialPosition;
    _reverseGeocode(_currentTarget);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onCameraIdle() {
    _debounce?.cancel();
    setState(() => _isLoadingAddress = true);
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _reverseGeocode(_currentTarget);
    });
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${pos.latitude},${pos.longitude}'
        '&key=${widget.apiKey}'
        '&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          if (mounted) {
            setState(() {
              _address = data['results'][0]['formatted_address'].toString();
              _isLoadingAddress = false;
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _address =
            'Ubicación (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})';
        _isLoadingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        title: Text(
          widget.isOrigin
              ? 'Seleccionar origen en el mapa'
              : 'Seleccionar destino en el mapa',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 16.5,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (c) => _mapController = c,
            onCameraMove: (pos) => _currentTarget = pos.target,
            onCameraIdle: _onCameraIdle,
            onTap: (point) {
              _currentTarget = point;
              _mapController?.animateCamera(CameraUpdate.newLatLng(point));
              _onCameraIdle();
            },
          ),
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  size: 46,
                  color: widget.isOrigin
                      ? Colors.green.shade600
                      : Colors.redAccent,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (_isLoadingAddress)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          widget.isOrigin ? Icons.trip_origin : Icons.flag,
                          color: widget.isOrigin
                              ? Colors.green.shade700
                              : Colors.redAccent,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF9D408),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context, {
                          'latLng': _currentTarget,
                          'address': _address,
                        });
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        widget.isOrigin
                            ? 'Confirmar origen'
                            : 'Confirmar destino',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
