package com.snoozio.app
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.content.Intent
import android.app.NotificationManager
import android.content.Context
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Vibrator
import android.os.VibrationEffect
import android.os.Build
import android.util.Log
import android.media.MediaPlayer
import android.media.AudioAttributes
import org.json.JSONArray

class MainActivity: FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.snoozio.app/alarm"
        private const val TAG = "SnoozioAlarm"
    }

    private var ringtone: Ringtone? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var isAlarmPlaying = false
    
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity onCreate")
        createNotificationChannels()

        // Check initial intent for alarm payload
        val initialIntent = intent
        val payload = initialIntent?.extras?.getString("payload")
        if (payload?.startsWith("alarm:") == true) {
            Log.d(TAG, "Alarm intent detected on create")
            val alarmId = payload.substring("alarm:".length)
            playAlarmSoundForId(alarmId)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "=== CONFIGURING FLUTTER ENGINE ===")
        Log.d(TAG, "Binary Messenger: ${flutterEngine.dartExecutor.binaryMessenger}")
        
        try {
            methodChannel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL
            )
            
            methodChannel?.setMethodCallHandler { call, result ->
                Log.d(TAG, "Method called: ${call.method}")
                
                when (call.method) {
                    "playAlarmSound" -> {
                        Log.d(TAG, "playAlarmSound called")
                        val soundPath = call.argument<String>("soundPath")
                        val soundType = call.argument<String>("soundType")
                        playAlarmSound(soundPath, soundType)
                        startVibration()
                        result.success(true)
                    }
                    "stopAlarmSound" -> {
                        Log.d(TAG, "stopAlarmSound called")
                        stopAlarmSound()
                        result.success(true)
                    }
                    "isAlarmPlaying" -> {
                        Log.d(TAG, "isAlarmPlaying: $isAlarmPlaying")
                        result.success(isAlarmPlaying)
                    }
                    else -> {
                        Log.d(TAG, "Unknown method: ${call.method}")
                        result.notImplemented()
                    }
                }
            }
            
            Log.d(TAG, "MethodChannel configured successfully on channel: $CHANNEL")
        } catch (e: Exception) {
            Log.e(TAG, "Error configuring MethodChannel: ${e.message}", e)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val alarmChannel = android.app.NotificationChannel(
                "alarms_channel",
                "Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Full-screen alarms with sound"
                enableVibration(true)
                enableLights(true)
                lightColor = android.graphics.Color.RED
                setBypassDnd(true)
                setShowBadge(true)
            }

            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(alarmChannel)
            Log.d(TAG, "Notification channels created")
        }
    }

    private fun handleNotificationIntent(intent: Intent?) {
        val payload = intent?.extras?.getString("payload")
        if (payload?.startsWith("alarm:") == true) {
            Log.d(TAG, "Alarm notification intent received")
            startVibration()
        }
    }

    private fun playAlarmSound(soundPath: String?, soundType: String?) {
        try {
            Log.d(TAG, "=== STARTING ALARM SOUND ===")
            Log.d(TAG, "soundPath=$soundPath, soundType=$soundType")

            // Stop any existing sound first
            stopAlarmSound()

            if (soundPath != null && soundPath.isNotEmpty() && soundPath != "null") {
                // Play custom sound
                try {
                    Log.d(TAG, "Attempting to play CUSTOM sound: $soundPath")
                    mediaPlayer = MediaPlayer().apply {
                        // Set audio attributes for alarm stream
                        setAudioAttributes(
                            AudioAttributes.Builder()
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .build()
                        )
                        
                        setDataSource(this@MainActivity, Uri.parse(soundPath))
                        isLooping = true // Enable looping BEFORE prepare
                        setVolume(1.0f, 1.0f) // Set max volume
                        
                        // Add listeners
                        setOnPreparedListener { mp ->
                            Log.d(TAG, "MediaPlayer prepared, starting playback")
                            mp.start()
                            isAlarmPlaying = true
                            Log.d(TAG, "Custom alarm sound PLAYING (looping=${mp.isLooping})")
                        }
                        
                        setOnCompletionListener { mp ->
                            Log.d(TAG, "MediaPlayer completed")
                            if (isAlarmPlaying) {
                                Log.d(TAG, "Restarting playback...")
                                mp.start()
                            }
                        }
                        
                        setOnErrorListener { mp, what, extra ->
                            Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                            playSystemAlarmSound()
                            true
                        }
                        
                        prepareAsync() // Use async to avoid blocking
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error playing custom sound: ${e.message}", e)
                    playSystemAlarmSound()
                }
            } else {
                // Play system sound
                Log.d(TAG, "Playing SYSTEM alarm sound (default)")
                playSystemAlarmSound()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in playAlarmSound: ${e.message}", e)
        }
    }

    private fun playSystemAlarmSound() {
        try {
            Log.d(TAG, "=== PLAYING DEFAULT ALARM SOUND ===")

            // Use the app's default notification.wav from raw resources
            val alarmUri = Uri.parse("android.resource://${packageName}/raw/notification")
            Log.d(TAG, "Default alarm URI: $alarmUri")

            // Use MediaPlayer for consistent looping behavior
            playSystemAlarmWithMediaPlayer(alarmUri)
        } catch (e: Exception) {
            Log.e(TAG, "Error playing default alarm: ${e.message}", e)
        }
    }

    private fun playSystemAlarmWithMediaPlayer(uri: Uri) {
        try {
            Log.d(TAG, "Playing system alarm via MediaPlayer")
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                )
                setDataSource(this@MainActivity, uri)
                isLooping = true
                setVolume(1.0f, 1.0f)

                setOnPreparedListener { mp ->
                    Log.d(TAG, "System MediaPlayer prepared")
                    mp.start()
                    isAlarmPlaying = true
                    Log.d(TAG, "System alarm PLAYING via MediaPlayer")
                }

                setOnErrorListener { mp, what, extra ->
                    Log.e(TAG, "System MediaPlayer error: what=$what, extra=$extra")
                    true
                }

                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error with MediaPlayer fallback: ${e.message}", e)
        }
    }

    private fun playAlarmSoundForId(alarmId: String) {
        try {
            Log.d(TAG, "Loading alarm config for ID: $alarmId")
            
            // Load alarm configuration from SharedPreferences
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val alarmsJson = prefs.getString("flutter.custom_alarms", null)

            var soundPath: String? = null
            var soundType: String? = null

            if (alarmsJson != null) {
                Log.d(TAG, "Found alarms JSON, parsing...")
                val alarmsArray = JSONArray(alarmsJson)
                for (i in 0 until alarmsArray.length()) {
                    val alarmObj = alarmsArray.getJSONObject(i)
                    if (alarmObj.getString("id") == alarmId) {
                        soundType = alarmObj.optString("soundId", "default")
                        soundPath = alarmObj.optString("soundPath", null)
                        Log.d(TAG, "Found alarm config: soundType=$soundType, path=$soundPath")
                        break
                    }
                }
            } else {
                Log.d(TAG, "No alarms JSON found in SharedPreferences")
            }

            playAlarmSound(soundPath, soundType)
        } catch (e: Exception) {
            Log.e(TAG, "Error loading alarm config: ${e.message}", e)
            playAlarmSound(null, null) // Fallback to default
        }
    }

    private fun stopAlarmSound() {
        try {
            Log.d(TAG, "=== STOPPING ALARM SOUND ===")
            
            // Stop MediaPlayer
            mediaPlayer?.let { mp ->
                try {
                    if (mp.isPlaying) {
                        mp.stop()
                        Log.d(TAG, "MediaPlayer stopped")
                    }
                    mp.release()
                    Log.d(TAG, "MediaPlayer released")
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping MediaPlayer: ${e.message}")
                }
            }
            mediaPlayer = null
            
            // Stop Ringtone
            ringtone?.let { rt ->
                try {
                    if (rt.isPlaying) {
                        rt.stop()
                        Log.d(TAG, "Ringtone stopped")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping Ringtone: ${e.message}")
                }
            }
            ringtone = null
            
            isAlarmPlaying = false
            stopVibration()
            
            Log.d(TAG, "Alarm fully stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error in stopAlarmSound: ${e.message}", e)
        }
    }

    private fun startVibration() {
        try {
            Log.d(TAG, "=== STARTING VIBRATION ===")
            
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val pattern = longArrayOf(0, 1000, 500) // wait 0ms, vibrate 1000ms, pause 500ms
                val effect = VibrationEffect.createWaveform(pattern, 0) // 0 = repeat from start
                vibrator?.vibrate(effect)
                Log.d(TAG, "Vibration started (API 26+, pattern repeating)")
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(longArrayOf(0, 1000, 500), 0)
                Log.d(TAG, "Vibration started (legacy, pattern repeating)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting vibration: ${e.message}", e)
        }
    }

    private fun stopVibration() {
        try {
            Log.d(TAG, "=== STOPPING VIBRATION ===")
            vibrator?.cancel()
            vibrator = null
            Log.d(TAG, "Vibration cancelled and cleared")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping vibration: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "MainActivity destroying")
        stopAlarmSound()
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        super.onDestroy()
    }

    override fun onPause() {
        Log.d(TAG, "MainActivity paused (alarm continues playing)")
        super.onPause()
        // DO NOT stop alarm when app pauses!
    }
    
    override fun onResume() {
        Log.d(TAG, "MainActivity resumed")
        super.onResume()
    }
}