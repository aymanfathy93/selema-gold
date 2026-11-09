package com.selema.selema_gold

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import org.json.JSONObject
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class GoldWatchService : Service() {

    companion object {
        @Volatile
        var running = false
        private const val OUNCE = 31.1034768
        private const val INTERVAL_SEC = 20L

        fun ensure(ctx: Context) {
            val i = Intent(ctx, GoldWatchService::class.java)
            if (WatchStore.activeCount(ctx) > 0) {
                if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
            } else if (running) {
                ctx.stopService(i)
            }
        }
    }

    private var executor: ScheduledExecutorService? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = WatchStore.settings(this).optString("watchText", "جاري متابعة سعر الذهب")
        val n = Notifier.watchNotification(this, text)
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(Notifier.WATCH_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(Notifier.WATCH_ID, n)
            }
        } catch (e: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        if (WatchStore.activeCount(this) == 0) {
            stopSelf()
            return START_NOT_STICKY
        }
        acquireWakeLock()
        if (executor == null) {
            val ex = Executors.newSingleThreadScheduledExecutor()
            ex.scheduleWithFixedDelay({ safeTick() }, 0, INTERVAL_SEC, TimeUnit.SECONDS)
            executor = ex
        }
        return START_STICKY
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SelemaGold::watch")
            wl.setReferenceCounted(false)
            wl.acquire()
            wakeLock = wl
        } catch (e: Exception) {
        }
    }

    private fun safeTick() {
        try {
            tick()
        } catch (e: Throwable) {
        }
    }

    private fun fmt(v: Double): String = String.format(Locale.US, "%.2f", v)

    private fun tick() {
        val ctx: Context = this
        val deals = WatchStore.dealsArray(ctx)
        var active = 0
        for (i in 0 until deals.length()) {
            if (deals.optJSONObject(i)?.optString("status") == "active") active++
        }
        if (active == 0) {
            stopSelf()
            return
        }

        val settings = WatchStore.settings(ctx)
        var egp = settings.optDouble("usdEgp", 0.0)
        val now = System.currentTimeMillis()
        if (egp <= 0.0 || now - WatchStore.egpCheckedAt(ctx) > 30 * 60 * 1000L) {
            val e = PriceFetcher.usdEgp()
            if (e != null) {
                egp = e
                WatchStore.setEgp(ctx, e)
                WatchStore.setEgpCheckedAt(ctx, now)
            }
        }
        val xau = PriceFetcher.xau() ?: return
        if (egp <= 0.0) return

        val margin = settings.optDouble("margin", 15.0)
        val base24 = xau * egp / OUNCE
        fun sell(k: Int) = base24 * k / 24.0
        fun buy(k: Int) = sell(k) - margin

        Notifier.updateWatch(
            ctx,
            "XAU ${fmt(xau)} $  •  24K ${fmt(sell(24))}  •  21K ${fmt(sell(21))}"
        )

        val push = settings.optBoolean("push", true)
        val sound = settings.optBoolean("sound", true)
        val title = settings.optString("title", "وصل السعر للهدف")
        val hint = settings.optString("bodyHint", "")
        val hits = HashMap<String, Double>()

        for (i in 0 until deals.length()) {
            val d = deals.optJSONObject(i) ?: continue
            if (d.optString("status") != "active") continue
            val type = d.optString("type", "buy")
            val karat = d.optInt("karat", 24)
            val low = d.optDouble("low", 0.0)
            val high = d.optDouble("high", 0.0)
            val price = if (type == "buy") buy(karat) else sell(karat)
            val key = "${type}_$karat"
            val last = WatchStore.lastPrice(ctx, key + "_" + d.optString("id"))
            val inRange = price >= low && price <= high
            val crossed = last > 0 && ((last < low && price > high) || (last > high && price < low))
            WatchStore.setLastPrice(ctx, key + "_" + d.optString("id"), price)
            if (inRange || crossed) {
                hits[d.optString("id")] = price
                val ev = JSONObject()
                ev.put("dealId", d.optString("id"))
                ev.put("type", type)
                ev.put("karat", karat)
                ev.put("low", low)
                ev.put("high", high)
                ev.put("price", price)
                ev.put("time", now)
                WatchStore.addEvent(ctx, ev)
                val label = if (type == "buy") "Buy Price (${karat}K)" else "Sell Price (${karat}K)"
                val body = "$label = ${fmt(price)} EGP  [${fmt(low)} - ${fmt(high)}]\n$hint"
                if (push) Notifier.showAlert(ctx, (d.optString("id").hashCode() and 0xFFFF), title, body)
            }
        }
        if (hits.isNotEmpty()) {
            WatchStore.markDone(ctx, hits, now)
            AlarmPlayer.play(ctx, sound)
        }
        if (WatchStore.activeCount(ctx) == 0) stopSelf()
    }

    override fun onDestroy() {
        running = false
        try {
            executor?.shutdownNow()
        } catch (e: Exception) {
        }
        executor = null
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (e: Exception) {
        }
        wakeLock = null
        super.onDestroy()
    }
}
