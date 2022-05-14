package pl.blach.sunmachine

import android.bluetooth.BluetoothAdapter
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val CHANNEL = "pl.blach.sunmachine/native"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if(call.method == "btenable") {
                val mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
                result.success(mBluetoothAdapter.enable())
            } else if(call.method == "btdisable") {
                val mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
                result.success(mBluetoothAdapter.disable())
            } else {
                result.notImplemented()
            }
        }
    }
}
