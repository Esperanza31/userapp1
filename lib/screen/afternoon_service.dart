import 'dart:async';
import 'package:amplify_api/amplify_api.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mini_project_five/models/ModelProvider.dart';
import 'package:mini_project_five/pages/busdata.dart';
import 'package:mini_project_five/screen/evening_bus.dart';
import 'package:mini_project_five/amplifyconfiguration.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api_dart/amplify_api_dart.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:mini_project_five/pages/loading.dart';
import 'package:mini_project_five/pages/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AfternoonService extends StatefulWidget {
  final Function(int) updateSelectedBox;
  final bool isDarkMode;

  AfternoonService({required this.updateSelectedBox, required this.isDarkMode});

  @override
  _AfternoonServiceState createState() => _AfternoonServiceState();
}

class _AfternoonServiceState extends State<AfternoonService> {
  int selectedBox = 0; // Default to no selection
  int? bookedTripIndexKAP;
  int? bookedTripIndexCLE;
  bool confirmationPressed = false;
  //bool showBookingDetails = false;
  DateTime currentTime = DateTime.now();
  String? BookingID;
  String selectedBusStop = '';
  BusSchedule _BusSchedule = BusSchedule();
  List<DateTime> KAP_DT = [];
  List<DateTime> CLE_DT = [];
  int _eveningService = 9;
  SharedPreferenceService prefsService = SharedPreferenceService();
  Future<Map<String, dynamic>?>? futureBookingData;
  bool? _showBookingService;




  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _configureAmplify();
    futureBookingData = prefsService.getBookingData();
    Future.delayed(Duration(seconds: 15), () {
      setState(() {
        _showBookingService = false;
      });
    });
  }

  Future<Map<String, dynamic>?> loadBookingData() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedBox = prefs.getInt('selectedBox');
    final bookedTripIndexKAP = prefs.getInt('bookedTripIndexKAP');
    final bookedTripIndexCLE = prefs.getInt('bookedTripIndexCLE');
    final busStop = prefs.getString('selectedBusStop');

    if (selectedBox != null) {
      return {
        'selectedBox': selectedBox,
        'bookedTripIndexKAP': bookedTripIndexKAP,
        'bookedTripIndexCLE': bookedTripIndexCLE,
        'busStop': busStop
      };
    }
    return null; // No booking data
  }



  void _configureAmplify() async {
    final provider = ModelProvider();
    final amplifyApi = AmplifyAPI(options: APIPluginOptions(modelProvider: provider));
    final dataStorePlugin = AmplifyDataStore(modelProvider: provider);

    Amplify.addPlugin(dataStorePlugin);
    Amplify.addPlugin(amplifyApi);
    Amplify.configure(amplifyconfig);

    print('Amplify configured');
  }

  Future<void> create(String _MRTStation, int _TripNo, String _BusStop) async {
    try {
      final model = BOOKINGDETAILS5(
        id: Uuid().v4(),
        MRTStation: _MRTStation,
        TripNo: _TripNo,
        BusStop: _BusStop,
      );

      final request = ModelMutations.create(model);
      final response = await Amplify.API.mutate(request: request).response;

      final createdBOOKINGDETAILS5 = response.data;
      if (createdBOOKINGDETAILS5 == null) {
        safePrint('errors: ${response.errors}');
        return;
      }

      String id = createdBOOKINGDETAILS5.id;
      setState(() {
        BookingID = id;
      });
      safePrint('Mutation result: $BookingID');
    } on ApiException catch (e) {
      safePrint('Mutation failed: $e');
    }

    _MRTStation == 'KAP' ? countKAP(_TripNo, _BusStop) : countCLE(_TripNo, _BusStop);
  }

  Future<BOOKINGDETAILS5?> readByID() async {
    final request = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.ID.eq(BookingID),
    );
    final response = await Amplify.API.query(request: request).response;
    final data = response.data?.items.firstOrNull;
    return data;
  }

  Future<int?> countBooking(String MRT, int TripNo) async {
    int? count;
    try {
      final request = ModelQueries.list(
        BOOKINGDETAILS5.classType,
        where: BOOKINGDETAILS5.MRTSTATION.eq(MRT).and(
            BOOKINGDETAILS5.TRIPNO.eq(TripNo)),
      );
      final response = await Amplify.API.query(request: request).response;
      final data = response.data?.items;

      if (data != null) {
        count = data.length;
        print('$count');
      } else {
        count = 0;
      }
    } catch (e) {
      print('$e');
    }
    return count;
  }

  Future<void> delete() async {
    final BOOKINGDETAILS5? bookingToDelete = await readByID();
    if (bookingToDelete != null) {
      final request = ModelMutations.delete(bookingToDelete);
      final response = await Amplify.API.mutate(request: request).response;
      if (bookingToDelete.MRTStation == 'KAP') {
        countKAP(bookingToDelete.TripNo, bookingToDelete.BusStop);
      } else {
        countCLE(bookingToDelete.TripNo, bookingToDelete.BusStop);
      }
    } else {
      print('No booking found with ID: $BookingID');
    }
  }

  Future<void> countCLE(int _TripNo, String _BusStop) async {
    // Read if there is a row
    final request1 = ModelQueries.list(
      CLE.classType,
      where: CLE.TRIPNO.eq(_TripNo).and(CLE.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');

    // If data1 != null delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      await Amplify.API.mutate(request: request2).response;
    }

    // Count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION.eq('CLE').and(
          BOOKINGDETAILS5.TRIPNO.eq(_TripNo)).and(
          BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    final int count = data2?.length ?? 0;
    print('$count');

    // Create the row if count is greater than 0
    if (count > 0) {
      final model = CLE(
        BusStop: _BusStop,
        TripNo: _TripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      await Amplify.API.mutate(request: request4).response;
    }
  }

  Future<void> countKAP(int _TripNo, String _BusStop) async {
    // Read if there is a row
    final request1 = ModelQueries.list(
      KAP.classType,
      where: KAP.TRIPNO.eq(_TripNo).and(KAP.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');

    // If data1 != null delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      await Amplify.API.mutate(request: request2).response;
    }

    // Count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION.eq('KAP').and(
          BOOKINGDETAILS5.TRIPNO.eq(_TripNo)).and(
          BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    final int count = data2?.length ?? 0;
    print('$count');

    // Create the row if count is greater than 0
    if (count > 0) {
      final model = KAP(
        BusStop: _BusStop,
        TripNo: _TripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      await Amplify.API.mutate(request: request4).response;
    }
  }

  void showBusStopSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          color: Colors.cyan[50],
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 5),
                Text('Choose bus stop: ',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _BusSchedule.BusStop.length -2,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: ListTile(
                          title: Text(_BusSchedule.BusStop[index+2],
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w900,
                            ),),
                          onTap: () {
                            setState((){
                              selectedBusStop = _BusSchedule.BusStop[index+2];
                            });
                            // Handle bus stop selection here
                            Navigator.pop(context); // Close the bottom sheet
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void updateSelectedBox(int box) {
    if (!confirmationPressed) {
      setState(() {
        selectedBox = box;
      });
      widget.updateSelectedBox(box);
    }
  }

  void updateBookingStatusKAP(int index, bool newValue) {
    setState(() {
      if (confirmationPressed) {
        // If confirmation is pressed, allow changing selection
        confirmationPressed = false;
      } else {
        if (newValue) {
          // If the trip is selected, update the booked trip index
          bookedTripIndexKAP = index;
        } else {
          // If the trip is deselected, reset the booked trip index if it matches
          if (bookedTripIndexKAP == index) {
            bookedTripIndexKAP = null;
          }
        }
      }
    });
  }

  void updateBookingStatusCLE(int index, bool newValue) {
    setState(() {
      if (confirmationPressed) {
        // If confirmation is pressed, allow changing selection
        confirmationPressed = false;
      } else {
        if (newValue) {
          // If the trip is selected, update the booked trip index
          bookedTripIndexCLE = index;
        } else {
          // If the trip is deselected, reset the booked trip index if it matches
          if (bookedTripIndexCLE == index) {
            bookedTripIndexCLE = null;
          }
        }
      }
    });
  }

  List<DateTime> getDepartureTimes() {
    if (selectedBox == 1) {
      return _BusSchedule.KAPDepartureTime;
    } else {
      return _BusSchedule.CLEDepartureTime;
    }
  }

  String formatTime(DateTime time) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void showBookingConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 2),
                  Text(
                    'Booking Confirmed!',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                'Thank you for booking with us. Your booking has been confirmed',
                style: TextStyle(
                  fontSize: 13,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Row(
                  children: [
                    Text(
                      'Trip Number:             ',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    //SizedBox(width: MediaQuery.of(context).size.width * 0.1),
                    Text('${selectedBox == 1 ? bookedTripIndexKAP! + 1 : bookedTripIndexCLE! + 1}',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),)
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Time:                          ',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    //SizedBox(width: MediaQuery.of(context).size.width * 0.21),
                    Text(
                      '${formatTime(getDepartureTimes()[selectedBox == 1 ? bookedTripIndexKAP! : bookedTripIndexCLE!])}',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Station:                      ',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    //SizedBox(width: MediaQuery.of(context).size.width * 0.19),
                    Text(
                      '${selectedBox == 1 ? 'KAP' : 'CLE'}',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Bus Stop:                  ',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    //SizedBox(width: MediaQuery.of(context).size.width * 0.15),
                    Text(
                      '$selectedBusStop',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String selectedStation = selectedBox == 1 ? 'KAP' : 'CLE';
    return FutureBuilder<Map<String, dynamic>?>(
        future: futureBookingData,
        builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      } else if (snapshot.hasError) {
        return Scaffold(
          body: Center(child: Text('Error loading data')),
        );
      } else if (snapshot.hasData && snapshot.data != null) {
        final data = snapshot.data!;
        selectedBox = data['selectedBox'];
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Padding(
        padding: const EdgeInsets.all(8.0),
          child: Text('Select MRT:',
          style: TextStyle(
          color: widget.isDarkMode ? Colors.white : Colors.black,
          ),),
          ),
          Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
          children: [
          Expanded(
          child: GestureDetector(
          onTap: () {
          setState(() {
          updateSelectedBox(1);
          });
          } , // Update CLE
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
          onTap: () {
          setState(() {
          updateSelectedBox(2);
          });
          },  // Update CLE
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
          SizedBox(height: 5),
           _showBookingService == true ?
              BookingService(
                departureTimes: getDepartureTimes(),
                eveningService: _eveningService,
                selectedBox: selectedBox,
                KAPDepartureTime: _BusSchedule.KAPDepartureTime,
                CLEDepartureTime: _BusSchedule.CLEDepartureTime,
                bookedTripIndexKAP: bookedTripIndexKAP,
                bookedTripIndexCLE: bookedTripIndexCLE,
                updateBookingStatusKAP: updateBookingStatusKAP,
                updateBookingStatusCLE: updateBookingStatusCLE,
                confirmationPressed: true,
                countBooking: countBooking,
                isDarkMode: widget.isDarkMode,
                showBusStopSelectionBottomSheet: showBusStopSelectionBottomSheet,
                onPressedConfirm: () {
                  setState(() {
                    confirmationPressed = true;
                    //showBookingDetails = true;
                    create(selectedStation, selectedBox == 1 ? bookedTripIndexKAP!+1 : bookedTripIndexCLE!+1, selectedBusStop);
                  });
                  showBookingConfirmationDialog(context);
                },
              ) :
              BookingConfirmation(
                eveningService: _eveningService,
                selectedBox: selectedBox,KAPDepartureTime: data['KAPDepartureTime'] ?? [],
                CLEDepartureTime: data['CLEDepartureTime'] ?? [],
                bookedTripIndexKAP: data['bookedTripIndexKAP'],
                bookedTripIndexCLE: data['bookedTripIndexCLE'],
                getDepartureTimes: getDepartureTimes,
                BusStop: selectedBusStop,
                isDarkMode: widget.isDarkMode,
                onCancel: () {
                  setState(() {
                    confirmationPressed = false;
                    bookedTripIndexKAP = null;
                    bookedTripIndexCLE = null;
                    //showBookingDetails = false;
                    delete();
                    prefsService.clearBookingData();
                  });
                  Navigator.of(context).pop;
                },
              )
          ]);}
      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Select MRT:',
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black,
          ),),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      updateSelectedBox(1);
                    });
                  } , // Update CLE
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
                  onTap: () {
                    setState(() {
                      updateSelectedBox(2);
                    });
                  },  // Update CLE
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
        SizedBox(height: 5),
        if (selectedBox != 0)
        //showBookingDetails
          confirmationPressed
              ? BookingConfirmation(
            eveningService: _eveningService,
            selectedBox: selectedBox,
            KAPDepartureTime: KAP_DT,
            CLEDepartureTime: CLE_DT,
            bookedTripIndexKAP: bookedTripIndexKAP,
            bookedTripIndexCLE: bookedTripIndexCLE,
            getDepartureTimes: getDepartureTimes,
            BusStop: selectedBusStop,
            isDarkMode: widget.isDarkMode,
            onCancel: () {
              setState(() {
                confirmationPressed = false;
                bookedTripIndexKAP = null;
                bookedTripIndexCLE = null;
                //showBookingDetails = false;
                delete();
                prefsService.clearBookingData();
              });
            },
          )
              :
          BookingService(
            departureTimes: getDepartureTimes(),
            eveningService: _eveningService,
            selectedBox: selectedBox,
            KAPDepartureTime: _BusSchedule.KAPDepartureTime,
            CLEDepartureTime: _BusSchedule.CLEDepartureTime,
            bookedTripIndexKAP: bookedTripIndexKAP,
            bookedTripIndexCLE: bookedTripIndexCLE,
            updateBookingStatusKAP: updateBookingStatusKAP,
            updateBookingStatusCLE: updateBookingStatusCLE,
            confirmationPressed: confirmationPressed,
            countBooking: countBooking,
            isDarkMode: widget.isDarkMode,
            showBusStopSelectionBottomSheet: showBusStopSelectionBottomSheet,
            onPressedConfirm: () {
              setState(() {
                confirmationPressed = true;
                //showBookingDetails = true;
                create(selectedStation, selectedBox == 1 ? bookedTripIndexKAP!+1 : bookedTripIndexCLE!+1, selectedBusStop);
              });
              showBookingConfirmationDialog(context);
            },
          ),
      ],
    );
  }
    );}
}

class BookingService extends StatefulWidget {
  final List<DateTime> departureTimes;
  final int selectedBox;
  final int? bookedTripIndexKAP;
  final int? bookedTripIndexCLE;
  final VoidCallback onPressedConfirm;
  final bool confirmationPressed;
  final Function(int index, bool newValue) updateBookingStatusKAP;
  final Function(int index, bool newValue) updateBookingStatusCLE;
  final Future<int?> Function(String MRT, int index) countBooking;
  final Function showBusStopSelectionBottomSheet;
  final List<DateTime> KAPDepartureTime;
  final List<DateTime> CLEDepartureTime;
  final int eveningService;
  final bool isDarkMode;

  BookingService({
    required this.departureTimes,
    required this.selectedBox,
    required this.bookedTripIndexKAP,
    required this.bookedTripIndexCLE,
    required this.onPressedConfirm,
    required this.confirmationPressed,
    required this.countBooking,
    required this.updateBookingStatusKAP,
    required this.updateBookingStatusCLE,
    required this.showBusStopSelectionBottomSheet,
    required this.KAPDepartureTime,
    required this.CLEDepartureTime,
    required this.eveningService,
    required this.isDarkMode
  });

  @override
  State<BookingService> createState() => _BookingServiceState();
}
class _BookingServiceState extends State<BookingService> {
  Color finalColor = Colors.grey;
  late Timer _timer;
  late Map<int, int?> bookingCounts; //store count
  bool _loading = true;
  int Vacancy_Green = 3;
  int Vacancy_Yellow = 4;
  int Vacancy_Red = 5;

  bool canConfirm() {
    return widget.selectedBox == 1 ? widget.bookedTripIndexKAP != null : widget.bookedTripIndexCLE != null;
  }

  @override
  void didUpdateWidget(covariant BookingService oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedBox != widget.selectedBox) {
      setState(() {
        _loading = true;
        bookingCounts = {};
      });
      _updateBookingCounts();
    }
  }

  @override
  void initState() {
    super.initState();
    bookingCounts = {};
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _updateBookingCounts();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateBookingCounts() async {
    for (int i = 0; i < widget.departureTimes.length; i++) {
      int? count = await widget.countBooking(widget.selectedBox == 1 ? 'KAP' : 'CLE', i + 1);
      if (mounted){
      setState(() {
        bookingCounts[i] = count;
      });}
    }
    if (mounted){
    setState(() {
      _loading = false;
    });}
  }

  bool _isFull(int? count) {
    return count != null && count >= Vacancy_Red;
  }

  Color _getColor(int _count) {
    if (_count < Vacancy_Green)
      return Colors.green;
    else if (_count >= Vacancy_Green && _count <= Vacancy_Yellow)
      return Colors.yellowAccent;
    else
      return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return _loading == true
        ? LoadingScroll(isDarkMode: widget.isDarkMode)
        : Column(
      children: [
        SizedBox(height: 20),
        Text(
          'Capacity Indicator',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w900,
            fontSize: 25,
              color: widget.isDarkMode ? Colors.white : Colors.black
          ),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: MediaQuery.of(context).size.width * 0.1),
            Container(width: MediaQuery.of(context).size.width * 0.15, height: 5, color: Colors.green),
            SizedBox(width: MediaQuery.of(context).size.width * 0.03),
            Text('Available', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black)),
            SizedBox(width: MediaQuery.of(context).size.width * 0.2),
            Container(width: MediaQuery.of(context).size.width * 0.15, height: 5, color: Colors.yellowAccent),
            SizedBox(width: MediaQuery.of(context).size.width * 0.03),
            Text('Half Full', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black)),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: MediaQuery.of(context).size.width * 0.4),
            Text('FULL', style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black)),
            Container(width: MediaQuery.of(context).size.width * 0.15, height: 5, color: Colors.red),
          ],
        ),
        ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: widget.departureTimes.length,
            itemBuilder: (context, index) {
              final time = widget.departureTimes[index];
              List KAPDepartureTIME = widget.KAPDepartureTime;
              List CLEDepartureTIME = widget.CLEDepartureTime;
              bool isBookedKAP = index == widget.bookedTripIndexKAP;
              bool isBookedCLE = index == widget.bookedTripIndexCLE;
              bool canBook = widget.selectedBox == 1
                  ? widget.bookedTripIndexKAP == null
                  : widget.bookedTripIndexCLE == null;
              int? count = bookingCounts[index];
              bool isFull = _isFull(count);

              return Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 0.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: isFull == true ? Colors.grey[300] : Colors.lightBlue[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0.0), // Set to 0.0 for 90-degree corners
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                              child: Row(
                                children: [
                                  if (count != null)
                                    Container(width: 8, height: 57, color: _getColor(count)),
                                  Text(
                                    ' Departure Trip ${index + 1}',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(width: 70),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      width: 2,
                                      height: 40,
                                      color: Colors.black, // Adjust color as needed
                                    ),
                                  ),
                                  SizedBox(width: 30),
                                  Text(
                                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: isFull
                              ? null
                              : () {
                            if (!isFull) {
                              if (widget.selectedBox == 1) {
                                // Check the current state and decide whether to show the bottom sheet
                                if (!isBookedKAP) {
                                  widget.updateBookingStatusKAP(index, true);
                                  widget.showBusStopSelectionBottomSheet(context);
                                } else {
                                  widget.updateBookingStatusKAP(index, false);
                                }
                              } else {
                                // Check the current state and decide whether to show the bottom sheet
                                if (!isBookedCLE) {
                                  widget.updateBookingStatusCLE(index, true);
                                  widget.showBusStopSelectionBottomSheet(context);
                                } else {
                                  widget.updateBookingStatusCLE(index, false);
                                }
                              }
                            }
                          },
                          child: Icon(
                            widget.selectedBox == 1
                                ? (isBookedKAP ? Icons.check_box : Icons.check_box_outline_blank)
                                : (isBookedCLE ? Icons.check_box : Icons.check_box_outline_blank),
                            color: isFull ? Colors.grey : Colors.blue,
                            size: 30,
                          ),
                        )

                      ],
                    ),
                  ],
                ),
              );
            }),
        if (canConfirm())
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: widget.onPressedConfirm,
                child: Text('Confirm'),
              ),
            ),
          ),
        SizedBox(height: 20),
        if (widget.selectedBox == 1 && DateTime.now().hour >= widget.eveningService)
          Row(
            children: [
              SizedBox(width: 10),
              Text(
                'Estimated Arrivng Time at KAP',
                style: TextStyle(
                  fontSize: 23,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? Colors.white : Colors.black
                ),
              ),
            ],
          ),
        if (widget.selectedBox == 2 && DateTime.now().hour >= widget.eveningService)
          Row(
            children: [
              SizedBox(width: 10),
              Text(
                'Estimated Arrivng Time at CLE',
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                  fontSize: 23,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        SizedBox(height: 5),
        if (DateTime.now().hour >= widget.eveningService)
        Row(
          children: [
            SizedBox(width: MediaQuery.of(context).size.width * 0.05),
            Text('Bus Stop',
              style: TextStyle(
                fontSize: 10,
                  color: widget.isDarkMode ? Colors.white : Colors.black
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width * 0.32),
            Text('Upcoming bus(min)',
              style: TextStyle(
                fontSize: 10,
                  color: widget.isDarkMode ? Colors.white : Colors.black
              ),
            ),
            SizedBox(width: 20),
            Text('Next bus(min)',
              style: TextStyle(
                fontSize: 10,
                  color: widget.isDarkMode ? Colors.white : Colors.black
              ),
            ),
          ],
        ),
        if (DateTime.now().hour >= widget.eveningService)
          EveningStartPoint.getBusTime(2, context),
      ],
    );
  }
}

class BookingConfirmation extends StatefulWidget {
  final int selectedBox;
  int? bookedTripIndexKAP;
  int? bookedTripIndexCLE;
  final List<DateTime> Function() getDepartureTimes;
  final VoidCallback onCancel;
  String? BusStop;
  final List<DateTime> KAPDepartureTime;
  final List<DateTime> CLEDepartureTime;
  final int eveningService;
  final bool isDarkMode;

  BookingConfirmation({
    required this.selectedBox,
    this.bookedTripIndexKAP,
    this.bookedTripIndexCLE,
    required this.getDepartureTimes,
    required this.onCancel,
    this.BusStop,
    required this.KAPDepartureTime,
    required this.CLEDepartureTime,
    required this.eveningService,
    required this.isDarkMode
  });

  @override
  State<BookingConfirmation> createState() => _BookingConfirmationState();
}


class _BookingConfirmationState extends State<BookingConfirmation> {
  late Map<String, String?> ColorValues;
  int random_num = 1;
  DateTime? now;
  late Timer timer;
  bool _loading = true;
  int departureSeconds = 0;
  Duration timeUpdateInterval = Duration(seconds: 1);
  Duration apiFetchInterval = Duration(minutes: 3);
  int secondsElapsed = 0;
  Timer? _clocktimer;
  SharedPreferenceService prefsService = SharedPreferenceService();


  @override
  void initState() {

    super.initState();
    widget.KAPDepartureTime;
    widget.CLEDepartureTime;
    getTime().then((_) {
      _clocktimer = Timer.periodic(timeUpdateInterval, (timer) {
        updateTimeManually();
        secondsElapsed += timeUpdateInterval.inSeconds;

        if (secondsElapsed >= apiFetchInterval.inSeconds) {
          getTime();
          secondsElapsed = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _clocktimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }




  Color? generateColor(DateTime departureTime, int selectedTripNo) {
    List<Color?> colors = [
      Colors.red[100],
      Colors.yellow[200],
      Colors.white,
      Colors.tealAccent[100],
      Colors.orangeAccent[200],
      Colors.greenAccent[100],
      Colors.indigo[100],
      Colors.purpleAccent[100],
      Colors.grey[400],
      Colors.limeAccent[100]
    ];

    //DateTime departureTime = DT[selectedTripNo - 1];
    int departureSeconds = departureTime.hour * 3600 + departureTime.minute * 60;
    int combinedSeconds = now!.second + departureSeconds;
    int roundedSeconds = (combinedSeconds ~/ 10) * 10;
    DateTime roundedTime = DateTime(
        now!.year, now!.month, now!.day, now!.hour, now!.minute, roundedSeconds);
    int seed = roundedTime.millisecondsSinceEpoch ~/ (1000 * 10);
    Random random = Random(seed);
    int syncedRandomNum = random.nextInt(10);
    return colors[syncedRandomNum];
  }

  Future<void> getTime() async {
    try {
      final uri = Uri.parse('https://worldtimeapi.org/api/timezone/Singapore');
      print("Printing URI");
      print(uri);
      final response = await get(uri);
      print("Printing response");
      print(response);

      // Response response = await get(
      //     Uri.parse('https://worldtimeapi.org/api/timezone/Singapore'));
      print(response.body);
      Map data = jsonDecode(response.body);
      print(data);
      String datetime = data['datetime'];
      String offset = data['utc_offset'].substring(1, 3);
      setState(() {
        now = DateTime.parse(datetime);
        now = now!.add(Duration(hours: int.parse(offset)));
      });
    }
    catch (e) {
      print('caught error: $e');
    }
  }

  void updateTimeManually(){
    setState(() {
      now = now!.add(timeUpdateInterval);
    });
  }
  void showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Cancel Booking"),
          content: Text("Are you sure you want to cancel this booking?"),
          actions: <Widget>[
            TextButton(
              child: Text("No"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Yes"),
              onPressed: () {
                widget.onCancel();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {


    final int? bookedTripIndex = widget.selectedBox == 1
        ? widget.bookedTripIndexKAP
        : widget.bookedTripIndexCLE;
    final DateTime bookedTime = widget.getDepartureTimes()[bookedTripIndex!];
    final String station = widget.selectedBox == 1 ? 'KAP' : 'CLE';
    DateTime currentTime = DateTime.now();
    bool isAfter3pm = currentTime.hour >= 15 ? true : false;
    prefsService.saveBookingData(
      widget.selectedBox,
      widget.bookedTripIndexKAP,
      widget.bookedTripIndexCLE,
      widget.BusStop,
    );


    if (bookedTime != null) {
      if (now == null) {
        return Container(child: LoadingScroll(isDarkMode: widget.isDarkMode));
      }
      else {
        return Container(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Container(
                  color: generateColor(bookedTime, bookedTripIndex),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.event_available, color: Colors.blueAccent),
                            Text(
                              'Booking Confirmation:',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            SizedBox(width: 10),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'Trip Number',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.4),
                            //SizedBox(width: 300),
                            Text('${bookedTripIndex + 1}',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),)
                          ],
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: MediaQuery
                              .of(context)
                              .size
                              .width * 0.9,
                          height: 1,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'Time',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.55),
                            //SizedBox(width: 350),
                            Text('${bookedTime.hour.toString().padLeft(
                                2, '0')}:${bookedTime.minute.toString().padLeft(
                                2, '0')}',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),)
                          ],
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: MediaQuery
                              .of(context)
                              .size
                              .width * 0.9,
                          height: 1,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'Station',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.51),
                            //SizedBox(width: 333),
                            Text('$station',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),)
                          ],
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: MediaQuery
                              .of(context)
                              .size
                              .width * 0.9,
                          height: 1,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'BusStop:',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.48),
                            //SizedBox(width:320),
                            Text('${widget.BusStop}',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                              ),)
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(width: MediaQuery
                                .of(context)
                                .size
                                .width * 0.65),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                              child: ElevatedButton(
                                onPressed: showCancelDialog,
                                child: Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (DateTime.now().hour >= widget.eveningService)
                EveningStartPoint.getBusTime(widget.selectedBox, context),
            ],
          ),
        );
      }
    }
    else
      return SizedBox();
  }}


class SharedPreferenceService {
  static const String bookingDataKey = 'bookingData';

  // Save booking data
  Future<void> saveBookingData(selectedBox, bookedTripIndexKAP, bookedTripIndexCLE, BusStop) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedBox', selectedBox);
    await prefs.setInt('bookedTripIndexKAP', bookedTripIndexKAP ?? -1);
    await prefs.setInt('bookedTripIndexCLE', bookedTripIndexCLE ?? -1);
    await prefs.setString('selectedBusStop', BusStop!);
  }

  // Retrieve booking data
  Future<Map<String, dynamic>?> getBookingData() async {
    final prefs = await SharedPreferences.getInstance();

    // Fetch stored values from SharedPreferences
    int? selectedBox = prefs.getInt('selectedBox');
    int? bookedTripIndexKAP = prefs.getInt('bookedTripIndexKAP');
    int? bookedTripIndexCLE = prefs.getInt('bookedTripIndexCLE');
    String? selectedBusStop = prefs.getString('selectedBusStop');

    // Check if any of the required values are missing
    if (selectedBox != null && selectedBusStop != null) {
      // Create a map to return the values
      return {
        'selectedBox': selectedBox,
        'bookedTripIndexKAP': bookedTripIndexKAP == -1 ? null : bookedTripIndexKAP, // Handle the null value using -1
        'bookedTripIndexCLE': bookedTripIndexCLE == -1 ? null : bookedTripIndexCLE, // Handle the null value using -1
        'BusStop': selectedBusStop,
      };
    } else {
      // If the data is incomplete or missing, return null
      return null;
    }
  }


  // Clear booking data
  Future<void> clearBookingData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(bookingDataKey);
  }
}



