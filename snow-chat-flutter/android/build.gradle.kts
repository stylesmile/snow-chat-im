allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 8+ 强制要求所有 Android 库模块声明 namespace。
// record 4.4.4 等第三方库未配置 namespace，在 projectsLoaded 阶段统一注入，
// 确保所有子项目已被 gradle 发现但尚未 evaluation，可以安全修改。
gradle.projectsLoaded {
    allprojects.forEach { proj ->
        if (proj.plugins.hasPlugin("com.android.library") ||
            proj.plugins.hasPlugin("com.android.application")) {
            // 通过 extensions 访问 Android DSL（Kotlin DSL 中不能用 project.android）
            val androidExt = proj.extensions.findByType(
                com.android.build.gradle.LibraryExtension::class.java
            ) ?: proj.extensions.findByType(
                com.android.build.gradle.AppExtension::class.java
            )
            if (androidExt != null && androidExt.namespace == null) {
                // 优先使用已有 namespace；其次用 applicationId；最后从 AndroidManifest.xml 提取 package
                val manifestFile = androidExt.sourceSets
                    .getByName("main")
                    .manifest
                    .srcFile
                if (manifestFile.exists()) {
                    val manifestText = manifestFile.readText()
                    val pkgMatch = Regex("""package="([^"]+)""", setOf(RegexOption.MULTILINE))
                        .find(manifestText)
                    val ns: String = androidExt.namespace
                        ?: androidExt.defaultConfig.applicationId
                        ?: pkgMatch?.groups?.get(1)?.value
                        ?: proj.group.toString()
                    androidExt.namespace = ns
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
