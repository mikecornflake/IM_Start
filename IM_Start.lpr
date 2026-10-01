Program IM_Start;

{$mode objfpc}{$H+}

Uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms,
  MainForm
  {$IFDEF WINDOWS}
  ,Windows,Dialogs
  {$ENDIF};

  {$R *.res}

Const
  CAppMutexName = 'InspectorMike.IM_Start.SingleInstance';

Var
  hAppMutex: THandle;

Begin
  {$IFDEF WINDOWS}
  hAppMutex := CreateMutex(nil, True, CAppMutexName);

  If (hAppMutex = 0) Then
    Halt;

  If GetLastError = ERROR_ALREADY_EXISTS Then
  Begin
    // Tell the existing instance to show itself
    PostMessage(HWND_BROADCAST,RegisterWindowMessage('InspectorMike.IM_Start.Show'),0, 0);

    CloseHandle(hAppMutex);
    ShowMessage('IM_Start is already running in the system tray');
    Halt;
  End;
  {$ENDIF}

  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.ShowMainForm := False;
  Application.CreateForm(TfrmIMStart, frmIMStart);
  Application.Run;

  {$IFDEF WINDOWS}
  CloseHandle(hAppMutex);
  {$ENDIF}
End.
