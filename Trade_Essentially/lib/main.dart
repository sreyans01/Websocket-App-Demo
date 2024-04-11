import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trade_essentially/constants.dart';
import 'package:trade_essentially/network_constant.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  HashSet<int> subscribedStocks = HashSet();
  late Future<Map<String, Map<String, dynamic>>> _futureData;
  final _channel = IOWebSocketChannel.connect(
      NetworkConstants.getWebsocketUrl(StringConstants.FIRSTNAME));
  Timer? _timer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Watchlist'),
      ),
      body: FutureBuilder<Map<String, Map<String, dynamic>>>(
        future: _futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            Map<String, Map<String, dynamic>> data =
                snapshot.data ?? <String, Map<String, dynamic>>{};
            return ListView.builder(
              itemCount: data.keys.length,
              itemBuilder: (context, index) {
                var value = data.values.elementAt(index);
                return stockItem(
                    int.parse(data.keys.elementAt(index)), value, data);
              },
            );
          }
        },
      ),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadJsonData() async {
    String jsonData = await rootBundle.loadString('assets/stocks.json');
    Map<String, dynamic> dataMap = json.decode(jsonData);
    Map<String, Map<String, dynamic>> finalDataMap = HashMap();
    // Access data from the map
    dataMap.forEach((key, value) {
      finalDataMap[key] = json.decode(jsonEncode(value));

      print('Company: ${value['company']}');
      print('Symbol: ${value['symbol']}');
      print('Industry: ${value[Constants.KEY_INDUSTRY]}');
      print('Sectoral Index: ${value['sectoralIndex']}');
      print('-------------------------');
    });

    return finalDataMap;
  }

  @override
  void initState() {
    super.initState();
    _futureData = _loadJsonData();
    _channel.stream.listen((message) {
      // Handle incoming messages here
      Map<String, dynamic> dataMap = json.decode(message);
      _futureData.then((map) {
        dataMap.forEach((key, value) {
          map[key]?[Constants.KEY_LTP] = value.toString();
          print('Received message: $key ${map[key]?[Constants.KEY_LTP]}');
        });
        setState(() {});
      });
      // You can parse the message if it's in JSON format
      // var parsedMessage = json.decode(message);
      // Then, do something with the parsed message
    });
  }

  void subscribe(int index) {
    // Create and send the message
    if (index > 0) subscribedStocks.add(index);
    Map<String, dynamic> message = {
      "Task": "subscribe",
      "Mode": "ltp",
      "Tokens": subscribedStocks.toList()
    };
    print("${jsonEncode(message)}");
    _channel.sink.add(jsonEncode(message));
  }

  void unsubscribe(int index) {
    // Create and send the message
    subscribedStocks.remove(index);
    Map<String, dynamic> message = {
      "Task": "unsubscribe",
      "Mode": "ltp",
      "Tokens": [index]
    };
    _channel.sink.add(jsonEncode(message));
  }

  @override
  void dispose() {
    int goingAwayStatus = 1001;
    _channel.sink.close(goingAwayStatus);
    super.dispose();
  }

  Widget stockItem(
      int index, Map<String, dynamic> stock, Map<String, dynamic> stockData) {
    return Dismissible(
      key: Key(index.toString()),
      direction: DismissDirection.startToEnd,
      onDismissed: (direction) {
        setState(() {
          _futureData.then((stockData) {
            stockData.remove(index.toString());
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${stock['company']} deleted from watchlist"),
          ),
        );
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Icon(Icons.delete, color: Colors.white),
        ),
      ),
      child: Column(
        children: <Widget>[
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(stock[Constants.KEY_SYMBOL]),
                Text(stock[Constants.KEY_LTP] ?? "")
              ],
            ),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(stock[Constants.KEY_SECTORAL_INDEX]),
                Text(StringConstants.LTP)
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                  onPressed: () {
                    subscribe(index);
                  },
                  child: Text(StringConstants.SUBSCRIBE)),
              TextButton(
                  onPressed: () {
                    unsubscribe(index);
                  },
                  child: Text(
                    StringConstants.UNSUBSCRIBE,
                    style: TextStyle(color: Colors.red),
                  )),
            ],
          ),
          Divider(), // Divider after each ListTile
        ],
      ),
    );
  }

  void subscribeToAll(List<String> stocks) {
    stocks.forEach((element) {
      subscribedStocks.add(int.parse(element));
    });
    subscribe(-1);
  }
}
