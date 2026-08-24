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
    // AGP 8+ 强制要求所有 Android 库模块声明 namespace。
    // record 4.4.4 等第三方库未配置，此处自动从 AndroidManifest.xml 的 package 属性注入，
    // 避免 "Namespace not specified" 构建失败。
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library") ||
            project.plugins.hasPlugin("com.android.application")) {
            val ns = project.android.namespace
                ?: project.android.defaultConfig.applicationId
                ?: runCatching {
                    project.android.sourceSets
                        .getByName("main")
                        .manifest
                        .srcFile
                        .readText()
                        .toRegex("""package="([^"]+)""")
                        .findAll()
                        .firstOrNull()
                        ?.groupValues
                        ?.get(1)
                }.getOrNull()
                ?: project.group.toString()
            project.android.namespace = ns
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
