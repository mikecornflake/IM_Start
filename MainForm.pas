Unit MainForm;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}
{-------------------------------------------------------------------------------
  Application      : ShortcutTray
  Description
    The second version of my own start menu.
    First was written in AutohotKey.  Powerful, but not easily portable.

  Source
    Copyright (c) 2026
    Inspector Mike 2.0 Pty Ltd
    Mike Thompson (mike.cornflake@gmail.com)

  History
    19/08/2026: Completion of human code review
    01/07/2026: Creation - largely ChatGPT with Mike providing functional
                           testing - no code review

  License
    This library is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or (at
    your option) any later version.

    This library is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this library. If not, see <https://www.gnu.org/licenses/>.

    SPDX-License-Identifier: GPL-3.0-or-later
-------------------------------------------------------------------------------}
Interface

Uses
  Classes, Contnrs, SysUtils, Forms, Controls, Menus, ExtCtrls, Dialogs,
  LazFileUtils
  {$IFDEF Windows}, Windows{$ENDIF};

Type

  TShortcutInfo = Class
  Public
    Caption: String;
    MenuName: String;
    ExeName: String;
    Params: String;
    WorkDir: String;
  End;

  { TfrmIMStart }

  TfrmIMStart = Class(TForm)
    ilShortcuts: TImageList;
    pmShortcuts: TPopupMenu;
    TrayIcon: TTrayIcon;
    Procedure TrayIconClick(Sender: TObject);

    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
  Private
    FShortcutImageCount: Integer;
    FTokens: TStringList;
    FShortcutsFile: String;
    FShortcutInfos: TFPObjectList;
    FMenuShowing: Boolean;

    // Menu Building Helper routines
    Function ExpandShortcutTokens(Const AText: String): String;
    Function ExtractExeAndParams(Const ALine: String;
      out AExe, AParams: String): Boolean;
    Function FindOrCreateFolderMenu(Const AFolder: String): TMenuItem;
    Procedure AddSeparatorToMenu(Const AMenu: String);
    Procedure AddShortcutToMenu(Const AMenu, ACaption, AExe, AParams: String);

    // Primary routines
    Procedure LoadShortcuts;
    Procedure RebuildMenu;

    // User clicks shortcut menu
    Procedure RunShortcut(Sender: TObject);
    // Edit the Shortcut file externally
    Procedure OpenShortcutsFile(Sender: TObject);

    // Application menu items
    Procedure DoAbout(Sender: TObject);
    Procedure ReloadShortcuts(Sender: TObject);
    Procedure EditShortcuts(Sender: TObject);
    Procedure ExitApp(Sender: TObject);

    // Allow shortcut Icon to toggle disabled while loading...
    Procedure SetTrayIcon(AImageIndex: Integer);
  Public
  End;

Var
  frmIMStart: TfrmIMStart;

Const
  ICON_TRAY_ENABLED = 11;
  ICON_TRAY_DISABLED = 12;
  ICON_FOLDER = 1;
  ICON_IE = 13;
  SECTION_DEFAULT = 'Shortcuts';

Implementation

{$R *.lfm}

Uses
  StrUtils, OSSupport, FileSupport, StringSupport, FormAbout, Graphics,
  FormEditor, ThirdPartySupport,
  // Here to activate the TabPage in FormAbout
  ffmpegSupport, LibmpvSupport, TesseractSupport, XPDFSupport, qpdfSupport,
  PopplerSupport,
  LazSerialSupport;

  { TfrmIMStart }

Procedure TfrmIMStart.FormCreate(Sender: TObject);
Begin
  // TODO: Why isn't this being set from Project Options?
  Application.Title := 'Inspector Mike Start Menu';

  FShortcutInfos := TFPObjectList.Create(True);
  FShortcutsFile := AppendPathDelim(ExtractFilePath(Application.ExeName)) +
    'shortcuts.txt';

  TrayIcon.Hint := 'IM Start Menu';
  TrayIcon.Visible := True;

  FTokens := TStringList.Create;
  FTokens.CaseSensitive := False;
  FTokens.NameValueSeparator := '=';

  // Remember how many icons are built into the ImageList
  FShortcutImageCount := ilShortcuts.Count;

  RebuildMenu;
  FMenuShowing := False;

  // As IM_Start is the launch point for all IM apps, we should indicate
  // which support libraries are available in the About dialog

  // These next are all lazy singletons:
  // IncludeAttribution is an empty call to enforce creation
  QPDF.IncludeAttribution;
  Poppler.IncludeAttribution;
  LibmpvDLL.IncludeAttribution;
  XPDF.IncludeAttribution;
  Tesseract.IncludeAttribution;
  FFmpeg.IncludeAttribution;

  // These items are always available, but only only shown when specifically
  // Included
  ThirdParties.Include([THIRDPARTY_LAZSERIAL, THIRDPARTY_IMAGEMAGICK,
    THIRDPARTY_ZEOS, THIRDPARTY_BGRABITMAP, THIRDPARTY_TURBOPOWER_IPRO,
    THIRDPARTY_WGS84]);
End;

Procedure TfrmIMStart.FormDestroy(Sender: TObject);
Begin
  FreeAndNil(FTokens);
  FreeAndNil(FShortcutInfos);
End;

Procedure TfrmIMStart.TrayIconClick(Sender: TObject);
Var
  P: TPoint;
Begin
  If FMenuShowing Then
    Exit;

  FMenuShowing := True;
  Try
    {$IFDEF Windows}
    SetForegroundWindow(Handle);
    {$ENDIF}

    GetCursorPos(P);
    pmShortcuts.Popup(P.X, P.Y);

    {$IFDEF Windows}
    PostMessage(Handle, WM_NULL, 0, 0);
    {$ENDIF}
  Finally
    FMenuShowing := False;
  End;
End;

Procedure TfrmIMStart.SetTrayIcon(AImageIndex: Integer);
Var
  LIcon: TIcon;
Begin
  LIcon := TIcon.Create;
  Try
    ilShortcuts.GetIcon(AImageIndex, LIcon);
    TrayIcon.Icon.Assign(LIcon);
  Finally
    LIcon.Free;
  End;
End;

//------------------
Procedure TfrmIMStart.LoadShortcuts;
Var
  sl: TStringList;
  i, iIndex: Integer;
  sLine, sSectionName, sCaptionText, sCommandText: String;
  sExeName, sParams, sLeft, sRight: String;
Begin
  // Remove dynamically added icons
  While ilShortcuts.Count > FShortcutImageCount Do
    ilShortcuts.Delete(ilShortcuts.Count - 1);

  FShortcutInfos.Clear;
  FTokens.Clear;

  If Not FileExists(FShortcutsFile) Then
    Exit;

  sl := TStringList.Create;
  Try
    sl.LoadFromFile(FShortcutsFile);

    // In case the user never defines a section...
    sSectionName := SECTION_DEFAULT;

    For i := 0 To sl.Count - 1 Do
    Begin
      sLine := ExpandFile(Trim(sl[i]));

      // Skip blank lines
      If sLine = '' Then
        Continue;

      // Skip comments
      If (sLine[1] = '#') Or (sLine[1] = ';') Then
        Continue;

      // Define section heading (may be nested ie "section\subsection"
      If (sLine[1] = '[') And (sLine[Length(sLine)] = ']') Then
      Begin
        sSectionName := Trim(Copy(sLine, 2, Length(sLine) - 2));

        // Let the user know what we are currently loading
        // This is temporary
        TrayIcon.Hint := sSectionName;

        // Normalize separators
        sSectionName := StringReplace(sSectionName, '/', '\', [rfReplaceAll]);

        Continue;
      End;

      // Build up the tokens
      // These need to be defined early in the Shortcuts file, we only parse the file once
      If SameText(sSectionName, 'Tokens') Then
      Begin
        iIndex := Pos('=', sLine);

        If iIndex > 0 Then
        Begin
          sLeft := Trim(Copy(sLine, 1, iIndex - 1));
          sRight := Trim(Copy(sLine, iIndex + 1, MaxInt));

          FTokens.Values[sLeft] := sRight;
        End;

        Continue;
      End;

      // Add seperator
      If sLine = '-' Then
      Begin
        AddSeparatorToMenu(sSectionName);
        Continue;
      End;

      // What's left must be shortcut, try and load this...
      iIndex := Pos('=', sLine);

      If iIndex > 0 Then
      Begin
        sCaptionText := Trim(Copy(sLine, 1, iIndex - 1));
        sCommandText := Trim(Copy(sLine, iIndex + 1, MaxInt));
      End
      Else
      Begin
        sCaptionText := '';
        sCommandText := sLine;
      End;

      sCommandText := ExpandShortcutTokens(sCommandText);

      // Only add the shortcut to the menu if it's valid
      If ExtractExeAndParams(sCommandText, sExeName, sParams) Then
        AddShortcutToMenu(sSectionName, sCaptionText, sExeName, sParams);
    End;

  Finally
    sl.Free;
  End;

  TrayIcon.Hint := Application.Title;
End;

Function TfrmIMStart.ExpandShortcutTokens(Const AText: String): String;
Var
  i: Integer;
  sTokenName, sTokenValue: String;
Begin
  Result := AText;

  // This only expands user-defined [Tokens].

  For i := 0 To FTokens.Count - 1 Do
  Begin
    sTokenName := Trim(FTokens.Names[i]);
    sTokenValue := Trim(FTokens.ValueFromIndex[i]);

    If sTokenName <> '' Then
      Result := StringReplace(Result, '<' + sTokenName + '>',
        sTokenValue, [rfReplaceAll, rfIgnoreCase]);
  End;
End;

Function TfrmIMStart.ExtractExeAndParams(Const ALine: String;
  out AExe, AParams: String): Boolean;
Var
  s: String;
  P: SizeInt;
Begin
  Result := False;
  AExe := '';
  AParams := '';

  s := Trim(ALine);
  If s = '' Then
    Exit;

  // Allow comments in shortcuts.text.
  If (s[1] = '#') Or (s[1] = ';') Then
    Exit;

  If s[1] = '"' Then
  Begin
    P := PosEx('"', s, 2);
    If P = 0 Then
      Exit;

    AExe := Copy(s, 2, P - 2);
    AParams := Trim(Copy(s, P + 1, MaxInt));
  End
  Else
  Begin
    // Fallback for unquoted paths with no spaces.
    P := Pos(' ', s);
    If P = 0 Then
      AExe := s
    Else
    Begin
      AExe := Copy(s, 1, P - 1);
      AParams := Trim(Copy(s, P + 1, MaxInt));
    End;
  End;

  Result := AExe <> '';
End;

Function TfrmIMStart.FindOrCreateFolderMenu(Const AFolder: String): TMenuItem;

  Function FindOrCreateChildMenu(AParent: TMenuItem; Const ACaption: String): TMenuItem;
  Var
    i: Integer;
  Begin
    For i := 0 To AParent.Count - 1 Do
      If SameText(AParent.Items[i].Caption, ACaption) Then
        Exit(AParent.Items[i]);

    Result := TMenuItem.Create(pmShortcuts);
    Result.Caption := ACaption;
    Result.ImageIndex := ICON_FOLDER;
    AParent.Add(Result);
  End;

Var
  slParts: TStringList;
  i: Integer;
  oParent, oChild: TMenuItem;
Begin
  slParts := TStringList.Create;
  Try
    slParts.Delimiter := '\';
    slParts.StrictDelimiter := True;
    slParts.DelimitedText := AFolder;

    oParent := nil;

    For i := 0 To slParts.Count - 1 Do
    Begin
      If oParent = nil Then
      Begin
        // Top-level menu
        oParent := FindOrCreateChildMenu(pmShortcuts.Items, slParts[i]);
      End
      Else
      Begin
        // Submenu under oParent
        oChild := FindOrCreateChildMenu(oParent, slParts[i]);
        oParent := oChild;
      End;
    End;

    Result := oParent;
  Finally
    slParts.Free;
  End;
End;

Procedure TfrmIMStart.AddSeparatorToMenu(Const AMenu: String);
Var
  FolderMenu, Item: TMenuItem;
Begin
  If Trim(AMenu) = '' Then
    Exit;

  FolderMenu := FindOrCreateFolderMenu(AMenu);

  Item := TMenuItem.Create(pmShortcuts);
  Item.Caption := '-';
  FolderMenu.Add(Item);
End;

// TODO FileSupport?
Function IsURL(Const AInput: String): Boolean;
Begin
  Result :=
    AInput.StartsWith('http://', True) Or AInput.StartsWith('https://', True) Or
    AInput.StartsWith('sharepoint:', True);
End;

Procedure TfrmIMStart.AddShortcutToMenu(Const AMenu, ACaption, AExe, AParams: String);
Var
  oInfo: TShortcutInfo;
  oFolderMenu, oItem: TMenuItem;
  bFile, bFolder, bURL: Boolean;
  icoTemp: TIcon;
Begin
  bFile := FileExists(AExe);
  bFolder := DirectoryExists(AExe);
  bURL := IsURL(AExe);

  If Not bFile And Not bFolder And Not bURL Then
    Exit;

  oInfo := TShortcutInfo.Create;
  oInfo.MenuName := AMenu;
  oInfo.ExeName := AExe;
  oInfo.Params := AParams;

  If bURL Then
    oInfo.WorkDir := ''   // URLs have no working directory
  Else
    oInfo.WorkDir := ExtractFilePath(AExe);

  If Trim(ACaption) <> '' Then
    oInfo.Caption := Trim(ACaption)
  Else
    oInfo.Caption := ExtractFileNameOnly(AExe);

  FShortcutInfos.Add(oInfo);

  If Trim(AMenu) <> '' Then
    oFolderMenu := FindOrCreateFolderMenu(AMenu)
  Else
    oFolderMenu := FindOrCreateFolderMenu(SECTION_DEFAULT);

  oItem := TMenuItem.Create(pmShortcuts);
  If Trim(ACaption) <> '' Then
    oItem.Caption := Trim(ACaption)
  Else
    oItem.Caption := ExtractFileNameOnly(AExe);

  oItem.Hint := AExe + ' ' + AParams;
  oItem.Tag := PtrInt(oInfo);
  oItem.OnClick := @RunShortcut;

  If bURL Then
    oItem.ImageIndex := ICON_IE
  Else
  Begin
    icoTemp := GetShellSmallIcon(AExe);
    Try
      If Assigned(icoTemp) Then
        oItem.ImageIndex := ilShortcuts.AddIcon(icoTemp);
    Finally
      icoTemp.Free;
    End;
  End;

  oFolderMenu.Add(oItem);
End;

Procedure TfrmIMStart.RebuildMenu;

  Function HasUsefulChildren(AMenu: TMenuItem): Boolean;
  Var
    i: Integer;
  Begin
    Result := False;

    For i := 0 To AMenu.Count - 1 Do
      If AMenu.Items[i].Caption <> '-' Then
        Exit(True);
  End;

  // Dynamic loading can leave empty section menus when their files
  // do not exist. Remove those unused sections recursively.
  Procedure ClearUnusedMenuItems(AParent: TMenuItem);
  Var
    oMenu: TMenuItem;
    i: Integer;
  Begin
    For i := AParent.Count - 1 Downto 0 Do
    Begin
      oMenu := AParent.Items[i];

      If oMenu.Caption = '-' Then
        Continue;

      // First remove any empty folders below this one
      ClearUnusedMenuItems(oMenu);

      // Then this folder may itself have become empty
      If (oMenu.ImageIndex = ICON_FOLDER) And (Not HasUsefulChildren(oMenu)) Then
      Begin
        AParent.Delete(i);
        oMenu.Free;
      End;
    End;
  End;

Var
  Item, mnuApp: TMenuItem;
Begin
  SetTrayIcon(ICON_TRAY_DISABLED);
  Try
    pmShortcuts.Items.Clear;

    // Parses the full Shortcuts file once, but doesn't load shortcuts for
    // files that don't exist
    LoadShortcuts;

    // This clears Menu Sections that were created from the Shortcuts file, but which
    // didn't have any valid shortcuts loaded
    ClearUnusedMenuItems(pmShortcuts.Items);

    If FShortcutInfos.Count = 0 Then
    Begin
      Item := TMenuItem.Create(pmShortcuts);
      Item.Caption := 'No shortcuts found';
      Item.Enabled := False;
      pmShortcuts.Items.Add(Item);
    End;

    // Now add the application menus
    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := '-';
    pmShortcuts.Items.Add(Item);

    mnuApp := TMenuItem.Create(pmShortcuts);
    mnuApp.Caption := 'IM Start';
    mnuApp.ImageIndex := 11;
    pmShortcuts.Items.Add(mnuApp);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := 'About';
    Item.OnClick := @DoAbout;
    Item.ImageIndex := 11;
    mnuApp.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := '-';
    mnuApp.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := 'Edit shortcuts';
    Item.OnClick := @EditShortcuts;
    Item.ImageIndex := 3;
    mnuApp.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := '-';
    mnuApp.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := 'Open shortcuts.txt';
    Item.OnClick := @OpenShortcutsFile;
    Item.Enabled := FileExists(FShortcutsFile);
    Item.ImageIndex := 3;
    mnuApp.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := 'Reload shortcuts';
    Item.OnClick := @ReloadShortcuts;
    Item.ImageIndex := 9;
    mnuApp.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := '-';
    mnuApp.Add(Item);

    Item := TMenuItem.Create(pmShortcuts);
    Item.Caption := 'Exit';
    Item.OnClick := @ExitApp;
    Item.ImageIndex := 10;
    mnuApp.Add(Item);
  Finally
    SetTrayIcon(ICON_TRAY_ENABLED);
  End;
End;

Procedure TfrmIMStart.RunShortcut(Sender: TObject);
Var
  oInfo: TShortcutInfo;
Begin
  If Not (Sender Is TMenuItem) Then
    Exit;

  oInfo := TShortcutInfo(TMenuItem(Sender).Tag);
  If Not Assigned(oInfo) Then
    Exit;

  If DirectoryExists(oInfo.ExeName) Then
    LaunchDocument(oInfo.ExeName)
  Else If SameText(ExtractFileExt(oInfo.ExeName), '.exe') Then
    LaunchExternalTool(oInfo.ExeName, oInfo.Params)
  Else
    LaunchDocument(oInfo.ExeName);
End;

Procedure TfrmIMStart.OpenShortcutsFile(Sender: TObject);
Begin
  LaunchDocument(FShortcutsFile);
End;

Procedure TfrmIMStart.DoAbout(Sender: TObject);
Begin
  FormAbout.ShowAbout;
End;

Procedure TfrmIMStart.ReloadShortcuts(Sender: TObject);
Begin
  RebuildMenu;
End;

Procedure TfrmIMStart.EditShortcuts(Sender: TObject);
Var
  frmEditor: TfrmEditor;
Begin
  frmEditor := TfrmEditor.Create(Self);
  frmEditor.Filename := FShortcutsFile;
  Try
    If frmEditor.ShowModal = mrOk Then
      RebuildMenu;
  Finally
    frmEditor.Free;
  End;
End;

Procedure TfrmIMStart.ExitApp(Sender: TObject);
Begin
  Application.Terminate;
End;

End.
