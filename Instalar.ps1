# Instala o kit da etiquetadora nesta máquina. Precisa rodar elevado (o Instalar.bat já pede).
$Destino   = "C:\ProgramData\Script"
$Script    = Join-Path $Destino "Map-Etiquetadora.ps1"
$Tarefa    = "Mapear Etiquetadora"
$StartupAntigo = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\MapEtiquetadora.bat"
$erros     = 0

function Ok($m)    { Write-Host "[OK]    $m" -ForegroundColor Green }
function Aviso($m) { Write-Host "[AVISO] $m" -ForegroundColor Yellow }
function Falha($m) { Write-Host "[FALHA] $m" -ForegroundColor Red; $script:erros++ }

# 1. Copia os arquivos
foreach ($arq in "Map-Etiquetadora.ps1", "impressoras.txt") {
    if (-not (Test-Path "$PSScriptRoot\$arq" -PathType Leaf)) { Falha "$arq não encontrado na pasta do kit ($PSScriptRoot)." }
}
if ($erros) { exit 1 }

New-Item -ItemType Directory -Path $Destino -Force | Out-Null
Copy-Item "$PSScriptRoot\Map-Etiquetadora.ps1" $Destino -Force
Copy-Item "$PSScriptRoot\impressoras.txt"       $Destino -Force
Get-ChildItem $Destino -File | Unblock-File      # tira o bloqueio de arquivo vindo de pendrive / e-mail
if ((Test-Path $Script) -and (Test-Path "$Destino\impressoras.txt")) { Ok "Arquivos copiados para $Destino" }
else { Falha "Não foi possível copiar os arquivos para $Destino" }

# 2. Tarefa agendada: roda em todo logon, para qualquer usuário, no contexto desse usuário
try {
    # Grupo "Usuários" pelo SID, para funcionar no Windows em português (BUILTIN\Usuários)
    $grupo = (New-Object System.Security.Principal.SecurityIdentifier "S-1-5-32-545").Translate([System.Security.Principal.NTAccount]).Value

    $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Script`""
    $trigger   = New-ScheduledTaskTrigger -AtLogOn
    $trigger.Delay = "PT20S"   # espera 20 s depois do logon (rede e spooler)
    $principal = New-ScheduledTaskPrincipal -GroupId $grupo -RunLevel Limited
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -StartWhenAvailable -MultipleInstances Parallel -ExecutionTimeLimit (New-TimeSpan -Minutes 15)

    Register-ScheduledTask -TaskName $Tarefa -Action $action -Trigger $trigger -Principal $principal `
        -Settings $settings -Force -ErrorAction Stop | Out-Null
    Ok "Tarefa agendada '$Tarefa' criada (roda em todo logon, para $grupo)"
} catch { Falha "Não foi possível criar a tarefa agendada: $($_.Exception.Message)" }

# 3. Remove o lançador antigo da pasta Startup, para não rodar duas vezes
if (Test-Path $StartupAntigo) {
    Remove-Item $StartupAntigo -Force -ErrorAction SilentlyContinue
    Ok "Lançador antigo da pasta Startup removido"
}

# 4. Instala o driver de cada etiquetadora (mapeando uma vez como administrador).
#    Sem o driver na máquina, o usuário comum é barrado pelo Point and Print.
$lista = @(Get-Content "$PSScriptRoot\impressoras.txt" -Encoding UTF8 |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') })

if ($lista.Count -eq 0) { Falha "impressoras.txt não tem nenhuma impressora configurada." }

foreach ($caminho in $lista) {
    $servidor = ($caminho.TrimStart('\') -split '\\')[0]
    if ($servidor -ieq $env:COMPUTERNAME) { Aviso "$caminho está no USB desta própria máquina; não precisa mapear aqui."; continue }
    try {
        # Mapeia uma vez como administrador: isso instala o driver na máquina.
        $erroAdd = $null
        try { Add-Printer -ConnectionName $caminho -ErrorAction Stop } catch { $erroAdd = $_.Exception.Message }

        # Confere pelo driver: pega o nome do driver na máquina da etiquetadora e vê se ele existe aqui.
        # (Não dá para conferir pelo Get-Printer: na janela elevada a conexão nem sempre aparece na lista.)
        $compart = ($caminho.TrimStart('\') -split '\\', 2)[1]
        $remota  = Get-Printer -ComputerName $servidor -ErrorAction SilentlyContinue |
                   Where-Object { $_.ShareName -ieq $compart -or $_.Name -ieq $compart } | Select-Object -First 1

        if ($remota) {
            if (Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $remota.DriverName }) {
                Ok "Driver instalado ($($remota.DriverName)): $caminho"
            } elseif ($erroAdd) { throw $erroAdd }
            else { throw "o driver '$($remota.DriverName)' não aparece nesta máquina." }
        } elseif ($erroAdd) {
            throw $erroAdd
        } else {
            Ok "Conexão criada e driver instalado: $caminho"
        }
    } catch {
        Falha "Driver de $caminho não instalado: $($_.Exception.Message)"
        Write-Host "        Confira se a máquina $servidor está ligada e com a etiquetadora compartilhada, e rode o Instalar.bat de novo." -ForegroundColor Red
    }
}

Write-Host ""
if ($erros -eq 0) {
    Write-Host "Instalação concluída. Faça logoff e entre com outro usuário para testar (aguarde ~1 minuto)." -ForegroundColor Green
} else {
    Write-Host "Instalação terminou com $erros falha(s). Veja as mensagens em vermelho acima." -ForegroundColor Red
}
