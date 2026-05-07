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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    group = "build"
    description = "Deletes the build directory."
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    plugins.withId("java") {
        extensions.configure<JavaPluginExtension> {
            toolchain {
                languageVersion.set(JavaLanguageVersion.of(17))
            }
        }
    }
}

// Workaround: AGP 8.x requires a namespace in every library module, and
// some packages (e.g. flutter_jailbreak_detection) also mix Java 1.8 with
// Kotlin 17 causing an "Inconsistent JVM-target" error.
// gradle.afterProject fires immediately after each project is evaluated.
gradle.afterProject {
    if (plugins.hasPlugin("com.android.library")) {
        val android = extensions.findByName("android")
            as? com.android.build.gradle.LibraryExtension ?: return@afterProject
        // Fix missing namespace
        if (android.namespace == null) {
            android.namespace = group.toString()
        }
        // Align Java compile target with the Kotlin toolchain (both → 17)
        android.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }
}