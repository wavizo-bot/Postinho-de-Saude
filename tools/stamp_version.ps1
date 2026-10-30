# Carimba a versao do build em version.json e confere as fontes.
#
# Uso:
#   .\tools\stamp_version.ps1
#
# Fontes da verdade:
#   project.godot   -> application/config/version (exibicao)
#   export_presets.cfg -> Android version/name e version/code
#   version.json    -> pacote Windows (quatro campos) e Android
#
# O script nao inventa versao: se as fontes divergirem, ele falha e mostra o
# que corrigir. Assim o numero exibido no app nunca fica diferente do pacote.

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
$projeto = [IO.File]::ReadAllText((Join-Path $raiz "project.godot"))
$presets = [IO.File]::ReadAllText((Join-Path $raiz "export_presets.cfg"))

$m = [regex]::Match($projeto, 'config/version="([^"]+)"')
if (-not $m.Success) { throw "config/version ausente em project.godot." }
$config = $m.Groups[1].Value

$mNome = [regex]::Match($presets, 'version/name="([^"]+)"')
$mCodigo = [regex]::Match($presets, 'version/code=(\d+)')
$mTarget = [regex]::Match($presets, 'gradle_build/target_sdk="(\d+)"')
if (-not $mNome.Success -or -not $mCodigo.Success) {
    throw "version/name ou version/code ausente em export_presets.cfg."
}
$androidNome = $mNome.Groups[1].Value
$androidCodigo = [int]$mCodigo.Groups[1].Value
$target = if ($mTarget.Success) { [int]$mTarget.Groups[1].Value } else { 0 }

if ($config -ne $androidNome) {
    throw "Versao divergente: project.godot=$config, Android=$androidNome. Iguale antes de buildar."
}
if ($target -lt 35) {
    throw "targetSdk $target abaixo de 35 (Regra A7). Ajuste export_presets.cfg."
}

$partes = $config.Split(".")
if ($partes.Count -eq 3) {
    $windows = "$config.0"
} elseif ($partes.Count -eq 4) {
    $windows = $config
} else {
    throw "Versao '$config' nao tem 3 ou 4 campos."
}

$dados = [ordered]@{
    versao = $config
    codigo = $androidCodigo
    windows = $windows
    android = $androidNome
    canal = "release"
}
$json = $dados | ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $raiz "version.json"), $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Versao carimbada: app=$config Android=$androidNome ($androidCodigo) Windows=$windows targetSdk=$target"
