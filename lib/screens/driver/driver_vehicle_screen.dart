import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../passenger/passenger_available_cars_screen.dart';

class DriverVehicleScreen extends StatefulWidget {
  const DriverVehicleScreen({super.key});

  @override
  State<DriverVehicleScreen> createState() => _DriverVehicleScreenState();
}

class _DriverVehicleScreenState extends State<DriverVehicleScreen> {
  final IntercityVehicleRepository _repo = IntercityVehicleRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.ensureCurrentDriverVehicleSynced();
  }

  Future<void> _callPassenger(SeatPassengerInfo passenger) async {
    final uri = Uri(scheme: 'tel', path: passenger.phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Llamando a ${passenger.passengerName} (${passenger.phone})...',
        ),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _openEditRouteDialog(AvailableCarItem car) {
    final originCtrl = TextEditingController(text: car.originCity);
    final destCtrl = TextEditingController(text: car.destinationCity);
    final timeCtrl = TextEditingController(text: car.departureLabel);
    final priceCtrl = TextEditingController(
      text: car.pricePerSeat.toStringAsFixed(2),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Configurar Ruta y Salida',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: originCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ciudad de Origen (De:)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: destCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ciudad de Destino (A:)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Horario de salida (ej. Hoy, 14:30)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio por asiento (S/)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9D408),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final origin = originCtrl.text.trim().isNotEmpty
                  ? originCtrl.text.trim()
                  : car.originCity;
              final dest = destCtrl.text.trim().isNotEmpty
                  ? destCtrl.text.trim()
                  : car.destinationCity;
              final label = timeCtrl.text.trim().isNotEmpty
                  ? timeCtrl.text.trim()
                  : car.departureLabel;
              final price =
                  double.tryParse(priceCtrl.text.trim()) ?? car.pricePerSeat;

              await _repo.updateVehicleRouteAndSchedule(
                carId: car.id,
                originCity: origin,
                destinationCity: dest,
                departureLabel: label,
                pricePerSeat: price,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text(
              'Guardar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _openDirectChat(AvailableCarItem car, SeatPassengerInfo passenger) {
    final messageController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: _repo,
          builder: (ctx, _) {
            final liveCar = _repo.getCarById(car.id);
            final seatMessages = liveCar.chatMessages
                .where((m) => m['seatNumber'] == passenger.seatNumber)
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: 410,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9D408),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black87,
                            child: Icon(
                              Icons.person,
                              color: Color(0xFFF9D408),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${passenger.passengerName} • Asiento ${passenger.seatNumber}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  passenger.etaText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.black),
                            onPressed: () => _callPassenger(passenger),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F1F1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Hola conductor, reservé el Asiento ${passenger.seatNumber}. Estoy en camino hacia la agencia (${passenger.etaText}).',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          ...seatMessages.map((msg) {
                            final isDriver = msg['sender'] == 'driver';
                            return Align(
                              alignment: isDriver
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDriver
                                      ? const Color(0xFFF9D408)
                                      : const Color(0xFFF1F1F1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  (msg['text'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: messageController,
                              decoration: InputDecoration(
                                hintText:
                                    'Escribe para coordinar el recojo...',
                                hintStyle: const TextStyle(fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFFF5F5F5),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: const Color(0xFFF9D408),
                            child: IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.black,
                                size: 18,
                              ),
                              onPressed: () async {
                                final text = messageController.text.trim();
                                if (text.isEmpty) return;
                                messageController.clear();
                                await _repo.sendDirectChatMessage(
                                  carId: liveCar.id,
                                  seatNumber: passenger.seatNumber,
                                  senderRole: 'driver',
                                  senderName: liveCar.driverName,
                                  text: text,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onTapSeatBox(AvailableCarItem car, int seatNumber) async {
    final isOccupied = car.seatStates[seatNumber] == 'occupied';
    final passenger = car.seatPassengers[seatNumber];

    if (isOccupied) {
      final shouldRelease = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Asiento $seatNumber • ${passenger?.passengerName ?? 'Ocupado'}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Estado: Ocupado (${passenger?.etaText ?? 'ETA: 12 min a 15 min'})\n\n'
            '¿Deseas liberar este asiento por cancelación anticipada? '
            'El vehículo actualizará su disponibilidad en tiempo real en la lista pública.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF25C54),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Liberar Asiento'),
            ),
          ],
        ),
      );

      if (shouldRelease == true) {
        await _repo.cancelSeatReservation(
          carId: car.id,
          seatNumber: seatNumber,
        );
        if (!mounted) return;
        final updated = _repo.getCarById(car.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Asiento $seatNumber liberado. Disponible ahora: '
              '${updated.availableSeatsCount}/4 Disponibles.',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } else {
      final nameController = TextEditingController(
        text: seatNumber == 2 ? 'María Torres' : 'Pasajero $seatNumber',
      );
      final shouldOccupy = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Asignar Asiento $seatNumber',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa el nombre del pasajero para ocupar este asiento:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre del pasajero',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF9D408),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Ocupar Asiento',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (shouldOccupy == true) {
        final name = nameController.text.trim().isNotEmpty
            ? nameController.text.trim()
            : 'Pasajero $seatNumber';
        await _repo.occupySeat(
          carId: car.id,
          seatNumber: seatNumber,
          passengerId: 'pax_manual_$seatNumber',
          passengerName: name,
          passengerPhone: '+51987654321',
          etaText: 'ETA: 12 min a 15 min',
        );
        if (!mounted) return;
        final updated = _repo.getCarById(car.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updated.isFull
                  ? '¡4/4 Asientos Ocupados! El vehículo se retiró automáticamente de la lista pública de pasajeros.'
                  : 'Asiento $seatNumber asignado a $name (${updated.occupiedSeatsCount}/4 ocupados).',
            ),
            backgroundColor: updated.isFull
                ? Colors.orange.shade900
                : Colors.black87,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final car = _repo.driverPrimaryVehicle;
        final occupiedCount = car.occupiedSeatsCount;
        final passengersList = car.seatPassengers.values.toList()
          ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

        return Container(
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Tarjeta de Nueva Solicitud (Pendiente)
                if (car.pendingRequests.isNotEmpty)
                  ...car.pendingRequests.map(
                    (req) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Nueva Solicitud (Pendiente)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${req.passengerName} - Asiento ${req.seatNumber} (${req.seatPositionDescription}) - S/ ${req.price.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF9D408),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () async {
                                await _repo.acceptPendingRequest(
                                  carId: car.id,
                                  request: req,
                                );
                                if (!context.mounted) return;
                                final updated = _repo.getCarById(car.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      updated.isFull
                                          ? 'Viaje aceptado. ¡4/4 Asientos ocupados! Vehículo ocultado de la lista pública.'
                                          : 'Viaje de ${req.passengerName} aceptado en el Asiento ${req.seatNumber}.',
                                    ),
                                    backgroundColor: Colors.green.shade700,
                                  ),
                                );
                              },
                              child: const Text(
                                'Aceptar Viaje',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF25C54),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () {
                                _repo.rejectPendingRequest(
                                  carId: car.id,
                                  request: req,
                                );
                              },
                              child: const Text(
                                'Rechazar',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Encabezado "Mi Vehículo y Asientos"
                const Text(
                  'Mi Vehículo y Asientos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${car.vehicleModel} - ${car.vehiclePlate}${car.agencyName.trim().isNotEmpty ? ' • ${car.agencyName}' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${car.departureLabel} • S/ ${car.pricePerSeat.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openEditRouteDialog(car),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Mapa de Ocupación en Tiempo Real (Esquema superior del auto)
                SizedBox(
                  width: 286,
                  height: 340,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: CarTopDownOutlinePainter(),
                        ),
                      ),
                      // Asiento 1 (Copiloto delantero derecho)
                      Positioned(
                        top: 84,
                        right: 40,
                        child: _DriverSeatOccupancyBox(
                          seatNumber: 1,
                          isOccupied: car.seatStates[1] == 'occupied',
                          passengerShortName:
                              car.seatPassengers[1]?.shortName ?? 'Ocupado',
                          onTap: () => _onTapSeatBox(car, 1),
                        ),
                      ),
                      // Fila trasera: Asientos 2, 3 y 4
                      Positioned(
                        bottom: 52,
                        left: 32,
                        right: 32,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _DriverSeatOccupancyBox(
                              seatNumber: 2,
                              isOccupied: car.seatStates[2] == 'occupied',
                              passengerShortName:
                                  car.seatPassengers[2]?.shortName ?? 'Ocupado',
                              onTap: () => _onTapSeatBox(car, 2),
                            ),
                            _DriverSeatOccupancyBox(
                              seatNumber: 3,
                              isOccupied: car.seatStates[3] == 'occupied',
                              passengerShortName:
                                  car.seatPassengers[3]?.shortName ?? 'Ocupado',
                              onTap: () => _onTapSeatBox(car, 3),
                            ),
                            _DriverSeatOccupancyBox(
                              seatNumber: 4,
                              isOccupied: car.seatStates[4] == 'occupied',
                              passengerShortName:
                                  car.seatPassengers[4]?.shortName ?? 'Ocupado',
                              onTap: () => _onTapSeatBox(car, 4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Leyenda Disponible (Verde) / Ocupado (Rojo con X)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1EE61E),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.black54,
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Disponible',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4362C),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.black87,
                              width: 1,
                            ),
                          ),
                          child: const CustomPaint(
                            painter: OccupiedCrossPainter(
                              color: Colors.black87,
                              strokeWidth: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Ocupado',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade300, height: 1),
                const SizedBox(height: 14),

                // Resumen Estado del Viaje y Ocupación Actual
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado del Viaje: Ruta ${car.originCity} → ${car.destinationCity}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Ocupación Actual: $occupiedCount / 4 Asientos',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: car.isFull
                                  ? const Color(0xFFFFEBEE)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: car.isFull
                                    ? const Color(0xFFF4362C)
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                            child: Text(
                              car.isFull
                                  ? 'Oculto en lista pública (Lleno)'
                                  : '${car.availableSeatsCount}/4 Disponibles en lista',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: car.isFull
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Listado de Próximos Pasajeros + Herramientas de Comunicación Directa
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: const [
                      Icon(
                        Icons.people_alt_outlined,
                        size: 19,
                        color: Colors.black87,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Próximos Pasajeros (En camino a la agencia)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (passengersList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Text(
                      'No hay asientos ocupados en este momento. Todos los asientos (4/4) están disponibles en la lista pública.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  )
                else
                  ...passengersList.map(
                    (pax) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4362C),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${pax.seatNumber}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pax.passengerName} (Asiento ${pax.seatNumber})',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_filled,
                                      size: 14,
                                      color: Color(0xFFE65100),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        pax.etaText,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFE65100),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Acceso directo a Chat
                          IconButton(
                            tooltip: 'Chat directo',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF9D408),
                              foregroundColor: Colors.black,
                              minimumSize: const Size(38, 38),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                            ),
                            onPressed: () => _openDirectChat(car, pax),
                          ),
                          const SizedBox(width: 6),
                          // Acceso directo a Llamada telefónica
                          IconButton(
                            tooltip: 'Llamada telefónica',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF1EE61E),
                              foregroundColor: Colors.black,
                              minimumSize: const Size(38, 38),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.phone_outlined, size: 19),
                            onPressed: () => _callPassenger(pax),
                          ),
                          const SizedBox(width: 6),
                          // Liberar asiento por cancelación anticipada
                          IconButton(
                            tooltip: 'Cancelar / Liberar asiento',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              foregroundColor: Colors.red.shade700,
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(
                              Icons.event_seat_outlined,
                              size: 18,
                            ),
                            onPressed: () async {
                              await _repo.cancelSeatReservation(
                                carId: car.id,
                                seatNumber: pax.seatNumber,
                              );
                              if (!context.mounted) return;
                              final updated = _repo.getCarById(car.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Reserva de ${pax.passengerName} cancelada. '
                                    'Asiento ${pax.seatNumber} disponible (${updated.availableSeatsCount}/4 Disponibles).',
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DriverSeatOccupancyBox extends StatelessWidget {
  final int seatNumber;
  final bool isOccupied;
  final String passengerShortName;
  final VoidCallback onTap;

  const _DriverSeatOccupancyBox({
    required this.seatNumber,
    required this.isOccupied,
    required this.passengerShortName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isOccupied
        ? const Color(0xFFF4362C)
        : const Color(0xFF1EE61E);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.black87,
                width: 1.3,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isOccupied)
                  const CustomPaint(
                    size: Size(48, 48),
                    painter: OccupiedCrossPainter(
                      color: Color(0x66000000),
                      strokeWidth: 2.0,
                    ),
                  ),
                Text(
                  '$seatNumber',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isOccupied ? 'Ocupado\n($passengerShortName)' : 'Disponible',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
