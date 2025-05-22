Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Obtém o diretório onde o script está localizado
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

' Define o diretório de trabalho atual
WshShell.CurrentDirectory = scriptDir

' Executa exec.exe de forma oculta (0 = janela oculta)
WshShell.Run Chr(34) & scriptDir & "\exec.exe" & Chr(34), 0

Set fso = Nothing
Set WshShell = Nothing
