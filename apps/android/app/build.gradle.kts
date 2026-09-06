plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "dev.varn.gui.gallery"
    compileSdk = 35

    defaultConfig {
        applicationId = "dev.varn.gui.gallery"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    // The renderer is shared with the library a consuming app would depend on, so it is compiled from source here.
    sourceSets["main"].kotlin.srcDir("../../../renderers/android/src/main/kotlin")

    // The archive is built by: python3 run.py sample
    sourceSets["main"].assets.srcDir("../../../sample/dist")

    // The conformance suite lives beside the renderer it exercises, and runs on the JVM.
    sourceSets["test"].kotlin.srcDir("../../../renderers/android/src/test/kotlin")

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // The released aar, fetched with: python3 run.py fetch-native
    implementation(files("libs/varn.aar"))

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
}
