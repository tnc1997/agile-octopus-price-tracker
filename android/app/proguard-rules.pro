# Keep the ONNX Runtime classes flutter_onnxruntime binds to over JNI, so R8
# minimization does not strip them and leave `mid == null` at runtime.
# See https://pub.dev/packages/flutter_onnxruntime "Required development setup".
-keep class ai.onnxruntime.** { *; }
