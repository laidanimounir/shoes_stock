import 'package:flutter/material.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desktop POS - Gestion de Stock'),
      ),
      body: const Center(
        child: Text(
          'POS System Window\n(Sales, Cart, Products)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
