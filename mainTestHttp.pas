unit mainTestHttp;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  IPPeerClient, Data.Bind.Components, Data.Bind.ObjectScope, REST.Client;

type
  TForm1 = class(TForm)
    LabeledEdit1: TLabeledEdit;
    LabeledEdit2: TLabeledEdit;
    Button1: TButton;
    Button2: TButton;
    LabeledEdit3: TLabeledEdit;
    RESTClient1: TRESTClient;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  WinInet,
  madStrings,
  Registry ;
// SysUtils;


procedure TForm1.Button1Click(Sender: TObject);
var
  sProyServer: String;
  iProxyPort: Integer;
begin
  //UseIEProxyInfo(sProyServer, iProxyPort);
  //Þetta er breyting
  LabeledEdit1.Text := sProyServer;
  LabeledEdit2.Text := IntToStr(iProxyPort);

end;

function detectIEProxyServer(): string;
begin
  with TRegistry.Create do
    try
      RootKey := HKEY_CURRENT_USER;
      if OpenKey('\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        False) then begin
        Result := ReadString('ProxyServer');
        CloseKey;
      end
      else
        Result := '';
    finally
      Free;
    end;
end;

// this function translate a WinInet Error Code to a description of the error.
function GetWinInetError(ErrorCode: Cardinal): string;
const
  winetdll = 'wininet.dll';
var
  Len: Integer;
  Buffer: PChar;
begin // https://theroadtodelphi.com/category/wininet/
  Len := FormatMessage(FORMAT_MESSAGE_FROM_HMODULE or
    FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER or
    FORMAT_MESSAGE_IGNORE_INSERTS or FORMAT_MESSAGE_ARGUMENT_ARRAY,
    Pointer(GetModuleHandle(winetdll)), ErrorCode, 0, @Buffer,
    SizeOf(Buffer), nil);
  try
    while (Len > 0) and
{$IFDEF UNICODE}(CharInSet(Buffer[Len - 1], [#0 .. #32, '.']))
{$ELSE}(Buffer[Len - 1] in [#0 .. #32, '.']) {$ENDIF}
      do
      Dec(Len);
    SetString(Result, Buffer, Len);
  finally
    LocalFree(HLOCAL(Buffer));
  end;
end;

function SetToIgnoreCerticateErrors(var aErrorMsg: string): Boolean;
var
  vDWFlags: DWord;
  vDWFlagsLen: DWord;
  hInter, hRemoteUrl, hConnect: HINTERNET;
  Code: Cardinal;
begin
  // https://stackoverflow.com/questions/9861309/wininet-ssl-client-authenticate-oddness
  Result := False;

//  hInter := InternetOpen(PChar('Explorer 5.0'), INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
//  if hInter = nil then begin
//    Code := GetLastError;
//    aErrorMsg := Format('Error %d Description %s', [Code, GetWinInetError(Code)]);
//  end;
//  hConnect := InternetConnect(hInter, PChar('https://www.postur.is'), INTERNET_DEFAULT_HTTPS_PORT, nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
//  if hConnect = nil then begin
//    Code := GetLastError;
//    raise Exception.Create(Format('InternetConnect Error %d Description %s', [Code, GetWinInetError(Code)]));
//  end;
  try
    vDWFlagsLen := SizeOf(vDWFlags);

    if not InternetQueryOption(hConnect, INTERNET_OPTION_SECURITY_FLAGS, Pointer(@vDWFlags), vDWFlagsLen) then begin
      Code := GetLastError;
      aErrorMsg := Format('Error %d Description %s',
        [Code, GetWinInetError(Code)]);
      // aErrorMsg := 'Internal error in SetToIgnoreCerticateErrors when trying to get wininet flags.' + IntToStr(GetLastError); // + GetWininetError;
      Exit;
    end;
    vDWFlags := vDWFlags or SECURITY_FLAG_IGNORE_UNKNOWN_CA or
      SECURITY_FLAG_IGNORE_CERT_DATE_INVALID or
      SECURITY_FLAG_IGNORE_CERT_CN_INVALID or SECURITY_FLAG_IGNORE_REVOCATION;
    if not InternetSetOption(hConnect, INTERNET_OPTION_SECURITY_FLAGS, Pointer(@vDWFlags), vDWFlagsLen) then begin
      aErrorMsg := 'Internal error in SetToIgnoreCerticateErrors when trying to set wininet INTERNET_OPTION_SECURITY_FLAGS flag .';
      // + GetWininetError;
      Exit;
    end;
    Result := True;
  except
    on E: Exception do begin
      aErrorMsg := 'Unknown error in SetToIgnoreCerticateErrors.' + E.Message;
    end;
  end;
end;

//function SetToIgnoreCerticateErrors2(var aErrorMsg: string): Boolean;
//var
//  vDWFlags: DWord;
//  vDWFlagsLen: DWord;
//begin
//  Result := False;
//  try
//    vDWFlagsLen := SizeOf(vDWFlags);
//    if not InternetQueryOptionA(oRequestHandle, INTERNET_OPTION_SECURITY_FLAGS, @vDWFlags, vDWFlagsLen) then begin
//      aErrorMsg := 'Internal error in SetToIgnoreCerticateErrors when trying to get wininet flags.' + GetWininetError;
//      Exit;
//    end;
//    vDWFlags := vDWFlags or SECURITY_FLAG_IGNORE_UNKNOWN_CA or SECURITY_FLAG_IGNORE_CERT_DATE_INVALID or SECURITY_FLAG_IGNORE_CERT_CN_INVALID or SECURITY_FLAG_IGNORE_REVOCATION;
//    if not InternetSetOptionA(oRequestHandle, INTERNET_OPTION_SECURITY_FLAGS, @vDWFlags, vDWFlagsLen) then begin
//      aErrorMsg := 'Internal error in SetToIgnoreCerticateErrors when trying to set wininet INTERNET_OPTION_SECURITY_FLAGS flag .' + GetWininetError;
//      Exit;
//    end;
//    Result := True;
//  except
//    on E: Exception do begin
//      aErrorMsg := 'Unknown error in SetToIgnoreCerticateErrors.' + E.Message;
//    end;
//  end;
//end;

function UseIEProxyInfo(var ProxyHost: String; var ProxyPort: Integer): Boolean;
var
  ProxyInfo: PInternetProxyInfo;
  Len: LongWord;
  ProxyDetails: String;
  s2: String;
  i1: Integer;

  procedure RemoveProtocol(var str: string);
  var
    i1: Integer;
  begin
    i1 := PosText('://', str);
    if i1 > 0 then
      Delete(str, 1, i1 + 2);
    i1 := PosText('http=', str);
    if i1 > 0 then begin
      Delete(str, 1, i1 + 4);
      str := SubStr(str, 1, ' ');
    end;
  end;

begin
  // https://stackoverflow.com/questions/2013802/how-can-a-delphi-application-detect-the-network-proxy-settings-of-a-windows-pc/2052459
  Result := False;
  Len := 4096;
  GetMem(ProxyInfo, Len);
  try
    if InternetQueryOption(nil, INTERNET_OPTION_PROXY, ProxyInfo, Len) then
    begin
      if ProxyInfo^.dwAccessType = INTERNET_OPEN_TYPE_PROXY then begin
        Result := True;
        ProxyDetails := ProxyInfo^.lpszProxy;

        RemoveProtocol(ProxyDetails);
        s2 := SubStr(ProxyDetails, 2, ':');
        if s2 <> '' then begin
          try
            i1 := StrToInt(s2);
          except
            i1 := -1;
          end;
          if i1 <> -1 then begin
            ProxyHost := SubStr(ProxyDetails, 1, ':');
            ProxyPort := i1;
          end;
        end;
      end;
    end;
  finally
    FreeMem(ProxyInfo);
  end;
end;

//procedure BeforePost(const HTTPReqResp: THTTPReqResp; Data: Pointer);
////procedure TForm1.HTTPRIO1HTTPWebNode1BeforePost(const HTTPReqResp: THTTPReqResp; Data: Pointer);
//var
//   SecurityFlags: DWord;
//   SecurityFlagsLen: DWord;
//   Request: HINTERNET;
//begin
////https://groups.google.com/forum/#!topic/borland.public.delphi.webservices.soap/bISn-ZZ0v4A
//   Request := Data;
//
//   if soIgnoreInvalidCerts in HTTPRIO1.HTTPWebNode.InvokeOptions then begin
//     SecurityFlagsLen := SizeOf(SecurityFlags);
//     InternetQueryOption(Request, INTERNET_OPTION_SECURITY_FLAGS, Pointer(@SecurityFlags), SecurityFlagsLen);
//     SecurityFlags := SecurityFlags or SECURITY_FLAG_IGNORE_UNKNOWN_CA;
//     InternetSetOption(Request, INTERNET_OPTION_SECURITY_FLAGS, Pointer(@SecurityFlags), SecurityFlagsLen);
//   end;
//end;

procedure TForm1.Button2Click(Sender: TObject);
var
  sMessage : String;
begin
    SetToIgnoreCerticateErrors(sMessage);
    LabeledEdit3.Text := sMessage;
end;




end.
