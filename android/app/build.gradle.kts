plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "se.vouchhunter.app"
    compileSdk = 35
    defaultConfig {
        applicationId = "se.vouchhunter.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        manifestPlaceholders["MAPS_API_KEY"] = providers.environmentVariable("ANDROID_MAPS_API_KEY").getOrElse("")
    }
    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
            buildConfigField("String", "API_BASE_URL", "\"http://10.0.2.2:8787\"")
        }
        release {
            isMinifyEnabled = false
            buildConfigField("String", "API_BASE_URL", "\"" + providers.environmentVariable("VOUCHHUNTER_API_URL").getOrElse("https://configuration-required.invalid") + "\"")
        }
    }
    buildFeatures { buildConfig = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation("androidx.activity:activity-ktx:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("com.google.android.gms:play-services-maps:19.2.0")
    implementation("io.github.sceneview:arsceneview:2.3.0")
    implementation("com.google.zxing:core:3.5.3")
}
