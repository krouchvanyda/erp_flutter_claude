allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// stream_webrtc_flutter 1.0.13 (pulled in by stream_video_flutter 0.9.6)
// compiles against android-31, which AGP 8.13's AAR-metadata check rejects
// (androidx deps need compileSdk >= 34). Raising its compileSdk is
// compile-time only — minSdk / targetSdk (runtime behaviour) are untouched.
// Remove once stream_video_flutter is upgraded (stream_webrtc_flutter >= 2.0
// already uses 36). Must be registered BEFORE evaluationDependsOn below.
subprojects {
    if (name == "stream_webrtc_flutter") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                ?.compileSdk = 36
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

plugins {
    // ...

    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services") version "4.4.4" apply false

}