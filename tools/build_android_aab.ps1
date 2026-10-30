# Exporta o Android no formato AAB (Google Play) com R8, assinatura de release
# e verificacao do artefato final. Gera tambem o APK universal para teste.
#
# Uso (PowerShell, na raiz do projeto):
#   .\tools\build_android_aab.ps1
#
# Requisitos:
#   - Godot 4.7.2 com template Android instalado
#   - JDK 17, Android SDK (build-tools/platform 36) e bundletool
#   - Segredos em C:\APPS\ID.OAuth\postinho\segredos.json (fora do repositorio)
#
# NUNCA coloque senha ou keystore neste arquivo/repositorio.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "segredos.ps1")

$raiz = Split-Path -Parent $PSScriptRoot
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "C:\Users\Maycon\tools\godot\Godot_v4.7.2-stable_win64_console.exe" }
$javaBin = if ($env:JAVA_BIN) { $env:JAVA_BIN } else { "C:\Users\Maycon\tools\jdk17\jdk-17.0.20.1+1\bin" }
$sdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { "C:\Users\Maycon\AppData\Local\Android\Sdk" }
$saida = Join-Path $raiz "build\android"
$universalDir = Join-Path $saida "universal"
$preset = Join-Path $raiz "export_presets.cfg"

New-Item -ItemType Directory -Force -Path $saida, $universalDir | Out-Null

& (Join-Path $PSScriptRoot "stamp_version.ps1")
& (Join-Path $PSScriptRoot "preparar_android.ps1")
$versao = Get-VersaoPostinho
$segredos = Get-SegredosPostinho

$bundletool = if ($env:BUNDLETOOL_JAR) { $env:BUNDLETOOL_JAR } else {
    Get-ChildItem "$env:TEMP\opencode" -Filter "bundletool-all-*.jar" -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $bundletool) { throw "bundletool-all-*.jar nao encontrado. Defina BUNDLETOOL_JAR." }

function Get-BuildTool([string]$nome) {
    $pasta = Get-ChildItem (Join-Path $sdk "build-tools") -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $pasta) { return $null }
    return Join-Path $pasta.FullName $nome
}

$aab = Join-Path $saida "PostinhoDeSaude.aab"
$apks = Join-Path $saida "PostinhoDeSaude.apks"
$apk = Join-Path $universalDir "universal.apk"
$apkRelease = Join-Path $saida ("PostinhoDeSaude-{0}.apk" -f $versao.versao)
$dumpManifest = Join-Path $saida "manifest-dump.xml"
$dumpBadging = Join-Path $saida "badging.txt"
$relatorio = Join-Path $saida "VERIFICACAO.txt"
$sha = Join-Path $saida "SHA256.txt"

$original = Set-PresetAndroidSegredo -Arquivo $preset -Segredos $segredos
try {
    Write-Host "Exportando AAB $($versao.versao) com R8..."
    & $godot --headless --path $raiz --export-release "Android AAB" $aab
    if ($LASTEXITCODE -ne 0) { throw "Falha na exportacao do AAB." }
} finally {
    Restore-Arquivo -Arquivo $preset -Conteudo $original
}
if (-not (Test-Path $aab)) { throw "AAB nao foi gerado." }

Write-Host "Conferindo R8/mapping/DEX..."
$saidaPython = & python (Join-Path $PSScriptRoot "verificar_aab.py") $aab 2>&1
$textoPython = $saidaPython | Out-String
Write-Host $textoPython.Trim()
if ($LASTEXITCODE -ne 0) { throw "Verificacao do AAB falhou.`n$textoPython" }

Write-Host "Conferindo manifesto e assinatura..."
$manifesto = & "$javaBin\java.exe" -jar $bundletool dump manifest --bundle=$aab 2>&1 | Out-String
[IO.File]::WriteAllText($dumpManifest, $manifesto, (New-Object System.Text.UTF8Encoding($false)))
if ($manifesto -notmatch ('android:versionCode="' + $versao.codigo + '"')) { throw "versionCode do AAB nao confere." }
if ($manifesto -notmatch ('android:versionName="' + [regex]::Escape($versao.android) + '"')) { throw "versionName do AAB nao confere." }
if ($manifesto -notmatch 'android:targetSdkVersion="(\d+)"') { throw "targetSdkVersion ausente no AAB." }
$target = [int]$Matches[1]
if ($target -lt 35) { throw "targetSdk $target abaixo de 35 (Regra A7)." }
if ($manifesto -match 'com.google.android.gms.permission.AD_ID') { throw "Permissao AD_ID presente; remover (Regra A11)." }
if ($manifesto -match 'android:debuggable="true"') { throw "AAB de release com debuggable=true." }

$jarsigner = & "$javaBin\jarsigner.exe" -verify -verbose -certs $aab 2>&1 | Out-String
[IO.File]::WriteAllText((Join-Path $saida "jarsigner.txt"), $jarsigner, (New-Object System.Text.UTF8Encoding($false)))
if ($jarsigner -notmatch 'jar verified') { throw "AAB nao passou na verificacao do jarsigner." }

Write-Host "Gerando APK universal assinado..."
if (Test-Path $apks) { Remove-Item $apks -Force }
& "$javaBin\java.exe" -jar $bundletool build-apks --bundle=$aab --output=$apks --mode=universal `
    --ks=$($segredos.android_keystore) --ks-key-alias=$($segredos.android_alias) `
    --ks-pass="pass:$($segredos.android_store_password)" --key-pass="pass:$($segredos.android_key_password)" --overwrite
if ($LASTEXITCODE -ne 0) { throw "bundletool build-apks falhou." }
python -c "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); open(sys.argv[2],'wb').write(z.read('universal.apk'))" $apks $apk
if ($LASTEXITCODE -ne 0) { throw "Falha ao extrair universal.apk." }
Copy-Item $apk $apkRelease -Force

$apksigner = Get-BuildTool "apksigner.bat"
if ($apksigner) {
    $ass = & $apksigner verify --verbose --print-certs $apk 2>&1 | Out-String
    [IO.File]::WriteAllText((Join-Path $saida "apksigner.txt"), $ass, (New-Object System.Text.UTF8Encoding($false)))
    if ($ass -notmatch 'Verified using v2 scheme.*true' -and $ass -notmatch 'Verified using v3 scheme.*true') {
        throw "APK universal sem assinatura v2/v3 verificada."
    }
}

$aapt2 = Get-BuildTool "aapt2.exe"
if ($aapt2) {
    $badging = & $aapt2 dump badging $apk 2>&1 | Out-String
    [IO.File]::WriteAllText($dumpBadging, $badging, (New-Object System.Text.UTF8Encoding($false)))
}

$hashAab = (Get-FileHash $aab -Algorithm SHA256).Hash
$hashApk = (Get-FileHash $apk -Algorithm SHA256).Hash
$hashApks = (Get-FileHash $apks -Algorithm SHA256).Hash
$linhas = @(
    "Postinho de Saude - verificacao Android",
    "Versao: $($versao.versao) | versionCode: $($versao.codigo) | targetSdk: $target",
    "AAB: $aab",
    "AAB SHA256: $hashAab",
    "APK universal: $apk",
    "APK SHA256: $hashApk",
    "APKS: $apks",
    "APKS SHA256: $hashApks",
    "",
    $textoPython.Trim(),
    "",
    "jarsigner: jar verified",
    "manifesto: $dumpManifest",
    "badging: $dumpBadging"
)
[IO.File]::WriteAllText($relatorio, ($linhas -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($sha, ("{0}  {1}`r`n{2}  {3}`r`n{4}  {5}" -f $hashAab, $aab, $hashApk, $apk, $hashApks, $apks), (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Android OK: $aab"
Write-Host "APK universal: $apk"
Write-Host "Relatorio: $relatorio"
exit 0
