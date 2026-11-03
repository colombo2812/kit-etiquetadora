# Copia a configuração da etiqueta (tamanho, escuridão, posição) de uma etiquetadora para outra.
# Rodar como ADMINISTRADOR na máquina onde a etiquetadora está ligada no USB.
#
#   Salvar a configuração já ajustada:  .\Config-Etiqueta.ps1 -Exportar
#   Aplicar em outra máquina-servidor:  .\Config-Etiqueta.ps1 -Aplicar
#
# O arquivo etiqueta-config.xml fica na mesma pasta deste script.
param(
    [switch]$Exportar,
    [switch]$Aplicar,
    [string]$Impressora = "ZDesigner ZD220-203dpi ZPL"
)
$Arquivo = Join-Path $PSScriptRoot "etiqueta-config.xml"

if (-not (Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $Impressora })) {
    Write-Host "Impressora '$Impressora' não encontrada nesta máquina. Impressoras locais:" -ForegroundColor Red
    Get-Printer | Where-Object { $_.Type -eq 'Local' } | Select-Object Name, ShareName | Format-Table -AutoSize
    exit 1
}

try {
    if ($Exportar) {
        (Get-PrintConfiguration -PrinterName $Impressora -ErrorAction Stop).PrintTicketXML |
            Set-Content $Arquivo -Encoding UTF8
        Write-Host "[OK] Configuração salva em $Arquivo" -ForegroundColor Green
    }
    elseif ($Aplicar) {
        if (-not (Test-Path $Arquivo)) { throw "Arquivo $Arquivo não encontrado. Rode primeiro com -Exportar na máquina já configurada." }
        Set-PrintConfiguration -PrinterName $Impressora -PrintTicketXml (Get-Content $Arquivo -Raw -Encoding UTF8) -ErrorAction Stop
        Write-Host "[OK] Configuração aplicada em '$Impressora'." -ForegroundColor Green
        Write-Host "     Vale para quem mapear a etiquetadora a partir de agora." -ForegroundColor Green
    }
    else {
        Write-Host "Use -Exportar (salvar) ou -Aplicar (aplicar). Veja o cabeçalho do script." -ForegroundColor Yellow
    }
} catch { Write-Host "[FALHA] $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
