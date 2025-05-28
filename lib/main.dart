import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider(
          create: (context) {
            return OctopusEnergyApiClient();
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Price Tracker for Agile Octopus',
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xfff050f8),
          onPrimary: Color(0xff100030),
          secondary: Color(0xff5840ff),
          onSecondary: Color(0xffffffff),
          error: Color(0xffff3e68),
          onError: Color(0xffffffff),
          surface: Color(0xff100030),
          onSurface: Color(0xffffffff),
        ),
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
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class OctopusEnergyApiClient {
  final http.Client _client;

  ProductsService? _products;

  OctopusEnergyApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  ProductsService get products {
    return _products ??= ProductsService(
      client: _client,
    );
  }
}

class OctopusEnergyApiClientException implements Exception {
  /// Checks that the [response] has a success status code.
  ///
  /// Throws an [OctopusEnergyApiClientException] if the [response] does not have a success status code.
  static http.Response checkIsSuccessStatusCode(
    http.Response response,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OctopusEnergyApiClientException();
    } else {
      return response;
    }
  }
}

class ProductsService {
  final http.Client _client;

  const ProductsService({
    required http.Client client,
  }) : _client = client;

  Future<PaginatedHistoricalChargeList> listElectricityTariffStandardUnitRates(
    String productCode,
    String tariffCode, {
    int? page,
    int? pageSize,
    DateTime? periodFrom,
    DateTime? periodTo,
  }) async {
    final response = await _client.get(
      Uri.https(
        'api.octopus.energy',
        '/v1/products/$productCode/electricity-tariffs/$tariffCode/standard-unit-rates',
        {
          if (page != null) 'page': page,
          if (pageSize != null) 'page_size': pageSize,
          if (periodFrom != null) 'period_from': periodFrom.toIso8601String(),
          if (periodTo != null) 'period_to': periodTo.toIso8601String(),
        },
      ),
    );

    OctopusEnergyApiClientException.checkIsSuccessStatusCode(response);

    return PaginatedHistoricalChargeList.fromJson(
      json.decode(
        response.body,
      ),
    );
  }
}

class PaginatedHistoricalChargeList {
  final int count;
  final List<HistoricalCharge> results;
  final Uri? next;
  final Uri? previous;

  const PaginatedHistoricalChargeList({
    required this.count,
    required this.results,
    this.next,
    this.previous,
  });

  factory PaginatedHistoricalChargeList.fromJson(
    Map<String, dynamic> json,
  ) {
    final next = json['next'];
    final previous = json['previous'];

    return PaginatedHistoricalChargeList(
      count: json['count'],
      results: List<HistoricalCharge>.from(
        json['results'].map(
          (result) {
            return HistoricalCharge.fromJson(result);
          },
        ),
      ),
      next: next != null ? Uri.parse(next) : null,
      previous: previous != null ? Uri.parse(previous) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'results': List<dynamic>.from(
        results.map(
          (result) {
            return result.toJson();
          },
        ),
      ),
      'next': next,
      'previous': previous,
    };
  }
}

class HistoricalCharge {
  final String? paymentMethod;
  final DateTime? validFrom;
  final DateTime? validTo;
  final double valueExcVat;
  final double valueIncVat;

  const HistoricalCharge({
    this.paymentMethod,
    this.validFrom,
    this.validTo,
    required this.valueExcVat,
    required this.valueIncVat,
  });

  factory HistoricalCharge.fromJson(
    Map<String, dynamic> json,
  ) {
    final validFrom = json['valid_from'];
    final validTo = json['valid_to'];

    return HistoricalCharge(
      paymentMethod: json['payment_method'],
      valueExcVat: json['value_exc_vat'].toDouble(),
      valueIncVat: json['value_inc_vat'].toDouble(),
      validFrom: validFrom != null ? DateTime.parse(validFrom) : null,
      validTo: validTo != null ? DateTime.parse(validTo) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_method': paymentMethod,
      'value_exc_vat': valueExcVat,
      'value_inc_vat': valueIncVat,
      'valid_from': validFrom?.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
    };
  }
}
