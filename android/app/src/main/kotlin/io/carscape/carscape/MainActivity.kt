package io.carscape.carscape

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var tutorialVehicle: TutorialVehicleBridge? = null
    private var vehicle: VehicleBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        tutorialVehicle = TutorialVehicleBridge(applicationContext, messenger)
        vehicle = VehicleBridge(applicationContext, messenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        tutorialVehicle?.dispose()
        tutorialVehicle = null
        vehicle?.dispose()
        vehicle = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
