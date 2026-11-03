# Kit Etiquetadora: mapeamento automático de impressoras compartilhadas

Scripts para Windows que mapeiam automaticamente, em todo logon e para **qualquer usuário**, impressoras USB compartilhadas por outra máquina da rede (ex.: Zebra ZD220, HP). O driver vem da própria máquina que compartilha a impressora.

Autor: **Pedro Colombo**.

## Como funciona

- `Instalar.bat` pede elevação, desbloqueia os arquivos e roda o `Instalar.ps1`.
- `Instalar.ps1` copia o kit para `C:\ProgramData\Script`, cria a tarefa agendada **"Mapear Etiquetadora"** (dispara no logon do grupo Usuários, com 20 s de atraso) e instala o driver de cada impressora mapeando-a uma vez como administrador.
- `Map-Etiquetadora.ps1` roda no logon de cada usuário: testa a porta 445 da máquina que compartilha, mapeia o que falta e tenta de novo por até 10 minutos.
- `impressoras.txt` lista as impressoras, uma por linha.
- `Config-Etiqueta.ps1` (opcional, específico da ZD220) exporta/aplica a configuração da etiqueta (tamanho, escuridão, posição) entre máquinas.

## Uso

1. Na máquina com a impressora no USB, compartilhe a impressora.
2. Edite `impressoras.txt` com o caminho `\\HOSTNAME\NOME-DO-COMPARTILHAMENTO`. Para várias impressoras, uma linha para cada.
3. Copie a pasta do kit para `C:\` da máquina cliente e rode `Instalar.bat`.
4. Faça logoff e entre com outro usuário. Em cerca de 1 minuto a impressora aparece.

Não instale dois kits diferentes no mesmo PC: o segundo sobrescreve `C:\ProgramData\Script\impressoras.txt`. Junte as impressoras no mesmo arquivo.

## Diagnóstico

Cada usuário tem um log em `%LOCALAPPDATA%\map-etiquetadora.log`.

## Configuração da etiqueta (ZD220)

Rode como administrador na máquina onde a etiquetadora está no USB:

```powershell
.\Config-Etiqueta.ps1 -Exportar   # salva etiqueta-config.xml a partir da máquina já ajustada
.\Config-Etiqueta.ps1 -Aplicar    # aplica em outra máquina-servidor
```

Use `-Impressora "Nome"` se o nome da impressora for outro.

## Requisitos

Windows 10/11 com PowerShell 5.1. Os `.ps1` estão em UTF-8 com BOM e quebra de linha CRLF; o `.gitattributes` mantém o CRLF.
