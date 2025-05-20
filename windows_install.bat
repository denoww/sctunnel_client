@echo off
setlocal

set APP_DIR=%~1


echo 🔧 Instalando e ativando OpenSSH Server...

:: Verifica se é Admin
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo ⚠️ Este script precisa ser executado como administrador.
  pause
  exit /b
)

:: Instala o OpenSSH.Server via PowerShell
echo 📦 Instalando OpenSSH Server...
powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"

:: Inicia e configura o serviço SSH
echo 🚀 Iniciando serviço SSH...
sc start sshd
sc config sshd start=auto

:: Libera porta 22 no firewall
echo 🔓 Liberando porta 22 no firewall...
powershell -Command "New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22"

rem :: Verifica se o Npcap já está instalado
rem reg query "HKLM\SOFTWARE\Npcap" >nul 2>&1
rem if %errorlevel% neq 0 (
rem     echo 📥 Baixando e instalando Npcap...
rem     curl -L -o npcap.exe https://nmap.org/npcap/dist/npcap-1.78.exe
rem     npcap.exe /S
rem     if %errorlevel% equ 0 (
rem         echo ✅ Npcap instalado com sucesso.
rem     ) else (
rem         echo ❌ Erro ao instalar o Npcap.
rem     )
rem ) else (
rem     echo ✅ Npcap já está instalado.
rem )





:: Recebe apenas o diretório base (ex: C:\SeuCondominioTunnel)
set EXEC_PATH=%APP_DIR%\exec.exe
set TAREFA_NOME=SeuCondominioTunnel

if not exist "%EXEC_PATH%" (
    echo ❌ Executável não encontrado: %EXEC_PATH%
    pause
    exit /b 1
)

:: Remove tarefa antiga (caso exista)
schtasks /delete /tn "%TAREFA_NOME%" /f >nul 2>&1

:: Cria a nova tarefa
schtasks /Create /F /SC MINUTE /MO 1 ^
  /TN "%TAREFA_NOME%" ^
  /TR "\"%EXEC_PATH%\"" ^
  /RL HIGHEST

if %errorlevel% equ 0 (
    echo ✅ Tarefa agendada com sucesso para: %EXEC_PATH%
) else (
    echo ❌ Falha ao agendar tarefa. Código: %errorlevel%
)


echo Executando agendamento em %DATE% %TIME% >> %APP_DIR%\agendamento.log


endlocal


echo ✅ Instalação finalizada!
exit /b
