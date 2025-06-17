import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'common/shell_route.dart';
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
          $shellRoute,
          $welcomeRoute,
        ],
        redirect: (context, state) async {
          final preferences = context.read<SharedPreferencesAsync>();

          if (!await preferences.containsKey('grid_supply_point_group_id')) {
            return WelcomeRoute().location;
          }

          if (!await preferences.containsKey('import_product_code')) {
            return WelcomeRoute().location;
          }

          if (!await preferences.containsKey('import_tariff_code')) {
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
          surfaceContainerLowest: Color(0xff180048),
          surfaceContainerLow: Color(0xff180048),
          surfaceContainer: Color(0xff180048),
          surfaceContainerHigh: Color(0xff180048),
          surfaceContainerHighest: Color(0xff180048),
          outline: Color(0xff5840ff),
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

  Future<Product> retrieveAProduct(
    String productCode, {
    DateTime? tariffsActiveAt,
  }) async {
    final response = await _client.get(
      Uri.https(
        'api.octopus.energy',
        '/v1/products/$productCode',
        {
          if (tariffsActiveAt != null)
            'tariffs_active_at': tariffsActiveAt.toIso8601String(),
        },
      ),
    );

    OctopusEnergyApiClientException.checkIsSuccessStatusCode(response);

    return Product.fromJson(
      json.decode(
        response.body,
      ),
    );
  }
}

class Eco7ElectricityTariff {
  final String? code;
  final double? standingChargeExcVat;
  final double? standingChargeIncVat;
  final double? onlineDiscountExcVat;
  final double? onlineDiscountIncVat;
  final double? dualFuelDiscountExcVat;
  final double? dualFuelDiscountIncVat;
  final double? exitFeesExcVat;
  final double? exitFeesIncVat;
  final String? exitFeesType;
  final List<Link>? links;
  final double? dayUnitRateExcVat;
  final double? dayUnitRateIncVat;
  final double? nightUnitRateExcVat;
  final double? nightUnitRateIncVat;

  const Eco7ElectricityTariff({
    this.code,
    this.standingChargeExcVat,
    this.standingChargeIncVat,
    this.onlineDiscountExcVat,
    this.onlineDiscountIncVat,
    this.dualFuelDiscountExcVat,
    this.dualFuelDiscountIncVat,
    this.exitFeesExcVat,
    this.exitFeesIncVat,
    this.exitFeesType,
    this.links,
    this.dayUnitRateExcVat,
    this.dayUnitRateIncVat,
    this.nightUnitRateExcVat,
    this.nightUnitRateIncVat,
  });

  factory Eco7ElectricityTariff.fromJson(
    Map<String, dynamic> json,
  ) {
    return Eco7ElectricityTariff(
      code: json['code'],
      standingChargeExcVat: json['standing_charge_exc_vat']?.toDouble(),
      standingChargeIncVat: json['standing_charge_inc_vat']?.toDouble(),
      onlineDiscountExcVat: json['online_discount_exc_vat']?.toDouble(),
      onlineDiscountIncVat: json['online_discount_inc_vat']?.toDouble(),
      dualFuelDiscountExcVat: json['dual_fuel_discount_exc_vat']?.toDouble(),
      dualFuelDiscountIncVat: json['dual_fuel_discount_inc_vat']?.toDouble(),
      exitFeesExcVat: json['exit_fees_exc_vat']?.toDouble(),
      exitFeesIncVat: json['exit_fees_inc_vat']?.toDouble(),
      exitFeesType: json['exit_fees_type'],
      links: json['links'] != null
          ? List<Link>.from(
              (json['links'] as List<dynamic>).map(
                (link) {
                  return Link.fromJson(link);
                },
              ),
            )
          : null,
      dayUnitRateExcVat: json['day_unit_rate_exc_vat']?.toDouble(),
      dayUnitRateIncVat: json['day_unit_rate_inc_vat']?.toDouble(),
      nightUnitRateExcVat: json['night_unit_rate_exc_vat']?.toDouble(),
      nightUnitRateIncVat: json['night_unit_rate_inc_vat']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'standing_charge_exc_vat': standingChargeExcVat,
      'standing_charge_inc_vat': standingChargeIncVat,
      'online_discount_exc_vat': onlineDiscountExcVat,
      'online_discount_inc_vat': onlineDiscountIncVat,
      'dual_fuel_discount_exc_vat': dualFuelDiscountExcVat,
      'dual_fuel_discount_inc_vat': dualFuelDiscountIncVat,
      'exit_fees_exc_vat': exitFeesExcVat,
      'exit_fees_inc_vat': exitFeesIncVat,
      'exit_fees_type': exitFeesType,
      'links': links != null
          ? List<dynamic>.from(
              links!.map(
                (link) {
                  return link.toJson();
                },
              ),
            )
          : null,
      'day_unit_rate_exc_vat': dayUnitRateExcVat,
      'day_unit_rate_inc_vat': dayUnitRateIncVat,
      'night_unit_rate_exc_vat': nightUnitRateExcVat,
      'night_unit_rate_inc_vat': nightUnitRateIncVat,
    };
  }
}

class GasTariff {
  final String? code;
  final double? standingChargeExcVat;
  final double? standingChargeIncVat;
  final double? onlineDiscountExcVat;
  final double? onlineDiscountIncVat;
  final double? dualFuelDiscountExcVat;
  final double? dualFuelDiscountIncVat;
  final double? exitFeesExcVat;
  final double? exitFeesIncVat;
  final String? exitFeesType;
  final List<Link>? links;
  final double? standardUnitRateExcVat;
  final double? standardUnitRateIncVat;

  const GasTariff({
    this.code,
    this.standingChargeExcVat,
    this.standingChargeIncVat,
    this.onlineDiscountExcVat,
    this.onlineDiscountIncVat,
    this.dualFuelDiscountExcVat,
    this.dualFuelDiscountIncVat,
    this.exitFeesExcVat,
    this.exitFeesIncVat,
    this.exitFeesType,
    this.links,
    this.standardUnitRateExcVat,
    this.standardUnitRateIncVat,
  });

  factory GasTariff.fromJson(
    Map<String, dynamic> json,
  ) {
    return GasTariff(
      code: json['code'],
      standingChargeExcVat: json['standing_charge_exc_vat']?.toDouble(),
      standingChargeIncVat: json['standing_charge_inc_vat']?.toDouble(),
      onlineDiscountExcVat: json['online_discount_exc_vat']?.toDouble(),
      onlineDiscountIncVat: json['online_discount_inc_vat']?.toDouble(),
      dualFuelDiscountExcVat: json['dual_fuel_discount_exc_vat']?.toDouble(),
      dualFuelDiscountIncVat: json['dual_fuel_discount_inc_vat']?.toDouble(),
      exitFeesExcVat: json['exit_fees_exc_vat']?.toDouble(),
      exitFeesIncVat: json['exit_fees_inc_vat']?.toDouble(),
      exitFeesType: json['exit_fees_type'],
      links: json['links'] != null
          ? List<Link>.from(
              (json['links'] as List<dynamic>).map(
                (link) {
                  return Link.fromJson(link);
                },
              ),
            )
          : null,
      standardUnitRateExcVat: json['standard_unit_rate_exc_vat']?.toDouble(),
      standardUnitRateIncVat: json['standard_unit_rate_inc_vat']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'standing_charge_exc_vat': standingChargeExcVat,
      'standing_charge_inc_vat': standingChargeIncVat,
      'online_discount_exc_vat': onlineDiscountExcVat,
      'online_discount_inc_vat': onlineDiscountIncVat,
      'dual_fuel_discount_exc_vat': dualFuelDiscountExcVat,
      'dual_fuel_discount_inc_vat': dualFuelDiscountIncVat,
      'exit_fees_exc_vat': exitFeesExcVat,
      'exit_fees_inc_vat': exitFeesIncVat,
      'exit_fees_type': exitFeesType,
      'links': links != null
          ? List<dynamic>.from(
              links!.map(
                (link) {
                  return link.toJson();
                },
              ),
            )
          : null,
      'standard_unit_rate_exc_vat': standardUnitRateExcVat,
      'standard_unit_rate_inc_vat': standardUnitRateIncVat,
    };
  }
}

class GridSupplyPointGroupIds {
  static const eastMidlands = '_B';
  static const easternEngland = '_A';
  static const london = '_C';
  static const merseysideAndNorthernWales = '_D';
  static const northEasternEngland = '_F';
  static const northWesternEngland = '_G';
  static const northernScotland = '_P';
  static const southEasternEngland = '_J';
  static const southWesternEngland = '_L';
  static const southernEngland = '_H';
  static const southernScotland = '_N';
  static const southernWales = '_K';
  static const westMidlands = '_E';
  static const yorkshire = '_M';

  const GridSupplyPointGroupIds._();
}

class GridSupplyPointGroupNames {
  static const eastMidlands = 'East Midlands';
  static const easternEngland = 'Eastern England';
  static const london = 'London';
  static const merseysideAndNorthernWales = 'Merseyside and Northern Wales';
  static const northEasternEngland = 'North Eastern England';
  static const northWesternEngland = 'North Western England';
  static const northernScotland = 'Northern Scotland';
  static const southEasternEngland = 'South Eastern England';
  static const southWesternEngland = 'South Western England';
  static const southernEngland = 'Southern England';
  static const southernScotland = 'Southern Scotland';
  static const southernWales = 'Southern Wales';
  static const westMidlands = 'West Midlands';
  static const yorkshire = 'Yorkshire';

  const GridSupplyPointGroupNames._();
}

class PaginatedGridSupplyPointList {
  final int? count;
  final List<GridSupplyPoint>? results;
  final Uri? next;
  final Uri? previous;

  const PaginatedGridSupplyPointList({
    this.count,
    this.results,
    this.next,
    this.previous,
  });

  factory PaginatedGridSupplyPointList.fromJson(
    Map<String, dynamic> json,
  ) {
    return PaginatedGridSupplyPointList(
      count: json['count'],
      results: json['results'] != null
          ? List<GridSupplyPoint>.from(
              (json['results'] as List<dynamic>).map(
                (result) {
                  return GridSupplyPoint.fromJson(result);
                },
              ),
            )
          : null,
      next: json['next'] != null ? Uri.parse(json['next']) : null,
      previous: json['previous'] != null ? Uri.parse(json['previous']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'results': results != null
          ? List<dynamic>.from(
              results!.map(
                (result) {
                  return result.toJson();
                },
              ),
            )
          : null,
      'next': next?.toString(),
      'previous': previous?.toString(),
    };
  }
}

class GridSupplyPoint {
  final String? groupId;

  const GridSupplyPoint({
    this.groupId,
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
  final int? count;
  final List<HistoricalCharge>? results;
  final Uri? next;
  final Uri? previous;

  const PaginatedHistoricalChargeList({
    this.count,
    this.results,
    this.next,
    this.previous,
  });

  factory PaginatedHistoricalChargeList.fromJson(
    Map<String, dynamic> json,
  ) {
    return PaginatedHistoricalChargeList(
      count: json['count']?.toInt(),
      results: json['results'] != null
          ? List<HistoricalCharge>.from(
              (json['results'] as List<dynamic>).map(
                (result) {
                  return HistoricalCharge.fromJson(result);
                },
              ),
            )
          : null,
      next: json['next'] != null ? Uri.parse(json['next']) : null,
      previous: json['previous'] != null ? Uri.parse(json['previous']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'results': results != null
          ? List<dynamic>.from(
              results!.map(
                (result) {
                  return result.toJson();
                },
              ),
            )
          : null,
      'next': next?.toString(),
      'previous': previous?.toString(),
    };
  }
}

class HistoricalCharge {
  final String? paymentMethod;
  final DateTime? validFrom;
  final DateTime? validTo;
  final double? valueExcVat;
  final double? valueIncVat;

  const HistoricalCharge({
    this.paymentMethod,
    this.validFrom,
    this.validTo,
    this.valueExcVat,
    this.valueIncVat,
  });

  factory HistoricalCharge.fromJson(
    Map<String, dynamic> json,
  ) {
    return HistoricalCharge(
      paymentMethod: json['payment_method'],
      validFrom: json['valid_from'] != null
          ? DateTime.parse(json['valid_from'])
          : null,
      validTo:
          json['valid_to'] != null ? DateTime.parse(json['valid_to']) : null,
      valueExcVat: json['value_exc_vat']?.toDouble(),
      valueIncVat: json['value_inc_vat']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_method': paymentMethod,
      'valid_from': validFrom?.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
      'value_exc_vat': valueExcVat,
      'value_inc_vat': valueIncVat,
    };
  }
}

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

class Product {
  final String? code;
  final String? fullName;
  final String? displayName;
  final String? description;
  final bool? isVariable;
  final bool? isGreen;
  final bool? isTracker;
  final bool? isPrepay;
  final bool? isBusiness;
  final bool? isRestricted;
  final int? term;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final DateTime? tariffsActiveAt;
  final Map<String, Map<String, StandardElectricityTariff>>?
      singleRegisterElectricityTariffs;
  final Map<String, Map<String, Eco7ElectricityTariff>>?
      dualRegisterElectricityTariffs;
  final Map<String, Map<String, GasTariff>>? singleRegisterGasTariffs;
  final Map<String, Map<String, SampleQuotes>>? sampleQuotes;
  final SampleConsumption? sampleConsumption;
  final List<Link>? links;
  final String? brand;

  const Product({
    this.code,
    this.fullName,
    this.displayName,
    this.description,
    this.isVariable,
    this.isGreen,
    this.isTracker,
    this.isPrepay,
    this.isBusiness,
    this.isRestricted,
    this.term,
    this.availableFrom,
    this.availableTo,
    this.tariffsActiveAt,
    this.singleRegisterElectricityTariffs,
    this.dualRegisterElectricityTariffs,
    this.singleRegisterGasTariffs,
    this.sampleQuotes,
    this.sampleConsumption,
    this.links,
    this.brand,
  });

  factory Product.fromJson(
    Map<String, dynamic> json,
  ) {
    return Product(
      code: json['code'],
      fullName: json['full_name'],
      displayName: json['display_name'],
      description: json['description'],
      isVariable: json['is_variable'],
      isGreen: json['is_green'],
      isTracker: json['is_tracker'],
      isPrepay: json['is_prepay'],
      isBusiness: json['is_business'],
      isRestricted: json['is_restricted'],
      term: json['term'],
      availableFrom: json['available_from'] != null
          ? DateTime.parse(json['available_from'])
          : null,
      availableTo: json['available_to'] != null
          ? DateTime.parse(json['available_to'])
          : null,
      tariffsActiveAt: json['tariffs_active_at'] != null
          ? DateTime.parse(json['tariffs_active_at'])
          : null,
      singleRegisterElectricityTariffs:
          json['single_register_electricity_tariffs'] != null
              ? Map<String, Map<String, StandardElectricityTariff>>.from(
                  (json['single_register_electricity_tariffs']
                          as Map<String, dynamic>)
                      .map(
                    (key, value) {
                      return MapEntry<String,
                          Map<String, StandardElectricityTariff>>(
                        key,
                        (value as Map<String, dynamic>).map(
                          (key, value) {
                            return MapEntry<String, StandardElectricityTariff>(
                              key,
                              StandardElectricityTariff.fromJson(value),
                            );
                          },
                        ),
                      );
                    },
                  ),
                )
              : null,
      dualRegisterElectricityTariffs: json[
                  'dual_register_electricity_tariffs'] !=
              null
          ? Map<String, Map<String, Eco7ElectricityTariff>>.from(
              (json['dual_register_electricity_tariffs']
                      as Map<String, dynamic>)
                  .map(
                (key, value) {
                  return MapEntry<String, Map<String, Eco7ElectricityTariff>>(
                    key,
                    (value as Map<String, dynamic>).map(
                      (key, value) {
                        return MapEntry<String, Eco7ElectricityTariff>(
                          key,
                          Eco7ElectricityTariff.fromJson(value),
                        );
                      },
                    ),
                  );
                },
              ),
            )
          : null,
      singleRegisterGasTariffs: json['single_register_gas_tariffs'] != null
          ? Map<String, Map<String, GasTariff>>.from(
              (json['single_register_gas_tariffs'] as Map<String, dynamic>).map(
                (key, value) {
                  return MapEntry<String, Map<String, GasTariff>>(
                    key,
                    (value as Map<String, dynamic>).map(
                      (key, value) {
                        return MapEntry<String, GasTariff>(
                          key,
                          GasTariff.fromJson(value),
                        );
                      },
                    ),
                  );
                },
              ),
            )
          : null,
      sampleQuotes: json['sample_quotes'] != null
          ? Map<String, Map<String, SampleQuotes>>.from(
              (json['sample_quotes'] as Map<String, dynamic>).map(
                (key, value) {
                  return MapEntry<String, Map<String, SampleQuotes>>(
                    key,
                    (value as Map<String, dynamic>).map(
                      (key, value) {
                        return MapEntry<String, SampleQuotes>(
                          key,
                          SampleQuotes.fromJson(value),
                        );
                      },
                    ),
                  );
                },
              ),
            )
          : null,
      sampleConsumption: SampleConsumption.fromJson(json['sample_consumption']),
      links: json['links'] != null
          ? List<Link>.from(
              (json['links'] as List<dynamic>).map(
                (link) {
                  return Link.fromJson(link);
                },
              ),
            )
          : null,
      brand: json['brand'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'full_name': fullName,
      'display_name': displayName,
      'description': description,
      'is_variable': isVariable,
      'is_green': isGreen,
      'is_tracker': isTracker,
      'is_prepay': isPrepay,
      'is_business': isBusiness,
      'is_restricted': isRestricted,
      'term': term,
      'available_from': availableFrom?.toIso8601String(),
      'available_to': availableTo?.toIso8601String(),
      'tariffs_active_at': tariffsActiveAt?.toIso8601String(),
      'single_register_electricity_tariffs':
          singleRegisterElectricityTariffs != null
              ? Map<String, dynamic>.from(
                  singleRegisterElectricityTariffs!.map(
                    (key, value) {
                      return MapEntry<String, dynamic>(
                        key,
                        value.map(
                          (key, value) {
                            return MapEntry<String, dynamic>(
                              key,
                              value.toJson(),
                            );
                          },
                        ),
                      );
                    },
                  ),
                )
              : null,
      'dual_register_electricity_tariffs':
          dualRegisterElectricityTariffs != null
              ? Map<String, dynamic>.from(
                  dualRegisterElectricityTariffs!.map(
                    (key, value) {
                      return MapEntry<String, dynamic>(
                        key,
                        value.map(
                          (key, value) {
                            return MapEntry<String, dynamic>(
                              key,
                              value.toJson(),
                            );
                          },
                        ),
                      );
                    },
                  ),
                )
              : null,
      'single_register_gas_tariffs': singleRegisterGasTariffs != null
          ? Map<String, dynamic>.from(
              singleRegisterGasTariffs!.map(
                (key, value) {
                  return MapEntry<String, dynamic>(
                    key,
                    value.map(
                      (key, value) {
                        return MapEntry<String, dynamic>(
                          key,
                          value.toJson(),
                        );
                      },
                    ),
                  );
                },
              ),
            )
          : null,
      'sample_quotes': sampleQuotes != null
          ? Map<String, dynamic>.from(
              sampleQuotes!.map(
                (key, value) {
                  return MapEntry<String, dynamic>(
                    key,
                    value.map(
                      (key, value) {
                        return MapEntry<String, dynamic>(
                          key,
                          value.toJson(),
                        );
                      },
                    ),
                  );
                },
              ),
            )
          : null,
      'sample_consumption': sampleConsumption?.toJson(),
      'links': links != null
          ? List<dynamic>.from(
              links!.map(
                (link) {
                  return link.toJson();
                },
              ),
            )
          : null,
      'brand': brand,
    };
  }
}

class SampleConsumption {
  final Map<String, int>? electricitySingleRate;
  final Map<String, int>? electricityDualRate;
  final Map<String, int>? dualFuelSingleRate;
  final Map<String, int>? dualFuelDualRate;

  const SampleConsumption({
    this.electricitySingleRate,
    this.electricityDualRate,
    this.dualFuelSingleRate,
    this.dualFuelDualRate,
  });

  factory SampleConsumption.fromJson(
    Map<String, dynamic> json,
  ) {
    return SampleConsumption(
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

class StandardElectricityTariff {
  final String? code;
  final double? standingChargeExcVat;
  final double? standingChargeIncVat;
  final double? onlineDiscountExcVat;
  final double? onlineDiscountIncVat;
  final double? dualFuelDiscountExcVat;
  final double? dualFuelDiscountIncVat;
  final double? exitFeesExcVat;
  final double? exitFeesIncVat;
  final String? exitFeesType;
  final List<Link>? links;
  final double? standardUnitRateExcVat;
  final double? standardUnitRateIncVat;

  const StandardElectricityTariff({
    this.code,
    this.standingChargeExcVat,
    this.standingChargeIncVat,
    this.onlineDiscountExcVat,
    this.onlineDiscountIncVat,
    this.dualFuelDiscountExcVat,
    this.dualFuelDiscountIncVat,
    this.exitFeesExcVat,
    this.exitFeesIncVat,
    this.exitFeesType,
    this.links,
    this.standardUnitRateExcVat,
    this.standardUnitRateIncVat,
  });

  factory StandardElectricityTariff.fromJson(
    Map<String, dynamic> json,
  ) {
    return StandardElectricityTariff(
      code: json['code'],
      standingChargeExcVat: json['standing_charge_exc_vat']?.toDouble(),
      standingChargeIncVat: json['standing_charge_inc_vat']?.toDouble(),
      onlineDiscountExcVat: json['online_discount_exc_vat']?.toDouble(),
      onlineDiscountIncVat: json['online_discount_inc_vat']?.toDouble(),
      dualFuelDiscountExcVat: json['dual_fuel_discount_exc_vat']?.toDouble(),
      dualFuelDiscountIncVat: json['dual_fuel_discount_inc_vat']?.toDouble(),
      exitFeesExcVat: json['exit_fees_exc_vat']?.toDouble(),
      exitFeesIncVat: json['exit_fees_inc_vat']?.toDouble(),
      exitFeesType: json['exit_fees_type'],
      links: json['links'] != null
          ? List<Link>.from(
              (json['links'] as List<dynamic>).map(
                (link) {
                  return Link.fromJson(link);
                },
              ),
            )
          : null,
      standardUnitRateExcVat: json['standard_unit_rate_exc_vat']?.toDouble(),
      standardUnitRateIncVat: json['standard_unit_rate_inc_vat']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'standing_charge_exc_vat': standingChargeExcVat,
      'standing_charge_inc_vat': standingChargeIncVat,
      'online_discount_exc_vat': onlineDiscountExcVat,
      'online_discount_inc_vat': onlineDiscountIncVat,
      'dual_fuel_discount_exc_vat': dualFuelDiscountExcVat,
      'dual_fuel_discount_inc_vat': dualFuelDiscountIncVat,
      'exit_fees_exc_vat': exitFeesExcVat,
      'exit_fees_inc_vat': exitFeesIncVat,
      'exit_fees_type': exitFeesType,
      'links': links != null
          ? List<dynamic>.from(
              links!.map(
                (link) {
                  return link.toJson();
                },
              ),
            )
          : null,
      'standard_unit_rate_exc_vat': standardUnitRateExcVat,
      'standard_unit_rate_inc_vat': standardUnitRateIncVat,
    };
  }
}

class Address {
  String? aerialway;
  String? aeroway;
  String? allotments;
  String? amenity;
  String? borough;
  String? boundary;
  String? bridge;
  String? city;
  String? cityBlock;
  String? cityDistrict;
  String? club;
  String? commercial;
  String? continent;
  String? country;
  String? countryCode;
  String? county;
  String? craft;
  String? croft;
  String? district;
  String? emergency;
  String? farm;
  String? farmyard;
  String? hamlet;
  String? historic;
  String? houseName;
  String? houseNumber;
  String? industrial;
  String? isolatedDwelling;
  String? landuse;
  String? leisure;
  String? manMade;
  String? military;
  String? mountainPass;
  String? municipality;
  String? natural;
  String? neighbourhood;
  String? office;
  String? place;
  String? postcode;
  String? quarter;
  String? railway;
  String? region;
  String? residential;
  String? retail;
  String? road;
  String? shop;
  String? state;
  String? stateDistrict;
  String? subdivision;
  String? suburb;
  String? tourism;
  String? town;
  String? tunnel;
  String? village;
  String? waterway;

  Address({
    this.aerialway,
    this.aeroway,
    this.allotments,
    this.amenity,
    this.borough,
    this.boundary,
    this.bridge,
    this.city,
    this.cityBlock,
    this.cityDistrict,
    this.club,
    this.commercial,
    this.continent,
    this.country,
    this.countryCode,
    this.county,
    this.craft,
    this.croft,
    this.district,
    this.emergency,
    this.farm,
    this.farmyard,
    this.hamlet,
    this.historic,
    this.houseName,
    this.houseNumber,
    this.industrial,
    this.isolatedDwelling,
    this.landuse,
    this.leisure,
    this.manMade,
    this.military,
    this.mountainPass,
    this.municipality,
    this.natural,
    this.neighbourhood,
    this.office,
    this.place,
    this.postcode,
    this.quarter,
    this.railway,
    this.region,
    this.residential,
    this.retail,
    this.road,
    this.shop,
    this.state,
    this.stateDistrict,
    this.subdivision,
    this.suburb,
    this.tourism,
    this.town,
    this.tunnel,
    this.village,
    this.waterway,
  });

  factory Address.fromJson(
    Map<String, dynamic> json,
  ) {
    return Address(
      aerialway: json['aerialway'],
      aeroway: json['aeroway'],
      allotments: json['allotments'],
      amenity: json['amenity'],
      borough: json['borough'],
      boundary: json['boundary'],
      bridge: json['bridge'],
      city: json['city'],
      cityBlock: json['city_block'],
      cityDistrict: json['city_district'],
      club: json['club'],
      commercial: json['commercial'],
      continent: json['continent'],
      country: json['country'],
      countryCode: json['country_code'],
      county: json['county'],
      craft: json['craft'],
      croft: json['croft'],
      district: json['district'],
      emergency: json['emergency'],
      farm: json['farm'],
      farmyard: json['farmyard'],
      hamlet: json['hamlet'],
      historic: json['historic'],
      houseName: json['house_name'],
      houseNumber: json['house_number'],
      industrial: json['industrial'],
      isolatedDwelling: json['isolated_dwelling'],
      landuse: json['landuse'],
      leisure: json['leisure'],
      manMade: json['man_made'],
      military: json['military'],
      mountainPass: json['mountain_pass'],
      municipality: json['municipality'],
      natural: json['natural'],
      neighbourhood: json['neighbourhood'],
      office: json['office'],
      place: json['place'],
      postcode: json['postcode'],
      quarter: json['quarter'],
      railway: json['railway'],
      region: json['region'],
      residential: json['residential'],
      retail: json['retail'],
      road: json['road'],
      shop: json['shop'],
      state: json['state'],
      stateDistrict: json['state_district'],
      subdivision: json['subdivision'],
      suburb: json['suburb'],
      tourism: json['tourism'],
      town: json['town'],
      tunnel: json['tunnel'],
      village: json['village'],
      waterway: json['waterway'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aerialway': aerialway,
      'aeroway': aeroway,
      'allotments': allotments,
      'amenity': amenity,
      'borough': borough,
      'boundary': boundary,
      'bridge': bridge,
      'city': city,
      'city_block': cityBlock,
      'city_district': cityDistrict,
      'club': club,
      'commercial': commercial,
      'continent': continent,
      'country': country,
      'country_code': countryCode,
      'county': county,
      'craft': craft,
      'croft': croft,
      'district': district,
      'emergency': emergency,
      'farm': farm,
      'farmyard': farmyard,
      'hamlet': hamlet,
      'historic': historic,
      'house_name': houseName,
      'house_number': houseNumber,
      'industrial': industrial,
      'isolated_dwelling': isolatedDwelling,
      'landuse': landuse,
      'leisure': leisure,
      'man_made': manMade,
      'military': military,
      'mountain_pass': mountainPass,
      'municipality': municipality,
      'natural': natural,
      'neighbourhood': neighbourhood,
      'office': office,
      'place': place,
      'postcode': postcode,
      'quarter': quarter,
      'railway': railway,
      'region': region,
      'residential': residential,
      'retail': retail,
      'road': road,
      'shop': shop,
      'state': state,
      'state_district': stateDistrict,
      'subdivision': subdivision,
      'suburb': suburb,
      'tourism': tourism,
      'town': town,
      'tunnel': tunnel,
      'village': village,
      'waterway': waterway,
    };
  }
}

class Place {
  Address? address;
  String? addressType;
  List<double>? boundingBox;
  String? displayName;
  Map<String, String>? extraTags;
  double? importance;
  double? lat;
  double? lon;
  String? name;
  Map<String, String>? nameDetails;
  int? osmId;
  String? osmType;
  String? placeClass;
  int? placeId;
  int? placeRank;
  String? type;

  Place({
    this.address,
    this.addressType,
    this.boundingBox,
    this.displayName,
    this.extraTags,
    this.importance,
    this.lat,
    this.lon,
    this.name,
    this.nameDetails,
    this.osmId,
    this.osmType,
    this.placeClass,
    this.placeId,
    this.placeRank,
    this.type,
  });

  factory Place.fromJson(
    Map<String, dynamic> json,
  ) {
    return Place(
      address:
          json['address'] != null ? Address.fromJson(json['address']) : null,
      addressType: json['addresstype'],
      boundingBox: (json['boundingbox'] as List?)?.map(
        (coordinate) {
          return double.parse(coordinate);
        },
      ).toList(),
      displayName: json['display_name'],
      extraTags: json['extratags'],
      importance: json['importance'],
      lat: json['lat'] != null ? double.parse(json['lat']) : null,
      lon: json['lon'] != null ? double.parse(json['lon']) : null,
      name: json['name'],
      nameDetails: json['namedetails'],
      osmId: json['osm_id'],
      osmType: json['osm_type'],
      placeClass: json['class'],
      placeId: json['place_id'],
      placeRank: json['place_rank'],
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address?.toJson(),
      'addresstype': addressType,
      'boundingbox': boundingBox?.map(
        (coordinate) {
          return coordinate.toString();
        },
      ).toList(),
      'display_name': displayName,
      'extratags': extraTags,
      'importance': importance,
      'lat': lat?.toString(),
      'lon': lon?.toString(),
      'name': name,
      'namedetails': nameDetails,
      'osm_id': osmId,
      'osm_type': osmType,
      'class': placeClass,
      'place_id': placeId,
      'place_rank': placeRank,
      'type': type,
    };
  }
}
