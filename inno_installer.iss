[Setup]
AppName=SeuCondominio Tunnel
AppVersion=1.0
DefaultDirName={pf}\SeuCondominioTunnel
DefaultGroupName=SeuCondominio
OutputBaseFilename=setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "exec.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "scTunnel.pem"; DestDir: "{app}"; Flags: ignoreversion
Source: "config.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "windows_install.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "npcap.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
Filename: "{tmp}\npcap.exe"; Parameters: "/S"; StatusMsg: "Instalando Npcap..."; Flags: runhidden waituntilterminated
Filename: "windows_install.bat"; Flags: runascurrentuser shellexec waituntilterminated
Filename: "{app}\exec.exe"; Description: "Iniciar serviço"; Flags: postinstall nowait skipifsilent
