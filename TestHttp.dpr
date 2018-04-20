program TestHttp;

uses
  Vcl.Forms,
  mainTestHttp in 'mainTestHttp.pas' {Form1},
  unitWinInet in 'unitWinInet.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
