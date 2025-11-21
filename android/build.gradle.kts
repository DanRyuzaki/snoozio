allprojects {
    repositories {
        google()
        mavenCentral()
    }
    gradle.projectsEvaluated {
        tasks.withType(JavaCompile::class) {
            options.compilerArgs.add("-Xlint:-deprecation")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)
subprojects {
    afterEvaluate {
        // Disable lint for all dependencies
        tasks.findByName("lint")?.enabled = false
        tasks.findByName("lintDebug")?.enabled = false
        tasks.findByName("lintRelease")?.enabled = false
        tasks.findByName("lintAnalyzeDebug")?.enabled = false
    }
}
subprojects {
    afterEvaluate {
        tasks.configureEach {
            if (name.contains("Lint")) {
                enabled = false
            }
        }
    }
}
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    configurations.all {
        resolutionStrategy {
            force("com.google.android.play:core:1.10.3")
            force("com.google.android.play:core-common:2.0.3")
        }
    }
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
