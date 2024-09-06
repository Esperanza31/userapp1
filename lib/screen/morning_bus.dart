import 'package:flutter/material.dart';
import 'package:mini_project_five/pages/get_bus_time.dart';
import 'package:mini_project_five/pages/busdata.dart';

class BusPage extends StatefulWidget {

  final Function(int) updateSelectedBox;
  final bool isDarkMode;

  BusPage({required this.updateSelectedBox, required this.isDarkMode});
  @override
  _BusPageState createState() => _BusPageState();
}

class _BusPageState extends State<BusPage> {
  int selectedBox = 1;
  BusSchedule _BusSchedule = BusSchedule();
  bool _isDarkMode = false;
  //LocationService _locationService = LocationService();
  //Map_Page _map_page = Map_Page();

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  void updateSelectedBox(int box){
    setState(() {
      selectedBox = box;
    });
    widget.updateSelectedBox(box);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => updateSelectedBox(1), // Update CLE
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 0),
                    height: selectedBox == 1 ? 70 : 40,
                    curve: Curves.easeOutCubic,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        color: selectedBox == 1 ? Colors.blueAccent : Colors.grey,
                        child: Center(
                          child: Text(
                            'KAP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => updateSelectedBox(2), // Update CLE
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 0),
                    height: selectedBox == 2 ? 70 : 40,
                    curve: Curves.easeOutCubic,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        color: selectedBox == 2 ? Colors.blueAccent : Colors.grey,
                        child: Center(
                          child: Text(
                            'CLE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        BusTimeFunctions.getBusTime(selectedBox == 2
            ? _BusSchedule.CLEArrivalTime
            : _BusSchedule.KAPArrivalTime),
        SizedBox(height: 16),
      ],
    );
  }
}


