package com.example.location_reminder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import androidx.work.Configuration
import androidx.work.WorkManager

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize WorkManager manually
        try {
            val config = Configuration.Builder()
                .setMinimumLoggingLevel(android.util.Log.INFO)
                .build()
            
            WorkManager.initialize(applicationContext, config)
            android.util.Log.d("MainActivity", "✅ WorkManager initialized successfully")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ WorkManager initialization failed: ${e.message}")
        }
    }
}
