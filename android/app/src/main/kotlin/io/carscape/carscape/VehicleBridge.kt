package io.carscape.carscape

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import ai.pleos.playground.vehicle.Vehicle
import ai.pleos.playground.vehicle.api.model.area.SeatArea
import ai.pleos.playground.vehicle.api.model.area.WindowArea
import ai.pleos.playground.vehicle.api.model.capability.AccessType
import ai.pleos.playground.vehicle.api.model.capability.AreaBounds
import ai.pleos.playground.vehicle.api.model.capability.CapabilityConfig
import ai.pleos.playground.vehicle.constant.area.DoorValue
import ai.pleos.playground.vehicle.constant.area.SeatValue
import ai.pleos.playground.vehicle.constant.area.WindowValue
import ai.pleos.playground.vehicle.constant.control.LightState
import ai.pleos.playground.vehicle.constant.control.VehicleGear
import ai.pleos.playground.vehicle.constant.control.WiperState
import ai.pleos.playground.vehicle.constant.unit.TemperatureUnit
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/**
 * Read-only Vehicle SDK access behind lib/vehicle/pleos_vehicle_service.dart.
 * Device ids are the Dart `DeviceId` names. Never writes to the car.
 *
 * - `io.carscape/vehicle` `isSupported(id)`: the device's `check…Capabilities`.
 * - `io.carscape/vehicle/<id>` events `{value, seat}`: current value, then changes.
 */
@Suppress("DEPRECATION") // SDK 2.3.2 gear read is deprecated, not removed.
class VehicleBridge(context: Context, messenger: BinaryMessenger) {
    /** One readable value; [seat] is the Dart `Seat` name for per-seat devices. */
    private class Reader(val seat: String?, val read: ((Number?) -> Unit, (Exception) -> Unit) -> Unit)

    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val methods = MethodChannel(messenger, "io.carscape/vehicle")
    private val channels = DEVICES.associateWith { EventChannel(messenger, "io.carscape/vehicle/$it") }
    private var sdk: Vehicle? = null
    private val readers = mutableMapOf<String, List<Reader>>()
    private val sinks = mutableMapOf<String, EventChannel.EventSink>()
    private val last = mutableMapOf<String, Number>()
    private val inFlight = mutableMapOf<String, Long>()

    // ponytail: polls get… instead of register… listeners. The tutorial bridge
    // found AVD subscriptions can miss callbacks, and 300 ms is quick enough for
    // a hands-on check. Add listeners if a puzzle needs faster reactions.
    private val poll = object : Runnable {
        override fun run() {
            if (sinks.isEmpty()) return
            sinks.keys.toList().forEach(::readAll)
            main.postDelayed(this, POLL_MS)
        }
    }

    init {
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> resolve(call.arguments as String) { result.success(it.isNotEmpty()) }
                else -> result.notImplemented()
            }
        }
        channels.forEach { (id, channel) ->
            channel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sinks[id] = events
                    last.keys.removeAll { it.startsWith("$id:") } // a new listener gets the current value
                    resolve(id) {}
                    main.removeCallbacks(poll)
                    main.post(poll)
                }

                override fun onCancel(arguments: Any?) {
                    sinks.remove(id)
                }
            })
        }
    }

    private fun vehicle(): Vehicle = sdk ?: Vehicle(appContext).also { it.initialize(); sdk = it }

    /** Finds the device's readers once; unsupported answers aren't cached so "다시 점검" retries. */
    private fun resolve(id: String, done: (List<Reader>) -> Unit) {
        readers[id]?.let { return done(it) }
        var answered = false
        fun answer(found: List<Reader>) {
            main.post {
                if (answered) return@post
                answered = true
                if (found.isNotEmpty()) readers[id] = found
                Log.i(TAG, "$id supported=${found.isNotEmpty()}")
                done(found)
            }
        }
        main.postDelayed({ answer(emptyList()) }, TIMEOUT_MS)
        try {
            probe(vehicle(), id, ::answer) { Log.w(TAG, "$id: ${it.message}"); answer(emptyList()) }
        } catch (e: Exception) {
            Log.w(TAG, "$id: ${e.message}")
            answer(emptyList())
        }
    }

    private fun readAll(id: String) {
        readers[id].orEmpty().forEach { reader ->
            val key = "$id:${reader.seat}"
            val now = SystemClock.uptimeMillis()
            if ((inFlight[key] ?: Long.MIN_VALUE) > now - TIMEOUT_MS) return@forEach
            inFlight[key] = now
            val failed = { e: Exception -> main.post { inFlight.remove(key); Log.w(TAG, "$key: ${e.message}") }; Unit }
            try {
                reader.read({ value -> main.post { inFlight.remove(key); if (value != null) emit(id, reader.seat, value) } }, failed)
            } catch (e: Exception) {
                inFlight.remove(key)
                Log.w(TAG, "$key: ${e.message}")
            }
        }
    }

    private fun emit(id: String, seat: String?, value: Number) {
        val key = "$id:$seat"
        if (last[key] == value) return
        last[key] = value
        Log.i(TAG, "$key=$value")
        sinks[id]?.success(mapOf("value" to value, "seat" to seat))
    }

    private fun readable(config: CapabilityConfig) =
        config.accessType == AccessType.READ || config.accessType == AccessType.READ_WRITE

    private fun bit(on: Boolean) = if (on) 1 else 0
    private fun on(value: Any?, yes: Any) = value?.let { bit(it == yes) }
    private fun single(reader: Reader?) = listOfNotNull(reader)

    /** Passenger-side zone first (the heater prompt), then driver, then any. */
    private fun zone(config: CapabilityConfig, areas: Collection<SeatArea>) =
        if (!readable(config)) null
        else areas.firstOrNull { SeatValue.ROW_1_RIGHT in it.values }
            ?: areas.firstOrNull { SeatValue.ROW_1_LEFT in it.values }
            ?: areas.firstOrNull()

    private fun probe(sdk: Vehicle, id: String, found: (List<Reader>) -> Unit, failed: (Exception) -> Unit) {
        val hvac = sdk.getHVAC()
        val wheel = sdk.getSteeringWheel()
        when (id) {
            "cabinLight" -> {
                val light = sdk.getLight()
                light.checkReadingLightStateCapabilities({ c, areas ->
                    found(if (!readable(c)) emptyList() else SEATS.mapNotNull { (seat, code) ->
                        SeatArea(code).takeIf { it in areas }?.let { area ->
                            Reader(seat) { ok, fail -> light.getCurrentReadingLightState(area, { ok(on(it, LightState.ON)) }, fail) }
                        }
                    })
                }, failed)
            }
            "passengerHeater" -> hvac.checkHvacTemperatureCapabilities({ c: CapabilityConfig, areas: Map<SeatArea, AreaBounds<Float>> ->
                found(single(zone(c, areas.keys)?.let { area ->
                    Reader(null) { ok, fail -> hvac.getHvacTemperature(area, TemperatureUnit.CELSIUS, ok, fail) }
                }))
            }, failed)
            // AVD reports clockwise as negative; right is positive like the tutorial.
            // Whole degrees so sensor jitter never counts as a turn.
            "steering" -> wheel.checkSteeringWheelAngleCapabilities({ c, _ ->
                found(single(if (!readable(c)) null else Reader(null) { ok, fail ->
                    wheel.getCurrentSteeringWheelAngle({ ok(it?.let { angle -> -angle.roundToInt() }) }, fail)
                }))
            }, failed)
            "window" -> {
                val window = sdk.getWindow()
                window.checkWindowPositionCapabilities({ c, areas ->
                    found(if (!readable(c)) emptyList() else SEATS.mapNotNull { (seat, code) ->
                        val area = WindowArea(WindowValue.valueOf(code.name))
                        areas[area]?.takeIf { it.maxValue > it.minValue }?.let { b ->
                            Reader(seat) { ok, fail ->
                                window.getCurrentWindowPosition(area, { ok(it?.let { p -> (p - b.minValue) * 100 / (b.maxValue - b.minValue) }) }, fail)
                            }
                        }
                    })
                }, failed)
            }
            // One value for all doors and the trunk: 1 when any is open.
            "door" -> {
                val door = sdk.getDoor()
                door.checkDoorPositionCapabilities({ c, areas ->
                    val doors = if (!readable(c)) emptyMap()
                        else areas.filter { (area, b) -> DoorValue.HOOD !in area.values && b.maxValue > b.minValue }
                    found(single(if (doors.isEmpty()) null else Reader(null) { ok, fail ->
                        var left = doors.size
                        var open = false
                        var gaveUp = false
                        doors.forEach { (area, b) ->
                            door.getCurrentDoorPosition(area, { p -> main.post {
                                if (p != null && p > b.minValue) open = true
                                if (--left == 0) ok(bit(open))
                            } }, { e -> main.post { if (!gaveUp) { gaveUp = true; fail(e) } } })
                        }
                    }))
                }, failed)
            }
            "wiper" -> {
                val wiper = sdk.getWiper()
                val front = WindowArea(WindowValue.FRONT_WINDSHIELD)
                wiper.checkWiperStateCapabilities({ c, areas ->
                    found(single(if (!readable(c) || front !in areas) null else Reader(null) { ok, fail ->
                        wiper.getCurrentWiperState(front, { ok(on(it, WiperState.ON)) }, fail)
                    }))
                }, failed)
            }
            // No capability check for gear: a successful read means supported.
            // Value 1 = P (Dart `gearPark`), 0 = anything else.
            "gear" -> {
                val gear = sdk.getGear()
                val reader = Reader(null) { ok, fail -> gear.getCurrentGearSelectionState({ ok(on(it, VehicleGear.GEAR_PARK)) }, fail) }
                reader.read({ value -> found(if (value == null) emptyList() else listOf(reader)) }, failed)
            }
            "recirculation" -> hvac.checkHvacRecirculationCapabilities({ c, areas ->
                found(single(zone(c, areas)?.let { area ->
                    Reader(null) { ok, fail -> hvac.getHvacRecirculationState(area, { ok(on(it, true)) }, fail) }
                }))
            }, failed)
            "rearDefrost" -> {
                val rear = WindowArea(WindowValue.REAR_WINDSHIELD)
                hvac.checkHvacDefrosterCapabilities({ c, areas ->
                    found(single(if (!readable(c) || rear !in areas) null else Reader(null) { ok, fail ->
                        hvac.getHvacDefrosterState(rear, { ok(on(it, true)) }, fail)
                    }))
                }, failed)
            }
            "steeringHeater" -> wheel.checkHvacSteeringWheelHeatCapabilities({ c, _ ->
                found(single(if (!readable(c)) null else Reader(null) { ok, fail -> wheel.getHvacSteeringWheelHeatState(ok, fail) }))
            }, failed)
            "airCon" -> hvac.checkHvacAcCapabilities({ c, areas ->
                found(single(zone(c, areas)?.let { area ->
                    Reader(null) { ok, fail -> hvac.getHvacAcState(area, { ok(on(it, true)) }, fail) }
                }))
            }, failed)
            "fanSpeed" -> hvac.checkHvacFanSpeedCapabilities({ c, areas ->
                found(single(zone(c, areas.keys)?.let { area ->
                    Reader(null) { ok, fail -> hvac.getHvacFanSpeed(area, ok, fail) }
                }))
            }, failed)
            else -> found(emptyList())
        }
    }

    fun dispose() {
        main.removeCallbacksAndMessages(null)
        methods.setMethodCallHandler(null)
        channels.values.forEach { it.setStreamHandler(null) }
        sinks.clear()
        try { sdk?.release() } catch (_: Exception) {}
        sdk = null
    }

    companion object {
        private const val TAG = "CarscapeVehicleCheck"
        private const val POLL_MS = 300L
        private const val TIMEOUT_MS = 3000L
        private val DEVICES = listOf(
            "cabinLight", "passengerHeater", "steering", "window", "door", "wiper", "gear",
            "recirculation", "rearDefrost", "steeringHeater", "airCon", "fanSpeed",
        )
        private val SEATS = listOf(
            "driver" to SeatValue.ROW_1_LEFT,
            "passenger" to SeatValue.ROW_1_RIGHT,
            "rearLeft" to SeatValue.ROW_2_LEFT,
            "rearRight" to SeatValue.ROW_2_RIGHT,
        )
    }
}
