@echo off
echo [INFO] Apagando conexoes.txt...
del "%~dp0conexoes.txt" >nul 2>&1

if exist "%~dp0conexoes.txt" (
    echo [ERRO] Falha ao excluir conexoes.txt!
) else (
    echo [OK] conexoes.txt removido com sucesso.
)

pause
