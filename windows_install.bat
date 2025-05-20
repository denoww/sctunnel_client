@echo off
setlocal
echo 🔧 Instalando e ativando OpenSSH Server e Npcap...

:: Verifica se é Admin
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo ⚠️  Este script precisa ser executado como administrador.
  pause
  exit /b
)

:: Instala o OpenSSH.Server via PowerShell
echo 📦 Instalando OpenSSH Server...
powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"

:: Inicia e ativa o serviço SSH
echo 🚀 Iniciando serviço SSH...
sc start sshd
sc config sshd start=auto

:: Libera porta 22 no firewall
echo 🔓 Liberando porta 22 no firewall...
powershell -Command "New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22"

:: Verifica se o Npcap já está instalado
reg query "HKLM\SOFTWARE\Npcap" >nul 2>&1
if %errorlevel% neq 0 (
    echo 📥 Baixando e instalando Npcap...
    curl -L -o npcap.exe https://nmap.org/npcap/dist/npcap-1.78.exe
    npcap.exe /S
    if %errorlevel% equ 0 (
        echo ✅ Npcap instalado com sucesso.
    ) else (
        echo ❌ Erro ao instalar o Npcap.
    )
) else (
    echo ✅ Npcap já está instalado.
)

echo ✅ Instalação finalizada!
pause
