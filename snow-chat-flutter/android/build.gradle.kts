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
// record 4.4.4 等老插件的 build.gradle 里没写 namespace，这里统一补。
//
// ⚠️ 时机必须是「插件被 apply 的那一刻」：用 beforeProject + pluginManager.withPlugin
// 注册回调，回调在子项目执行 `apply plugin: 'com.android.library'` 时同步触发，
// 早于 AGP 创建 variant。
// ⚠️ 不能改用 gradle.projectsLoaded：那个时机子项目的 build.gradle 还没执行，
// hasPlugin 恒为 false，一个 namespace 都补不上（pub 缓存一刷新就打不出包）。
fun Project.injectAndroidNamespaceIfMissing() {
    // 通过 extensions 访问 Android DSL（Kotlin DSL 中不能用 project.android）
    val androidExt: com.android.build.gradle.BaseExtension? =
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?: extensions.findByType(com.android.build.gradle.AppExtension::class.java)
    if (androidExt == null || androidExt.namespace != null) return

    // 优先用 AndroidManifest.xml 的 package；其次 applicationId；最后 group
    val manifestFile = androidExt.sourceSets.getByName("main").manifest.srcFile
    val fromManifest = if (manifestFile.exists()) {
        Regex("""package="([^"]+)""").find(manifestFile.readText())?.groupValues?.get(1)
    } else {
        null
    }
    androidExt.namespace = fromManifest
        ?.takeIf { it.isNotEmpty() }
        ?: androidExt.defaultConfig.applicationId?.takeIf { it.isNotEmpty() }
        ?: group.toString()
}

gradle.beforeProject {
    pluginManager.withPlugin("com.android.library") { injectAndroidNamespaceIfMissing() }
    pluginManager.withPlugin("com.android.application") { injectAndroidNamespaceIfMissing() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
