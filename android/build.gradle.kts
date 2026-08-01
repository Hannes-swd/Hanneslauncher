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
// Some plugin modules still declare an older compileSdk than the AndroidX
// libraries they pull in demand, which fails the release build on their
// metadata check. Raising it here keeps that out of every single plugin.
// Registered before the evaluation below, which is the last point where a
// callback can still be added.
subprojects {
    afterEvaluate {
        val android = extensions.findByType(
            com.android.build.api.dsl.LibraryExtension::class.java,
        )
        if (android != null && (android.compileSdk ?: 0) < 36) {
            android.compileSdk = 36
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
