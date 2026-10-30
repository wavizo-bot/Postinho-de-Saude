# Regras minimas de R8 para o runtime do Godot.
# O R8 full mode e as otimizacoes ficam em tools/android/gradle.properties.
# Objetivo: nao quebrar chamadas JNI/reflexao do motor e ainda remover o que
# o jogo nao usa.

-keepattributes SourceFile,LineNumberTable

# O motor chama classes Java por JNI e por reflexao.
-keep class org.godotengine.godot.** { *; }
-keep class org.godotengine.plugin.** { *; }

# Activity/host gerados pelo template e nosso pacote.
-keep class com.godot.game.** { *; }

# Metodos nativos e anotados para uso pelo GDScript.
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepclassmembers class * {
    @org.godotengine.godot.plugin.UsedByGodot <methods>;
}

# Nao falhar por dependencias opcionais que o Godot referencia.
-dontwarn org.godotengine.**
-dontwarn kotlin.**
