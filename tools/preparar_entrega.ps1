# Monta a pasta build/entrega com os pacotes finais e os checksums SHA256.
# Nao copia keystore, PFX, senhas ou qualquer arquivo de segredo.
#
# Uso (PowerShell, na raiz do projeto):
#   .\tools\preparar_entrega.ps1

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
$versao = Get-Content (Join-Path $raiz "version.json") -Raw | ConvertFrom-Json

$origemAab = Join-Path $raiz "build\android\PostinhoDeSaude.aab"
$origemApk = Join-Path $raiz ("build\android\PostinhoDeSaude-{0}.apk" -f $versao.versao)
$origemMsix = Join-Path $raiz ("build\msix\PostinhoDeSaude_{0}_x64.msix" -f $versao.windows)
$origemCer = Join-Path $raiz "build\msix\PostinhoDeSaude-teste.cer"

foreach ($origem in @($origemAab, $origemApk, $origemMsix, $origemCer)) {
    if (-not (Test-Path $origem)) { throw "Artefato ausente: $origem" }
}

$entrega = Join-Path $raiz "build\entrega"
Remove-Item -Recurse -Force $entrega -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $entrega | Out-Null

$itens = @(
    @{ Origem = $origemAab;  Nome = ("PostinhoDeSaude-{0}.aab" -f $versao.versao) },
    @{ Origem = $origemApk;  Nome = ("PostinhoDeSaude-{0}-universal.apk" -f $versao.versao) },
    @{ Origem = $origemMsix; Nome = ("PostinhoDeSaude-{0}-x64.msix" -f $versao.windows) },
    @{ Origem = $origemCer;  Nome = "PostinhoDeSaude-teste.cer" }
)

$linhas = New-Object System.Collections.Generic.List[string]
foreach ($item in $itens) {
    $destino = Join-Path $entrega $item.Nome
    Copy-Item $item.Origem $destino -Force
    $hash = (Get-FileHash $destino -Algorithm SHA256).Hash
    $linhas.Add(("{0}  {1}" -f $hash, $item.Nome))
    Write-Host ("{0}  {1}  {2} bytes" -f $hash, $item.Nome, (Get-Item $destino).Length)
}

[IO.File]::WriteAllText(
    (Join-Path $entrega "SHA256SUMS.txt"),
    (($linhas -join "`r`n") + "`r`n"),
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host ""
Write-Host "Entrega pronta: $entrega"
exit 0
