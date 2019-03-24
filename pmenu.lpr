program pmenu;

{$mode objfpc}{$H+}

{$R 'sources.rc'}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  { you can add units after this }
  Classes, SysUtils, FileUtil, Controls, Graphics, Dialogs, LCLType,
  StdCtrls, Menus, Windows, ShellApi, InterfaceBase,
  laz2_DOM, laz2_XMLRead, laz2_XMLCfg, laz2_XMLUtils,
  laz_XMLStreaming;

{$R *.res}

type

  { TMenuItemX }

  TMenuItemX = class(TMenuItem)
  private
    FCmd: string;       // menu item shell command
    FCmdCtrl: string;   // command when CTRL key pressed
    FCmdShift: string;  // command when SHIFT key pressed
    FCmdHide: Boolean;  // start mode
    procedure OnClickProc(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
  end;

  { TPopupMenuX }

  TPopupMenuX = class(TPopupMenu)
  private
    procedure LoadSubMenu(MenuNode: TDOMNode; MenuItem: TMenuItemX);
  public
    procedure LoadMenu(ConfigFile: TFilename);
  end;

//--------------------------------------------------------------------------------------------------

var
  MainMenu: TPopupMenuX;
  // Hook for handle mouse events for close menu
  Hook: THandle;

//--------------------------------------------------------------------------------------------------

procedure CloseApp;
begin
  // close self application
  UnhookWindowsHookEx(Hook);
  Application.Terminate;
end;

function MessageHookProc(Code, wParam: Integer; var EventStrut: TEventMsg): Integer; stdcall;
begin
  // this is the JournalRecordProc
  Result := CallNextHookEx(Hook, Code, wParam, Longint(@EventStrut));
  // the CallNextHookEX is not really needed for journal hook since it it not
  // really in a hook chain, but it's standard for a Hook}
  if Code < 0 then Exit;
  // we should cancel operation if you get HC_SYSMODALON
  if Code = HC_SYSMODALON then Exit;
  if Code = HC_ACTION then
   begin
    if (EventStrut.message = WM_LBUTTONUP) or (EventStrut.message =  WM_LBUTTONDOWN) or
       (EventStrut.message = WM_RBUTTONDOWN) or (EventStrut.message = WM_RBUTTONUP) then
      CloseApp;
  end;
end;

{ TPopupMenuX }

procedure TPopupMenuX.LoadSubMenu(MenuNode: TDOMNode; MenuItem: TMenuItemX);
var
  NewMenuItem: TMenuItemX;
  Attr: TDOMNode;
  i: Integer;
begin
  // load menu from XML node
  if (LowerCase(MenuNode.NodeName) = 'comment') then
     Exit;
  if (LowerCase(MenuNode.NodeName) <> 'menu') then
    begin
      MessageDlg('Error',
        'Error at read menu config (pmenu.xml), all nodes must have menu type',
         mtError, [mbOk], -1);
      CloseApp;
    end;
  NewMenuItem := TMenuItemX.Create(MainMenu);
  // read attributes
  // Caption
  NewMenuItem.Caption := MenuNode.Attributes.GetNamedItem('Caption').NodeValue;
  if NewMenuItem.Caption = '' then
    begin
      MessageDlg('Error',
        'Error at read menu config (pmenu.xml), menu items must have Caption attribute, except root.',
         mtError, [mbOk], -1);
      CloseApp;
    end;
  // Command / CommandCtrl / CommandShift
  Attr := MenuNode.Attributes.GetNamedItem('Command');
  if Attr <> nil then NewMenuItem.FCmd := Attr.NodeValue;
  Attr := MenuNode.Attributes.GetNamedItem('CommandCtrl');
  if Attr <> nil then NewMenuItem.FCmdCtrl := Attr.NodeValue;
  Attr := MenuNode.Attributes.GetNamedItem('CommandShift');
  if Attr <> nil then NewMenuItem.FCmdShift := Attr.NodeValue;
  // ExecHide
  Attr := MenuNode.Attributes.GetNamedItem('ExecHide');
  if (Attr <> nil) and (LowerCase(Attr.NodeValue) = 'true') then NewMenuItem.FCmdHide := True
    else NewMenuItem.FCmdHide := False;

  // add new item to menu
  MenuItem.Add(NewMenuItem);
  // load sub menu
  if MenuNode.HasChildNodes then
    for i := 0 to MenuNode.ChildNodes.Count-1 do
      LoadSubMenu(MenuNode.ChildNodes[i], NewMenuItem);
end;

procedure TPopupMenuX.LoadMenu(ConfigFile: TFilename);
var
  MenuNode: TDOMNode;
  ConfigDoc: TXMLDocument;
  i: Integer;
begin
  // read xml menu structure
  ReadXMLFile(ConfigDoc, ConfigFile);
  MenuNode := ConfigDoc.FirstChild;
  if MenuNode.NodeName = 'comment' then MenuNode := ConfigDoc.NextSibling;
  if (LowerCase(MenuNode.NodeName) = 'menu') and (MenuNode.HasChildNodes) then
    for i := 0 to MenuNode.ChildNodes.Count-1 do
      LoadSubMenu(MenuNode.ChildNodes[i], TMenuItemX(MainMenu.Items));
end;

//--------------------------------------------------------------------------------------------------

{ PPopupMenu }

procedure TMenuItemX.OnClickProc(Sender: TObject);
var
  State: TKeyboardState;
  ShowMode: Cardinal;
  procedure SplitCmdAndParams(CmdRaw: string; var Cmd: PChar; var Params: PChar);
  var
    p: Integer;
  begin
    // separate command from parameters
    CmdRaw := Trim(CmdRaw);
    p := Pos(' ', CmdRaw);
    if p = 0 then
      begin
        Cmd := PChar(CmdRaw);
        Params := nil;
      end
    else
      begin
        Cmd := PChar(Copy(CmdRaw, 0, p-1));
        Params := PChar(Copy(CmdRaw, p+1, Length(CmdRaw)-p+1));
      end;
  end;
  procedure ExecuteCommand(CmdRaw: string);
  var
    n, i: Integer;
    Cmds: TStringList;
    Cmd, Params: PChar;
  begin
    // execute one or many commands
    CmdRaw := Trim(CmdRaw);
    n := Pos('\n', CmdRaw);
    if n = 0 then
      begin
       // execute one command
       SplitCmdAndParams(FCmd, Cmd, Params);
       ShellExecute(0, nil, Cmd, Params, nil, ShowMode);
      end
    else
      begin
        // split commands list
        Cmds:= TStringList.Create;
        i := 0;
        while n > 0 do
          begin
            Cmds.Add(Copy(CmdRaw, 0, n-1));
            CmdRaw := Copy(CmdRaw, n+2, Length(CmdRaw)-n+2);
            n := Pos('\n', CmdRaw);
            if i > 255 then Break;
            Inc(i);
          end;
        Cmds.Add(CmdRaw);
        for i := 0 to Cmds.Count-1 do
          begin
            SplitCmdAndParams(Cmds[i], Cmd, Params);
            ShellExecute(0, nil, Cmd, Params, nil, ShowMode);
            if i < Cmds.Count-1 then Sleep(250);
          end;
      end;
  end;
begin
  UnhookWindowsHookEx(Hook);
  //
  GetKeyboardState(State);

  if FCmdHide then
    ShowMode := SW_HIDE
  else
    ShowMode := SW_SHOWNORMAL;

  if ((State[VK_CONTROL] and 128)<>0) then
    begin
      ShowMessage('VK_CONTROL')
    end
  else if ((State[VK_SHIFT] and 128)<>0) then
    begin
     ShowMessage('VK_SHIFT')
    end
  else   // normal
    ExecuteCommand(FCmd);
  //
  CloseApp;
end;

constructor TMenuItemX.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  OnClick := @OnClickProc;
end;

begin
  Application.Title:='PowerMenu';
  Application.Initialize;

  MainMenu := TPopupMenuX.Create(Application);
  MainMenu.LoadMenu('pmenu.xml');
  //MainMenu.OnClose := @MainMenuClose;


  Hook := SetWindowsHookEx(WH_JOURNALRECORD, HOOKPROC(@MessageHookProc), hInstance, 0);
  MainMenu.PopUp(Mouse.CursorPos.X, Mouse.CursorPos.Y);

  Application.Run;
end.

