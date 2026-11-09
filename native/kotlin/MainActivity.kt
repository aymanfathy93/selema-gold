package com.selema.selema_gold

import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "selema/gold").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "sync" -> {
                        val deals = call.argument<String>("deals") ?: "[]"
                        val settings = call.argument<String>("settings") ?: "{}"
                        WatchStore.save(this, deals, settings)
                        GoldWatchService.ensure(this)
                        result.success(true)
                    }
                    "getEvents" -> result.success(WatchStore.takeEvents(this))
                    "stopAlarm" -> {
                        AlarmPlayer.stop()
                        Notifier.cancelAlerts(this)
                        result.success(true)
                    }
                    "isRinging" -> result.success(AlarmPlayer.isPlaying())
                    "isRunning" -> result.success(GoldWatchService.running)
                    "testAlert" -> {
                        val title = call.argument<String>("title") ?: "Selema Gold"
                        val body = call.argument<String>("body") ?: ""
                        val sound = call.argument<Boolean>("sound") ?: true
                        val push = call.argument<Boolean>("push") ?: true
                        val ev = JSONObject()
                        ev.put("dealId", "test")
                        ev.put("type", "buy")
                        ev.put("karat", 24)
                        ev.put("low", 0.0)
                        ev.put("high", 0.0)
                        ev.put("price", 0.0)
                        ev.put("time", System.currentTimeMillis())
                        ev.put("test", true)
                        WatchStore.addEvent(this, ev)
                        if (push || sound) Notifier.showAlert(this, 999, title, body, sound)
                        AlarmPlayer.play(this, sound)
                        result.success(true)
                    }
                    "testEmail" -> {
                        val url = call.argument<String>("url") ?: ""
                        val to = call.argument<String>("to") ?: ""
                        Thread {
                            val ok = PriceFetcher.sendMail(
                                url, to, "Selema Gold: إيميل تجريبي",
                                "<div dir='rtl' style='font-family:Arial;font-size:16px'>" +
                                    "<h2 style='color:#B8913F'>Selema Trading</h2>" +
                                    "<p>تم ربط التنبيهات بالإيميل بنجاح ✅</p></div>"
                            )
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "requestNotif" -> {
                        requestNotifPermission()
                        result.success(true)
                    }
                    "batteryExempt" -> {
                        requestBatteryExemption()
                        result.success(true)
                    }
                    "isBatteryExempt" -> result.success(isBatteryExempt())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ERR", e.message, null)
            }
        }
    }

    private fun requestNotifPermission() {
        if (Build.VERSION.SDK_INT >= 33) {
            val p = "android.permission.POST_NOTIFICATIONS"
            if (checkSelfPermission(p) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(p), 77)
            }
        }
    }

    private fun isBatteryExempt(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    @SuppressLint("BatteryLife")
    private fun requestBatteryExemption() {
        if (Build.VERSION.SDK_INT < 23) return
        try {
            val i = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            i.data = Uri.parse("package:$packageName")
            startActivity(i)
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (e2: Exception) {
            }
        }
    }
}
