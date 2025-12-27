@echo off
setlocal enabledelayedexpansion

:: Configura caminhos
set "APP_DIR=%~dp0"
set "VBS_PATH=%APP_DIR%windows_agendador_tarefas_exec_oculto.vbs"
set "TAREFA_NOME=sc_tunnel"
set "XML_PATH=%TEMP%\tarefa_sc_tunnel.xml"




rem rem permissão pem
rem set PEM_PATH=%APP_DIR%scTunnel.pem

rem echo [INFO] Aplicando permissões seguras ao PEM...
rem icacls "%PEM_PATH%" /inheritance:r /grant:r "%USERNAME%:R" >nul
rem if %errorlevel% neq 0 (
rem     echo [ERRO] Falha ao aplicar permissões no PEM!
rem     pause
rem     exit /b 1
rem )

rem echo [INFO] Permissão ajustada com sucesso: %PEM_PATH%



rem agendador de tarefas

:: Escapa & do caminho para uso seguro no echo
set "CMD_ESC_EXEC_PATH=%VBS_PATH:&=^&%"

:: Gera o XML da tarefa agendada (grupo: Administradores)
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
>> "%XML_PATH%" echo       ^<GroupId^>S-1-5-32-544^</GroupId^>
>> "%XML_PATH%" echo       ^<RunLevel^>HighestAvailable^</RunLevel^>
>> "%XML_PATH%" echo     ^</Principal^>
>> "%XML_PATH%" echo   ^</Principals^>
>> "%XML_PATH%" echo   ^<Settings^>
>> "%XML_PATH%" echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
>> "%XML_PATH%" echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
>> "%XML_PATH%" echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
>> "%XML_PATH%" echo     ^<Enabled^>true^</Enabled^>
>> "%XML_PATH%" echo     ^<Hidden^>false^</Hidden^>
>> "%XML_PATH%" echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
>> "%XML_PATH%" echo   ^</Settings^>
>> "%XML_PATH%" echo   ^<Actions Context="Author"^>
>> "%XML_PATH%" echo     ^<Exec^>
>> "%XML_PATH%" echo       ^<Command^>wscript.exe^</Command^>
>> "%XML_PATH%" echo       ^<Arguments^>"!CMD_ESC_EXEC_PATH!"^</Arguments^>
>> "%XML_PATH%" echo     ^</Exec^>
>> "%XML_PATH%" echo   ^</Actions^>
>> "%XML_PATH%" echo ^</Task^>


:: Remove tarefa antiga se existir
schtasks /delete /tn "%TAREFA_NOME%" /f >nul 2>&1

:: Cria a nova tarefa com base no XML
schtasks /create /tn "%TAREFA_NOME%" /xml "%XML_PATH%" /f

if %errorlevel% equ 0 (
    echo.
    echo ✅ Tarefa criada com sucesso com execução oculta.
    echo 🔄 A execução ocorrerá a cada 1 minuto.
) else (
    echo.
    echo ❌ [ERRO] Falha ao criar a tarefa. Código: %errorlevel%
)



endlocal


echo  Instalação finalizada!
exit /b
