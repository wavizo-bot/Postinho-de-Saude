# Prepara o projeto Gradle do Android com R8 e regras proprias.
#
# Uso:
#   .\tools\preparar_android.ps1
#
# O Godot recria android/build a partir do template instalado quando a pasta
# nao existe. Este script garante a base e sobrescreve apenas os arquivos de
# build que precisam ser reproduziveis no repositorio.

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
$destino = Join-Path $raiz "android\build"
$custom = Join-Path $PSScriptRoot "android"

if (-not (Test-Path (Join-Path $destino "build.gradle"))) {
    $zip = Get-ChildItem "$env:APPDATA\Godot\export_templates" -Recurse -File -Filter "android_source.zip" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $zip) {
        throw "Template Android do Godot nao encontrado. No editor: Projeto > Instalar Modelo de Compilacao Android."
    }
    Write-Host "Extraindo template Android: $($zip.FullName)"
    New-Item -ItemType Directory -Force -Path $destino | Out-Null
    python -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" $zip.FullName $destino
    if ($LASTEXITCODE -ne 0) { throw "Falha ao extrair o template Android." }
}

Copy-Item (Join-Path $custom "build.gradle") (Join-Path $destino "build.gradle") -Force
Copy-Item (Join-Path $custom "gradle.properties") (Join-Path $destino "gradle.properties") -Force
Copy-Item (Join-Path $custom "proguard-rules.pro") (Join-Path $destino "proguard-rules.pro") -Force

# AGP 8.6.x nao grava o r8.json que a Google Play usa para o relatorio de
# otimizacao DEX. AGP 8.10+ grava, e o Gradle 8.11.1 do template atende ao
# requisito minimo. Fixamos a versao para o build ser reproduzivel.
$configGradle = Join-Path $destino "config.gradle"
$configTexto = [IO.File]::ReadAllText($configGradle)
$configNovo = [regex]::Replace($configTexto, "androidGradlePlugin:\s*'[^']+'", "androidGradlePlugin: '8.10.1'")
if ($configNovo -notmatch "androidGradlePlugin:\s*'8\.10\.1'") {
    throw "Nao foi possivel fixar o Android Gradle Plugin 8.10.1 em config.gradle."
}
if ($configNovo -ne $configTexto) {
    [IO.File]::WriteAllText($configGradle, $configNovo, (New-Object System.Text.UTF8Encoding($false)))
}

$texto = [IO.File]::ReadAllText((Join-Path $destino "build.gradle"))
if ($texto -notmatch "minifyEnabled true" -or $texto -notmatch "shrinkResources true") {
    throw "build.gradle sem R8/minify. A copia do tools/android falhou."
}
$props = [IO.File]::ReadAllText((Join-Path $destino "gradle.properties"))
if ($props -notmatch "android.enableR8.fullMode=true") {
    throw "gradle.properties sem R8 full mode."
}
Write-Host "Android preparado: R8 full mode, minify e shrinkResources ativos."
