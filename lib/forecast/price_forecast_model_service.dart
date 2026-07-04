import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// Loads the bundled price-forecast model and holds the ready-to-run inference
/// session.
///
/// The model is trained offline by `script/train_price_forecast_model.py`,
/// exported to ONNX by `script/export_price_forecast_model.py`, and bundled as
/// the `assets/price_forecast_model.onnx` asset. It is a gradient-boosted tree
/// ensemble (a single ai.onnx.ml `TreeEnsembleRegressor`) that maps a slot's
/// conditions to a forecast Agile Octopus unit rate in pence per kWh inclusive
/// of VAT — the model-based counterpart to `SeasonalAverageLookupService`, which
/// forecasts the same quantity from a bucketed lookup table.
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

  /// Releases the inference session and the ONNX Runtime environment.
  ///
  /// Frees the native resources [load] acquired. Call this when the service is
  /// no longer needed; the instance must not be used afterwards.
  void release() {
    _session.release();
    OrtEnv.instance.release();
  }
}
