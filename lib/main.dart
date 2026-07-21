import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nominatim_api_client/nominatim_api_client.dart';
import 'package:octopus_energy_api_client/v1.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart';

import 'common/shell_route.dart';
import 'forecast/forecast_service.dart';
import 'forecast/neso_api_client.dart';
import 'forecast/price_forecast_model_service.dart';
import 'welcome/welcome_route.dart';

void main() {
  initializeTimeZones();

  runApp(
    MultiProvider(
      providers: [
        Provider(
          create: (context) {
            return NesoApiClient();
          },
        ),
        Provider(
          create: (context) {
            return NominatimApiClient(
              client: clientViaUserAgent('AgileOctopusPriceTracker/0.6.0'),
            );
          },
        ),
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
        // Begin loading the price-forecast model at start-up (lazy: false) so
        // its inference session is ready by the time the forecast needs it. The
        // value is null until the load completes, so consumers read
        // PriceForecastModelService? and handle the loading state.
        FutureProvider(
          create: (context) {
            return PriceForecastModelService.load();
          },
          initialData: null,
          lazy: false,
        ),
        // Compose the forecast service from the NESO client and the price
        // forecast model. The latter is null until its start-up load completes,
        // so the service is itself null until then; consumers read
        // ForecastService? and hold off forecasting until it is ready.
        ProxyProvider2<NesoApiClient, PriceForecastModelService?,
            ForecastService?>(
          update: (context, nesoApiClient, priceForecastModelService, _) {
            if (priceForecastModelService == null) {
              return null;
            }

            return ForecastService(
              nesoApiClient: nesoApiClient,
              priceForecastModelService: priceForecastModelService,
            );
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
        dividerTheme: DividerThemeData(
          color: Color(0xff5840ff),
        ),
      ),
    );
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

class PaymentMethods {
  static const directDebitMonthly = 'direct_debit_monthly';
  static const directDebitQuarterly = 'direct_debit_quarterly';
  static const paymentOnReceiptOfBill = 'porob';
  static const prepayment = 'prepayment';
  static const varying = 'varying';

  const PaymentMethods._();
}
