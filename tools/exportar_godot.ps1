# Executa um export do Godot com watchdog.
#
# O Godot 4.7.2 no Windows conclui o export headless mas pode continuar vivo
# depois do marcador "[ DONE ] export". Este helper espera o marcador, encerra
# o editor e confere se o artefato foi gerado. Sem isso, o build fica preso e o
# bloco finally que restaura export_presets.cfg nunca roda.
#
# Uso interno pelos scripts build_android_aab.ps1 e build_msix.ps1.

function Invoke-GodotExport {
    param(
        [Parameter(Mandatory = $true)][string]$Godot,
        [Parameter(Mandatory = $true)][string]$Raiz,
        [Parameter(Mandatory = $true)][string]$Preset,
        [Parameter(Mandatory = $true)][string]$Destino,
        [int]$TimeoutMin = 30
    )

    $marca = "postinho-export-" + [guid]::NewGuid().ToString("N")
    $stdout = Join-Path $env:TEMP "$marca.out.log"
    $stderr = Join-Path $env:TEMP "$marca.err.log"
    $argumentos = "--headless --path `"$Raiz`" --export-release `"$Preset`" `"$Destino`""

    Write-Host "Godot: exportando '$Preset'..."
    $processo = Start-Process -FilePath $Godot -ArgumentList $argumentos -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $limite = (Get-Date).AddMinutes($TimeoutMin)
    $marcador = $false

    while ((Get-Date) -lt $limite) {
        if ($processo.HasExited) { break }
        if (Test-Path $stdout) {
            try {
                if (Select-String -Path $stdout -Pattern '\[ DONE \].*export' -Quiet -ErrorAction Stop) {
                    $marcador = $true
                    break
                }
            } catch {
                # O arquivo pode estar em escrita; tenta de novo no proximo ciclo.
            }
        }
        Start-Sleep -Milliseconds 500
    }

    if (-not $processo.HasExited) {
        & taskkill.exe /PID $processo.Id /T /F 2>&1 | Out-Null
        Start-Sleep -Seconds 2
    }

    if (-not (Test-Path $Destino)) {
        $saida = if (Test-Path $stdout) { (Get-Content $stdout -Tail 25) -join "`n" } else { "" }
        $erro = if (Test-Path $stderr) { (Get-Content $stderr -Tail 25) -join "`n" } else { "" }
        throw "Export nao gerou '$Destino'.`nSTDOUT:`n$saida`nSTDERR:`n$erro"
    }
    if ((Get-Item $Destino).Length -le 0) {
        throw "Export gerou arquivo vazio: $Destino"
    }
    if (-not $marcador) {
        Write-Host "Aviso: marcador de export nao visto; o artefato existe e sera validado."
    }
    Write-Host "Godot: export concluido -> $Destino"
}
