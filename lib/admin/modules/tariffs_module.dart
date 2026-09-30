import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/tariff_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import 'shared_admin_widgets.dart';

enum _TariffField {
  baseFare('Tarifa base', null),
  perKm('Por kilómetro', '/ km'),
  perMinute('Por minuto', '/ min'),
  minFare('Tarifa mínima', null),
  nightSurcharge('Recargo nocturno', null);

  final String label;
  final String? suffix;
  const _TariffField(this.label, this.suffix);
}

extension _VehicleCategoryUi on VehicleCategory {
  IconData get icon {
    switch (this) {
      case VehicleCategory.moto:
        return Icons.two_wheeler;
    }
  }
}

class TariffsModule extends StatefulWidget {
  const TariffsModule({super.key});

  @override
  State<TariffsModule> createState() => _TariffsModuleState();
}

class _TariffsModuleState extends State<TariffsModule> {
  final _firestore = FirestoreService.instance;
  final _formKey = GlobalKey<FormState>();

  final Map<VehicleCategory, Map<_TariffField, TextEditingController>>
  _tariffCtrls = {
    for (final category in VehicleCategory.values)
      category: {
        for (final field in _TariffField.values) field: TextEditingController(),
      },
  };
  final _nightStartCtrl = TextEditingController();
  final _nightEndCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _simKmCtrl = TextEditingController(text: '5.2');
  final _simMinCtrl = TextEditingController(text: '15');

  VehicleCategory _simCategory = VehicleCategory.values.first;
  int _simHour = 14;
  DateTime? _updatedAt;
  String? _loadError;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final fields in _tariffCtrls.values) {
      for (final controller in fields.values) {
        controller.dispose();
      }
    }
    _nightStartCtrl.dispose();
    _nightEndCtrl.dispose();
    _radiusCtrl.dispose();
    _simKmCtrl.dispose();
    _simMinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await _firestore.ensurePricingSettings();
      if (!mounted) return;
      setState(() {
        _applySettings(result.settings);
        if (result.created) _updatedAt = DateTime.now();
        _loading = false;
      });
      if (result.created) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración inicial creada con valores por defecto.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = _describeError(e);
        _loading = false;
      });
    }
  }

  void _applySettings(PricingSettings settings) {
    for (final category in VehicleCategory.values) {
      final tariff = settings.tariffFor(category);
      final ctrls = _tariffCtrls[category]!;
      ctrls[_TariffField.baseFare]!.text = _amount(tariff.baseFare);
      ctrls[_TariffField.perKm]!.text = _amount(tariff.perKm);
      ctrls[_TariffField.perMinute]!.text = _amount(tariff.perMinute);
      ctrls[_TariffField.minFare]!.text = _amount(tariff.minFare);
      ctrls[_TariffField.nightSurcharge]!.text = _amount(tariff.nightSurcharge);
    }
    _nightStartCtrl.text = '${settings.nightStartHour}';
    _nightEndCtrl.text = '${settings.nightEndHour}';
    _radiusCtrl.text = settings.maxOfferRadiusKm.toString();
    _updatedAt = settings.updatedAt;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final settings = _readDraft();
    if (settings == null) return;

    setState(() => _saving = true);
    try {
      await _firestore.savePricingSettings(settings);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _updatedAt = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarifas actualizadas.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${_describeError(e)}')),
      );
    }
  }

  PricingSettings? _readDraft() {
    final tariffs = <VehicleCategory, VehicleTariff>{};
    for (final category in VehicleCategory.values) {
      final ctrls = _tariffCtrls[category]!;
      final baseFare = _parse(ctrls[_TariffField.baseFare]!.text);
      final perKm = _parse(ctrls[_TariffField.perKm]!.text);
      final perMinute = _parse(ctrls[_TariffField.perMinute]!.text);
      final minFare = _parse(ctrls[_TariffField.minFare]!.text);
      final nightSurcharge = _parse(ctrls[_TariffField.nightSurcharge]!.text);
      if (baseFare == null ||
          perKm == null ||
          perMinute == null ||
          minFare == null ||
          nightSurcharge == null) {
        return null;
      }
      tariffs[category] = VehicleTariff(
        baseFare: baseFare,
        perKm: perKm,
        perMinute: perMinute,
        minFare: minFare,
        nightSurcharge: nightSurcharge,
      );
    }

    final nightStart = int.tryParse(_nightStartCtrl.text.trim());
    final nightEnd = int.tryParse(_nightEndCtrl.text.trim());
    final radius = _parse(_radiusCtrl.text);
    if (nightStart == null || nightEnd == null || radius == null) return null;
    if (nightStart > 23 || nightEnd > 23 || radius <= 0) return null;

    return PricingSettings(
      tariffs: tariffs,
      nightStartHour: nightStart,
      nightEndHour: nightEnd,
      maxOfferRadiusKm: radius,
    );
  }

  String _describeError(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'la sesión actual no tiene permiso sobre settings/pricing. '
          'Revisa las reglas de Firestore.';
    }
    return error.toString();
  }

  double? _parse(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  String _amount(double value) => value.toStringAsFixed(2);

  String _soles(double value) => 'S/ ${value.toStringAsFixed(2)}';

  String _plain(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  String? _validateAmount(String? value) {
    final number = _parse(value ?? '');
    return number == null || number < 0 ? 'Valor inválido' : null;
  }

  String? _validateHour(String? value) {
    final hour = int.tryParse((value ?? '').trim());
    return hour == null || hour < 0 || hour > 23 ? 'De 0 a 23' : null;
  }

  String? _validateRadius(String? value) {
    final radius = _parse(value ?? '');
    return radius == null || radius <= 0 ? 'Mayor a 0' : null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminHeader(
            'Tarifas',
            'Cotización dinámica del servicio de mototaxi',
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            _errorCard()
          else
            _content(),
        ],
      ),
    );
  }

  Widget _content() {
    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final parameters = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final category in VehicleCategory.values) ...[
                _tariffCard(category),
                const SizedBox(height: 16),
              ],
              _globalCard(),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _pair(wide, parameters, _simulatorCard()),
              const SizedBox(height: 20),
              _saveBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _pair(bool wide, Widget left, Widget right) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 16), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  Widget _errorCard() {
    return adminCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: MijanoTheme.signal),
          const SizedBox(width: 12),
          Expanded(child: Text('No se pudo cargar la configuración: $_loadError')),
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _tariffCard(VehicleCategory category) {
    final ctrls = _tariffCtrls[category]!;
    final baseFare = _parse(ctrls[_TariffField.baseFare]!.text);
    final minFare = _parse(ctrls[_TariffField.minFare]!.text);
    final minFareIsUnreachable =
        baseFare != null && minFare != null && minFare <= baseFare;

    return adminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(category.icon, category.label, 'Parámetros de cotización'),
          const SizedBox(height: 20),
          ..._inPairs([
            for (final field in _TariffField.values)
              _numberField(
                controller: ctrls[field]!,
                label: field.label,
                prefix: 'S/ ',
                suffix: field.suffix,
                validator: _validateAmount,
              ),
          ]),
          if (minFareIsUnreachable) ...[
            const SizedBox(height: 16),
            _hint(
              'La tarifa mínima no supera la tarifa base, por lo que nunca se aplicará.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _globalCard() {
    return adminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.nights_stay_outlined,
            'Configuración global',
            'Horario nocturno y alcance de solicitudes',
          ),
          const SizedBox(height: 20),
          ..._inPairs([
            _numberField(
              controller: _nightStartCtrl,
              label: 'Inicio nocturno',
              suffix: 'h',
              validator: _validateHour,
              integer: true,
            ),
            _numberField(
              controller: _nightEndCtrl,
              label: 'Fin nocturno',
              suffix: 'h',
              validator: _validateHour,
              integer: true,
            ),
            _numberField(
              controller: _radiusCtrl,
              label: 'Radio de solicitudes',
              suffix: 'km',
              validator: _validateRadius,
            ),
          ]),
          const SizedBox(height: 16),
          _hint(
            'El recargo se aplica cuando el viaje inicia dentro de la franja nocturna.',
          ),
        ],
      ),
    );
  }

  Widget _simulatorCard() {
    final draft = _readDraft();
    final km = _parse(_simKmCtrl.text);
    final min = _parse(_simMinCtrl.text);
    final canQuote = draft != null && km != null && min != null;
    final isNight = draft?.isNightHour(_simHour) ?? false;

    return adminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.calculate_outlined,
            'Simulador de cotización',
            'Usa los valores del formulario, aunque no estén guardados',
          ),
          const SizedBox(height: 20),
          if (VehicleCategory.values.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in VehicleCategory.values)
                  _categoryChip(category),
              ],
            ),
            const SizedBox(height: 16),
          ],
          ..._inPairs([
            _numberField(controller: _simKmCtrl, label: 'Distancia', suffix: 'km'),
            _numberField(controller: _simMinCtrl, label: 'Tiempo', suffix: 'min'),
          ]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hora del viaje',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${_simHour.toString().padLeft(2, '0')}:00${isNight ? ' · nocturno' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: MijanoTheme.ink,
                ),
              ),
            ],
          ),
          Slider(
            value: _simHour.toDouble(),
            min: 0,
            max: 23,
            divisions: 23,
            activeColor: MijanoTheme.ink,
            inactiveColor: MijanoTheme.ink.withValues(alpha: 0.15),
            onChanged: (value) => setState(() => _simHour = value.round()),
          ),
          const SizedBox(height: 8),
          if (canQuote)
            _quotePanel(draft, km, min)
          else
            _hint('Completa los valores con números válidos para ver la cotización.'),
        ],
      ),
    );
  }

  Widget _quotePanel(PricingSettings draft, double km, double min) {
    final tariff = draft.tariffFor(_simCategory);
    final quote = draft.quote(
      category: _simCategory,
      distanceKm: km,
      durationMin: min,
      hour: _simHour,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MijanoTheme.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          _line('Tarifa base', _soles(quote.baseFare)),
          _line(
            'Distancia (${_plain(km)} km × ${_soles(tariff.perKm)})',
            _soles(quote.distanceCost),
          ),
          _line(
            'Tiempo (${_plain(min)} min × ${_soles(tariff.perMinute)})',
            _soles(quote.timeCost),
          ),
          _line(
            'Recargo nocturno',
            _soles(quote.nightSurcharge),
            muted: !quote.isNight,
          ),
          const Divider(height: 24),
          _line('Subtotal', _soles(quote.subtotal), bold: true),
          if (quote.minFareApplied)
            _line(
              'Ajuste por tarifa mínima',
              '+ ${_soles(quote.total - quote.subtotal)}',
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: MijanoTheme.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Precio final',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _soles(quote.total),
                  style: const TextStyle(
                    color: MijanoTheme.sol,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBar() {
    final updatedAt = _updatedAt;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        Text(
          updatedAt == null
              ? 'Sin registro de la última actualización.'
              : 'Última actualización: ${DateFormat('dd/MM/yyyy HH:mm').format(updatedAt)}',
          style: const TextStyle(color: Colors.black54),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          icon: _saving
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.save_outlined),
          label: const Text('Guardar cambios'),
        ),
      ],
    );
  }

  Widget _categoryChip(VehicleCategory category) {
    final selected = _simCategory == category;
    return ChoiceChip(
      avatar: Icon(category.icon, size: 18, color: MijanoTheme.ink),
      label: Text(category.label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _simCategory = category),
      selectedColor: MijanoTheme.sol,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? MijanoTheme.ink : Colors.black12),
      ),
    );
  }

  Widget _cardTitle(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: MijanoTheme.sol.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: MijanoTheme.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: MijanoTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffix,
    String? Function(String?)? validator,
    bool integer = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [
        integer
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        if (integer) LengthLimitingTextInputFormatter(2),
      ],
      validator: validator,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
      ),
    );
  }

  List<Widget> _inPairs(List<Widget> children) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final second =
      i + 1 < children.length ? children[i + 1] : const SizedBox.shrink();
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 16),
              Expanded(child: second),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _line(
      String label,
      String value, {
        bool muted = false,
        bool bold = false,
      }) {
    final style = TextStyle(
      color: muted ? Colors.black38 : MijanoTheme.ink,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _hint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: Colors.black45),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}