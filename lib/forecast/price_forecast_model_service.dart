import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:timezone/timezone.dart' as tz;

/// Loads the bundled price-forecast model and holds the ready-to-run inference
/// session.
///
/// The model is trained offline by `script/train_price_forecast_model.py`,
/// exported to ONNX by `script/export_price_forecast_model.py`, and bundled as
/// the `assets/price_forecast_model.onnx` asset. It is a gradient-boosted tree
/// ensemble (a single ai.onnx.ml `TreeEnsembleRegressor`) that maps a slot's
/// conditions to a forecast Agile Octopus unit rate in pence per kWh inclusive
/// of VAT. It replaced the earlier seasonal-average lookup table, which
/// forecast the same quantity by bucketing historical prices and returning a
/// bucket average.
///
/// This service owns the lifecycle of the [OrtSession]: [load] reads the asset,
/// initialises the ONNX Runtime environment and builds the session; [release]
/// tears both down. It is loaded once at start-up (see `main.dart`) and the
/// resulting instance is shared for the application's lifetime rather than a
/// session being rebuilt per forecast — building one parses and prepares the
/// whole tree ensemble, which is paid once here.
class PriceForecastModelService {
  /// Creates a service around an already-built inference [session].
  ///
  /// Private so that instances can only be obtained through [load], which is
  /// responsible for reading the asset, initialising the ONNX Runtime
  /// environment and constructing the session. This synchronous constructor
  /// exists only to hold the finished session once that work is done.
  PriceForecastModelService._({
    required OrtSession session,
  }) : _session = session;

  /// The asset key of the bundled ONNX model.
  ///
  /// Matches the path declared under `flutter: assets:` in `pubspec.yaml`, which
  /// `script/export_price_forecast_model.py` writes to directly so the bundled
  /// asset stays in step with the model whenever it is regenerated. Passed to
  /// [AssetBundle.load] by [load].
  static const _assetKey = 'assets/price_forecast_model.onnx';

  /// The single-letter Grid Supply Point region codes, in the order that fixes
  /// each one's ordinal encoding (`A` -> 0, `B` -> 1, ... `P` -> 13).
  ///
  /// The model was trained with the region ordinal-encoded against this exact
  /// list (see `GSP_CODES` in `script/train_price_forecast_model.py`), so
  /// [getFeatures] must map a letter to the same index — a divergence would feed
  /// the model the wrong region with no error. Kept here as the Dart half of
  /// that contract, since the ONNX runtime does not surface the model's embedded
  /// metadata to read it back from the asset.
  static const _gspCodes = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'J',
    'K',
    'L',
    'M',
    'N',
    'P',
  ];

  /// The inclusive start and exclusive end of the local evening-peak window, as
  /// an hour of the day.
  ///
  /// A slot whose local start hour falls in `[16, 19)` — 16:00, 17:00 or 18:00 —
  /// is flagged as peak, exactly as `PEAK_HOUR_START`/`PEAK_HOUR_END` define it
  /// in `script/train_price_forecast_model.py`, so the `is_peak` feature
  /// [getFeatures] derives matches how the model was trained.
  static const _peakHourStart = 16;

  /// The exclusive end of the local evening-peak window; see [_peakHourStart].
  static const _peakHourEnd = 19;

  /// The Europe/London time zone — the zone the model's timestamp features were
  /// derived in during training.
  ///
  /// [getFeatures] converts each incoming instant to this zone before deriving its
  /// time-of-day, weekend, peak and month features, so the runtime features line
  /// up with the build regardless of the incoming instant's own zone or the
  /// device's (UK clocks shift for British Summer Time, so neither can be
  /// assumed).
  static final _location = tz.getLocation('Europe/London');

  /// The ONNX Runtime session wrapping the bundled model.
  ///
  /// Held for the service's lifetime so inference reuses the one prepared
  /// ensemble rather than rebuilding it per call. Kept private: the session's
  /// lifecycle (creation in [load], teardown in [release]) is owned here, and
  /// its input/output tensor names are surfaced through [inputNames] and
  /// [outputNames].
  final OrtSession _session;

  /// The names of the model's input tensors, in the order the graph declares
  /// them.
  ///
  /// The exported graph takes a single positional feature tensor (named
  /// `input`), so this is a one-element list; it is surfaced so a caller can
  /// key the input map it passes to inference off the model itself rather than a
  /// hard-coded string.
  List<String> get inputNames {
    return _session.inputNames;
  }

  /// The names of the model's output tensors, in the order the graph declares
  /// them.
  ///
  /// The regressor emits a single prediction tensor, so this is a one-element
  /// list; it is surfaced so a caller can read that tensor back by name rather
  /// than by a hard-coded string.
  List<String> get outputNames {
    return _session.outputNames;
  }

  /// Loads the bundled model and returns a ready-to-run service.
  ///
  /// Initialises the ONNX Runtime environment, reads the [_assetKey] asset as
  /// raw bytes and builds an [OrtSession] from them. This work is paid once
  /// here; call this during start-up and reuse the returned instance rather than
  /// rebuilding a session per forecast, and call [release] when it is no longer
  /// needed.
  ///
  /// Pass [bundle] to load from a specific [AssetBundle] (e.g. a test bundle);
  /// it defaults to [rootBundle], the application's bundled assets.
  ///
  /// Completes with an error if the asset is missing or is not a valid ONNX
  /// model the runtime can load.
  static Future<PriceForecastModelService> load({
    AssetBundle? bundle,
  }) async {
    // Default to the root bundle if none is provided.
    bundle ??= rootBundle;

    // Bring up the ONNX Runtime environment before creating any session. This
    // is idempotent, so loading more than once (e.g. across a hot restart) is
    // harmless.
    OrtEnv.instance.init();

    // Read the bundled model as raw bytes. Slice by the ByteData's own offset
    // and length so the view covers exactly the asset's bytes regardless of how
    // it is backed.
    final data = await bundle.load(_assetKey);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    // Build the inference session from the model bytes. Constructing it parses
    // and prepares the whole tree ensemble, which is why it is done once here.
    final session = OrtSession.fromBuffer(bytes, OrtSessionOptions());

    return PriceForecastModelService._(session: session);
  }

  /// Forecasts the unit rate (in pence per kWh, inclusive of VAT) for a
  /// half-hour slot under the given conditions.
  ///
  /// [gsp] is the Grid Supply Point region code. Both the bare letter as it
  /// appears in the model's encoding (e.g. `"C"` for London) and the
  /// application's stored group-identifier form with a leading underscore (e.g.
  /// `"_C"`) are accepted.
  ///
  /// [dateTime] is the instant of the slot; its own time zone does not matter,
  /// as it is converted to Europe/London — the zone the model's timestamp
  /// features were derived in — before those features are built.
  ///
  /// [embeddedWindMw], [embeddedSolarMw] and [windMw] are the slot's NESO
  /// forecast columns in megawatts, passed straight through as the model's three
  /// generation features.
  ///
  /// The conditions are assembled into the model's feature vector by [getFeatures]
  /// and run through the inference session as a single-row `[1, featureCount]`
  /// tensor; the one prediction is read back off the `[1, 1]` output.
  ///
  /// Throws an [ArgumentError] if [gsp] is not a recognised region.
  double predict({
    required String gsp,
    required DateTime dateTime,
    required double embeddedWindMw,
    required double embeddedSolarMw,
    required double windMw,
  }) {
    // Assemble the feature vector in the model's declared order, then present it
    // as a [1, featureCount] float tensor — one slot, batch size one. The model
    // takes float32 input, so back the tensor with a Float32List (a plain
    // List<double> would be sent as float64 and rejected).
    final features = getFeatures(
      gsp: gsp,
      dateTime: dateTime,
      embeddedWindMw: embeddedWindMw,
      embeddedSolarMw: embeddedSolarMw,
      windMw: windMw,
    );

    final input = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(features),
      [1, features.length],
    );

    final runOptions = OrtRunOptions();

    List<OrtValue?>? outputs;
    try {
      // Key the input map off the model's own tensor name rather than a
      // hard-coded string, and read the single output tensor back by name too.
      outputs = _session.run(
        runOptions,
        {inputNames.first: input},
        outputNames,
      );

      // The regressor emits one [1, 1] tensor; its value is that shape as a
      // nested list, so the single prediction is the first element of the first
      // row.
      final output = outputs.first!.value as List;
      return (output.first as List).first as double;
    } finally {
      // Release the native tensors and run options however the run turns out, so
      // a forecast of hundreds of slots does not leak per call.
      input.release();
      runOptions.release();
      outputs?.forEach((output) => output?.release());
    }
  }

  /// The model's feature vector for a slot, in the exact column order the model
  /// was trained on.
  ///
  /// The order is the `FEATURES` list in `script/train_price_forecast_model.py`:
  /// `time_of_day`, `is_weekend`, `is_peak`, `month`, `gsp`, then the three NESO
  /// generation columns. Each timestamp-derived feature is computed from the
  /// slot's Europe/London wall-clock time so it matches how the model was
  /// trained; the region is ordinal-encoded against [_gspCodes]. Returned as
  /// doubles because the model takes a single float tensor.
  ///
  /// Exposed for tests so this contract can be pinned without loading the native
  /// runtime (which [predict] needs); [predict] is the production entry point.
  @visibleForTesting
  static List<double> getFeatures({
    required String gsp,
    required DateTime dateTime,
    required double embeddedWindMw,
    required double embeddedSolarMw,
    required double windMw,
  }) {
    // The model encodes the bare region letter (e.g. "C"); the app stores the
    // group identifier with a leading underscore (e.g. "_C"), so accept and
    // strip that form too. An unrecognised region is a caller error.
    final code = _gspCodes.indexOf(
      gsp.startsWith('_') ? gsp.substring(1) : gsp,
    );
    if (code < 0) {
      throw ArgumentError.value(gsp, 'gsp', 'Unknown region');
    }

    // Convert the instant to Europe/London wall-clock time so the derived
    // features line up with how the model was trained, regardless of the
    // incoming instant's own zone or the device's.
    final local = tz.TZDateTime.from(dateTime, _location);

    return [
      // Settlement period 1 = 00:00-00:30 local, so the half-hour index within
      // the day is hours*2 plus one once past the half hour — an ordinal 0-47,
      // exactly as the training script derives it.
      local.hour * 2 + (local.minute < 30 ? 0 : 1),
      // Saturday and Sunday are the weekend.
      local.weekday >= DateTime.saturday ? 1 : 0,
      // The local evening peak is the [start, end) hour window.
      local.hour >= _peakHourStart && local.hour < _peakHourEnd ? 1 : 0,
      local.month.toDouble(),
      code.toDouble(),
      embeddedWindMw,
      embeddedSolarMw,
      windMw,
    ];
  }

  /// Releases the inference session and the ONNX Runtime environment.
  ///
  /// Frees the native resources [load] acquired. Call this when the service is
  /// no longer needed; the instance must not be used afterwards.
  void release() {
    _session.release();
    OrtEnv.instance.release();
  }
}
