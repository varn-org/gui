package dev.varn.gui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.view.View
import org.json.JSONObject

/**
 * Where the device is, for as long as the node asking for it is on screen.
 *
 * The permission belongs to the activity, so the view does not ask for one itself: it asks the host,
 * the host asks the application, and the answer comes back the same way an activity result does. The
 * fix itself is the platform's own provider rather than Play services, so nothing here needs a key or
 * an account behind it.
 */
class VarnLocationView(context: Context) : View(context), VarnSettling, VarnReleasing, LocationListener {
    private val locations = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

    private var watching = false
    private var accuracy = "fine"
    private var asked: String? = null
    private var listening = false
    private var closed = false

    var onChange: ((JSONObject) -> Unit)? = null
    var onError: ((JSONObject) -> Unit)? = null

    /** Asked with the permission a fix needs, and answered with whether the reader allowed it. */
    var onPermission: ((String, (Boolean) -> Unit) -> Unit)? = null

    init {
        visibility = GONE
    }

    fun setWatch(value: Boolean) {
        watching = value
    }

    fun setAccuracy(value: String?) {
        accuracy = value ?: "fine"
    }

    override fun settle() {
        if (closed) {
            return
        }

        val wanted = "$watching/$accuracy"

        if (wanted == asked) {
            return
        }

        asked = wanted
        ask()
    }

    override fun release() {
        closed = true
        stop()
    }

    private fun ask() {
        stop()

        val permission =
            if (accuracy == "fine") Manifest.permission.ACCESS_FINE_LOCATION
            else Manifest.permission.ACCESS_COARSE_LOCATION

        if (context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            start()
            return
        }

        val request = onPermission

        if (request == null) {
            onError?.invoke(problem("this application cannot ask for permission to say where it is"))
            return
        }

        // The reader answers a permission dialog long after the screen may have gone.
        request(permission) { allowed ->
            if (closed) {
                return@request
            }

            if (allowed) {
                start()
                return@request
            }

            onError?.invoke(problem("this device is not allowed to say where it is"))
        }
    }

    private fun start() {
        val provider = provider()

        if (provider == null) {
            onError?.invoke(problem("this device has no location provider turned on"))
            return
        }

        listening = true

        runCatching {
            locations.requestLocationUpdates(provider, INTERVAL, 0f, this)
        }.onFailure { failure ->
            listening = false
            onError?.invoke(problem(failure.message ?: "the device could not be asked where it is"))
        }
    }

    private fun stop() {
        if (!listening) {
            return
        }

        listening = false
        locations.removeUpdates(this)
    }

    /**
     * Answers the provider a fix comes from, which is the fused one where the platform has it.
     *
     * A device sitting indoors can wait minutes for a satellite, so the network provider is what a
     * screen asking once is given wherever the fused provider is not available.
     */
    private fun provider(): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && locations.isProviderEnabled(LocationManager.FUSED_PROVIDER)) {
            return LocationManager.FUSED_PROVIDER
        }

        if (accuracy == "fine" && locations.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            return LocationManager.GPS_PROVIDER
        }

        if (locations.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            return LocationManager.NETWORK_PROVIDER
        }

        return null
    }

    override fun onLocationChanged(fix: Location) {
        onChange?.invoke(
            JSONObject()
                .put("latitude", fix.latitude)
                .put("longitude", fix.longitude)
                .put("accuracy", fix.accuracy.toDouble()),
        )

        // A screen that asked once is answered once, and the receiver goes with the answer.
        if (!watching) {
            stop()
        }
    }

    override fun onProviderDisabled(provider: String) {
        onError?.invoke(problem("the device stopped saying where it is"))
    }

    private fun problem(message: String) = JSONObject().put("message", message)

    private companion object {
        const val INTERVAL = 2000L
    }
}
