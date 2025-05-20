@echo off
echo 🔧 Instalando e ativando OpenSSH Server no Windows...

:: Verifica se é Admin
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo ⚠️  Este script precisa ser executado como administrador.
  pause
  exit /b
)

:: Instala o OpenSSH.Server via PowerShell
powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"

:: Inicia e ativa o serviço SSH
sc start sshd
sc config sshd start=auto

:: Libera a porta no firewall
powershell -Command "New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22"

echo ✅ OpenSSH instalado e pronto!
pause
