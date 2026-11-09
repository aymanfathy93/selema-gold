package com.selema.selema_gold

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object WatchStore {
    private const val FILE = "selema_watch"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    @Synchronized
    fun save(ctx: Context, deals: String, settings: String) {
        // keep native "done" flags for deals the service already triggered
        val doneIds = HashSet<String>()
        val old = dealsArray(ctx)
        for (i in 0 until old.length()) {
            val d = old.optJSONObject(i) ?: continue
            if (d.optString("status") == "done") doneIds.add(d.optString("id"))
        }
        val arr = try { JSONArray(deals) } catch (e: Exception) { JSONArray() }
        for (i in 0 until arr.length()) {
            val d = arr.optJSONObject(i) ?: continue
            if (doneIds.contains(d.optString("id"))) d.put("status", "done")
        }
        val s = try { JSONObject(settings) } catch (e: Exception) { JSONObject() }
        val oldEgp = settings(ctx).optDouble("usdEgp", 0.0)
        if (s.optDouble("usdEgp", 0.0) <= 0.0 && oldEgp > 0.0) s.put("usdEgp", oldEgp)
        prefs(ctx).edit().putString("deals", arr.toString()).putString("settings", s.toString()).apply()
    }

    @Synchronized
    fun dealsArray(ctx: Context): JSONArray =
        try { JSONArray(prefs(ctx).getString("deals", "[]")) } catch (e: Exception) { JSONArray() }

    @Synchronized
    fun markDone(ctx: Context, hits: Map<String, Double>, time: Long) {
        val arr = dealsArray(ctx)
        for (i in 0 until arr.length()) {
            val d = arr.optJSONObject(i) ?: continue
            val p = hits[d.optString("id")] ?: continue
            d.put("status", "done")
            d.put("hitPrice", p)
            d.put("hitAt", time)
        }
        prefs(ctx).edit().putString("deals", arr.toString()).apply()
    }

    @Synchronized
    fun settings(ctx: Context): JSONObject =
        try { JSONObject(prefs(ctx).getString("settings", "{}")) } catch (e: Exception) { JSONObject() }

    @Synchronized
    fun setEgp(ctx: Context, v: Double) {
        val s = settings(ctx)
        s.put("usdEgp", v)
        prefs(ctx).edit().putString("settings", s.toString()).apply()
    }

    fun activeCount(ctx: Context): Int {
        val arr = dealsArray(ctx)
        var n = 0
        for (i in 0 until arr.length()) {
            if (arr.optJSONObject(i)?.optString("status") == "active") n++
        }
        return n
    }

    @Synchronized
    fun addEvent(ctx: Context, ev: JSONObject) {
        val arr = try { JSONArray(prefs(ctx).getString("events", "[]")) } catch (e: Exception) { JSONArray() }
        arr.put(ev)
        prefs(ctx).edit().putString("events", arr.toString()).apply()
    }

    @Synchronized
    fun takeEvents(ctx: Context): String {
        val v = prefs(ctx).getString("events", "[]") ?: "[]"
        prefs(ctx).edit().putString("events", "[]").apply()
        return v
    }

    @Synchronized
    fun lastPrice(ctx: Context, key: String): Double = prefs(ctx).getFloat("last_$key", -1f).toDouble()

    @Synchronized
    fun setLastPrice(ctx: Context, key: String, v: Double) {
        prefs(ctx).edit().putFloat("last_$key", v.toFloat()).apply()
    }

    @Synchronized
    fun egpCheckedAt(ctx: Context): Long = prefs(ctx).getLong("egp_at", 0L)

    @Synchronized
    fun setEgpCheckedAt(ctx: Context, t: Long) {
        prefs(ctx).edit().putLong("egp_at", t).apply()
    }
}

object AlarmPlayer {
    private var player: MediaPlayer? = null

    @Synchronized
    fun isPlaying(): Boolean = try { player?.isPlaying == true } catch (e: Exception) { false }

    @Synchronized
    fun play(ctx: Context, loop: Boolean) {
        stop()
        try {
            var uri: Uri? = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (uri == null) uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            if (uri == null) uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            if (uri == null) return
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            mp.setDataSource(ctx.applicationContext, uri)
            mp.isLooping = loop
            mp.setOnCompletionListener { stop() }
            mp.prepare()
            mp.start()
            player = mp
        } catch (e: Exception) {
            player = null
        }
    }

    @Synchronized
    fun stop() {
        try {
            player?.stop()
        } catch (e: Exception) {
        }
        try {
            player?.release()
        } catch (e: Exception) {
        }
        player = null
    }
}

object Notifier {
    const val CH_WATCH = "gold_watch"
    const val CH_ALERT = "gold_alerts_v1"
    const val WATCH_ID = 1001

    private fun nm(ctx: Context) = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun piFlags(): Int =
        if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        else PendingIntent.FLAG_UPDATE_CURRENT

    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val m = nm(ctx)
        if (m.getNotificationChannel(CH_WATCH) == null) {
            val c = NotificationChannel(CH_WATCH, "متابعة السعر", NotificationManager.IMPORTANCE_LOW)
            c.setShowBadge(false)
            m.createNotificationChannel(c)
        }
        if (m.getNotificationChannel(CH_ALERT) == null) {
            val c = NotificationChannel(CH_ALERT, "تنبيهات الأهداف", NotificationManager.IMPORTANCE_HIGH)
            c.enableVibration(true)
            c.vibrationPattern = longArrayOf(0, 600, 300, 600, 300, 600)
            c.setSound(null, null) // sound is played by AlarmPlayer
            c.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            m.createNotificationChannel(c)
        }
    }

    @Suppress("DEPRECATION")
    private fun builder(ctx: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, channel)
        else Notification.Builder(ctx)

    private fun openAppIntent(ctx: Context): PendingIntent {
        val i = Intent(ctx, MainActivity::class.java)
        i.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        return PendingIntent.getActivity(ctx, 0, i, piFlags())
    }

    fun watchNotification(ctx: Context, text: String): Notification {
        ensureChannels(ctx)
        return builder(ctx, CH_WATCH)
            .setSmallIcon(R.drawable.ic_stat_gold)
            .setContentTitle("Selema Gold")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openAppIntent(ctx))
            .build()
    }

    fun updateWatch(ctx: Context, text: String) {
        try {
            nm(ctx).notify(WATCH_ID, watchNotification(ctx, text))
        } catch (e: Exception) {
        }
    }

    @Suppress("DEPRECATION")
    fun showAlert(ctx: Context, id: Int, title: String, body: String) {
        ensureChannels(ctx)
        val stop = Intent(ctx, StopAlarmReceiver::class.java)
        val stopPi = PendingIntent.getBroadcast(ctx, 5, stop, piFlags())
        val b = builder(ctx, CH_ALERT)
            .setSmallIcon(R.drawable.ic_stat_gold)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(ctx))
            .setDeleteIntent(stopPi)
            .setCategory(Notification.CATEGORY_ALARM)
        if (Build.VERSION.SDK_INT < 26) {
            b.setPriority(Notification.PRIORITY_MAX)
            b.setVibrate(longArrayOf(0, 600, 300, 600))
        }
        if (Build.VERSION.SDK_INT >= 23) {
            val action = Notification.Action.Builder(null, "إيقاف الصوت / Stop", stopPi).build()
            b.addAction(action)
        }
        try {
            nm(ctx).notify(2000 + id, b.build())
        } catch (e: Exception) {
        }
    }

    fun cancelAlerts(ctx: Context) {
        try {
            val m = nm(ctx)
            if (Build.VERSION.SDK_INT >= 23) {
                for (n in m.activeNotifications) {
                    if (n.id != WATCH_ID) m.cancel(n.id)
                }
            }
        } catch (e: Exception) {
        }
    }
}

class StopAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        AlarmPlayer.stop()
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            GoldWatchService.ensure(context)
        } catch (e: Exception) {
        }
    }
}

object PriceFetcher {
    private const val UA =
        "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"

    private fun get(url: String): String? {
        var c: HttpURLConnection? = null
        return try {
            c = URL(url).openConnection() as HttpURLConnection
            c.connectTimeout = 12000
            c.readTimeout = 12000
            c.setRequestProperty("User-Agent", UA)
            c.setRequestProperty("Accept", "application/json")
            if (c.responseCode == 200) c.inputStream.bufferedReader().use { it.readText() } else null
        } catch (e: Exception) {
            null
        } finally {
            try {
                c?.disconnect()
            } catch (e: Exception) {
            }
        }
    }

    private fun yahooPrice(symbol: String): Double? {
        for (host in arrayOf("query1", "query2")) {
            val body = get("https://$host.finance.yahoo.com/v8/finance/chart/$symbol?interval=5m&range=1d") ?: continue
            try {
                val res = JSONObject(body).getJSONObject("chart").getJSONArray("result").getJSONObject(0)
                val p = res.getJSONObject("meta").optDouble("regularMarketPrice", 0.0)
                if (p > 0) return p
            } catch (e: Exception) {
            }
        }
        return null
    }

    /** Spot XAU/USD; gold-api.com first, then Yahoo gold futures as fallback. */
    fun xau(): Double? {
        val body = get("https://api.gold-api.com/price/XAU")
        if (body != null) {
            try {
                val p = JSONObject(body).optDouble("price", 0.0)
                if (p > 0) return p
            } catch (e: Exception) {
            }
        }
        return yahooPrice("GC%3DF")
    }

    fun usdEgp(): Double? {
        val y = yahooPrice("EGP%3DX")
        if (y != null && y > 10) return y
        val body = get("https://open.er-api.com/v6/latest/USD") ?: return null
        return try {
            val v = JSONObject(body).getJSONObject("rates").optDouble("EGP", 0.0)
            if (v > 10) v else null
        } catch (e: Exception) {
            null
        }
    }
}
