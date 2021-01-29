import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'event.dart';

const String simplePeriodicTask = 'simplePeriodicTask';

const kEventKey = 'work_manager_events';

// for debugging
Future<void> logging(String message) async {
  // 삼성: 7777 or 화웨이: 8888 or 애플: 9999
  final port = '9999';
  try {
    await http.get('http://192.168.0.45:$port/workManager?$message').timeout(Duration(seconds: 3));
  } catch (e) {
    print(e);
  }
}

// for debugging
Future<void> addEventInSharedPreferences(Event event) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String json = prefs.getString(kEventKey) ?? '[]';
  final List events = jsonDecode(json)..add(event.toJson());
  prefs.setString(kEventKey, jsonEncode(events));
}

void callbackDispatcher() {
  Workmanager.executeTask((task, _) async {
    Event event = Event(title: task);
    await addEventInSharedPreferences(event);
    await logging(event.title);
    return Future.value(true);
  });
}

void main() {
  initializeDateFormatting();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(home: TestScreen());
}

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> with WidgetsBindingObserver {
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onLoad();
  }

  Future<void> _onLoad() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final String json = prefs.getString(kEventKey) ?? '[]';
    _events = jsonDecode(json).map<Event>((v) => Event.fromJson(v)).toList();
    print('events: $_events');
    setState(() {});
    if (!mounted) return;
  }

  Future<void> _onInit() async {
    Workmanager.initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
    await addEventInSharedPreferences(Event(title: '# init'));
  }

  Future<void> _onRegister() async {
    await Workmanager.registerPeriodicTask(
      '3',
      simplePeriodicTask,
      frequency: Duration(minutes: 15),
    );
    await addEventInSharedPreferences(Event(title: '# start'));
  }

  Future<void> _onCancelAll() async {
    await Workmanager.cancelAll();
    await addEventInSharedPreferences(Event(title: '# cancel'));
  }

  Future<void> _onClear() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(kEventKey);
    setState(() => _events = []);
  }

  void showError(String errorMessage) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) {
        return Container(
          height: 200,
          child: Center(
            child: ListView(
              padding: EdgeInsets.all(15),
              children: <Widget>[Text(errorMessage)],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WorkManager Example'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _onLoad)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          RaisedButton(
            child: Text('init'),
            onPressed: _onInit,
          ),
          AndroidOnlyEnabledButton(
            child: Text('register'),
            onPressed: _onRegister,
          ),
          AndroidOnlyEnabledButton(
            child: Text('cancel'),
            onPressed: _onCancelAll,
          ),
          RaisedButton(
            child: Text('clear'),
            onPressed: _onClear,
          ),
          SizedBox(height: 10),
          if (_events.isEmpty)
            Center(child: Text('이벤트 없음'))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onLoad,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _events.length,
                  itemBuilder: (_, i) {
                    final Event event = _events[i];
                    final bool hasError = event.error.isNotEmpty;
                    final Color textColors = hasError ? Colors.blue : Colors.black87;
                    String logTimeIntervalMinutes = '';
                    if (i != 0) {
                      final DateTime previousEventTime = _events[i - 1].logTime;
                      final int interval =
                          event.logTime.difference(previousEventTime).inMinutes.abs();
                      if (interval != 0) logTimeIntervalMinutes = ' ($interval분)';
                    }
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        event.title + logTimeIntervalMinutes,
                        style: TextStyle(color: textColors),
                      ),
                      trailing: Text(
                        DateFormat('M/d a H:mm:ss', 'ko').format(event.logTime),
                        style: TextStyle(color: textColors),
                      ),
                      onTap: hasError ? () => showError(event.error) : null,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AndroidOnlyEnabledButton extends RaisedButton {
  AndroidOnlyEnabledButton({
    @required Widget child,
    @required VoidCallback onPressed,
  })  : assert(child != null, onPressed != null),
        super(child: child, onPressed: (Platform.isAndroid) ? onPressed : null);
}
