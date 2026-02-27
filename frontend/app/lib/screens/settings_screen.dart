import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {

  bool isDarkMode = true;
  bool notificationsEnabled = true;
  bool moodReminder = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF0A1428),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0A1428),
        elevation: 0,
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          const SizedBox(height: 10),

          /// 👤 Account
          const Text(
            "Account",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70),
          ),
          const SizedBox(height: 10),
          _tile(Icons.person, "Profile"),
          _tile(Icons.email, "Email"),

          const SizedBox(height: 25),

          /// 🎨 Appearance
          const Text(
            "Appearance",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text(
              "Dark Mode",
              style: TextStyle(color: Colors.white),
            ),
            value: isDarkMode,
            onChanged: (value) {
              setState(() {
                isDarkMode = value;
              });
            },
          ),

          const SizedBox(height: 25),

          /// 🔔 Notifications
          const Text(
            "Notifications",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text(
              "Enable Notifications",
              style: TextStyle(color: Colors.white),
            ),
            value: notificationsEnabled,
            onChanged: (value) {
              setState(() {
                notificationsEnabled = value;
              });
            },
          ),

          const SizedBox(height: 25),

          /// 🧠 App
          const Text(
            "App",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text(
              "Mood Reminder",
              style: TextStyle(color: Colors.white),
            ),
            value: moodReminder,
            onChanged: (value) {
              setState(() {
                moodReminder = value;
              });
            },
          ),

          _tile(Icons.delete_outline,
              "Clear Chat History"),

          const SizedBox(height: 25),

          /// ℹ About
          const Text(
            "About",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70),
          ),
          const SizedBox(height: 10),
          _tile(Icons.info_outline, "App Version 1.0.0"),
          _tile(Icons.privacy_tip_outlined,
              "Privacy Policy"),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style:
            const TextStyle(color: Colors.white),
      ),
      onTap: () {},
    );
  }
}