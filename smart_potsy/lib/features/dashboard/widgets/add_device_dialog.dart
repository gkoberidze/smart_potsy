import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.addDevice),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: AppStrings.deviceId,
                hintText: AppStrings.deviceIdHint,
                prefixIcon: Icon(Icons.memory),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'შეიყვანეთ მოწყობილობის ID';
                }
                if (value.length < 3) {
                  return 'ID უნდა იყოს მინიმუმ 3 სიმბოლო';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'შეიყვანეთ თქვენი ESP32 მოწყობილობის უნიკალური ID',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text(AppStrings.registerDevice),
        ),
      ],
    );
  }
}
