# ============================================================
# INVENTARIO DE PARQUE WINDOWS - VERSAO CORRIGIDA
# Coleta local sem WinRM e remoto via WinRM/PowerShell Remoting
# Gera dois CSVs:
# - Inventario_Sistemas_NOME-PC_yyyy-MM-dd_HH-mm-ss.csv
# - Inventario_Programas_NOME-PC_yyyy-MM-dd_HH-mm-ss.csv
# ============================================================

$DataHora = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$PastaSaida = "C:\Inventario"

if (!(Test-Path $PastaSaida)) {
    New-Item -ItemType Directory -Path $PastaSaida -Force | Out-Null
}

$NomeComputador = $env:COMPUTERNAME

$ArquivoSistemas = Join-Path $PastaSaida "Inventario_Sistemas_$($NomeComputador)_$DataHora.csv"
$ArquivoProgramas = Join-Path $PastaSaida "Inventario_Programas_$($NomeComputador)_$DataHora.csv"

# ============================================================
# LISTA DE COMPUTADORES
# Padrao: maquina local
# Para usar TXT, crie C:\Inventario\computadores.txt e descomente as 2 linhas abaixo
# ============================================================

$Computadores = @($env:COMPUTERNAME)

# $ArquivoComputadores = "C:\Inventario\computadores.txt"
# $Computadores = Get-Content $ArquivoComputadores | Where-Object { $_.Trim() -ne "" }

function Get-ProgramasInstaladosLocal {
    param(
        [string]$NomeComputador
    )

    $RegistryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($Path in $RegistryPaths) {
        Get-ItemProperty $Path -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -and
            $_.DisplayName.Trim() -ne "" -and
            $_.SystemComponent -ne 1 -and
            $_.ParentKeyName -eq $null
        } |
        Select-Object @{
            Name = "Computador"
            Expression = { $NomeComputador }
        }, @{
            Name = "Programa"
            Expression = { $_.DisplayName }
        }, @{
            Name = "Versao"
            Expression = { $_.DisplayVersion }
        }, @{
            Name = "ProgramaFormatado"
            Expression = {
                if ($_.DisplayVersion -and $_.DisplayVersion.Trim() -ne "") {
                    "$($_.DisplayName) [v$($_.DisplayVersion)]"
                }
                else {
                    "$($_.DisplayName) [vNao informado]"
                }
            }
        }, @{
            Name = "Fabricante"
            Expression = { $_.Publisher }
        }, @{
            Name = "DataInstalacao"
            Expression = { $_.InstallDate }
        }, @{
            Name = "LocalInstalacao"
            Expression = { $_.InstallLocation }
        }, @{
            Name = "OrigemRegistro"
            Expression = { $Path }
        }
    }
}

function Get-SistemaLocal {
    param(
        [string]$NomeComputador
    )

    $Sistema = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $SO = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $BIOS = Get-CimInstance Win32_BIOS -ErrorAction Stop
    $Processador = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    $BaseBoard = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $ProdutoSistema = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
    $Discos = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue

    $RAM_GB = [math]::Round($Sistema.TotalPhysicalMemory / 1GB, 2)

    $DiscoResumo = ($Discos | ForEach-Object {
        "$($_.DeviceID) Total: $([math]::Round($_.Size / 1GB, 2)) GB / Livre: $([math]::Round($_.FreeSpace / 1GB, 2)) GB"
    }) -join " | "

    [PSCustomObject]@{
        Computador              = $NomeComputador
        Status                  = "OK"
        Fabricante              = $Sistema.Manufacturer
        Modelo                  = $Sistema.Model
        SerialEquipamento       = $ProdutoSistema.IdentifyingNumber
        UUIDEquipamento         = $ProdutoSistema.UUID
        SerialBIOS              = $BIOS.SerialNumber
        SerialPlacaMae          = $BaseBoard.SerialNumber
        TipoSistema             = $Sistema.SystemType
        DominioOuGrupo          = $Sistema.Domain
        UsuarioLogado           = $Sistema.UserName
        MemoriaRAM_GB           = $RAM_GB
        Processador             = $Processador.Name
        NucleosFisicos          = $Processador.NumberOfCores
        ProcessadoresLogicos    = $Processador.NumberOfLogicalProcessors
        PlacaMaeFabricante      = $BaseBoard.Manufacturer
        PlacaMaeModelo          = $BaseBoard.Product
        VersaoBIOS              = $BIOS.SMBIOSBIOSVersion
        WindowsNome             = $SO.Caption
        WindowsVersao           = $SO.Version
        WindowsBuild            = $SO.BuildNumber
        WindowsArquitetura      = $SO.OSArchitecture
        WindowsSerialProduto    = $SO.SerialNumber
        DataInstalacaoWindows   = $SO.InstallDate
        UltimoBoot              = $SO.LastBootUpTime
        DiretorioWindows        = $SO.WindowsDirectory
        IdiomaSistema           = $SO.OSLanguage
        Discos                  = $DiscoResumo
        DataColeta              = Get-Date
        Erro                    = ""
    }
}

$InventarioSistemas = New-Object System.Collections.Generic.List[object]
$InventarioProgramas = New-Object System.Collections.Generic.List[object]

foreach ($Computador in $Computadores) {

    $Computador = $Computador.Trim()
    Write-Host "Coletando informacoes de $Computador..." -ForegroundColor Cyan

    try {
        $EhLocal = $false

        if ($Computador.ToUpper() -eq $env:COMPUTERNAME.ToUpper() -or $Computador -eq "." -or $Computador.ToLower() -eq "localhost") {
            $EhLocal = $true
        }

        if ($EhLocal) {
            $SistemaColetado = Get-SistemaLocal -NomeComputador $env:COMPUTERNAME
            $ProgramasColetados = Get-ProgramasInstaladosLocal -NomeComputador $env:COMPUTERNAME
        }
        else {
            $SistemaColetado = Invoke-Command -ComputerName $Computador -ScriptBlock ${function:Get-SistemaLocal} -ArgumentList $Computador -ErrorAction Stop
            $ProgramasColetados = Invoke-Command -ComputerName $Computador -ScriptBlock ${function:Get-ProgramasInstaladosLocal} -ArgumentList $Computador -ErrorAction Stop
        }

        $InventarioSistemas.Add($SistemaColetado)

        foreach ($Programa in $ProgramasColetados) {
            $InventarioProgramas.Add($Programa)
        }
    }
    catch {
        Write-Host "Erro ao coletar $($Computador): $($_.Exception.Message)" -ForegroundColor Red

        $InventarioSistemas.Add([PSCustomObject]@{
            Computador              = $Computador
            Status                  = "ERRO"
            Fabricante              = ""
            Modelo                  = ""
            SerialEquipamento       = ""
            UUIDEquipamento         = ""
            SerialBIOS              = ""
            SerialPlacaMae          = ""
            TipoSistema             = ""
            DominioOuGrupo          = ""
            UsuarioLogado           = ""
            MemoriaRAM_GB           = ""
            Processador             = ""
            NucleosFisicos          = ""
            ProcessadoresLogicos    = ""
            PlacaMaeFabricante      = ""
            PlacaMaeModelo          = ""
            VersaoBIOS              = ""
            WindowsNome             = ""
            WindowsVersao           = ""
            WindowsBuild            = ""
            WindowsArquitetura      = ""
            WindowsSerialProduto    = ""
            DataInstalacaoWindows   = ""
            UltimoBoot              = ""
            DiretorioWindows        = ""
            IdiomaSistema           = ""
            Discos                  = ""
            DataColeta              = Get-Date
            Erro                    = $_.Exception.Message
        })
    }
}

$InventarioSistemas |
    Export-Csv -Path $ArquivoSistemas -NoTypeInformation -Encoding UTF8 -Delimiter ";"

$InventarioProgramas |
    Sort-Object Computador, Programa |
    Export-Csv -Path $ArquivoProgramas -NoTypeInformation -Encoding UTF8 -Delimiter ";"

Write-Host ""
Write-Host "Inventario finalizado!" -ForegroundColor Green
Write-Host "Arquivo de sistemas: $ArquivoSistemas"
Write-Host "Arquivo de programas: $ArquivoProgramas"
