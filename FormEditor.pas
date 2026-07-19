Unit FormEditor;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, SynHighlighterIni, SynEdit;

Type

  { TfrmEditor }

  TfrmEditor = Class(TForm)
    btnAddFile: TToolButton;
    btnAddMenu: TToolButton;
    btnAddSep: TToolButton;
    btnCancel: TButton;
    btnSave: TButton;
    ilToolbar: TImageList;
    memShortcuts: TSynEdit;
    Panel1: TPanel;
    SynIniSyn1: TSynIniSyn;
    tbMain: TToolBar;
    btnSave2: TToolButton;
    ToolButton1: TToolButton;
    Procedure btnAddFileClick(Sender: TObject);
    Procedure btnAddMenuClick(Sender: TObject);
    Procedure btnAddSepClick(Sender: TObject);
    Procedure btnSave2Click(Sender: TObject);
    Procedure btnSaveClick(Sender: TObject);
  Private
    FFilename: String;
    Procedure InsertText(AText: String);
    Procedure SetFilename(AValue: String);
  Public
    Constructor Create(TheOwner: TComponent); Override;

    Property Filename: String Read FFilename Write SetFilename;
  End;

Implementation

{$R *.lfm}

{ TfrmEditor }

Constructor TfrmEditor.Create(TheOwner: TComponent);
Begin
  Inherited Create(TheOwner);

  memShortcuts.Lines.Clear;
End;

Procedure TfrmEditor.InsertText(AText: String);
Var
  Caret: TPoint;
Begin
  // Collapse any selection
  memShortcuts.BlockBegin := memShortcuts.CaretXY;
  memShortcuts.BlockEnd := memShortcuts.CaretXY;

  // Insert a newline
  memShortcuts.SelText := sLineBreak;

  // Move caret to the start of the new line
  Caret := memShortcuts.CaretXY;
  //Caret.Char := 1;
  memShortcuts.CaretXY := Caret;

  // Insert your text
  memShortcuts.SelText := AText;
End;

Procedure TfrmEditor.btnAddMenuClick(Sender: TObject);
Begin
  InsertText('[Menu]');
End;

Procedure TfrmEditor.btnAddFileClick(Sender: TObject);
Begin
  InsertText('Caption="Drive:\path\to\file.ext"');
End;

Procedure TfrmEditor.btnAddSepClick(Sender: TObject);
Begin
  InsertText('-');
End;

Procedure TfrmEditor.btnSave2Click(Sender: TObject);
Begin

End;

Procedure TfrmEditor.btnSaveClick(Sender: TObject);
Begin
  memShortcuts.Lines.SaveToFile(FFilename);
  ModalResult := mrOk;
End;

Procedure TfrmEditor.SetFilename(AValue: String);
Begin
  If FFilename = AValue Then
    Exit;

  FFilename := AValue;

  If FileExists(FFilename) Then
    memShortcuts.Lines.LoadFromFile(FFilename);
End;

End.
