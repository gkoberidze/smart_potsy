import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/device_service.dart';
import '../../../core/models/device.dart';
import '../../../core/models/telemetry.dart';
import '../../../core/theme/app_colors.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  late DeviceService _deviceService;
  List<Telemetry> _telemetryList = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _deviceService = DeviceService(context.read<ApiService>());
    _loadData();
    // Auto-refresh every 10 seconds for real-time updates
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    try {
      final telemetry = await _deviceService.getDeviceTelemetry(
        widget.device.deviceId,
        limit: 100,
      );
      if (mounted) {
        setState(() => _telemetryList = telemetry);
      }
    } catch (e) {
      // Silent fail for background refresh
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final telemetry = await _deviceService.getDeviceTelemetry(
        widget.device.deviceId,
        limit: 100,
      );
      setState(() {
        _telemetryList = telemetry;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading telemetry: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.primary,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildDeviceCard(),
                      const SizedBox(height: 40),
                      _buildSensorList(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildDeviceCard() {
    return Column(
      children: [
        Container(
          width: 200,
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(30),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              widget.device.deviceId,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showInfoDialog(),
          child: const Text(
            'ინფორმაცია',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showInfoDialog() {
    final isOnline = _telemetryList.isNotEmpty;
    final lastUpdate = widget.device.lastTelemetry?.recordedAt;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(widget.device.deviceId),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('ID:', widget.device.deviceId),
                _infoRow('სტატუსი:', isOnline ? 'ონლაინ ✅' : 'ოფლაინ ❌'),
                if (lastUpdate != null)
                  _infoRow('ბოლო განახლება:', _formatDateTime(lastUpdate)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('დახურვა'),
              ),
            ],
          ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSensorList() {
    // Get the latest telemetry record, or use the device's last telemetry
    final Telemetry? latest =
        _telemetryList.isNotEmpty
            ? _telemetryList.first
            : (widget.device.lastTelemetry != null
                ? Telemetry(
                  airTemperature: widget.device.lastTelemetry!.airTemperature,
                  airHumidity: widget.device.lastTelemetry!.airHumidity,
                  soilTemperature: widget.device.lastTelemetry!.soilTemperature,
                  soilMoisture: widget.device.lastTelemetry!.soilMoisture,
                  lightLevel: widget.device.lastTelemetry!.lightLevel,
                  recordedAt: widget.device.lastTelemetry!.recordedAt,
                )
                : null);

    return Column(
      children: [
        _buildSensorRow(
          icon: _buildTemperatureIcon(),
          value: latest?.airTemperature?.toStringAsFixed(1) ?? '--',
          unit: '°C',
        ),
        const SizedBox(height: 24),
        _buildSensorRow(
          icon: _buildSoilTempIcon(),
          value: latest?.soilTemperature?.toStringAsFixed(1) ?? '--',
          unit: '°C',
        ),
        const SizedBox(height: 24),
        _buildSensorRow(
          icon: _buildHumidityIcon(),
          value: latest?.airHumidity?.toStringAsFixed(1) ?? '--',
          unit: '%',
        ),
        const SizedBox(height: 24),
        _buildSensorRow(
          icon: _buildSoilMoistureIcon(),
          value: latest?.soilMoisture?.toStringAsFixed(1) ?? '--',
          unit: '%',
        ),
        const SizedBox(height: 24),
        _buildSensorRow(
          icon: _buildLightIcon(),
          value: latest?.lightLevel?.toStringAsFixed(0) ?? '--',
          unit: '%',
        ),
        if (latest?.recordedAt != null) ...[
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ბოლო განახლება: ${_formatDateTime(latest!.recordedAt!)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final gmt4 = dateTime.toUtc().add(const Duration(hours: 4));
    return '${gmt4.year}-${gmt4.month.toString().padLeft(2, '0')}-${gmt4.day.toString().padLeft(2, '0')} ${gmt4.hour.toString().padLeft(2, '0')}:${gmt4.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSensorRow({
    required Widget icon,
    required String value,
    required String unit,
  }) {
    return Row(
      children: [
        SizedBox(width: 60, child: icon),
        const Spacer(),
        Text(
          '$value$unit',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // Custom sensor icons matching the design
  Widget _buildTemperatureIcon() {
    return const Text(
      '°C',
      style: TextStyle(fontSize: 28, color: Colors.black54),
    );
  }

  Widget _buildSoilTempIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.thermostat_outlined, size: 24, color: Colors.black54),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: const Text(
                '~',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHumidityIcon() {
    return const Icon(
      Icons.water_drop_outlined,
      size: 32,
      color: Colors.black54,
    );
  }

  Widget _buildSoilMoistureIcon() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.grass, size: 24, color: Colors.black54),
        const SizedBox(width: 2),
        const Text('。', style: TextStyle(fontSize: 20, color: Colors.black54)),
      ],
    );
  }

  Widget _buildLightIcon() {
    return const Icon(Icons.wb_sunny_outlined, size: 32, color: Colors.black54);
  }
}
