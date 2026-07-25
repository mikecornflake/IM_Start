Program IM_Start;

{$mode objfpc}{$H+}

Uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms,
  MainForm;

  {$R *.res}

Begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.ShowMainForm := False;
  Application.CreateForm(TfrmIMStart, frmIMStart);
  Application.Run;
End.
