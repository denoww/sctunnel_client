[Setup]
AppName=sc_tunnel
AppVersion=1.0
DefaultDirName={pf}\sc_tunnel
DefaultGroupName=sc_tunnel
OutputBaseFilename=setup
Compression=lzma
SolidCompression=yes

[Icons]
Name: "{group}\Desinstalar"; Filename: "{uninstallexe}"

[Files]
Source: "windows_agendador_tarefas_exec_oculto.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "reset.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "scTunnel.pem"; DestDir: "{app}"; Flags: ignoreversion
Source: "exec.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "windows_configurar_apos_instalacao.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "install_npcap.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall


[Run]
Filename: "{tmp}\install_npcap.exe"; StatusMsg: "Instalando Npcap..."; Flags: waituntilterminated
Filename: "{app}\windows_configurar_apos_instalacao.bat"; Flags: runascurrentuser shellexec waituntilterminated
Filename: "{app}\exec.exe"; Description: "Iniciar serviço"; Flags: postinstall nowait skipifsilent


[UninstallRun]
Filename: "schtasks"; Parameters: "/Delete /TN ""sc_tunnel"" /F"; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{app}"



[Code]
var
  ClientePage: TInputQueryWizardPage;

procedure InitializeWizard;
begin
  ClientePage := CreateInputQueryPage(wpSelectDir, 'Código do Cliente', 'Código do Cliente',
    'Informe o código do cliente');
  ClientePage.Add('Código do Cliente:', False);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  if CurPageID = ClientePage.ID then begin
    if Trim(ClientePage.Values[0]) = '' then begin
      MsgBox('Você deve informar o código do cliente para continuar.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ClientePath: string;
  ClienteTexto: string;
begin
  if CurStep = ssPostInstall then begin
    ClientePath := ExpandConstant('{app}\cliente.txt');
    ClienteTexto := ClientePage.Values[0];
    if not SaveStringToFile(ClientePath, ClienteTexto, False) then
      MsgBox('Erro ao criar cliente.txt', mbError, MB_OK);
  end;
end;




