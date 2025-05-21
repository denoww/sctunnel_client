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





:: Escapa caracteres XML perigosos como &
set "ESC_EXEC_PATH=%EXEC_PATH:&=&amp;%"
:: Cria XML da tarefa agendada
> "%XML_PATH%" echo ^<?xml version="1.0" encoding="UTF-16"?^>
>> "%XML_PATH%" echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
>> "%XML_PATH%" echo   ^<RegistrationInfo^>
>> "%XML_PATH%" echo     ^<Description^>Túnel reverso SeuCondominio^</Description^>
>> "%XML_PATH%" echo     ^<Author^>SeuCondominio^</Author^>
>> "%XML_PATH%" echo   ^</RegistrationInfo^>
>> "%XML_PATH%" echo   ^<Triggers^>
>> "%XML_PATH%" echo     ^<TimeTrigger^>
>> "%XML_PATH%" echo       ^<Repetition^>^<Interval^>PT1M^</Interval^>^<StopAtDurationEnd^>false^</StopAtDurationEnd^>^</Repetition^>
>> "%XML_PATH%" echo       ^<StartBoundary^>2025-01-01T00:00:00^</StartBoundary^>
>> "%XML_PATH%" echo       ^<Enabled^>true^</Enabled^>
>> "%XML_PATH%" echo     ^</TimeTrigger^>
>> "%XML_PATH%" echo   ^</Triggers^>
>> "%XML_PATH%" echo   ^<Principals^>
>> "%XML_PATH%" echo     ^<Principal id="Author"^>
>> "%XML_PATH%" echo       ^<RunLevel^>HighestAvailable^</RunLevel^>
>> "%XML_PATH%" echo     ^</Principal^>
>> "%XML_PATH%" echo   ^</Principals^>
>> "%XML_PATH%" echo   ^<Settings^>
>> "%XML_PATH%" echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
>> "%XML_PATH%" echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
>> "%XML_PATH%" echo     ^<Enabled^>true^</Enabled^>
>> "%XML_PATH%" echo     ^<Hidden^>false^</Hidden^>
>> "%XML_PATH%" echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
>> "%XML_PATH%" echo   ^</Settings^>
>> "%XML_PATH%" echo   ^<Actions Context="Author"^>
>> "%XML_PATH%" echo     ^<Exec^>
>> "%XML_PATH%" echo       ^<Command^>%ESC_EXEC_PATH%^</Command^>
>> "%XML_PATH%" echo     ^</Exec^>
>> "%XML_PATH%" echo   ^</Actions^>
>> "%XML_PATH%" echo ^</Task^>
:: Remove a tarefa se já existir
schtasks /delete /tn "%TAREFA_NOME%" /f >nul 2>&1
:: Cria a nova tarefa agendada
rem schtasks /create /tn "%TAREFA_NOME%" /xml "%XML_PATH%" /ru SYSTEM /f
schtasks /create /tn "%TAREFA_NOME%" /xml "%XML_PATH%" /f

if %errorlevel% equ 0 (
    echo [OK] Tarefa agendada com sucesso para: %EXEC_PATH%
) else (
    echo [ERRO] Falha ao agendar tarefa. Código: %errorlevel%
)





:: Remove a tarefa existente, se houver
rem schtasks /delete /tn "%TAREFA_NOME%" /f >nul 2>&1

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

rem schtasks /create ^
rem   /tn "%TAREFA_NOME%" ^
rem   /tr "\"%APP_DIR%exec.exe\"" ^
rem   /sc minute ^
rem   /mo 1 ^
rem   /ru SYSTEM ^
rem   /f



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
set PEM_PATH=%APP_DIR%scTunnel.pem

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
