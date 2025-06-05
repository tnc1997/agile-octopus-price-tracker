import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home/home_route.dart';
import 'welcome/welcome_route.dart';

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
          $welcomeRoute,
        ],
        redirect: (context, state) async {
          final preferences = context.read<SharedPreferencesAsync>();

          if (!await preferences.containsKey('import_product_code')) {
            return WelcomeRoute().location;
          }

          if (!await preferences.containsKey('region_code')) {
            return WelcomeRoute().location;
          }

          return null;
        },
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

class OctopusEnergyApiClient {
  final http.Client _client;

  IndustryService? _industry;
  ProductsService? _products;

  OctopusEnergyApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  IndustryService get industry {
    return _industry ??= IndustryService(
      client: _client,
    );
  }

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

class IndustryService {
  final http.Client _client;

  const IndustryService({
    required http.Client client,
  }) : _client = client;

  Future<PaginatedGridSupplyPointList> listIndustryGridSupplyPoints({
    int? page,
    String? postcode,
  }) async {
    final response = await _client.get(
      Uri.https(
        'api.octopus.energy',
        '/v1/industry/grid-supply-points',
        {
          if (page != null) 'page': page.toString(),
          if (postcode != null) 'postcode': postcode,
        },
      ),
    );

    OctopusEnergyApiClientException.checkIsSuccessStatusCode(response);

    return PaginatedGridSupplyPointList.fromJson(
      json.decode(
        response.body,
      ),
    );
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

class GridSupplyPointGroupIds {
  static const eastEngland = '_A';
  static const eastMidlands = '_B';
  static const london = '_C';
  static const northWalesMerseysideAndCheshire = '_D';
  static const westMidlands = '_E';
  static const northEastEngland = '_F';
  static const northWestEngland = '_G';
  static const northScotland = '_P';
  static const southAndCentralScotland = '_N';
  static const southEastEngland = '_J';
  static const southernEngland = '_H';
  static const southWales = '_K';
  static const southWestEngland = '_L';
  static const yorkshire = '_M';

  const GridSupplyPointGroupIds._();
}

class PaginatedGridSupplyPointList {
  final int count;
  final List<GridSupplyPoint> results;
  final Uri? next;
  final Uri? previous;

  const PaginatedGridSupplyPointList({
    required this.count,
    required this.results,
    this.next,
    this.previous,
  });

  factory PaginatedGridSupplyPointList.fromJson(
    Map<String, dynamic> json,
  ) {
    final next = json['next'];
    final previous = json['previous'];

    return PaginatedGridSupplyPointList(
      count: json['count'],
      results: List<GridSupplyPoint>.from(
        json['results'].map(
          (result) {
            return GridSupplyPoint.fromJson(result);
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

class GridSupplyPoint {
  final String groupId;

  const GridSupplyPoint({
    required this.groupId,
  });

  factory GridSupplyPoint.fromJson(
    Map<String, dynamic> json,
  ) {
    return GridSupplyPoint(
      groupId: json['group_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
    };
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
class Link {
  final Uri? href;
  final String? method;
  final String? rel;

  const Link({
    this.href,
    this.method,
    this.rel,
  });

  factory Link.fromJson(
    Map<String, dynamic> json,
  ) {
    return Link(
      href: json['href'] != null ? Uri.parse(json['href']) : null,
      method: json['method'],
      rel: json['rel'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'href': href?.toString(),
      'method': method,
      'rel': rel,
    };
  }
}

class PaymentMethods {
  static const directDebitMonthly = 'direct_debit_monthly';
  static const directDebitQuarterly = 'direct_debit_quarterly';
  static const paymentOnReceiptOfBill = 'porob';
  static const prepayment = 'prepayment';
  static const varying = 'varying';

  const PaymentMethods._();
}

class SampleQuotes {
  final Map<String, int>? electricitySingleRate;
  final Map<String, int>? electricityDualRate;
  final Map<String, int>? dualFuelSingleRate;
  final Map<String, int>? dualFuelDualRate;

  const SampleQuotes({
    this.electricitySingleRate,
    this.electricityDualRate,
    this.dualFuelSingleRate,
    this.dualFuelDualRate,
  });

  factory SampleQuotes.fromJson(
    Map<String, dynamic> json,
  ) {
    return SampleQuotes(
      electricitySingleRate: json['electricity_single_rate'] != null
          ? Map<String, int>.from(
              json['electricity_single_rate'].map(
                (key, value) {
                  return MapEntry<String, int>(
                    key,
                    value.toInt(),
                  );
                },
              ),
            )
          : null,
      electricityDualRate: json['electricity_dual_rate'] != null
          ? Map<String, int>.from(
              json['electricity_dual_rate'].map(
                (key, value) {
                  return MapEntry<String, int>(
                    key,
                    value.toInt(),
                  );
                },
              ),
            )
          : null,
      dualFuelSingleRate: json['dual_fuel_single_rate'] != null
          ? Map<String, int>.from(
              json['dual_fuel_single_rate'].map(
                (key, value) {
                  return MapEntry<String, int>(
                    key,
                    value.toInt(),
                  );
                },
              ),
            )
          : null,
      dualFuelDualRate: json['dual_fuel_dual_rate'] != null
          ? Map<String, int>.from(
              json['dual_fuel_dual_rate'].map(
                (key, value) {
                  return MapEntry<String, int>(
                    key,
                    value.toInt(),
                  );
                },
              ),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'electricity_single_rate': electricitySingleRate,
      'electricity_dual_rate': electricityDualRate,
      'dual_fuel_single_rate': dualFuelSingleRate,
      'dual_fuel_dual_rate': dualFuelDualRate,
    };
  }
}
