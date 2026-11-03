package com.sukeesh.nosugar

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Reads text from an ingredient-label photo with on-device ML Kit OCR.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nosugar/ocr").setMethodCallHandler { call, result ->
            val path = call.arguments as? String
            if (call.method != "recognize" || path == null) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(image)
                    .addOnSuccessListener { result.success(it.text) }
                    .addOnFailureListener { result.error("ocr_failed", it.message, null) }
            } catch (e: Exception) {
                result.error("bad_image", e.message, null)
            }
        }
    }
}
