package dev.fluttercommunity.plus.packageinfo;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Build-time compatibility shim for projects where Flutter generates a
 * registrant entry for package_info_plus but the Android plugin module is not
 * available on the app compile classpath.
 */
public final class PackageInfoPlugin implements FlutterPlugin {
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    // Intentionally no-op. This app does not use package_info_plus directly.
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    // Intentionally no-op.
  }
}
