import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class AdminUsersScreen extends StatefulWidget {
  final String jwtToken;
  const AdminUsersScreen({Key? key, required this.jwtToken}) : super(key: key);

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> users = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/users'),
        headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          users = data['data']['users'] ?? [];
          loading = false;
        });
      } else {
        setState(() {
          error = 'Failed: \\${response.statusCode}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registered Users')),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(child: Text('Error: $error'))
              : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: Text(user['id'].toString()),
                    title: Text(user['email'] ?? ''),
                    subtitle: Text(user['created_at'] ?? ''),
                  );
                },
              ),
    );
  }
}
