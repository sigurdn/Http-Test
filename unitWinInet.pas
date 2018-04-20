unit unitWinInet;

interface

implementation

uses Winapi.WinInet, Winapi.Windows, System.Classes, System.SysUtils, Vcl.Forms;

var gbUseSSL : Boolean;



procedure CrackURL(const URL: String; out Scheme: Word; out UserName, Password, Host: String; out Port: Word; out ObjName: String);
var
  Parts: TURLComponents;
  CanonicalURL: String;
  Size: Cardinal;
begin
//https://prog.hu/tudastar/112946/wininet-https-http-authentikacio
  FillChar(Parts, SizeOf(TURLComponents), 0);
  Parts.dwStructSize := SizeOf(TURLComponents);
  if URL <> '' then
  begin
    Size := 3 * Length(URL);
    SetString(CanonicalURL, nil, Size);
    if not InternetCanonicalizeUrl(PChar(URL), PChar(CanonicalURL), Size, ICU_NO_META) then
      Size := 0;
    SetLength(CanonicalURL, Size);
    Parts.dwSchemeLength := 1;
    Parts.dwUserNameLength := 1;
    Parts.dwPasswordLength := 1;
    Parts.dwHostNameLength := 1;
    Parts.dwURLPathLength := 1;
    Parts.dwExtraInfoLength := 1;
    InternetCrackUrl(PChar(CanonicalURL), Size, 0, Parts);
  end;
  Scheme := Parts.nScheme;
  SetString(UserName, Parts.lpszUserName, Parts.dwUserNameLength);
  SetString(Password, Parts.lpszPassword, Parts.dwPasswordLength);
  SetString(Host, Parts.lpszHostName, Parts.dwHostNameLength);
  Port := Parts.nPort;
  SetString(ObjName, Parts.lpszUrlPath, Parts.dwUrlPathLength + Parts.dwExtraInfoLength);
end;

function GetUrlContent(const URL: String): String;
const
  AcceptType: array[0..1] of PChar = ('*/*', nil);
var
  hINet, hConn, hReq: HINTERNET;
  UserName, Password, Host, ObjName: String;
  Scheme, Port: Word;
  dwSize, dwError: DWORD;
  ReqFlags, Size: Cardinal;
  Stream: TStringStream;
  Buffer: array[0..255] of Byte;
begin
  Result := '';
  hINet := InternetOpen('Mozila/5.0', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hINet <> nil then begin
    try
      CrackURL(URL, Scheme, UserName, Password, Host, Port, ObjName);
      hConn := InternetConnect(hINet, PChar(Host), Port, PChar(UserName), PChar(Password), INTERNET_SERVICE_HTTP, 0, 0);
      if hConn <> nil then begin
        try
          ReqFlags := INTERNET_FLAG_RELOAD or INTERNET_FLAG_PRAGMA_NOCACHE
                   or INTERNET_FLAG_NO_CACHE_WRITE or INTERNET_FLAG_NO_COOKIES
                   or INTERNET_FLAG_NO_UI or INTERNET_FLAG_KEEP_CONNECTION;
          if Scheme = INTERNET_SCHEME_HTTPS then begin
            ReqFlags := ReqFlags or INTERNET_FLAG_SECURE;
          end;
          hReq := HttpOpenRequest(hConn, 'GET', PChar(ObjName), nil, nil, @AcceptType[0], ReqFlags, 0);
          if hReq <> nil then begin
            dwSize:=SizeOf(ReqFlags);
            // Get the current flags
            if Scheme = INTERNET_SCHEME_HTTPS then begin
              if (InternetQueryOption(hReq, INTERNET_OPTION_SECURITY_FLAGS, @ReqFlags, dwSize)) then begin
                 // Add desired flags
                 ReqFlags := ReqFlags or SECURITY_FLAG_IGNORE_UNKNOWN_CA or
                 SECURITY_FLAG_IGNORE_CERT_CN_INVALID or
                 SECURITY_FLAG_IGNORE_CERT_DATE_INVALID or
                 SECURITY_FLAG_IGNORE_REVOCATION;
                 // Set new flags
                 if not(InternetSetOption(hReq, INTERNET_OPTION_SECURITY_FLAGS, @ReqFlags, dwSize)) then begin
                    // Get error code
                    dwError := GetLastError;
                    // Failure
                    MessageBox(0, PChar(IntToStr(dwError)), PChar('Confirm'), MB_OK or MB_ICONINFORMATION);
                 end;
              end else begin
                 // Get error code
                 dwError := GetLastError;
                 // Failure
                 MessageBox(0, PChar(IntToStr(dwError)), PChar('Confirm'), MB_OK or MB_ICONINFORMATION);
              end;
            end;

            try
              if HttpSendRequest(hReq, nil, 0, nil, 0) then begin
                Stream := TStringStream.Create('');
                try
                  while InternetReadFile(hReq, @Buffer[0], SizeOf(Buffer), Size) and (Size <> 0) do begin
                    Stream.Write(Buffer[0], Size);
                  end;
                  Result := Stream.DataString;
                finally
                  Stream.Free;
                end;
              end;
            finally
              dwError := GetLastError;
//              MessageBox(0, PChar(IntToStr(dwError)), PChar('Confirm'), MB_OK or MB_ICONINFORMATION);
              InternetCloseHandle(hReq);
            end;
          end;
        finally
          InternetCloseHandle(hConn);
        end;
      end;
    finally
      InternetCloseHandle(hINet);
    end;
  end;
end;

function GetURLInput(strURL, strParams: String): string;
var
  hInet: HINTERNET;
  hConn: HINTERNET;
  hReq:  HINTERNET;
  dwLastError:DWORD;
  buf :Array[0..4095] of char;
  iBytesRead:Cardinal;

  data:   DWORD;
  size,dummy:Cardinal;
  nilptr:Pointer;
  dwRetVal:DWORD;


  bKeepOnLooping: boolean;
  bFlag: boolean;
  port:Integer;
  iInternetFlags:DWORD;
  dwFlags, dwBuffLen:DWORD;
begin
  //http://delphi.cjcsoft.net/viewthread.php?tid=47876
  hInet := InternetOpen('TESTAPP',INTERNET_OPEN_TYPE_PRECONFIG,nil, nil,0);
  if hInet = nil then exit;

  if gbUseSSL then
    port := INTERNET_DEFAULT_HTTPS_PORT
  else
    port :=INTERNET_DEFAULT_HTTP_PORT;
  hConn := InternetConnect(hInet, PChar(strURL), port,
   nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
  if hConn = nil then
  begin
    InternetCloseHandle(hInet);
    exit;
  end;
  iInternetFlags :=  INTERNET_FLAG_KEEP_CONNECTION OR  INTERNET_FLAG_NO_CACHE_WRITE OR INTERNET_FLAG_RELOAD;
  if gbUseSSL then  iInternetFlags := iInternetFlags OR INTERNET_FLAG_SECURE;
  hReq := HttpOpenRequest(hConn, 'POST', PChar(strParams), 'HTTP/1.0', nil, nil,iInternetFlags, 0);
  if hReq = nil then
  Begin
    InternetCloseHandle(hConn);
    InternetCloseHandle(hInet);
    exit;
  end;

  bKeepOnLooping := true;
  while bKeepOnLooping do
  begin
    if HttpSendRequest(hReq, nil, 0, nil, 0) then
      dwLastError := ERROR_SUCCESS
    else
      dwLastError:= GetLastError();
    if (dwLastError = ERROR_INTERNET_INVALID_CA) then
    begin
      dwBuffLen := sizeof(dwFlags);

      InternetQueryOption (hReq, INTERNET_OPTION_SECURITY_FLAGS,
            @dwFlags, dwBuffLen);

      dwFlags := dwFlags OR SECURITY_FLAG_IGNORE_UNKNOWN_CA;
      InternetSetOption (hReq, INTERNET_OPTION_SECURITY_FLAGS,
                            @dwFlags, sizeof (dwFlags) );
      continue;
    end;

   //Now check whether data is available
    size := sizeof(data);dummy := 0;

    HttpQueryInfo(hReq, HTTP_QUERY_STATUS_CODE or HTTP_QUERY_FLAG_NUMBER, @data, size, dummy);

    if (data = HTTP_STATUS_DENIED) or (data = HTTP_STATUS_PROXY_AUTH_REQ) then
    begin

      dwRetVal:= InternetErrorDlg(application.handle, hReq, dwLastError,
      FLAGS_ERROR_UI_FILTER_FOR_ERRORS or
      FLAGS_ERROR_UI_FLAGS_GENERATE_DATA or
      FLAGS_ERROR_UI_FLAGS_CHANGE_OPTIONS,
      nilptr );


      if dwRetVal = ERROR_INTERNET_FORCE_RETRY then
        continue
      else  //the only reason is user pressed CANCEL
      begin
        InternetCloseHandle(hReq);
        InternetCloseHandle(hConn);
        InternetCloseHandle(hInet);
        exit;
      end;
    end
    else
      bKeepOnLooping := false; //Everything was fine now.
  end; //End while looop

//  while(true) do
//  begin
//    bFlag:=InternetReadFile(hReq,@buf,BUFF_SIZE,iBytesRead);
//    if ((bFlag) and (not(iBytesRead=0))) then
//    begin
//      if iBytesRead         buf[iBytesRead]:=#0;
//      Result:=Result + buf;
//    end
//    else
//      break;
//  end;
  if hConn  = nil then InternetCloseHandle(hConn);
  if hReq = nil then InternetCloseHandle(hReq);
  if hInet = nil then InternetCloseHandle(hInet);
end;

initialization
  gbUseSSL := true;

end.
