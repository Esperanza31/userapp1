import 'package:flutter/material.dart';

class Settings extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const Settings({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  late bool isDarkMode;

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.isDarkMode;
  }

  void toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
    });
    widget.onThemeChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
        backgroundColor: isDarkMode ? Colors.lightBlue[600] : Colors.lightBlue[100],
      ),
      backgroundColor: isDarkMode ? Colors.lightBlue[900] : Colors.white,
      body: Padding(
        padding: EdgeInsets.fromLTRB(10, 10, 0, 10),
        child: Row(
          children: [
            Text('Light Mode', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            Switch(
              value: isDarkMode,
              onChanged: (value) {
                toggleTheme(value);
              },
            ),
            Text('Dark Mode', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }
}
