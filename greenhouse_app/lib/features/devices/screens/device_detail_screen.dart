import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/device_service.dart';
import '../../../core/models/device.dart';
import '../../../core/models/telemetry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../widgets/sensor_card.dart';
import '../widgets/telemetry_chart.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  late DeviceService _deviceService;
  DeviceStatus? _status;
  List<Telemetry> _telemetryHistory = [];
  bool _isLoading = true;
  String _selectedPeriod = 'today';

  @override
  void initState() {
    super.initState();
    _deviceService = DeviceService(context.read<ApiService>());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final status = await _deviceService.getDeviceStatus(
        widget.device.deviceId,
      );
      final telemetry = await _deviceService.getDeviceTelemetry(
        widget.device.deviceId,
        limit: _getLimitForPeriod(),
      );

      setState(() {
        _status = status;
        _telemetryHistory = telemetry;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int _getLimitForPeriod() {
    switch (_selectedPeriod) {
      case 'today':
        return 24;
      case 'week':
        return 168;
      case 'month':
        return 720;
      default:
        return 24;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.device.deviceId),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusHeader(),
                    const SizedBox(height: 24),
                    _buildSensorGrid(),
                    const SizedBox(height: 24),
                    _buildHistorySection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusHeader() {
    final isOnline = _status?.online ?? false;
    final lastSeen = _status?.lastSeen;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.success : AppColors.error,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isOnline ? AppColors.success : AppColors.error)
                        .withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? AppStrings.online : AppStrings.offline,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? AppColors.success : AppColors.error,
                    ),
                  ),
                  if (lastSeen != null)
                    Text(
                      '${AppStrings.lastUpdate}: ${_formatDateTime(lastSeen)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorGrid() {
    final latest = _status?.latestTelemetry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.telemetry,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            SensorCard(
              title: AppStrings.airTemperature,
              value: latest?.airTemperature?.toStringAsFixed(1) ?? '--',
              unit: '°C',
              icon: Icons.thermostat,
              color: AppColors.temperature,
            ),
            SensorCard(
              title: AppStrings.airHumidity,
              value: latest?.airHumidity?.toStringAsFixed(1) ?? '--',
              unit: '%',
              icon: Icons.water_drop,
              color: AppColors.humidity,
            ),
            SensorCard(
              title: AppStrings.soilTemperature,
              value: latest?.soilTemperature?.toStringAsFixed(1) ?? '--',
              unit: '°C',
              icon: Icons.grass,
              color: AppColors.soilMoisture,
            ),
            SensorCard(
              title: AppStrings.soilMoisture,
              value: latest?.soilMoisture?.toStringAsFixed(1) ?? '--',
              unit: '%',
              icon: Icons.opacity,
              color: AppColors.soilMoisture,
            ),
            SensorCard(
              title: AppStrings.lightLevel,
              value: latest?.lightLevel?.toString() ?? '--',
              unit: 'lux',
              icon: Icons.wb_sunny,
              color: AppColors.light,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              AppStrings.history,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'today', label: Text(AppStrings.today)),
                ButtonSegment(value: 'week', label: Text(AppStrings.week)),
                ButtonSegment(value: 'month', label: Text(AppStrings.month)),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (selection) {
                setState(() => _selectedPeriod = selection.first);
                _loadData();
              },
              style: ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_telemetryHistory.isNotEmpty) ...[
          TelemetryChart(
            title: AppStrings.airTemperature,
            telemetry: _telemetryHistory,
            valueGetter: (t) => t.airTemperature,
            color: AppColors.temperature,
          ),
          const SizedBox(height: 16),
          TelemetryChart(
            title: AppStrings.airHumidity,
            telemetry: _telemetryHistory,
            valueGetter: (t) => t.airHumidity,
            color: AppColors.humidity,
          ),
          const SizedBox(height: 16),
          TelemetryChart(
            title: AppStrings.soilMoisture,
            telemetry: _telemetryHistory,
            valueGetter: (t) => t.soilMoisture,
            color: AppColors.soilMoisture,
          ),
        ] else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'მონაცემები არ არის',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
