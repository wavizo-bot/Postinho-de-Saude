# Gera o MSIX a partir do build Windows, com versao carimbada e certificado
# de teste fora do repositorio.
#
# Uso (PowerShell, na raiz do projeto):
#   .\tools\build_msix.ps1
#   .\tools\build_msix.ps1 -SemExportar   # reaproveita build\windows
#
# Requisitos:
#   - Godot 4.7.2 (export Windows)
#   - Windows SDK com makeappx.exe e signtool.exe
#   - Segredos em C:\APPS\ID.OAuth\postinho\segredos.json (fora do repositorio)
#
# O .pfx nunca vai para o repositorio. O .cer publico pode ser distribuido para
# o usuario confiar no certificado de teste do sideload.

param([switch]$SemExportar)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "segredos.ps1")
. (Join-Path $PSScriptRoot "exportar_godot.ps1")

$raiz = Split-Path -Parent $PSScriptRoot
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "C:\Users\Maycon\tools\godot\Godot_v4.7.2-stable_win64_console.exe" }
$origem = Join-Path $raiz "build\windows"
$saida = Join-Path $raiz "build\msix"
$staging = Join-Path $raiz "build\msix-staging"
$desempacotado = Join-Path $raiz "build\msix-unpacked"
$entrega = Join-Path $raiz "build\entrega"
$nome = "PostinhoDeSaude"
$pub = "CN=Postinho de Saude"

& (Join-Path $PSScriptRoot "stamp_version.ps1")
$versao = Get-VersaoPostinho
$segredos = Get-SegredosPostinho
$versaoMsix = [string]$versao.windows

function Get-SdkTool([string]$nome) {
    $cmd = Get-Command $nome -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $kits = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    foreach ($k in $kits) {
        $c = Join-Path $k.FullName "x64\$nome"
        if (Test-Path $c) { return $c }
    }
    return $null
}

Write-Host "Limpando staging..."
Remove-Item -Recurse -Force $staging, $desempacotado -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $staging, $saida, $entrega | Out-Null

if (-not $SemExportar) {
    Write-Host "Exportando Windows $($versao.versao)..."
    Invoke-GodotExport -Godot $godot -Raiz $raiz -Preset "Windows Desktop" -Destino (Join-Path $origem "$nome.exe")
}
if (-not (Test-Path (Join-Path $origem "$nome.exe"))) {
    throw "Build Windows nao encontrado. Rode o export do Godot primeiro."
}

Write-Host "Copiando executavel e assets..."
Copy-Item (Join-Path $origem "$nome.exe") $staging
Copy-Item (Join-Path $origem "$nome.pck") $staging
New-Item -ItemType Directory -Force -Path (Join-Path $staging "Assets") | Out-Null
# Apenas os PNGs de logo; sidecars .import do Godot nao pertencem ao pacote.
Get-ChildItem (Join-Path $PSScriptRoot "msix\Assets") -File -Filter "*.png" |
    Copy-Item -Destination (Join-Path $staging "Assets") -Force

$manifesto = @"
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
         IgnorableNamespaces="uap rescap">
  <Identity Name="Postinho.PostinhoDeSaude" Publisher="$pub" Version="$versaoMsix" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>Postinho de Saude</DisplayName>
    <PublisherDisplayName>wavizo</PublisherDisplayName>
    <Description>Jogo independente sobre a rotina de um Agente Comunitario de Saude</Description>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.26100.0" />
  </Dependencies>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
  </Capabilities>
  <Resources>
    <Resource Language="pt-BR" />
  </Resources>
  <Applications>
    <Application Id="App" Executable="$nome.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="Postinho de Saude" Description="A rotina do ACS virou jogo"
        BackgroundColor="#1b1e24" Square150x150Logo="Assets\Square150x150Logo.png"
        Square44x44Logo="Assets\Square44x44Logo.png" />
    </Application>
  </Applications>
</Package>
"@
[IO.File]::WriteAllText((Join-Path $staging "AppxManifest.xml"), $manifesto, (New-Object System.Text.UTF8Encoding($false)))

# Certificado publico para o usuario confiar no sideload. O .pfx fica fora do repo.
$pfx = [string]$segredos.msix_pfx
$senha = [string]$segredos.msix_password
if (-not (Test-Path $pfx)) { throw "Certificado MSIX ausente: $pfx" }
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pfx, $senha)
$cer = Join-Path $saida "PostinhoDeSaude-teste.cer"
[IO.File]::WriteAllBytes($cer, $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))

Write-Host "Empacotando MSIX..."
$msix = Join-Path $saida ("{0}_{1}_x64.msix" -f $nome, $versaoMsix)
$makeappx = Get-SdkTool "makeappx.exe"
if (-not $makeappx) {
    Compress-Archive -Path (Join-Path $staging "*") -DestinationPath "$msix.zip" -Force
    Move-Item "$msix.zip" $msix -Force
} else {
    & $makeappx pack /d $staging /p $msix /o
    if ($LASTEXITCODE -ne 0) { throw "makeappx falhou." }
}

$signtool = Get-SdkTool "signtool.exe"
if ($signtool) {
    Write-Host "Assinando MSIX..."
    & $signtool sign /fd SHA256 /f $pfx /p $senha /a $msix
    if ($LASTEXITCODE -ne 0) { throw "signtool sign falhou." }
    & $signtool verify /pa /v $msix | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "signtool verify falhou." }
}

if ($makeappx) {
    & $makeappx unpack /p $msix /d $desempacotado /o | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "makeappx unpack falhou." }
    $manifestoLido = [IO.File]::ReadAllText((Join-Path $desempacotado "AppxManifest.xml"))
    if ($manifestoLido -notmatch ('Version="' + [regex]::Escape($versaoMsix) + '"')) {
        throw "Versao do MSIX desempacotado nao confere."
    }
    if (Test-Path (Join-Path $desempacotado "*.WebView2")) {
        throw "Pacote contem dados de perfil WebView2 (Regra W6)."
    }
}

Copy-Item $msix (Join-Path $entrega (Split-Path $msix -Leaf)) -Force
Copy-Item $cer (Join-Path $entrega (Split-Path $cer -Leaf)) -Force
$hash = (Get-FileHash $msix -Algorithm SHA256).Hash
$linhas = @(
    "Postinho de Saude - verificacao MSIX",
    "Versao: $versaoMsix",
    "Arquivo: $msix",
    "SHA256: $hash",
    "Certificado publico: $cer",
    "Instalacao local: Import-Certificate em LocalMachine\Root e TrustedPeople (admin); depois Add-AppxPackage.",
    "Observacao: a Microsoft Store reassina o pacote; este certificado serve so para sideload/teste."
)
[IO.File]::WriteAllText((Join-Path $saida "VERIFICACAO.txt"), ($linhas -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "MSIX OK: $msix"
Write-Host "SHA256: $hash"
exit 0
