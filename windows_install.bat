@echo off
setlocal




:: Define o diretório do script
set "APP_DIR=%~dp0"
set "EXEC_PATH=%APP_DIR%exec.exe"
set "VBS_PATH=%APP_DIR%executar_oculto.vbs"
set "TAREFA_NOME=sc_tunnel"

:: Verifica se o executável existe
if not exist "%EXEC_PATH%" (
    echo [ERRO] Executável não encontrado em "%EXEC_PATH%"
    pause
    exit /b 1
)



rem permissão pem
set PEM_PATH=%APP_DIR%scTunnel.pem

echo [INFO] Aplicando permissões seguras ao PEM...
icacls "%PEM_PATH%" /inheritance:r /grant:r "%USERNAME%:R" >nul
if %errorlevel% neq 0 (
    echo [ERRO] Falha ao aplicar permissões no PEM!
    pause
    exit /b 1
)

echo [INFO] Permissão ajustada com sucesso: %PEM_PATH%






rem :: Escapa caracteres XML perigosos como &
rem set "ESC_EXEC_PATH=%EXEC_PATH:&=&amp;%"
rem :: Cria XML da tarefa agendada
rem > "%XML_PATH%" echo ^<?xml version="1.0" encoding="UTF-16"?^>
rem >> "%XML_PATH%" echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
rem >> "%XML_PATH%" echo   ^<RegistrationInfo^>
rem >> "%XML_PATH%" echo     ^<Description^>Túnel reverso SeuCondominio^</Description^>
rem >> "%XML_PATH%" echo     ^<Author^>SeuCondominio^</Author^>
rem >> "%XML_PATH%" echo   ^</RegistrationInfo^>
rem >> "%XML_PATH%" echo   ^<Triggers^>
rem >> "%XML_PATH%" echo     ^<TimeTrigger^>
rem >> "%XML_PATH%" echo       ^<Repetition^>^<Interval^>PT1M^</Interval^>^<StopAtDurationEnd^>false^</StopAtDurationEnd^>^</Repetition^>
rem >> "%XML_PATH%" echo       ^<StartBoundary^>2025-01-01T00:00:00^</StartBoundary^>
rem >> "%XML_PATH%" echo       ^<Enabled^>true^</Enabled^>
rem >> "%XML_PATH%" echo     ^</TimeTrigger^>
rem >> "%XML_PATH%" echo   ^</Triggers^>
rem >> "%XML_PATH%" echo   ^<Principals^>
rem >> "%XML_PATH%" echo     ^<Principal id="Author"^>
rem >> "%XML_PATH%" echo       ^<RunLevel^>HighestAvailable^</RunLevel^>
rem >> "%XML_PATH%" echo     ^</Principal^>
rem >> "%XML_PATH%" echo   ^</Principals^>
rem >> "%XML_PATH%" echo   ^<Settings^>
rem >> "%XML_PATH%" echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
rem >> "%XML_PATH%" echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
rem >> "%XML_PATH%" echo     ^<Enabled^>true^</Enabled^>
rem >> "%XML_PATH%" echo     ^<Hidden^>false^</Hidden^>
rem >> "%XML_PATH%" echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
rem >> "%XML_PATH%" echo   ^</Settings^>
rem >> "%XML_PATH%" echo   ^<Actions Context="Author"^>
rem >> "%XML_PATH%" echo     ^<Exec^>
rem >> "%XML_PATH%" echo       ^<Command^>%ESC_EXEC_PATH%^</Command^>
rem >> "%XML_PATH%" echo     ^</Exec^>
rem >> "%XML_PATH%" echo   ^</Actions^>
rem >> "%XML_PATH%" echo ^</Task^>
rem :: Remove a tarefa se já existir
rem schtasks /delete /tn "%TAREFA_NOME%" /f >nul 2>&1
rem :: Cria a nova tarefa agendada
rem rem schtasks /create /tn "%TAREFA_NOME%" /xml "%XML_PATH%" /ru SYSTEM /f
rem schtasks /create /tn "%TAREFA_NOME%" /xml "%XML_PATH%" /f

rem if %errorlevel% equ 0 (
rem     echo [OK] Tarefa agendada com sucesso para: %EXEC_PATH%
rem ) else (
rem     echo [ERRO] Falha ao agendar tarefa. Código: %errorlevel%
rem )





:: Remove a tarefa existente, se houver
schtasks /delete /tn "%TAREFA_NOME%" /f >nul 2>&1


schtasks /create ^
  /tn "%TAREFA_NOME%" ^
  /tr "\"%APP_DIR%exec.exe\"" ^
  /sc minute ^
  /mo 1 ^
  /ru SYSTEM ^
  /f

rem schtasks /create ^
rem   /tn "%TAREFA_NOME%" ^
rem   /xml "%APP_DIR%windows_permissao_agendador_tarefas.xml" ^
rem   /ru SYSTEM ^
rem   /f

:: Cria a nova tarefa agendada que executa o script VBS
rem :: Cria o script VBScript para execução oculta
rem echo Set WshShell = CreateObject("WScript.Shell") > "%VBS_PATH%"
rem echo WshShell.CurrentDirectory = "%APP_DIR%" >> "%VBS_PATH%"
rem echo WshShell.Run "exec.exe", 0, False >> "%VBS_PATH%"
rem schtasks /create ^
rem   /tn "%TAREFA_NOME%" ^
rem   /tr "wscript.exe \"%VBS_PATH%\"" ^
rem   /sc minute ^
rem   /mo 1 ^
rem   /ru SYSTEM ^
rem   /f





if %errorlevel% equ 0 (
    echo Tarefa agendada com sucesso para: %EXEC_PATH%
) else (
    echo Falha ao agendar tarefa. Código: %errorlevel%
)







rem echo  Instalando e ativando OpenSSH Server...

rem :: Verifica se é Admin
rem net session >nul 2>&1
rem if %errorlevel% neq 0 (
rem   echo  Este script precisa ser executado como administrador.
rem   pause
rem   exit /b
rem )

rem :: Instala o OpenSSH.Server via PowerShell
rem echo  Instalando OpenSSH Server...
rem powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"

rem :: Inicia e configura o serviço SSH
rem echo  Iniciando serviço SSH...
rem sc start sshd
rem sc config sshd start=auto

rem :: Libera porta 22 no firewall
rem echo  Liberando porta 22 no firewall...
rem powershell -Command "New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22"







endlocal


echo  Instalação finalizada!
exit /b
