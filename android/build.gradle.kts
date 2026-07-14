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
    // Some plugins (screen_protector) leave their Kotlin jvmTarget at the
    // default while their Java target is 17, which fails the release build with
    // "Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks".
    // Pin both to 17 so every plugin module matches :app. configureEach is lazy,
    // so this must not sit in afterEvaluate — evaluationDependsOn below has
    // already evaluated the project by then.
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
        .configureEach {
            compilerOptions.jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
            )
        }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
