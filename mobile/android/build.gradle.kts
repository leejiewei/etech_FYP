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
    // Only redirect a subproject's build directory when it lives on the same
    // filesystem root as the new build directory. Flutter plugins are unpacked
    // into the pub cache on C:, while this project is on D:, and AGP's
    // generate*UnitTestConfig tasks relativize projectDir against buildDir --
    // which Windows cannot do across drives ("different roots"). That fails at
    // task-creation time, so Android Studio sync dies with "Multiple build
    // operations failed" even though `flutter build apk` works, because a
    // release assemble never creates the unit-test tasks.
    if (project.projectDir.toPath().root == newBuildDir.asFile.toPath().root) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
