import 'package:flutter/material.dart';
import 'package:mini_project_five/pages/map_page.dart';
import 'package:mini_project_five/pages/loading.dart';
import 'package:mini_project_five/pages/information.dart';
import 'package:mini_project_five/pages/busdata.dart';
import 'package:mini_project_five/pages/news_announcement.dart';
import 'package:mini_project_five/pages/settings.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BusSchedule().loadData();
  runApp(MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  void onThemeChanged(bool value) {
    setState(() {
      isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      initialRoute: '/home',
      routes: {
        '/': (context) => Loading(isDarkMode: isDarkMode),
        '/home': (context) => Map_Page(),
        '/information': (context) => Information_Page(isDarkMode: isDarkMode),
        '/newsannouncement': (context) => NewsAnnouncement(isDarkMode: isDarkMode),
        '/settings': (context) => Settings(
          isDarkMode: isDarkMode,
          onThemeChanged: onThemeChanged,
        ),
      },
    );
  }
}
