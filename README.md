# SMX Windows Inventory

Script PowerShell para coleta de inventário de computadores Windows.

## O que o script coleta

* Informações do dispositivo
* Fabricante e modelo
* Número de série do equipamento
* Número de série da BIOS
* Número de série da placa-mãe
* Processador
* Memória RAM
* Discos
* Informações do Windows
* Versão e build do Windows
* Programas instalados
* Versões dos programas instalados

## Como executar

Abra o **PowerShell como Administrador** e execute o comando abaixo:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "irm 'https://raw.githubusercontent.com/samirlabs/smx-windows-inventory/main/SMX-WindowsInventory.ps1' | iex"
```

## Onde os arquivos serão salvos

Após a execução, os relatórios serão gerados na pasta:

```text
C:\Inventario
```

Serão criados dois arquivos CSV:

```text
Inventario_Sistemas_NOME-DO-COMPUTADOR_DATA.csv
Inventario_Programas_NOME-DO-COMPUTADOR_DATA.csv
```

## Observações

O script não coleta senhas, credenciais ou dados pessoais sensíveis.

A coleta é local na máquina onde o comando for executado.
