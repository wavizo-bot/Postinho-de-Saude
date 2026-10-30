# Utilitarios de build: versao carimbada e segredos fora do repositorio.
# Nunca imprima o conteudo de segredos.json nem versione o arquivo.

$ErrorActionPreference = "Stop"

function Get-SegredosPostinho {
    $caminho = if ($env:POSTINHO_SEGREDOS) { $env:POSTINHO_SEGREDOS } else { "C:\APPS\ID.OAuth\postinho\segredos.json" }
    if (-not (Test-Path $caminho)) {
        throw "Segredos de build ausentes. Crie $caminho com android_keystore, android_alias, android_store_password, android_key_password, msix_pfx e msix_password."
    }
    return Get-Content -Raw -LiteralPath $caminho | ConvertFrom-Json
}

function Get-VersaoPostinho {
    $caminho = Join-Path (Split-Path -Parent $PSScriptRoot) "version.json"
    if (-not (Test-Path $caminho)) {
        throw "version.json ausente. Rode tools\stamp_version.ps1."
    }
    return Get-Content -Raw -LiteralPath $caminho | ConvertFrom-Json
}

function Set-PresetAndroidSegredo {
    param(
        [Parameter(Mandatory = $true)][string]$Arquivo,
        [Parameter(Mandatory = $true)]$Segredos
    )
    $original = [IO.File]::ReadAllText($Arquivo)
    $texto = $original
    $ks = ($Segredos.android_keystore -replace '\\', '/')
    $alias = [string]$Segredos.android_alias
    $senha = [string]$Segredos.android_store_password
    $texto = [regex]::Replace($texto, 'keystore/release="[^"]*"', { param($m) 'keystore/release="' + $ks + '"' })
    $texto = [regex]::Replace($texto, 'keystore/release_user="[^"]*"', { param($m) 'keystore/release_user="' + $alias + '"' })
    $texto = [regex]::Replace($texto, 'keystore/release_password="[^"]*"', { param($m) 'keystore/release_password="' + $senha + '"' })
    [IO.File]::WriteAllText($Arquivo, $texto, (New-Object System.Text.UTF8Encoding($false)))
    return $original
}

function Restore-Arquivo {
    param([string]$Arquivo, [string]$Conteudo)
    [IO.File]::WriteAllText($Arquivo, $Conteudo, (New-Object System.Text.UTF8Encoding($false)))
}
