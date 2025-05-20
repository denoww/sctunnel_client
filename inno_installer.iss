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
Filename: "{tmp}\npcap.exe"; StatusMsg: "Instalando Npcap..."; Flags: waituntilterminated
Filename: "windows_install.bat"; Flags: runascurrentuser shellexec waituntilterminated
Filename: "{app}\exec.exe"; Description: "Iniciar serviço"; Flags: postinstall nowait skipifsilent



[Code]
var
  ClienteCodigo: string;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  // Só pergunta na página de seleção de diretório
  if CurPageID = wpSelectDir then begin
    if not InputQuery('Código do Cliente', 'Qual código do cliente?', ClienteCodigo) then
    begin
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
  F: Integer;
begin
  if CurStep = ssPostInstall then begin
    ClientePath := ExpandConstant('{app}\cliente.txt');
    F := FileCreate(ClientePath);
    if F <> -1 then begin
      FileWrite(F, ClienteCodigo, Length(ClienteCodigo));
      FileClose(F);
    end else begin
      MsgBox('Erro ao criar cliente.txt', mbError, MB_OK);
    end;
  end;
end;
