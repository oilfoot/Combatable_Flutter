import 'package:flutter/material.dart';

import '../app_shell.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            24,
            24,
            AppShell.floatingNavExtraScrollSpace,
          ),
          child: SizedBox(
            width: double.infinity,
            height:
                MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top,
            child: const Center(
              child: Text(
                'Profile',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
