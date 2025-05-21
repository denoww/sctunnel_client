@echo off
setlocal




:: Define o diretório do script
set "SCRIPT_DIR=%~dp0"
set "EXEC_PATH=%SCRIPT_DIR%exec.exe"
set "VBS_PATH=%SCRIPT_DIR%executar_oculto.vbs"
set "TAREFA_NOME=sc_tunnel"

:: Verifica se o executável existe
if not exist "%EXEC_PATH%" (
    echo [ERRO] Executável não encontrado em "%EXEC_PATH%"
    pause
    exit /b 1
)

:: Cria o script VBScript para execução oculta
echo Set WshShell = CreateObject("WScript.Shell") > "%VBS_PATH%"
echo WshShell.CurrentDirectory = "%SCRIPT_DIR%" >> "%VBS_PATH%"
echo WshShell.Run "exec.exe", 0, False >> "%VBS_PATH%"

:: Remove a tarefa existente, se houver
schtasks /delete /tn "%TAREFA_NOME%" /f >nul 2>&1

:: Cria a nova tarefa agendada que executa o script VBS
rem schtasks /create ^
rem   /tn "%TAREFA_NOME%" ^
rem   /tr "wscript.exe \"%VBS_PATH%\"" ^
rem   /sc minute ^
rem   /mo 1 ^
rem   /ru SYSTEM ^
rem   /f

schtasks /create ^
  /tn "%TAREFA_NOME%" ^
  /tr "\"%SCRIPT_DIR%exec.exe\"" ^
  /sc minute ^
  /mo 1 ^
  /ru SYSTEM ^
  /f


if %errorlevel% equ 0 (
    echo Tarefa agendada com sucesso para: %EXEC_PATH%
) else (
    echo Falha ao agendar tarefa. Código: %errorlevel%
)







echo  Instalando e ativando OpenSSH Server...

:: Verifica se é Admin
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo  Este script precisa ser executado como administrador.
  pause
  exit /b
)

:: Instala o OpenSSH.Server via PowerShell
echo  Instalando OpenSSH Server...
powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"

:: Inicia e configura o serviço SSH
echo  Iniciando serviço SSH...
sc start sshd
sc config sshd start=auto

:: Libera porta 22 no firewall
echo  Liberando porta 22 no firewall...
powershell -Command "New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22"

rem :: Verifica se o Npcap já está instalado
rem reg query "HKLM\SOFTWARE\Npcap" >nul 2>&1
rem if %errorlevel% neq 0 (
rem     echo  Baixando e instalando Npcap...
rem     curl -L -o npcap.exe https://nmap.org/npcap/dist/npcap-1.78.exe
rem     npcap.exe /S
rem     if %errorlevel% equ 0 (
rem         echo  Npcap instalado com sucesso.
rem     ) else (
rem         echo  Erro ao instalar o Npcap.
rem     )
rem ) else (
rem     echo  Npcap já está instalado.
rem )




rem permissão pem
set PEM_PATH=%~dp0scTunnel.pem

echo [INFO] Aplicando permissões seguras ao PEM...
icacls "%PEM_PATH%" /inheritance:r /grant:r "%USERNAME%:R" >nul
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao aplicar permissões no PEM!
    pause
    exit /b 1
)

echo [INFO] Permissão ajustada com sucesso: %PEM_PATH%





endlocal


echo  Instalação finalizada!
exit /b
