Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = scriptDir

exePath = scriptDir & "\exec.exe"
logPath = scriptDir & "\windows_agendador_tarefas_exec_oculto.log"

' Cria log de execução
If fso.FileExists(logPath) Then
    Set logFileObj = fso.OpenTextFile(logPath, 8, True) ' Append
Else
    Set logFileObj = fso.CreateTextFile(logPath, True)
End If

logFileObj.WriteLine Now & " - Tentando rodar: " & exePath
logFileObj.Close
Set logFileObj = Nothing

' Executa o exe
WshShell.Run Chr(34) & exePath & Chr(34), 0

Set WshShell = Nothing
Set fso = Nothing
