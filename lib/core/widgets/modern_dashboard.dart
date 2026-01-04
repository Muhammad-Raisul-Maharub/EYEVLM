import 'package:flutter/material.dart';

class ModernDashboard extends StatelessWidget {
  final String name;
  final String email;
  final int scanCount;

  const ModernDashboard({super.key, required this.name, required this.email, required this.scanCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. The Glassmorphism Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade700, Colors.teal.shade400],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.teal.withAlpha(77), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person_rounded, size: 35, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 20),
              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statItem("Scans", "$scanCount"),
                  _statItem("Status", "Active"),
                  _statItem("Plan", "Free"),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
