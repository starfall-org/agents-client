import 'package:flutter/material.dart';

void main() {
  runApp(const AgentsApp());
}

class AgentsApp extends StatelessWidget {
  const AgentsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agents',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AgentsHomePage(),
    );
  }
}

class AgentsHomePage extends StatelessWidget {
  const AgentsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agents')),
      body: const Center(
        child: Text('Welcome to Agents'),
      ),
    );
  }
}
