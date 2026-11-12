package io.carscape.carscape

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import ai.pleos.playground.vehicle.Vehicle
import ai.pleos.playground.vehicle.api.model.area.SeatArea
import ai.pleos.playground.vehicle.api.model.area.WindowArea
import ai.pleos.playground.vehicle.api.model.capability.AccessType
import ai.pleos.playground.vehicle.api.model.capability.AreaBounds
import ai.pleos.playground.vehicle.api.model.capability.CapabilityConfig
import ai.pleos.playground.vehicle.constant.area.SeatValue
import ai.pleos.playground.vehicle.constant.area.WindowValue
import ai.pleos.playground.vehicle.constant.area.DoorValue
import ai.pleos.playground.vehicle.constant.control.LightState
import ai.pleos.playground.vehicle.constant.control.LightSwitch
import ai.pleos.playground.vehicle.constant.control.VehicleGear
import ai.pleos.playground.vehicle.constant.control.WiperState
import ai.pleos.playground.vehicle.constant.unit.TemperatureUnit
import ai.pleos.playground.vehicle.listener.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Observes vehicle inputs and clears supported puzzle controls at story startup. */
@Suppress("DEPRECATION") // SDK 2.3.2 Gear read is deprecated, not private; fail closed if unavailable.
class TutorialVehicleBridge(context: Context, messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val channel = EventChannel(messenger, "io.carscape/tutorial_vehicle/events")
    private val methods = MethodChannel(messenger, "io.carscape/tutorial_vehicle")
    private var sink: EventChannel.EventSink? = null
    private var vehicle: Vehicle? = null
    private var generation = 0
    private val cleanup = mutableListOf<() -> Unit>()
    private val readers = linkedMapOf<String, () -> Unit>()
    private val pending = mutableMapOf<String, Long>()
    private var requestSequence = 0L
    private val values = mutableMapOf<String, Any?>()
    private val capabilities = linkedMapOf<String, Any>("gloveboxOpen" to false)
    private val problems = linkedMapOf<String, String>()
    private var checksPending = 0
    private var pollCount = 0
    private var lightPuzzleActive = false
    private var resetResult: MethodChannel.Result? = null
    private var resetToken = 0
    private val lightOffActions = linkedMapOf<String, (() -> Unit, (Exception) -> Unit) -> Unit>()
    private var climateOff: (() -> Unit)? = null
    private val poll = object : Runnable {
        override fun run() {
            if (vehicle == null || sink == null) return
            // Reconcile even if a vehicle service misses a subscription callback.
            // Every read is bounded to one in-flight request per property/area.
            readers.values.toList().forEach { it() }
            if (++pollCount % 8 == 0) Log.d(TAG, "monitoring ${readers.size} properties")
            main.postDelayed(this, 500)
        }
    }

    init {
        channel.setStreamHandler(this)
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "refresh" -> { readers.values.toList().forEach { it() }; result.success(null) }
                "diagnostics" -> result.success(mapOf("capabilities" to capabilities, "problems" to problems, "values" to values))
                "setLightPuzzleActive" -> {
                    lightPuzzleActive = call.arguments == true
                    if (!lightPuzzleActive) cancelLightReset()
                    result.success(null)
                }
                "resetReadingLights" -> resetReadingLights(result)
                "prepareStoryClimate" -> {
                    if (lightPuzzleActive && values["parking:global"] == true) {
                        try { climateOff?.invoke() } catch (error: Exception) {
                            Log.w(TAG, "Startup climate reset unavailable", error)
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        sink = events
        val session = ++generation
        send(mapOf("type" to "connection", "value" to false))
        try {
            val sdk = Vehicle(appContext)
            vehicle = sdk
            sdk.initialize()
            Log.i(TAG, "Vehicle SDK initialized")
            discover(sdk, session)
            main.postDelayed(poll, 500)
        } catch (error: Exception) {
            issue("connection", error.message ?: error.javaClass.simpleName)
        }
    }

    override fun onCancel(arguments: Any?) = stop()

    private fun readable(config: CapabilityConfig) = config.accessType == AccessType.READ || config.accessType == AccessType.READ_WRITE
    private fun active(session: Int) = session == generation && vehicle != null && sink != null
    private fun seatId(area: SeatArea) = area.values.joinToString("+") { it.name }
    private fun seatArea(value: SeatValue) = SeatArea(value)
    private fun windowArea(value: WindowValue) = WindowArea(value)
    private val puzzleSeats = listOf(SeatValue.ROW_2_LEFT, SeatValue.ROW_2_RIGHT, SeatValue.ROW_1_LEFT, SeatValue.ROW_1_RIGHT)

    private fun send(event: Map<String, Any?>) {
        val target = sink
        main.post { if (sink === target) target?.success(event) }
    }

    private fun issue(feature: String, message: String) {
        if (Looper.myLooper() != Looper.getMainLooper()) { main.post { issue(feature, message) }; return }
        if (problems[feature] == message) return
        problems[feature] = message
        Log.w(TAG, "$feature: $message")
        send(mapOf("type" to "issue", "feature" to feature, "message" to message))
    }

    private fun clearIssue(feature: String) {
        if (problems.remove(feature) != null) {
            send(mapOf("type" to "issue", "feature" to feature, "message" to ""))
        }
    }

    private fun emit(kind: String, value: Any?, area: String? = null) {
        if (Looper.myLooper() != Looper.getMainLooper()) { main.post { emit(kind, value, area) }; return }
        val key = "$kind:${area ?: "global"}"
        val initial = !values.containsKey(key)
        if (!initial && values[key] == value) return
        values[key] = value
        Log.i(TAG, "$key=$value initial=$initial")
        send(mapOf("type" to "value", "kind" to kind, "value" to value, "area" to area, "initial" to initial))
    }

    private fun installReader(
        key: String,
        session: Int,
        read: ((Any?) -> Unit, (Exception) -> Unit) -> Unit,
        output: (Any?) -> Unit,
        enabled: () -> Boolean = { true },
        onUnavailable: () -> Unit = {},
    ) {
        readers[key] = reader@{
            if (!active(session) || !enabled() || pending.containsKey(key)) return@reader
            val request = ++requestSequence
            pending[key] = request
            val observedKey = when {
                key.startsWith("light:") -> "cabinLight:${key.removePrefix("light:")}"
                key == "wiper" || key == "parking" || key == "steering" -> "$key:global"
                else -> key
            }
            val hadValue = values.containsKey(observedKey)
            val beforeRead = values[observedKey]
            // A newer subscription observation wins over an older GET reply.
            fun changedWhileReading() = hadValue != values.containsKey(observedKey) || beforeRead != values[observedKey]
            fun unavailable() {
                onUnavailable()
                when {
                    key.startsWith("light:") -> emit("cabinLight", null, key.removePrefix("light:"))
                    key.startsWith("window:") -> emit("window", null, key.removePrefix("window:"))
                    key.startsWith("door:") -> emit("door", null, key.removePrefix("door:"))
                    key.startsWith("heater") -> emit("passengerHeater", null)
                    key == "wiper" -> emit("wiper", null)
                    key == "steering" -> emit("steering", null)
                    key == "parking" -> emit("parking", false)
                }
            }
            val timeout = Runnable {
                if (active(session) && pending[key] == request) {
                    pending.remove(key)
                    if (!changedWhileReading()) { issue(key, "차량 응답 시간 초과"); unavailable() }
                }
            }
            main.postDelayed(timeout, 4000)
            try {
                read({ value -> main.post {
                    if (!active(session) || pending[key] != request) return@post
                    pending.remove(key)
                    main.removeCallbacks(timeout)
                    if (changedWhileReading()) return@post
                    if (value == null) {
                        issue(key, "현재 상태를 읽을 수 없습니다")
                        unavailable()
                    } else {
                        clearIssue(key)
                        output(value)
                    }
                } }, { error -> main.post {
                    if (!active(session) || pending[key] != request) return@post
                    pending.remove(key)
                    main.removeCallbacks(timeout)
                    if (changedWhileReading()) return@post
                    issue(key, error.message ?: error.javaClass.simpleName)
                    unavailable()
                } })
            } catch (error: Exception) {
                pending.remove(key)
                main.removeCallbacks(timeout)
                issue(key, error.message ?: error.javaClass.simpleName)
                unavailable()
            }
        }
        readers[key]?.invoke()
    }

    private fun checkFinished(session: Int) {
        main.post {
            if (!active(session)) return@post
            if (--checksPending == 0) {
                send(mapOf("type" to "capabilities", "data" to capabilities.toMap()))
                send(mapOf("type" to "connection", "value" to true))
                Log.i(TAG, "Capabilities $capabilities")
            }
        }
    }

    private fun discover(sdk: Vehicle, session: Int) {
        checksPending = 7
        val light = sdk.getLight()
        light.checkReadingLightStateCapabilities(onComplete = { config, areas -> main.post {
            if (!active(session)) return@post
            val supported = puzzleSeats.filter { areas.containsKey(seatArea(it)) && readable(config) }
            capabilities["lights"] = supported.map { it.name }
            if (supported.size != 4) issue("lights", "네 자리의 독서등 상태를 모두 읽을 수 없습니다")
            supported.forEach { code ->
                val area = seatArea(code)
                val output: (Any?) -> Unit = { emit("cabinLight", it == LightState.ON, code.name) }
                installReader("light:${code.name}", session, { ok, fail -> light.getCurrentReadingLightState(area, ok, fail) }, output)
                val listener = object : LightStateListener {
                    override fun onLightStateUpdated(state: LightState?) { if (active(session) && state != null) main.post { output(state) } }
                    override fun onFailed(e: Exception) { issue("light:${code.name}", e.message ?: "조명 감지 실패") }
                }
                try { light.registerReadingLightState(area, listener); cleanup.add { light.unregisterReadingLightState(area, listener) } } catch (e: Exception) { issue("lightSubscription:${code.name}", e.message ?: "구독 실패") }
            }
            light.checkReadingLightSwitchCapabilities(onComplete = { switchConfig, switches -> main.post {
                if (!active(session)) return@post
                val writable = switchConfig.accessType == AccessType.WRITE || switchConfig.accessType == AccessType.READ_WRITE
                supported.forEach { code ->
                    val area = seatArea(code)
                    if (writable && switches[area]?.contains(LightSwitch.OFF) == true) {
                        lightOffActions[code.name] = { ok, fail ->
                            light.setReadingLightSwitch(area, LightSwitch.OFF, { _ ->
                                // Read back the physical state, not merely the requested switch.
                                light.getCurrentReadingLightState(area, { state -> main.post {
                                    if (active(session)) {
                                        emit("cabinLight", state?.let { it == LightState.ON }, code.name)
                                        if (state == LightState.OFF) ok() else fail(IllegalStateException("조명이 아직 켜져 있습니다"))
                                    }
                                } }, fail)
                            }, fail)
                        }
                    }
                }
                capabilities["lightControl"] = lightOffActions.size == 4
                if (lightOffActions.size != 4) issue("lightControl", "네 독서등을 끄는 기능을 지원하지 않습니다")
                checkFinished(session)
            } }, onFailed = { issue("lightControl", it.message ?: "독서등 제어 확인 실패"); checkFinished(session) })
        } }, onFailed = { issue("lights", it.message ?: "조명 지원 확인 실패"); checkFinished(session) })

        val hvac = sdk.getHVAC()
        // Require verified airflow plus a warm set temperature; AC-off alone is not heating.
        val hvacChecks = mutableMapOf<String, Set<SeatArea>>()
        var hvacPending = 3
        var powerWritable = false
        fun hvacDone() {
            if (--hvacPending != 0) return
            fun zone(feature: String): SeatArea? {
                val areas = hvacChecks[feature].orEmpty()
                return areas.firstOrNull { SeatValue.ROW_1_RIGHT in it.values } ?: areas.firstOrNull { SeatValue.ROW_1_LEFT in it.values }
            }
            val powerArea = zone("power")
            val fanArea = zone("fan")
            val temperatureArea = zone("temperature")
            capabilities["startupClimateOff"] = powerWritable && powerArea != null
            if (powerWritable && powerArea != null) {
                climateOff = {
                    hvac.setHvacPower(powerArea, false, { _, _ ->
                        main.post { if (active(session)) readers["heaterPower"]?.invoke() }
                    }, { error ->
                        Log.w(TAG, "Startup climate reset unavailable", error)
                    })
                }
            }
            capabilities["heater"] = powerArea != null && fanArea != null && temperatureArea != null
            capabilities["heaterArea"] = temperatureArea?.let(::seatId) ?: ""
            if (powerArea == null || fanArea == null || temperatureArea == null) issue("heater", "공조 전원·풍량·온도 지원을 확인할 수 없습니다")
            if (powerArea != null && fanArea != null && temperatureArea != null) {
                var power: Boolean? = null
                var fan: Int? = null
                var temperature: Float? = null
                fun update() {
                    val currentFan = fan
                    val currentTemperature = temperature
                    if (power == false) {
                        emit("passengerHeater", false)
                    } else if (power == true && currentFan != null && currentTemperature != null) {
                        emit("passengerHeater", currentFan > 0 && currentTemperature >= 26f)
                    }
                }
                fun updatePower(value: Boolean?) {
                    if (power != value) {
                        power = value
                        fan = null
                        temperature = null
                        // Replies from the previous power state can arrive after the transition.
                        pending.remove("heaterFan")
                        pending.remove("heaterTemperature")
                    }
                    if (value == false) {
                        clearIssue("heaterFan")
                        clearIssue("heaterTemperature")
                    }
                    update()
                }
                installReader("heaterPower", session,
                    { ok, fail -> hvac.getHvacPowerState(powerArea, ok, fail) },
                    { updatePower(it as? Boolean) },
                    onUnavailable = { updatePower(null) },
                )
                installReader("heaterFan", session,
                    { ok, fail -> hvac.getHvacFanSpeed(fanArea, ok, fail) },
                    { fan = it as? Int; update() },
                    enabled = { power == true },
                    onUnavailable = { fan = null },
                )
                installReader("heaterTemperature", session,
                    { ok, fail -> hvac.getHvacTemperature(temperatureArea, TemperatureUnit.CELSIUS, ok, fail) },
                    { temperature = it as? Float; update() },
                    enabled = { power == true },
                    onUnavailable = { temperature = null },
                )
            }
            checkFinished(session)
        }
        hvac.checkHvacPowerCapabilities(onComplete = { config, areas -> main.post {
            if (active(session)) {
                powerWritable = config.accessType == AccessType.READ_WRITE
                hvacChecks["power"] = if (readable(config)) areas.toSet() else emptySet()
                hvacDone()
            }
        } }, onFailed = { main.post { issue("heaterPower", it.message ?: "지원 확인 실패"); hvacDone() } })
        hvac.checkHvacFanSpeedCapabilities(onComplete = { config, areas -> main.post { if (active(session)) { hvacChecks["fan"] = if (readable(config)) areas.keys else emptySet(); hvacDone() } } }, onFailed = { main.post { issue("heaterFan", it.message ?: "지원 확인 실패"); hvacDone() } })
        hvac.checkHvacTemperatureCapabilities(onComplete = { config: CapabilityConfig, areas: Map<SeatArea, AreaBounds<Float>> -> main.post { if (active(session)) { hvacChecks["temperature"] = if (readable(config)) areas.keys else emptySet(); hvacDone() } } }, onFailed = { main.post { issue("heaterTemperature", it.message ?: "지원 확인 실패"); hvacDone() } })

        val window = sdk.getWindow()
        window.checkWindowPositionCapabilities(onComplete = { config, areas -> main.post {
            if (!active(session)) return@post
            val supported = puzzleSeats.map { WindowValue.valueOf(it.name) }.filter { code ->
                val bounds = areas[windowArea(code)]
                readable(config) && bounds != null && bounds.maxValue > bounds.minValue && bounds.minValue >= 0
            }
            capabilities["windows"] = supported.map { it.name }
            if (supported.size != 4) issue("windows", "네 자리의 창문 위치를 모두 읽을 수 없습니다")
            supported.forEach { code ->
                val area = windowArea(code)
                val bounds = areas.getValue(area)
                val output: (Any?) -> Unit = { raw ->
                    val value = raw as? Int
                    if (value != null && value in bounds.minValue..bounds.maxValue) {
                        val percent = (value - bounds.minValue) * 100.0 / (bounds.maxValue - bounds.minValue)
                        emit("window", percent, code.name)
                    }
                }
                installReader("window:${code.name}", session, { ok, fail -> window.getCurrentWindowPosition(area, ok, fail) }, output)
                val listener = object : WindowPositionListener {
                    override fun onWindowPositionUpdated(pos: Int?) { if (active(session) && pos != null) main.post { output(pos) } }
                    override fun onFailed(e: Exception) { issue("window:${code.name}", e.message ?: "창문 감지 실패") }
                }
                try { window.registerWindowPosition(area, listener); cleanup.add { window.unregisterWindowPosition(area, listener) } } catch (e: Exception) { issue("windowSubscription:${code.name}", e.message ?: "구독 실패") }
            }
            checkFinished(session)
        } }, onFailed = { issue("windows", it.message ?: "창문 지원 확인 실패"); checkFinished(session) })

        val wiper = sdk.getWiper()
        wiper.checkWiperStateCapabilities(onComplete = { config, areas -> main.post {
            if (!active(session)) return@post
            val front = windowArea(WindowValue.FRONT_WINDSHIELD)
            val supported = readable(config) && areas.containsKey(front)
            capabilities["wiper"] = supported
            if (!supported) issue("wiper", "앞유리 와이퍼 상태를 읽을 수 없습니다")
            if (supported) {
                val output: (Any?) -> Unit = { emit("wiper", it == WiperState.ON) }
                installReader("wiper", session, { ok, fail -> wiper.getCurrentWiperState(front, ok, fail) }, output)
                val listener = object : WiperStateListener {
                    override fun onWiperStateUpdated(state: WiperState?) { if (active(session) && state != null) main.post { output(state) } }
                    override fun onFailed(e: Exception) { issue("wiper", e.message ?: "와이퍼 감지 실패") }
                }
                try { wiper.registerWiperState(front, listener); cleanup.add { wiper.unregisterWiperState(front, listener) } } catch (e: Exception) { issue("wiperSubscription", e.message ?: "구독 실패") }
            }
            checkFinished(session)
        } }, onFailed = { issue("wiper", it.message ?: "와이퍼 지원 확인 실패"); checkFinished(session) })

        val door = sdk.getDoor()
        door.checkDoorPositionCapabilities(onComplete = { config, areas -> main.post {
            if (!active(session)) return@post
            val required = puzzleSeats.map { it.name }.toSet() + DoorValue.REAR.name
            val supported = areas.filter { (area, bounds) ->
                readable(config) && area.values.size == 1 &&
                    area.values.single() != DoorValue.HOOD && bounds.maxValue > bounds.minValue
            }
            val supportedIds = supported.keys.map { it.values.single().name }
            capabilities["doors"] = supportedIds
            if (!supportedIds.containsAll(required)) issue("doors", "네 문과 뒷 트렁크의 열림 상태를 모두 읽을 수 없습니다")
            supported.forEach { (area, bounds) ->
                val id = area.values.single().name
                val output: (Any?) -> Unit = { raw ->
                    val value = raw as? Int
                    emit("door", value?.takeIf { it in bounds.minValue..bounds.maxValue }?.let { it > bounds.minValue }, id)
                }
                installReader("door:$id", session, { ok, fail -> door.getCurrentDoorPosition(area, ok, fail) }, output)
                val listener = object : DoorPositionListener {
                    override fun onPositionUpdated(pos: Int?) { if (active(session)) main.post { output(pos) } }
                    override fun onFailed(e: Exception) { issue("door:$id", e.message ?: "문 감지 실패") }
                }
                try { door.registerDoorPosition(area, listener); cleanup.add { door.unregisterDoorPosition(area, listener) } } catch (e: Exception) { issue("door:$id", e.message ?: "문 구독 실패") }
            }
            checkFinished(session)
        } }, onFailed = { issue("doors", it.message ?: "문 지원 확인 실패"); checkFinished(session) })

        val steering = sdk.getSteeringWheel()
        steering.checkSteeringWheelAngleCapabilities(onComplete = { config, bounds -> main.post {
            if (!active(session)) return@post
            val supported = readable(config) && bounds.maxValue >= 0 && bounds.minValue <= -30
            capabilities["steering"] = supported
            if (!supported) issue("steering", "휠 각도를 읽을 수 없습니다")
            if (supported) {
                // Pleos SDK 2.3.2 / AVD 2.1 reports clockwise as negative.
                // Normalize the game contract to clockwise/right positive.
                val output: (Any?) -> Unit = { emit("steering", (it as? Float)?.let { angle -> -angle.toDouble() }) }
                installReader("steering", session, { ok, fail -> steering.getCurrentSteeringWheelAngle(ok, fail) }, output)
                val listener = object : SteeringWheelAngleListener {
                    override fun onSteeringWheelAngleUpdated(angle: Float?) { if (active(session)) main.post { output(angle) } }
                    override fun onFailed(e: Exception) { issue("steering", e.message ?: "휠 감지 실패") }
                }
                try { steering.registerSteeringWheelAngle(listener); cleanup.add { steering.unregisterSteeringWheelAngle(listener) } } catch (e: Exception) { issue("steering", e.message ?: "휠 구독 실패") }
            }
            checkFinished(session)
        } }, onFailed = { issue("steering", it.message ?: "휠 지원 확인 실패"); checkFinished(session) })
        // The public SDK exposes glovebox LOCK only, not open/closed position.
        // Never mistake unlocked for opened. This version deliberately uses heater-only fallback.
        checkFinished(session)
        installReader("parking", session, { ok, fail -> sdk.getGear().getCurrentGearSelectionState(ok, fail) }, { emit("parking", it == VehicleGear.GEAR_PARK) })
        val gearListener = object : GearSelectionListener {
            override fun onSelected(gear: VehicleGear?) { if (active(session)) main.post { emit("parking", gear == VehicleGear.GEAR_PARK) } }
            override fun onFailed(e: Exception) { emit("parking", false); issue("parking", e.message ?: "P단 확인 실패") }
        }
        try { sdk.getGear().registerGearSelection(gearListener); cleanup.add { sdk.getGear().unregisterGearSelection(gearListener) } } catch (e: Exception) { issue("parking", e.message ?: "기어 구독 실패") }
    }

    private fun cancelLightReset() {
        ++resetToken
        resetResult?.error("cancelled", "조명 단계를 벗어났습니다", null)
        resetResult = null
    }

    private fun resetReadingLights(result: MethodChannel.Result) {
        if (!lightPuzzleActive || values["parking:global"] != true || lightOffActions.size != 4) {
            result.error("unavailable", "조명 초기화를 사용할 수 없습니다", null)
            return
        }
        cancelLightReset()
        resetResult = result
        val token = ++resetToken
        val session = generation
        val deadline = android.os.SystemClock.uptimeMillis() + 5000
        fun attempt() {
            if (token != resetToken || !active(session) || !lightPuzzleActive) return
            if (values["parking:global"] != true) {
                cancelLightReset()
                return
            }
            var remaining = 4
            var failed = false
            fun finished(success: Boolean) {
                main.post {
                    if (token != resetToken || !active(session)) return@post
                    if (!success) failed = true
                    if (--remaining != 0) return@post
                    val allOff = puzzleSeats.all { values["cabinLight:${it.name}"] == false }
                    if (!failed && allOff) {
                        Log.i(TAG, "Reading lights reset: all four actual states OFF")
                        resetResult?.success(null); resetResult = null; ++resetToken
                    } else if (android.os.SystemClock.uptimeMillis() < deadline) {
                        main.postDelayed({ attempt() }, 200)
                    }
                }
            }
            lightOffActions.values.toList().forEach { action ->
                try { action({ finished(true) }, { finished(false) }) } catch (_: Exception) { finished(false) }
            }
        }
        main.postDelayed({
            if (token == resetToken && resetResult != null) {
                resetResult?.error("timeout", "조명의 실제 Off 상태를 확인하지 못했습니다", null)
                resetResult = null; ++resetToken
            }
        }, 5500)
        attempt()
    }

    private fun stop() {
        lightPuzzleActive = false
        cancelLightReset()
        lightOffActions.clear()
        climateOff = null
        ++generation
        main.removeCallbacks(poll)
        cleanup.toList().forEach { try { it() } catch (_: Exception) {} }
        cleanup.clear()
        readers.clear()
        pending.clear()
        values.clear()
        capabilities.clear()
        capabilities["gloveboxOpen"] = false
        problems.clear()
        try { vehicle?.release() } catch (_: Exception) {}
        vehicle = null
        sink = null
    }

    fun dispose() {
        stop()
        channel.setStreamHandler(null)
        methods.setMethodCallHandler(null)
    }

    companion object { private const val TAG = "CarscapeVehicle" }
}
