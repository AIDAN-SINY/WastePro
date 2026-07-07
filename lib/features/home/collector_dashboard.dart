import 'package:flutter/material.dart';

class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  bool _isOnline = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Collector Panel"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Status
          Container(
            padding: const EdgeInsets.all(20),
            color: _isOnline ? Colors.green : Colors.red,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isOnline ? "YOU ARE ONLINE" : "YOU ARE OFFLINE",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: _isOnline,
                  onChanged: (val) => setState(() => _isOnline = val),
                  activeThumbColor: Colors.white,
                ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: _isOnline
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 80, color: Colors.grey),
                        Text("Searching for nearby pickups..."),
                      ],
                    )
                  : const Text("Go online to start receiving collection tasks"),
            ),
          ),
        ],
      ),
    );
  }
}
