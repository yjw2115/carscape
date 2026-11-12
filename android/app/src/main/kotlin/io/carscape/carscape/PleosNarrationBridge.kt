package io.carscape.carscape

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import ai.pleos.playground.tts.TextToSpeech
import ai.pleos.playground.tts.constant.ErrorType
import ai.pleos.playground.tts.constant.Mode
import ai.pleos.playground.tts.listener.EventListener
import ai.pleos.playground.tts.listener.OnInitializeListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Plays Korean narration through the Pleos Speech Service. */
class PleosNarrationBridge(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "io.carscape/pleos_narration")
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private var engine: TextToSpeech? = null
    private var listener: EventListener? = null
    private var pending: MethodChannel.Result? = null
    private var timeout: Runnable? = null
    private var started = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.arguments as? String
                    if (text.isNullOrBlank()) result.success(false) else speak(text, result)
                }
                "stop" -> {
                    if (pending != null) closeEngine()
                    result.success(null)
                }
                "release" -> {
                    closeEngine()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun speak(text: String, result: MethodChannel.Result) {
        if (pending != null) closeEngine()
        pending = result
        started = false
        armTimeout(4500)
        try {
            val ready = engine
            if (ready != null) {
                ready.speak(text)
                return
            }
            val sdk = TextToSpeech(appContext, Mode.ON_DEVICE)
            engine = sdk
            val events = object : EventListener {
                override fun onReady() = Unit
                override fun onUpdatedRms(rms: Double) = Unit
                override fun onStart() {
                    main.post {
                        if (engine === sdk && pending != null) {
                            started = true
                            armTimeout(18000)
                            Log.i(TAG, "Pleos Korean narration started")
                        }
                    }
                }
                override fun onDone() {
                    main.post {
                        if (engine === sdk && started) {
                            Log.i(TAG, "Pleos Korean narration completed")
                            complete(true)
                        }
                    }
                }
                override fun onStop() {
                    main.post { if (engine === sdk && pending != null) fail("Playback stopped") }
                }
                override fun onError(errorType: ErrorType) {
                    main.post { if (engine === sdk && pending != null) fail(errorType.name) }
                }
            }
            listener = events
            sdk.initialize(object : OnInitializeListener {
                override fun onSuccess() {
                    main.post {
                        if (engine !== sdk || pending == null) return@post
                        try {
                            sdk.addEventListener(events)
                            sdk.setLocale(Locale.KOREA)
                            sdk.speak(text)
                        } catch (error: Exception) {
                            fail(error.javaClass.simpleName)
                        }
                    }
                }
                override fun onFailure(errorType: ErrorType) {
                    main.post { if (engine === sdk && pending != null) fail(errorType.name) }
                }
            })
        } catch (error: Exception) {
            fail(error.javaClass.simpleName)
        }
    }

    private fun armTimeout(delay: Long) {
        timeout?.let(main::removeCallbacks)
        timeout = Runnable { fail("Speech Service timed out") }.also { main.postDelayed(it, delay) }
    }

    private fun complete(success: Boolean) {
        timeout?.let(main::removeCallbacks)
        timeout = null
        started = false
        val result = pending
        pending = null
        result?.success(success)
    }

    private fun fail(reason: String) {
        Log.w(TAG, reason)
        closeEngine()
    }

    private fun closeEngine() {
        val sdk = engine
        val events = listener
        engine = null
        listener = null
        if (sdk != null) {
            if (events != null) runCatching { sdk.removeEventListener(events) }
            if (pending != null) runCatching { sdk.stop() }
            runCatching { sdk.release() }
        }
        complete(false)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        closeEngine()
    }

    companion object { private const val TAG = "CarscapeNarration" }
}
