import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.email, size: 30),
              title: Text('Email'),
              subtitle: Text('user@example.com'), // Replace with actual email
            ),
            Divider(),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _logout(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    // Perform logout operation (clear session, redirect to login, etc.)
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}
