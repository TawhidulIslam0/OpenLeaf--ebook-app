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

// AGP 8 no longer infers these namespaces from legacy plugin manifests.
val legacyAndroidNamespaces = mapOf(
    "permission_handler_android" to "com.baseflow.permissionhandler",
    "share_plus" to "dev.fluttercommunity.plus.share",
)

subprojects {
    legacyAndroidNamespaces[name]?.let { namespace ->
        afterEvaluate {
            val androidExtension = extensions.getByName("android")
            androidExtension.javaClass
                .getMethod("setNamespace", String::class.java)
                .invoke(androidExtension, namespace)
        }
    }
}

subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            // Match the app's Java 17 bytecode target across Android plugin modules.
            val compileOptions = androidExtension.javaClass
                .getMethod("getCompileOptions")
                .invoke(androidExtension)
            val javaVersionClass = org.gradle.api.JavaVersion::class.java
            compileOptions.javaClass
                .getMethod("setSourceCompatibility", javaVersionClass)
                .invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
            compileOptions.javaClass
                .getMethod("setTargetCompatibility", javaVersionClass)
                .invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
        }
    }
}

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
        )
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
