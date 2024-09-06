import 'package:flutter/material.dart';

class NewsAnnouncement extends StatelessWidget {
  final bool isDarkMode;

  const NewsAnnouncement({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.lightBlue[600] : Colors.lightBlue[100],
        title: Text(
          'NP News Announcements',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: isDarkMode ? Colors.lightBlue[900] : Colors.white,
        child: NewsAnnouncementWidget(isDarkMode: isDarkMode),
      ),
    );
  }
}

class NewsAnnouncementWidget extends StatelessWidget {
  final bool isDarkMode;

  const NewsAnnouncementWidget({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.announcement, color: Colors.orange),
                      SizedBox(width: 5.0),
                      Text(
                        'NP News Announcement',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Announcements news here',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
