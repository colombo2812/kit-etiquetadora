# Mapeia as etiquetadoras de impressoras.txt para o usuário que acabou de logar.
# Disparado pela tarefa agendada "Mapear Etiquetadora" em todo logon.
$ConfigFile    = Join-Path $PSScriptRoot "impressoras.txt"
$MaxTentativas = 20      # 20 x 30 s = até 10 minutos esperando rede / máquina da etiquetadora
$EsperaSeg     = 30
$LogFile       = Join-Path $env:LOCALAPPDATA "map-etiquetadora.log"

function Write-Log($msg) {
    try { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  [$env:USERNAME]  $msg" | Out-File $LogFile -Append -Encoding utf8 } catch {}
}

# Testa a porta 445 (compartilhamento de arquivos e impressoras). Não depende de ping,
# que costuma estar bloqueado no firewall de estações de trabalho.
function Test-Servidor($servidor) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $tcp.BeginConnect($servidor, 445, $null, $null)
        return ($ar.AsyncWaitHandle.WaitOne(3000) -and $tcp.Connected)
    } catch { return $false }
    finally { $tcp.Close() }
}

function Get-Servidor($caminho) { ($caminho.TrimStart('\') -split '\\')[0] }

try {
    if (-not (Test-Path $ConfigFile)) { Write-Log "impressoras.txt não encontrado em $ConfigFile."; exit 0 }

    $pendentes = @(Get-Content $ConfigFile -Encoding UTF8 |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') })

    # Na própria máquina onde a etiquetadora está no USB não se mapeia ela mesma.
    $pendentes = @($pendentes | Where-Object {
        if ((Get-Servidor $_) -ieq $env:COMPUTERNAME) { Write-Log "Ignorada (etiquetadora local desta máquina): $_"; $false } else { $true }
    })

    Write-Log "Início do logon. Impressoras a verificar: $($pendentes.Count)"

    for ($i = 1; $i -le $MaxTentativas -and $pendentes.Count -gt 0; $i++) {
        $mapeadas = @(Get-Printer -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
        $falharam = @()

        foreach ($caminho in $pendentes) {
            if ($mapeadas -icontains $caminho) { Write-Log "Já mapeada: $caminho"; continue }

            $servidor = Get-Servidor $caminho
            if (-not (Test-Servidor $servidor)) {
                Write-Log "Tentativa $i/${MaxTentativas}: $servidor inacessível (ligada? na rede?)."
                $falharam += $caminho
                continue
            }

            try {
                Add-Printer -ConnectionName $caminho -ErrorAction Stop
                Write-Log "Mapeada com sucesso: $caminho"
            } catch {
                Write-Log "Tentativa $i/${MaxTentativas}: erro em $caminho : $($_.Exception.Message)"
                $falharam += $caminho
            }
        }

        $pendentes = $falharam
        if ($pendentes.Count -gt 0 -and $i -lt $MaxTentativas) { Start-Sleep -Seconds $EsperaSeg }
    }

    foreach ($c in $pendentes) { Write-Log "Não mapeou agora: $c. Tenta de novo no próximo logon." }
}
catch { Write-Log "Erro geral: $($_.Exception.Message)" }
exit 0
