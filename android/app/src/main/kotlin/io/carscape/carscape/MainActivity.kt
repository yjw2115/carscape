package io.carscape.carscape

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var tutorialVehicle: TutorialVehicleBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tutorialVehicle = TutorialVehicleBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        tutorialVehicle?.dispose()
        tutorialVehicle = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
