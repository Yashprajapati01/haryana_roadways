package com.example.haryana_roadways

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.telephony.CellIdentityGsm
import android.telephony.CellIdentityLte
import android.telephony.CellIdentityNr
import android.telephony.CellIdentityWcdma
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoNr
import android.telephony.CellInfoWcdma
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var locationReply: io.flutter.plugin.common.MethodChannel.Result? = null
    private var notificationReply: io.flutter.plugin.common.MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "haryana_roadways/cell")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepareTracking" -> result.success(true)
                    "requestLocation" -> requestLocation(result)
                    "requestNotifications" -> requestNotifications(result)
                    "servingCell" -> result.success(servingCell())
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        when (requestCode) {
            locationRequest -> finish(locationReply, grantResults, Manifest.permission.ACCESS_FINE_LOCATION, permissions).also {
                locationReply = null
            }
            notificationRequest -> finish(notificationReply, grantResults, Manifest.permission.POST_NOTIFICATIONS, permissions).also {
                notificationReply = null
            }
            else -> super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    private fun requestLocation(result: io.flutter.plugin.common.MethodChannel.Result) {
        if (granted(Manifest.permission.ACCESS_FINE_LOCATION)) {
            result.success(true)
            return
        }
        locationReply?.success(false)
        locationReply = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
            locationRequest,
        )
    }

    private fun requestNotifications(result: io.flutter.plugin.common.MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || granted(Manifest.permission.POST_NOTIFICATIONS)) {
            result.success(true)
            return
        }
        notificationReply?.success(false)
        notificationReply = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationRequest,
        )
    }

    private fun granted(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun finish(
        reply: io.flutter.plugin.common.MethodChannel.Result?,
        grantResults: IntArray,
        permission: String,
        permissions: Array<out String>,
    ) {
        val index = permissions.indexOf(permission)
        val ok = index >= 0 && index < grantResults.size && grantResults[index] == PackageManager.PERMISSION_GRANTED
        reply?.success(ok)
    }

    companion object {
        private const val locationRequest = 42
        private const val notificationRequest = 41
    }

    private fun servingCell(): Map<String, Int>? {
        val tm = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
        val info = try {
            tm.allCellInfo?.firstOrNull { it.isRegistered }
        } catch (_: SecurityException) {
            null
        } ?: return null
        return when (info) {
            is CellInfoLte -> lte(info.cellIdentity)
            is CellInfoGsm -> gsm(info.cellIdentity)
            is CellInfoWcdma -> wcdma(info.cellIdentity)
            else -> if (Build.VERSION.SDK_INT >= 29 && info is CellInfoNr) {
                nr(info.cellIdentity as CellIdentityNr)
            } else {
                null
            }
        }
    }

    private fun lte(id: CellIdentityLte): Map<String, Int>? {
        val mcc = if (Build.VERSION.SDK_INT >= 28) id.mccString?.toIntOrNull() else null
        val mnc = if (Build.VERSION.SDK_INT >= 28) id.mncString?.toIntOrNull() else null
        @Suppress("DEPRECATION")
        val mccFallback = mcc ?: id.mcc
        @Suppress("DEPRECATION")
        val mncFallback = mnc ?: id.mnc
        return valid(mccFallback, mncFallback, id.tac, id.ci)
    }

    @Suppress("DEPRECATION")
    private fun gsm(id: CellIdentityGsm): Map<String, Int>? {
        val mcc = if (Build.VERSION.SDK_INT >= 28) id.mccString?.toIntOrNull() else null
        val mnc = if (Build.VERSION.SDK_INT >= 28) id.mncString?.toIntOrNull() else null
        return valid(mcc ?: id.mcc, mnc ?: id.mnc, id.lac, id.cid)
    }

    @Suppress("DEPRECATION")
    private fun wcdma(id: CellIdentityWcdma): Map<String, Int>? {
        val mcc = if (Build.VERSION.SDK_INT >= 28) id.mccString?.toIntOrNull() else null
        val mnc = if (Build.VERSION.SDK_INT >= 28) id.mncString?.toIntOrNull() else null
        return valid(mcc ?: id.mcc, mnc ?: id.mnc, id.lac, id.cid)
    }

    private fun nr(id: CellIdentityNr): Map<String, Int>? {
        val mcc = id.mccString?.toIntOrNull() ?: return null
        val mnc = id.mncString?.toIntOrNull() ?: return null
        val nci = id.nci
        if (nci > Int.MAX_VALUE) return null
        return valid(mcc, mnc, id.tac, nci.toInt())
    }

    private fun valid(mcc: Int, mnc: Int, lac: Int, cid: Int): Map<String, Int>? {
        if (mcc <= 0 || mcc == Int.MAX_VALUE) return null
        if (mnc < 0 || mnc == Int.MAX_VALUE) return null
        if (lac < 0 || lac == Int.MAX_VALUE) return null
        if (cid < 0 || cid == Int.MAX_VALUE) return null
        return mapOf("mcc" to mcc, "mnc" to mnc, "lac" to lac, "cid" to cid)
    }
}
