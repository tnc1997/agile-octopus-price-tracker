import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'main.g.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider(
          create: (context) {
            return OctopusEnergyApiClient();
          },
        ),
        Provider(
          create: (context) {
            return SharedPreferencesAsync();
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          $homeRoute,
        ],
      ),
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
    );
  }
}

@TypedGoRoute<HomeRoute>(
  path: '/',
)
class HomeRoute extends GoRouteData {
  const HomeRoute();

  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return const HomeScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<PaginatedHistoricalChargeList> _future;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.data case final data?) {
              data.results.sort(
                (a, b) {
                  if (a.validFrom case final a?) {
                    if (b.validFrom case final b?) {
                      return a.compareTo(b);
                    }
                  }

                  return 0;
                },
              );

              return ListView.builder(
                itemBuilder: (context, index) {
                  return HistoricalChargeListTile(
                    charge: data.results[index],
                  );
                },
                itemCount: data.results.length,
              );
            }

            return Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final client = context.read<OctopusEnergyApiClient>();

    _future = client.products.listElectricityTariffStandardUnitRates(
      'AGILE-24-10-01',
      'E-1R-AGILE-24-10-01-E',
      page: 1,
      pageSize: 96,
      periodFrom: DateTime.now().toUtc(),
    );
  }
}

class HistoricalChargeListTile extends StatelessWidget {
  const HistoricalChargeListTile({
    super.key,
    required this.charge,
  });

  final HistoricalCharge charge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        DateFormat('Hm').format(
          charge.validFrom!.toLocal(),
        ),
      ),
      subtitle: Text(
        NumberFormat('0.00p/kWh').format(
          charge.valueIncVat,
        ),
      ),
    );
  }
}

class PostcodeFormField extends StatelessWidget {
  const PostcodeFormField({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        label: Text('Postcode'),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your postcode.';
        }

        return null;
      },
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
          if (page != null) 'page': page.toString(),
          if (pageSize != null) 'page_size': pageSize.toString(),
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
