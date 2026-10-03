import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // Flutter Gradle Plugin must be applied after Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Read dart-defines passed by Flutter (base64-encoded, comma-separated).
// ---------------------------------------------------------------------------
val dartDefines: Map<String, String> by lazy {
    val raw = project.findProperty("dart-defines") as? String ?: return@lazy emptyMap()
    raw.split(",")
        .mapNotNull { encoded ->
            runCatching {
                val decoded = String(Base64.getDecoder().decode(encoded))
                val eq = decoded.indexOf('=')
                if (eq > 0) decoded.substring(0, eq) to decoded.substring(eq + 1) else null
            }.getOrNull()
        }
        .toMap()
}

// ---------------------------------------------------------------------------
// Read key.properties for release signing (file is gitignored; CI injects it).
// ---------------------------------------------------------------------------
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.therapylink.therapylink"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.therapylink.therapylink"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias     = keyProps.getProperty("keyAlias",     "")
            keyPassword  = keyProps.getProperty("keyPassword",  "")
            storeFile    = keyProps.getProperty("storeFile", "")
                .takeIf { it.isNotBlank() }?.let { file(it) }
            storePassword = keyProps.getProperty("storePassword", "")
        }
    }

    buildTypes {
        debug {
            // debuggable defaults to true; no signing override needed.
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false   // ProGuard/R8 deferred to hardening phase.
            isShrinkResources = false
        }
    }
}

// ---------------------------------------------------------------------------
// Release URL guard: fail the build if TL_API_URL is absent, HTTP, or looks
// like a local/placeholder address. Mirrors the Dart-side guard in main.dart.
// ---------------------------------------------------------------------------
tasks.configureEach {
    if (name.startsWith("assemble") && name.contains("Release")) {
        doFirst {
            val apiUrl = dartDefines["TL_API_URL"] ?: ""
            check(apiUrl.isNotBlank()) {
                "TL_API_URL dart-define is missing. " +
                "Build with --dart-define=TL_API_URL=https://your-api.example."
            }
            val badPatterns = listOf("http://", "localhost", "127.0.0.1", "0.0.0.0",
                "placeholder", "example.com", "trycloudflare.com")
            val hit = badPatterns.firstOrNull { apiUrl.contains(it, ignoreCase = true) }
            check(hit == null) {
                "TL_API_URL '$apiUrl' looks wrong (matched '$hit'). " +
                "Set a real production HTTPS URL before signing a release build."
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
