import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/models/device.dart';

class AlertSettingsScreen extends StatefulWidget {
  final Device device;

  const AlertSettingsScreen({super.key, required this.device});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  late NotificationService _notificationService;
  Map<String, dynamic>? _rules;
  bool _isLoading = true;

  // Controllers for alert thresholds
  late TextEditingController _tempMaxController;
  late TextEditingController _tempMinController;
  late TextEditingController _humidityMaxController;
  late TextEditingController _humidityMinController;
  late TextEditingController _soilMoistureMinController;
  late TextEditingController _soilMoistureMaxController;
  late TextEditingController _lightMinController;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(context.read<ApiService>());
    _loadAlertRules();
  }

  Future<void> _loadAlertRules() async {
    setState(() => _isLoading = true);
    final rules = await _notificationService.getDeviceAlertRules(
      widget.device.deviceId,
    );
    setState(() {
      _rules = rules;
      _initializeControllers();
      _isLoading = false;
    });
  }

  void _initializeControllers() {
    _tempMaxController = TextEditingController(
      text: (_rules?['airTemperatureMax'] ?? 35).toString(),
    );
    _tempMinController = TextEditingController(
      text: (_rules?['airTemperatureMin'] ?? 15).toString(),
    );
    _humidityMaxController = TextEditingController(
      text: (_rules?['airHumidityMax'] ?? 90).toString(),
    );
    _humidityMinController = TextEditingController(
      text: (_rules?['airHumidityMin'] ?? 30).toString(),
    );
    _soilMoistureMinController = TextEditingController(
      text: (_rules?['soilMoistureMin'] ?? 40).toString(),
    );
    _soilMoistureMaxController = TextEditingController(
      text: (_rules?['soilMoistureMax'] ?? 90).toString(),
    );
    _lightMinController = TextEditingController(
      text: (_rules?['lightLevelMin'] ?? 200).toString(),
    );
  }

  @override
  void dispose() {
    _tempMaxController.dispose();
    _tempMinController.dispose();
    _humidityMaxController.dispose();
    _humidityMinController.dispose();
    _soilMoistureMinController.dispose();
    _soilMoistureMaxController.dispose();
    _lightMinController.dispose();
    super.dispose();
  }

  Future<void> _saveRules() async {
    final newRules = {
      'airTemperatureMax': double.tryParse(_tempMaxController.text) ?? 35,
      'airTemperatureMin': double.tryParse(_tempMinController.text) ?? 15,
      'airHumidityMax': double.tryParse(_humidityMaxController.text) ?? 90,
      'airHumidityMin': double.tryParse(_humidityMinController.text) ?? 30,
      'soilMoistureMin': double.tryParse(_soilMoistureMinController.text) ?? 40,
      'soilMoistureMax': double.tryParse(_soilMoistureMaxController.text) ?? 90,
      'lightLevelMin': double.tryParse(_lightMinController.text) ?? 200,
    };

    final success = await _notificationService.setDeviceAlerts(
      widget.device.deviceId,
      newRules,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ წესები შენახულია'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('🔔 შეტყობინებების წესები')),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 შეტყობინებების წესები'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ჰაერის ტემპერატურა',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_tempMinController, 'მინ (°C)'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(_tempMaxController, 'მაქს (°C)'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'ჰაერის ტენიანობა',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_humidityMinController, 'მინ (%)'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(_humidityMaxController, 'მაქს (%)'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'ნიადაგის ტენიანობა',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_soilMoistureMinController, 'მინ (%)'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    _soilMoistureMaxController,
                    'მაქს (%)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'სინათლე',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildTextField(_lightMinController, 'მინ (%)'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveRules,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'შენახვა',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
      ),
    );
  }
}
