unit KM_Game;
{$I KaM_Remake.inc}
interface
uses Windows,
  {$IFDEF WDC} MPlayer, {$ENDIF}
  Forms, Controls, Classes, Dialogs, SysUtils, KromUtils, Math,
  KM_CommonTypes, KM_Defaults, KM_Utils, 
  KM_Controls, KM_GameInputProcess, KM_PlayersCollection, KM_Render, KM_LoadLib, KM_InterfaceMapEditor, KM_InterfaceGamePlay, KM_InterfaceMainMenu,
  KM_ResourceGFX, KM_Terrain, KM_LoadDAT, KM_Projectiles, KM_Sound, KM_Viewport, KM_Units, KM_Settings, KM_Music;

type TGameState = ( gsNoGame, //No game running at all, MainMenu
                    gsPaused, //Game is paused and responds to 'P' key only
                    gsOnHold, //Game is paused, shows victory options (resume, win) and responds to mouse clicks only
                    gsRunning, //Game is running normally
                    gsReplay,  //Game is showing replay, no player input allowed
                    gsEditor); //Game is in MapEditor mode

type
  TKMGame = class
  private
    ScreenX,ScreenY:word;
    FormControlsVisible:boolean;
    SelectingTroopDirection:boolean;
    SelectingDirPosition: TPoint;
    SelectedDirection: TKMDirection;
    GlobalTickCount:cardinal; //Not affected by Pause and anything
    fGameplayTickCount:cardinal;
    fGameName:string;
    fMissionFile:string; //Remember what we are playing incase we might want to replay
    ID_Tracker:cardinal; //Mainly Units-Houses tracker, to issue unique numbers on demand
    ActiveCampaign:TCampaign; //Campaign we are playing
    ActiveCampaignMap:byte; //Map of campaign we are playing, could be different than MaxRevealedMap
  public
    GameSpeed:integer;
    GameState:TGameState;
    fGameInputProcess:TGameInputProcess;
    fProjectiles:TKMProjectiles;
    fMusicLib: TMusicLib;
    fGlobalSettings: TGlobalSettings;
    fCampaignSettings: TCampaignSettings;
    fMainMenuInterface: TKMMainMenuInterface;
    fGamePlayInterface: TKMGamePlayInterface;
    fMapEditorInterface: TKMapEdInterface;
    constructor Create(ExeDir:string; RenderHandle:HWND; aScreenX,aScreenY:integer; aMediaPlayer:TMediaPlayer; NoMusic:boolean=false);
    destructor Destroy; override;
    procedure ToggleLocale();
    procedure ResizeGameArea(X,Y:integer);
    procedure ZoomInGameArea(X:single);
    procedure ToggleFullScreen(aToggle:boolean; ReturnToOptions:boolean);
    procedure KeyUp(Key: Word; Shift: TShiftState; IsDown:boolean=false);
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
    procedure MouseMove(Shift: TShiftState; X,Y: Integer);
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; X,Y: Integer);

    procedure GameInit();
    procedure GameStart(aMissionFile, aGameName:string; aCamp:TCampaign=cmp_Nil; aCampMap:byte=1);
    procedure GameError(aLoc:TKMPoint; aText:string); //Stop the game because of an error ()
    procedure GamePause(DoPause:boolean); //Set game on pause during gameplay
    procedure GameHold(DoHold:boolean); //Hold the game to ask if player wants to play after Victory
    procedure GameStop(const Msg:gr_Message; TextMsg:string='');

    procedure MapEditorStart(aMissionPath:string; aSizeX:integer=64; aSizeY:integer=64);
    procedure MapEditorSave(aMissionName:string; DoExpandPath:boolean);

    procedure ViewReplay(Sender:TObject);

    function GetMissionTime:cardinal;
    function CheckTime(aTimeTicks:cardinal):boolean;
    property GetTickCount:cardinal read fGameplayTickCount;
    property GetMissionFile:string read fMissionFile;
    property GetGameName:string read fGameName;
    property GetCampaign:TCampaign read ActiveCampaign;
    property GetCampaignMap:byte read ActiveCampaignMap;
    function GetNewID():cardinal;

    function Save(SlotID:shortint):string;
    function Load(SlotID:shortint):string;

    procedure UpdateState;
    procedure UpdateStateIdle(aFrameTime:cardinal);
    procedure PaintInterface;
  end;

  var
    fGame:TKMGame;

implementation
uses
  KM_Unit1, KM_Houses, KM_Player, KM_Units_Warrior;


{ Creating everything needed for MainMenu, game stuff is created on StartGame }
constructor TKMGame.Create(ExeDir:string; RenderHandle:HWND; aScreenX,aScreenY:integer; aMediaPlayer:TMediaPlayer; NoMusic:boolean=false);
begin
  ID_Tracker := 0;
  SelectingTroopDirection := false;
  SelectingDirPosition := Point(0,0);
  ScreenX := aScreenX;
  ScreenY := aScreenY;

  fGlobalSettings := TGlobalSettings.Create;
  fRender         := TRender.Create(RenderHandle);
  fTextLibrary    := TTextLibrary.Create(ExeDir+'data\misc\', fGlobalSettings.GetLocale);
  fSoundLib       := TSoundLib.Create(fGlobalSettings.GetLocale); //Required for button click sounds
  fMusicLib       := TMusicLib.Create(aMediaPlayer); //todo: @Krom: When I start the game with music disabled there is about 100ms of music which then cuts off. I assume the INI file is read after starting playback or something?
  fGlobalSettings.UpdateSFXVolume;
  fResource       := TResource.Create;
  fResource.LoadMenuResources(fGlobalSettings.GetLocale);

  fMainMenuInterface:= TKMMainMenuInterface.Create(ScreenX,ScreenY,fGlobalSettings);

  if not NoMusic then fMusicLib.PlayMenuTrack(not fGlobalSettings.IsMusic);

  fCampaignSettings := TCampaignSettings.Create; //todo: Init from INI
  GameSpeed := 1;
  GameState := gsNoGame;
  FormControlsVisible:=true;
  fLog.AppendLog('<== Game creation is done ==>');
end;


{ Destroy what was created }
destructor TKMGame.Destroy;
begin
  //Stop music imediently, so it doesn't keep playing and jerk while things closes
  fMusicLib.StopMusic;

  FreeAndNil(fCampaignSettings);
  FreeAndNil(fGlobalSettings);
  FreeAndNil(fMainMenuInterface);
  FreeAndNil(fResource);
  FreeAndNil(fSoundLib);
  FreeAndNil(fMusicLib);
  FreeAndNil(fTextLibrary);
  FreeAndNil(fRender);
  inherited;
end;


procedure TKMGame.ToggleLocale();
begin
  FreeAndNil(fMainMenuInterface);
  FreeAndNil(fTextLibrary);
  fTextLibrary := TTextLibrary.Create(ExeDir+'data\misc\', fGlobalSettings.GetLocale);
  fResource.LoadFonts(false, fGlobalSettings.GetLocale);
  fMainMenuInterface := TKMMainMenuInterface.Create(ScreenX, ScreenY, fGlobalSettings);
  fMainMenuInterface.ShowScreen_Options;
end;


procedure TKMGame.ResizeGameArea(X,Y:integer);
begin
  ScreenX:=X;
  ScreenY:=Y;
  fRender.RenderResize(X,Y,rm2D);
  if GameState in [gsPaused, gsRunning, gsReplay, gsEditor] then begin //If game is running
    fViewport.SetVisibleScreenArea(X,Y);
    if GameState in [gsPaused, gsRunning, gsReplay] then fGamePlayInterface.SetScreenSize(X,Y);
    if GameState in [gsEditor] then fMapEditorInterface.SetScreenSize(X,Y); 
    ZoomInGameArea(1);
  end else begin
    //Should resize all Controls somehow...
    //Remember last page and all relevant menu settings
    FreeAndNil(fMainMenuInterface);
    fMainMenuInterface:= TKMMainMenuInterface.Create(X,Y, fGlobalSettings);
    GameSpeed:=1;
    fMainMenuInterface.SetScreenSize(X,Y);
  end;
end;


procedure TKMGame.ZoomInGameArea(X:single);
begin
  if GameState in [gsRunning, gsReplay, gsEditor] then fViewport.SetZoom(X);
end;


procedure TKMGame.ToggleFullScreen(aToggle:boolean; ReturnToOptions:boolean);
begin
  Form1.ToggleFullScreen(aToggle, fGlobalSettings.GetResolutionID, ReturnToOptions);
end;


procedure TKMGame.KeyUp(Key: Word; Shift: TShiftState; IsDown:boolean=false);
begin
  //List of conflicting keys:
  //F12 Pauses Execution and switches to debug
  //F10 sets focus on MainMenu1
  //F9 is the default key in Fraps for video capture
  //others.. unknown

  if not IsDown and ENABLE_DESIGN_CONTORLS and (Key = VK_F7) then
    MODE_DESIGN_CONTORLS := not MODE_DESIGN_CONTORLS;
  if not IsDown and ENABLE_DESIGN_CONTORLS and (Key = VK_F6) then
    SHOW_CONTROLS_OVERLAY := not SHOW_CONTROLS_OVERLAY;

  case GameState of
    gsNoGame:   if fMainMenuInterface.MyControls.KeyUp(Key, Shift, IsDown) then exit; //Exit if handled
    gsPaused:   if Key=ord('P') then begin //Ignore all keys if game is on 'Pause'
                  if IsDown then exit;
                  GamePause(false);
                  fGameplayInterface.ShowPause(false); //Hide pause overlay
                end;
    gsOnHold:   ; //Ignore all keys if game is on victory 'Hold', only accept mouse clicks
    gsRunning:  begin //Game is running normally
                  if fGameplayInterface.MyControls.KeyUp(Key, Shift, IsDown) then exit;

                  //Scrolling
                  if Key = VK_LEFT  then fViewport.ScrollKeyLeft  := IsDown;
                  if Key = VK_RIGHT then fViewport.ScrollKeyRight := IsDown;
                  if Key = VK_UP    then fViewport.ScrollKeyUp    := IsDown;
                  if Key = VK_DOWN  then fViewport.ScrollKeyDown  := IsDown;

                  if IsDown then exit;
                  if Key = VK_BACK then begin
                    //Backspace resets the zoom and view, similar to other RTS games like Dawn of War.
                    //This is useful because it is hard to find default zoom using the scroll wheel, and if not zoomed 100% things can be scaled oddly (like shadows)
                    fViewport.SetZoom(1);
                    Form1.TB_Angle.Position := 0;
                    Form1.TB_Angle_Change(Form1.TB_Angle);
                  end;
                  if Key = VK_F8 then begin
                    GameSpeed := fGlobalSettings.GetSpeedup+1-GameSpeed; //1 or 11
                    if not (GameSpeed in [1,fGlobalSettings.GetSpeedup]) then GameSpeed:=1; //Reset just in case
                    fGameplayInterface.ShowClock(GameSpeed = fGlobalSettings.GetSpeedup);
                  end;
                  if Key = ord('P') then begin
                    GamePause(true); //if running then pause
                    fGameplayInterface.ShowPause(true); //Display pause overlay
                  end;
                  if Key=ord('W') then
                    fTerrain.RevealWholeMap(MyPlayer.PlayerID);
                  if fGamePlayInterface <> nil then //Also send shortcut to GamePlayInterface if it is there
                    fGamePlayInterface.ShortcutPress(Key, IsDown);

                  {Thats my debug example}
                  if Key=ord('5') then fGameplayInterface.IssueMessage(msgText,'123',KMPoint(0,0));
                  if Key=ord('6') then fGameplayInterface.IssueMessage(msgHouse,'123',KMPointRound(fViewport.GetCenter));
                  if Key=ord('7') then fGameplayInterface.IssueMessage(msgUnit,'123',KMPoint(0,0));
                  if Key=ord('8') then fGameplayInterface.IssueMessage(msgHorn,'123',KMPoint(0,0));
                  if Key=ord('9') then fGameplayInterface.IssueMessage(msgQuill,'123',KMPoint(0,0));
                  if Key=ord('0') then fGameplayInterface.IssueMessage(msgScroll,'123',KMPoint(0,0));

                  if Key=ord('V') then begin fGame.GameHold(true); exit; end; //Instant victory
                end;
    gsReplay:   begin
                  if IsDown then exit;
                  if Key = VK_BACK then begin
                    //Backspace resets the zoom and view, similar to other RTS games like Dawn of War.
                    //This is useful because it is hard to find default zoom using the scroll wheel, and if not zoomed 100% things can be scaled oddly (like shadows)
                    fViewport.SetZoom(1);
                    Form1.TB_Angle.Position := 0;
                    Form1.TB_Angle_Change(Form1.TB_Angle);
                  end;
                  if Key = VK_F8 then begin
                    GameSpeed := fGlobalSettings.GetSpeedup+1-GameSpeed; //1 or 11
                    if not (GameSpeed in [1,fGlobalSettings.GetSpeedup]) then GameSpeed:=1; //Reset just in case
                    fGameplayInterface.ShowClock(GameSpeed = fGlobalSettings.GetSpeedup);
                  end;
                end;
    gsEditor:   if fMapEditorInterface.MyControls.KeyUp(Key, Shift, IsDown) then exit;
  end;

  {Global hotkey for menu}
  if not IsDown and (Key=VK_F11) then begin
    Form1.ToggleControlsVisibility(FormControlsVisible);
    FormControlsVisible := not FormControlsVisible;
  end;

end;


procedure TKMGame.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var P: TKMPoint; MyRect: TRect; MOver:TKMControl; HitUnit: TKMUnit; HitHouse: TKMHouse;
begin
  case GameState of
    gsNoGame:   fMainMenuInterface.MyControls.MouseDown(X,Y,Button);
    gsPaused:   exit; //No clicking when paused
    gsOnHold:   exit; //No clicking when on hold
    gsReplay:   exit; //No clicking when replay goes .. ?
    gsRunning:  begin
                  fGameplayInterface.MyControls.MouseDown(X,Y,Button);
                  MOver := fGameplayInterface.MyControls.MouseOverControl;
                  P := GameCursor.Cell; //Get cursor position tile-wise

                  //These are only for testing purposes, Later on it should be changed a lot
                  if (Button = mbRight)
                    and(MOver = nil)
                    and(fGamePlayInterface <> nil)
                    and(not fGamePlayInterface.JoiningGroups)
                    and(fGamePlayInterface.GetShownUnit is TKMUnitWarrior)
                    and(TKMUnit(fGamePlayInterface.GetShownUnit).GetOwner = MyPlayer.PlayerID)
                    then
                  begin
                    //See if we are moving or attacking
                    HitUnit := fPlayers.UnitsHitTest(GameCursor.Cell.X, GameCursor.Cell.Y);
                    if (HitUnit <> nil) and (not (HitUnit is TKMUnitAnimal)) and
                       (fPlayers.CheckAlliance(MyPlayer.PlayerID, HitUnit.GetOwner) = at_Enemy) and
                      (fTerrain.Route_CanBeMade(TKMUnit(fGamePlayInterface.GetShownUnit).GetPosition, P, canWalk, true)) then
                    begin
                      //Place attack order here rather than in mouse up; why here??
                      fGameInputProcess.ArmyCommand(TKMUnitWarrior(fGamePlayInterface.GetShownUnit).GetCommander, gic_ArmyAttackUnit, HitUnit);
                    end
                    else
                    begin
                      HitHouse := fPlayers.HousesHitTest(GameCursor.Cell.X, GameCursor.Cell.Y);
                      if (HitHouse <> nil) and (not (HitHouse.IsDestroyed)) and
                         (fPlayers.CheckAlliance(MyPlayer.PlayerID, HitHouse.GetOwner) = at_Enemy) then
                      begin
                        fGameInputProcess.ArmyCommand(TKMUnitWarrior(fGamePlayInterface.GetShownUnit).GetCommander, gic_ArmyAttackHouse, HitHouse);
                      end
                      else
                      if (fTerrain.Route_CanBeMade(TKMUnit(fGamePlayInterface.GetShownUnit).GetPosition, P, canWalk, true)) then
                      begin
                        SelectingTroopDirection := true; //MouseMove will take care of cursor changing
                        //Record current cursor position so we can stop it from moving while we are setting direction
                        GetCursorPos(SelectingDirPosition); //First record it in referance to the screen pos for the clipcursor function
                        //Restrict cursor to a rectangle (half a rect in both axes)
                        MyRect := Rect(SelectingDirPosition.X-((DirCursorSqrSize-1) div 2),
                                       SelectingDirPosition.Y-((DirCursorSqrSize-1) div 2),
                                       SelectingDirPosition.X+((DirCursorSqrSize-1) div 2)+1,
                                       SelectingDirPosition.Y+((DirCursorSqrSize-1) div 2)+1);
                        ClipCursor(@MyRect);
                        //Now record it as Client XY
                        SelectingDirPosition := Point(X,Y);
                        SelectedDirection := dir_NA;
                      end;
                    end;
                  end
                  else
                  begin
                    if SelectingTroopDirection then
                      Form1.ApplyCursorRestriction; //Reset the cursor restrictions from selecting direction
                    SelectingTroopDirection := false;
                    fGamePlayInterface.ShowDirectionCursor(false);
                  end;
                end;
    gsEditor:   fMapEditorInterface.MyControls.MouseDown(X,Y,Button);
  end;
  MouseMove(Shift,X,Y);
end;


procedure TKMGame.MouseMove(Shift: TShiftState; X,Y: Integer);
var P:TKMPoint; HitUnit: TKMUnit; HitHouse: TKMHouse; DeltaX,DeltaY:shortint;
begin
  if InRange(X,1,ScreenX-1) and InRange(Y,1,ScreenY-1) then else exit; //Exit if Cursor is outside of frame

  case GameState of
    gsNoGame:   begin
                  fMainMenuInterface.MyControls.MouseMove(X,Y,Shift);
                  if fMainMenuInterface.MyControls.MouseOverControl is TKMTextEdit then // Show "CanEdit" cursor
                    Screen.Cursor := c_Info //@Lewin: Should be something else, any ideas?
                  else
                    Screen.Cursor := c_Default;
                  fMainMenuInterface.MouseMove(X,Y);
                end;
    gsPaused:   exit;
    gsOnHold:   begin
                  //@Lewin: any idea how do we send MouseOver to controls, but don't let them be pressed down
                  //@Krom: Could we modify the shift state so it doesn't see it as being pressed? I'm not sure I understand what you mean though.
                  //@Lewin: Here's the thing: in Victory state I want only 2 controls to be enabled, others should be disabled,
                  //but.. every control recieves MouseOver event, just try to move mouse with pressed button over any button while having a Victory and you see my concern 
                  //@Krom: Yeah, I see the difficulty. Looks like we'll have to add an exception for this case.
                  //       Idea: Perhaps we could set some kind of focus panel (normally nil, in this case the victory panel)
                  //       so events etc. will only be noticed for controls of that panel? (or all controls if it's nil) It could be a property of MyControls.
                  //       We'll probably find a use for that later so we can force the player to only use certain controls.
                  //@Lewin: I'd like to solve the case with minimal changes in code, or no at all.
                  fGameplayInterface.MyControls.MouseMove(X,Y,Shift);
                  if fGameplayInterface.MyControls.MouseOverControl()<>nil then
                    Screen.Cursor := c_Default
                end;
    gsRunning:  begin
                  if SelectingTroopDirection then
                  begin
                    DeltaX := SelectingDirPosition.X - X;
                    DeltaY := SelectingDirPosition.Y - Y;
                    //Compare cursor position and decide which direction it is
                    SelectedDirection := KMGetCursorDirection(DeltaX, DeltaY);
                    //Update the cursor based on this direction and negate the offset
                    fGamePlayInterface.ShowDirectionCursor(true,X+DeltaX,Y+DeltaY,SelectedDirection);
                    Screen.Cursor := c_Invisible;
                  end
                  else
                  begin
                  fGameplayInterface.MyControls.MouseMove(X,Y,Shift);
                  if fGameplayInterface.MyControls.MouseOverControl()<>nil then
                    Screen.Cursor := c_Default
                  else begin
                    fTerrain.ComputeCursorPosition(X,Y,Shift);
                    if CursorMode.Mode=cm_None then
                      if fGamePlayInterface.JoiningGroups and
                        (fGamePlayInterface.GetShownUnit is TKMUnitWarrior) then
                      begin
                        HitUnit  := MyPlayer.UnitsHitTest(GameCursor.Cell.X, GameCursor.Cell.Y);
                        if (HitUnit <> nil) and (not TKMUnitWarrior(HitUnit).IsSameGroup(TKMUnitWarrior(fGamePlayInterface.GetShownUnit))) and
                           (UnitGroups[byte(HitUnit.GetUnitType)] = UnitGroups[byte(fGamePlayInterface.GetShownUnit.GetUnitType)]) then
                          Screen.Cursor := c_JoinYes
                        else
                          Screen.Cursor := c_JoinNo;
                      end
                      else
                        if (MyPlayer.HousesHitTest(GameCursor.Cell.X, GameCursor.Cell.Y)<>nil)or
                           (MyPlayer.UnitsHitTest(GameCursor.Cell.X, GameCursor.Cell.Y)<>nil) then
                          Screen.Cursor := c_Info
                        else
                        if fGamePlayInterface.GetShownUnit is TKMUnitWarrior then
                        begin
                          HitUnit  := fPlayers.UnitsHitTest (GameCursor.Cell.X, GameCursor.Cell.Y);
                          HitHouse := fPlayers.HousesHitTest(GameCursor.Cell.X, GameCursor.Cell.Y);
                          if (fTerrain.CheckTileRevelation(GameCursor.Cell.X, GameCursor.Cell.Y, MyPlayer.PlayerID)>0) and
                             (((HitUnit<>nil) and (not (HitUnit is TKMUnitAnimal)) and (fPlayers.CheckAlliance(MyPlayer.PlayerID, HitUnit.GetOwner) = at_Enemy))or
                              ((HitHouse<>nil) and (fPlayers.CheckAlliance(MyPlayer.PlayerID, HitHouse.GetOwner) = at_Enemy))) then
                            Screen.Cursor := c_Attack
                          else if not fViewport.Scrolling then
                            Screen.Cursor := c_Default;
                        end
                        else if not fViewport.Scrolling then
                          Screen.Cursor := c_Default;
                    fTerrain.UpdateCursor(CursorMode.Mode, GameCursor.Cell);
                  end;
                  end;
                end;
    gsReplay:   begin
                  fTerrain.ComputeCursorPosition(X,Y,Shift); //To show coords in status bar
                  fTerrain.UpdateCursor(CursorMode.Mode, GameCursor.Cell);
                end;
    gsEditor:   begin
                  fMapEditorInterface.MyControls.MouseMove(X,Y,Shift);
                  if fMapEditorInterface.MyControls.MouseOverControl()<>nil then
                    Screen.Cursor:=c_Default
                  else
                  begin
                    fTerrain.ComputeCursorPosition(X,Y,Shift);
                    if CursorMode.Mode=cm_None then
                      if (MyPlayer.HousesHitTest(GameCursor.Cell.X, GameCursor.Cell.Y)<>nil)or
                         (MyPlayer.UnitsHitTest(GameCursor.Cell.X, GameCursor.Cell.Y)<>nil) then
                        Screen.Cursor:=c_Info
                      else if not fViewport.Scrolling then
                        Screen.Cursor:=c_Default;
                    fTerrain.UpdateCursor(CursorMode.Mode,GameCursor.Cell);

                    if ssLeft in Shift then //Only allow placing of roads etc. with the left mouse button
                    begin
                      P := GameCursor.Cell; //Get cursor position tile-wise
                      case CursorMode.Mode of
                        cm_Road:  if fTerrain.CanPlaceRoad(P, mu_RoadPlan)  then MyPlayer.AddRoad(P,false);
                        cm_Field: if fTerrain.CanPlaceRoad(P, mu_FieldPlan) then MyPlayer.AddField(P,ft_Corn);
                        cm_Wine:  if fTerrain.CanPlaceRoad(P, mu_WinePlan)  then MyPlayer.AddField(P,ft_Wine);
                        //cm_Wall: if fTerrain.CanPlaceRoad(P, mu_WinePlan) then MyPlayer.AddField(P,ft_Wine);
                        cm_Erase: begin
                                    if fMapEditorInterface.GetShownPage = esp_Units then
                                      MyPlayer.RemUnit(P);
                                    if fMapEditorInterface.GetShownPage = esp_Buildings then
                                    begin
                                      MyPlayer.RemHouse(P,true,false,true);
                                      if fTerrain.Land[P.Y,P.X].TileOverlay = to_Road then
                                        fTerrain.RemRoad(P);
                                      if fTerrain.TileIsCornField(P) or fTerrain.TileIsWineField(P) then
                                        fTerrain.RemField(P);
                                    end;
                                  end;
                      end;
                    end;
                  end;
                end;
  end;

Form1.StatusBar1.Panels.Items[1].Text := 'Cursor: '+
                                         floattostr(round(GameCursor.Float.X*10)/10)+' '+
                                         floattostr(round(GameCursor.Float.Y*10)/10)+' | '+
                                         inttostr(GameCursor.Cell.X)+' '+
                                         inttostr(GameCursor.Cell.Y);
end;


procedure TKMGame.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var P:TKMPoint; MOver:TKMControl; HitUnit: TKMUnit; OldSelected: TObject; OldDirSelecting: boolean;
begin
  OldDirSelecting := SelectingTroopDirection;
  if SelectingTroopDirection then
  begin
    //Reset the cursor position as it will have moved during direction selection
    SetCursorPos(Form1.Panel5.ClientToScreen(SelectingDirPosition).X,Form1.Panel5.ClientToScreen(SelectingDirPosition).Y);
    Form1.ApplyCursorRestriction; //Reset the cursor restrictions from selecting direction
    SelectingTroopDirection := false; //As soon as mouse is released
    fGamePlayInterface.ShowDirectionCursor(false);
  end;

  case GameState of //Remember clicked control
    gsNoGame:   MOver := fMainMenuInterface.MyControls.MouseOverControl();
    gsPaused:   MOver := nil;
    gsOnHold:   MOver := fGameplayInterface.MyControls.MouseOverControl();
    gsRunning:  MOver := fGameplayInterface.MyControls.MouseOverControl();
    gsEditor:   MOver := fMapEditorInterface.MyControls.MouseOverControl();
    else        MOver := nil; //MOver should always be initialized
  end;

  if (MOver <> nil) and (MOver is TKMButton) and MOver.Enabled and TKMButton(MOver).MakesSound then fSoundLib.Play(sfx_click);

  case GameState of
    gsNoGame:   fMainMenuInterface.MyControls.MouseUp(X,Y,Button);
    gsPaused:   exit;
    gsOnHold:   if fGamePlayInterface.ActiveWhenPause(MOver) then fGameplayInterface.MyControls.MouseUp(X,Y,Button);
    gsRunning:
      begin
        P := GameCursor.Cell; //Get cursor position tile-wise
        if MOver <> nil then
          fGameplayInterface.MyControls.MouseUp(X,Y,Button)
        else begin

          if (Button = mbMiddle) and (fGameplayInterface.MyControls.MouseOverControl = nil) then
            MyPlayer.AddUnit(ut_HorseScout, GameCursor.Cell); //Add only when cursor is over the map

          if Button = mbLeft then //Only allow placing of roads etc. with the left mouse button
          begin
            case CursorMode.Mode of
              cm_None:
                if not fGamePlayInterface.JoiningGroups then
                begin
                  //You cannot select nil (or unit/house from other team) simply by clicking on the terrain
                  OldSelected := fPlayers.Selected;
                  if (not fPlayers.HitTest(GameCursor.Cell.X, GameCursor.Cell.Y)) or
                    ((fPlayers.Selected is TKMHouse) and (TKMHouse(fPlayers.Selected).GetOwner <> MyPlayer.PlayerID))or
                    ((fPlayers.Selected is TKMUnit) and (TKMUnit(fPlayers.Selected).GetOwner <> MyPlayer.PlayerID)) then
                    fPlayers.Selected := OldSelected;

                  if (fPlayers.Selected is TKMHouse) then
                    fGamePlayInterface.ShowHouseInfo(TKMHouse(fPlayers.Selected));

                  if (fPlayers.Selected is TKMUnit) then begin
                    fGamePlayInterface.ShowUnitInfo(TKMUnit(fPlayers.Selected));
                    if (fPlayers.Selected is TKMUnitWarrior) and (OldSelected <> fPlayers.Selected) then
                      fSoundLib.PlayWarrior(TKMUnit(fPlayers.Selected).GetUnitType, sp_Select);
                  end;
                end;
              cm_Road:  if fTerrain.Land[P.Y,P.X].Markup = mu_RoadPlan then
                          fGameInputProcess.BuildCommand(gic_BuildRemovePlan, P)
                        else
                          fGameInputProcess.BuildCommand(gic_BuildRoadPlan, P);

              cm_Field: if fTerrain.Land[P.Y,P.X].Markup = mu_FieldPlan then
                          fGameInputProcess.BuildCommand(gic_BuildRemovePlan, P)
                        else
                          fGameInputProcess.BuildCommand(gic_BuildFieldPlan, P);
              cm_Wine:  if fTerrain.Land[P.Y,P.X].Markup = mu_WinePlan then
                          fGameInputProcess.BuildCommand(gic_BuildRemovePlan, P)
                        else
                          fGameInputProcess.BuildCommand(gic_BuildWinePlan, P);
              cm_Wall:  if fTerrain.Land[P.Y,P.X].Markup = mu_WallPlan then
                          fGameInputProcess.BuildCommand(gic_BuildRemovePlan, P)
                        else
                          fGameInputProcess.BuildCommand(gic_BuildWallPlan, P);
              cm_Houses: if fTerrain.CanPlaceHouse(P, THouseType(CursorMode.Tag1)) then begin
                           fGameInputProcess.BuildCommand(gic_BuildHousePlan, P, THouseType(CursorMode.Tag1));
                           fSoundLib.Play(sfx_placemarker);
                           fGamePlayInterface.Build_SelectRoad;
                         end else
                           fSoundLib.Play(sfx_CantPlace,P,false,4.0);
              cm_Erase:
                begin
                  fPlayers.Selected := MyPlayer.HousesHitTest(GameCursor.Cell.X, GameCursor.Cell.Y); //Select the house irregardless of unit below/above
                  if MyPlayer.RemHouse(P,false,true) then //Ask wherever player wants to destroy own house
                  begin
                    //don't ask about houses that are not started, they are removed bellow
                    if TKMHouse(fPlayers.Selected).GetBuildingState <> hbs_Glyph then
                    begin
                      fGamePlayInterface.ShowHouseInfo(TKMHouse(fPlayers.Selected),true);
                      fSoundLib.Play(sfx_click);
                    end;
                  end;
                  if (not MyPlayer.RemPlan(P)) and (not MyPlayer.RemHouse(P,false,true)) then
                    fSoundLib.Play(sfx_CantPlace,P,false,4.0); //Otherwise there is nothing to erase
                  //Now remove houses that are not started
                  if MyPlayer.RemHouse(P,false,true) and (TKMHouse(fPlayers.Selected).GetBuildingState = hbs_Glyph) then
                  begin
                    fGameInputProcess.BuildCommand(gic_BuildRemoveHouse, P);
                    fSoundLib.Play(sfx_click);
                  end;
                end;

            end; //case CursorMode.Mode of..
            if fGamePlayInterface.JoiningGroups and (fGamePlayInterface.GetShownUnit <> nil) and
              (fGamePlayInterface.GetShownUnit is TKMUnitWarrior) then
            begin
              HitUnit  := MyPlayer.UnitsHitTest(GameCursor.Cell.X, GameCursor.Cell.Y);
              if (HitUnit <> nil) and (not TKMUnitWarrior(HitUnit).IsSameGroup(TKMUnitWarrior(fGamePlayInterface.GetShownUnit))) and
                 (UnitGroups[byte(HitUnit.GetUnitType)] = UnitGroups[byte(fGamePlayInterface.GetShownUnit.GetUnitType)]) then
              begin
                fGameInputProcess.ArmyCommand(TKMUnitWarrior(fGamePlayInterface.GetShownUnit), gic_ArmyLink, HitUnit);
                fGamePlayInterface.JoiningGroups := false;
                fGamePlayInterface.ShowUnitInfo(fGamePlayInterface.GetShownUnit); //Refresh unit display
                Screen.Cursor:=c_Default; //Reset cursor when mouse released
              end;
            end;
          end;
        end; //if MOver<>nil then else..

        //These are only for testing purposes, Later on it should be changed a lot
        if (Button = mbRight)
        and(MOver = nil)
        and(fGamePlayInterface <> nil)
        and(fGamePlayInterface.GetShownUnit <> nil)
        and(OldDirSelecting) //If this is false then we are not moving, possibly attacking
        and(SelectingDirPosition.x <> 0)
        and(fGamePlayInterface.GetShownUnit is TKMUnitWarrior)
        and(TKMUnit(fGamePlayInterface.GetShownUnit).GetOwner = MyPlayer.PlayerID)
        and(not fGamePlayInterface.JoiningGroups)
        and(fTerrain.Route_CanBeMade(TKMUnit(fGamePlayInterface.GetShownUnit).GetPosition, P, canWalk, true))
        then
        begin
          Screen.Cursor:=c_Default; //Reset cursor when mouse released
          fGameInputProcess.ArmyCommand(TKMUnitWarrior(fGamePlayInterface.GetShownUnit), gic_ArmyWalk, P, SelectedDirection);
        end;

        if (Button = mbRight) and (MOver = nil) then
        begin
          fGameplayInterface.RightClickCancel; //Right clicking closes some menus
          if (Screen.Cursor = c_JoinYes) or (Screen.Cursor = c_JoinNo) then
            Screen.Cursor:=c_Default; //Reset cursor if it was joining
        end;

      end; //gsRunning
    gsEditor: begin
                fTerrain.ComputeCursorPosition(X,Y,Shift); //Update the cursor position and shift state in case it's changed
                P := GameCursor.Cell; //Get cursor position tile-wise
                if MOver <> nil then
                  fMapEditorInterface.MyControls.MouseUp(X,Y,Button)
                else
                if Button = mbRight then
                  fMapEditorInterface.RightClick_Cancel
                else
                if Button = mbLeft then //Only allow placing of roads etc. with the left mouse button
                  case CursorMode.Mode of
                    cm_None:  begin
                                fPlayers.HitTest(GameCursor.Cell.X, GameCursor.Cell.Y);
                                if fPlayers.Selected is TKMHouse then
                                  fMapEditorInterface.ShowHouseInfo(TKMHouse(fPlayers.Selected));
                                if fPlayers.Selected is TKMUnit then
                                  fMapEditorInterface.ShowUnitInfo(TKMUnit(fPlayers.Selected));
                              end;
                    cm_Road:  if fTerrain.CanPlaceRoad(P, mu_RoadPlan) then MyPlayer.AddRoad(P,false);
                    cm_Field: if fTerrain.CanPlaceRoad(P, mu_FieldPlan) then MyPlayer.AddField(P,ft_Corn);
                    cm_Wine:  if fTerrain.CanPlaceRoad(P, mu_WinePlan) then MyPlayer.AddField(P,ft_Wine);
                    //cm_Wall:
                    cm_Houses:if fTerrain.CanPlaceHouse(P, THouseType(CursorMode.Tag1)) then
                              begin
                                MyPlayer.AddHouse(THouseType(CursorMode.Tag1),P);
                                fMapEditorInterface.Build_SelectRoad;
                              end;
                    cm_Height:; //handled in UpdateStateIdle
                    cm_Objects: fTerrain.SetTree(P, CursorMode.Tag1);
                    cm_Units: if fTerrain.CanPlaceUnit(P, TUnitType(CursorMode.Tag1)) then
                              begin //Check if we can really add a unit
                                if TUnitType(CursorMode.Tag1) in [ut_Serf..ut_Barbarian] then
                                  MyPlayer.AddUnit(TUnitType(CursorMode.Tag1), P, false)
                                else
                                  fPlayers.PlayerAnimals.AddUnit(TUnitType(CursorMode.Tag1), P, false);
                              end;
                    cm_Erase:
                              case fMapEditorInterface.GetShownPage of
                                esp_Terrain:    fTerrain.Land[P.Y,P.X].Obj := 255;
                                esp_Units:      begin
                                                  MyPlayer.RemUnit(P);
                                                  fPlayers.PlayerAnimals.RemUnit(P); //Animals are common for all
                                                end;
                                esp_Buildings:  begin
                                                  MyPlayer.RemHouse(P,true,false,true);
                                                  if fTerrain.Land[P.Y,P.X].TileOverlay = to_Road then
                                                    fTerrain.RemRoad(P);
                                                  if fTerrain.TileIsCornField(P) or fTerrain.TileIsWineField(P) then
                                                    fTerrain.RemField(P);
                                                end;
                              end;
                  end;
              end;
  end;

end;


procedure TKMGame.MouseWheel(Shift: TShiftState; WheelDelta: Integer; X, Y: Integer);
begin
  if (MOUSEWHEEL_ZOOM_ENABLE) and (fGame.GameState in [gsRunning,gsEditor]) and (fViewport<>nil) then
    fViewport.SetZoom(fViewport.Zoom+WheelDelta/2000);

  case GameState of //Remember clicked control
    gsNoGame:   fMainMenuInterface.MyControls.MouseWheel(X, Y, WheelDelta);
    gsPaused:   ;
    gsOnHold:   ;
    gsRunning:  fGameplayInterface.MyControls.MouseWheel(X, Y, WheelDelta);
    gsReplay:   fGameplayInterface.MyControls.MouseWheel(X, Y, WheelDelta);
    gsEditor:   fMapEditorInterface.MyControls.MouseWheel(X, Y, WheelDelta);
  end;

end;


procedure TKMGame.GameInit();
begin
  RandSeed := 4; //Sets right from the start since it affects TKMAllPlayers.Create and other Types
  GameSpeed := 1; //In case it was set in last run mission

  if fResource.GetDataState<>dls_All then begin
    fMainMenuInterface.ShowScreen_Loading('units and houses');
    fRender.Render;
    fResource.LoadGameResources();
    fMainMenuInterface.ShowScreen_Loading('tileset');
    fRender.Render;
    fRender.LoadTileSet();
  end;

  fMainMenuInterface.ShowScreen_Loading('initializing');
  fRender.Render;

  fViewport := TViewport.Create;
  fGamePlayInterface := TKMGamePlayInterface.Create;

  //Here comes terrain/mission init
  fTerrain := TTerrain.Create;
  fProjectiles := TKMProjectiles.Create;

  fViewport.SetZoom(1);
  fRender.RenderResize(ScreenX,ScreenY,rm2D);
  fViewport.SetVisibleScreenArea(ScreenX,ScreenY);

  fGameplayTickCount := 0; //Restart counter
end;


procedure TKMGame.GameStart(aMissionFile, aGameName:string; aCamp:TCampaign=cmp_Nil; aCampMap:byte=1);
var ResultMsg:string; fMissionParser: TMissionParser;
begin
  GameInit;

  //If input is empty - replay last map
  if aMissionFile <> '' then begin
    fMissionFile := aMissionFile;
    fGameName := aGameName;
    ActiveCampaign := aCamp;
    ActiveCampaignMap := aCampMap; //MapID is incremented in CampSettings and passed on to here from outside
  end;

  fLog.AppendLog('Loading DAT...');
  if CheckFileExists(fMissionFile,true) then
  begin
    //todo: Use exception trapping and raising system here similar to that used for load
    fMissionParser := TMissionParser.Create(mpm_Game);
    ResultMsg := fMissionParser.LoadDATFile(fMissionFile);
    FreeAndNil(fMissionParser);
    if ResultMsg<>'' then begin
      GameStop(gr_Error, ResultMsg);
      //Show all required error messages here
      exit;
    end;
    fLog.AppendLog('DAT Loaded');
  end
  else
  begin
    fTerrain.MakeNewMap(64, 64); //For debug we use blank mission
    fPlayers := TKMAllPlayers.Create(MAX_PLAYERS);
    MyPlayer := fPlayers.Player[1];
  end;
  Form1.StatusBar1.Panels[0].Text:='Map size: '+inttostr(fTerrain.MapX)+' x '+inttostr(fTerrain.MapY);
  fGamePlayInterface.EnableOrDisableMenuIcons(not (fPlayers.fMissionMode = mm_Tactic));

  fLog.AppendLog('Gameplay initialized',true);

  GameState := gsRunning;

  fGameInputProcess := TGameInputProcess.Create(gipRecording);
  Save(99); //Thats our base for a game record
  CopyFile(PChar(KMSlotToSaveName(99,'sav')), PChar(KMSlotToSaveName(99,'bas')), false);

  fLog.AppendLog('Gameplay recording initialized',true);
  RandSeed := 4; //Random after StartGame and ViewReplay should match
end;


{ Set viewport and save command log }
procedure TKMGame.GameError(aLoc:TKMPoint; aText:string);
begin
  //Negotiate duplicate calls for GameError
  if GameState = gsNoGame then exit;

  fViewport.SetCenter(aLoc.X, aLoc.Y);
  GamePause(true);
  SHOW_UNIT_ROUTES := true;
  SHOW_UNIT_MOVEMENT := true;
  if fTerrain.TileInMapCoords(aLoc.X, aLoc.Y) then
    fTerrain.Land[aLoc.Y, aLoc.X].IsUnit := 128;

  if MessageDlg(
  '  An error has occoured during gameplay. '+UpperCase(aText)+eol+
  '  Please send the files save99.bas, save99.sav and save99.rpl from your KaM Remake\Save folder to the developers. '+
  'Contact details can be found in the Readme file. Thank you very much for your kind help!'+eol+eol+
  '  WARNING: Continuing to play after this error may cause further crashes and instabilities. Would you like to take this risk and continue playing?'
  , mtWarning, [mbYes, mbNo], 0) <> mrYes then
    fGame.GameStop(gr_Error,'') //Exit to main menu will save the Replay data
  else
    if (fGameInputProcess <> nil) and (fGameInputProcess.State = gipRecording) then
      fGameInputProcess.SaveToFile(KMSlotToSaveName(99,'rpl')); //Save replay data ourselves
end;


procedure TKMGame.GamePause(DoPause:boolean);
begin
  if GameState in [gsPaused, gsRunning, gsReplay] then
  if DoPause then
    GameState := gsPaused
  else
    GameState := gsRunning;
end;


//Put the game on Hold for Victory screen
procedure TKMGame.GameHold(DoHold:boolean);
begin
  if DoHold then begin
    fGame.GamePause(false); //Unpause game just in case
    fGame.fGameplayInterface.ShowPause(false);
  end;

  if GameState in [gsOnHold, gsRunning] then
  if DoHold then begin
    GameState := gsOnHold;
    fGame.fGamePlayInterface.ShowPlayMore(true);
  end else
    GameState := gsRunning;
end;


procedure TKMGame.GameStop(const Msg:gr_Message; TextMsg:string='');
begin
  GameState := gsNoGame;

  //Take results from MyPlayer before data is flushed
  if Msg in [gr_Win, gr_Defeat, gr_Cancel] then
    fMainMenuInterface.Fill_Results;

  if (fGameInputProcess <> nil) and (fGameInputProcess.State = gipRecording) then
    fGameInputProcess.SaveToFile(KMSlotToSaveName(99,'rpl'));
    
  FreeAndNil(fGameInputProcess);
  FreeAndNil(fPlayers);
  FreeAndNil(fProjectiles);
  FreeAndNil(fTerrain);

  FreeAndNil(fGamePlayInterface);  //Free both interfaces
  FreeAndNil(fMapEditorInterface); //Free both interfaces
  FreeAndNil(fViewport);
  ID_Tracker := 0; //Reset ID tracker

  case Msg of
    gr_Win    :  begin
                   fLog.AppendLog('Gameplay ended - Win',true);
                   fMainMenuInterface.ShowScreen_Results(Msg); //Mission results screen
                   fCampaignSettings.RevealMap(ActiveCampaign, ActiveCampaignMap+1);
                 end;
    gr_Defeat:   begin
                   fLog.AppendLog('Gameplay ended - Defeat',true);
                   fMainMenuInterface.ShowScreen_Results(Msg); //Mission results screen
                 end;
    gr_Cancel:   begin
                   fLog.AppendLog('Gameplay canceled',true);
                   fMainMenuInterface.ShowScreen_Results(Msg); //show the results so the user can see how they are going so far
                 end;
    gr_Error:    begin
                   fLog.AppendLog('Gameplay error',true);
                   fMainMenuInterface.ShowScreen_Error(TextMsg);
                 end;
    gr_Silent:   fLog.AppendLog('Gameplay stopped silently',true); //Used when loading new savegame from gameplay UI
    gr_MapEdEnd: begin
                   fLog.AppendLog('MapEditor closed',true);
                   fMainMenuInterface.ShowScreen_Main;
                 end;
  end;
end;


{Mission name accepted in 2 formats:
- absolute path, when opening a map from Form1.Menu
- relative, from Maps folder}
procedure TKMGame.MapEditorStart(aMissionPath:string; aSizeX:integer=64; aSizeY:integer=64);
var ResultMsg:string; fMissionParser:TMissionParser; i: integer;
begin
  if not FileExists(aMissionPath) and (aSizeX*aSizeY=0) then exit; //Erroneous call

  GameStop(gr_Silent); //Stop MapEd if we are loading from existing MapEd session

  RandSeed:=4; //Sets right from the start since it affects TKMAllPlayers.Create and other Types
  GameSpeed := 1; //In case it was set in last run mission

  if fResource.GetDataState<>dls_All then begin
    fMainMenuInterface.ShowScreen_Loading('units and houses');
    fRender.Render;
    fResource.LoadGameResources();
    fMainMenuInterface.ShowScreen_Loading('tileset');
    fRender.Render;
    fRender.LoadTileSet();
  end;

  fMainMenuInterface.ShowScreen_Loading('initializing');
  fRender.Render;

  fViewport := TViewport.Create;
  fMapEditorInterface := TKMapEdInterface.Create;

  //Here comes terrain/mission init
  fTerrain := TTerrain.Create;

  fLog.AppendLog('Loading DAT...');
  if FileExists(aMissionPath) then begin
    fMissionParser := TMissionParser.Create(mpm_Editor);
    ResultMsg := fMissionParser.LoadDATFile(aMissionPath);
    if ResultMsg<>'' then begin
      GameStop(gr_Error, ResultMsg);
      //Show all required error messages here
      exit;
    end;
    FreeAndNil(fMissionParser);
    fLog.AppendLog('DAT Loaded');
    fGameName := TruncateExt(ExtractFileName(aMissionPath));
  end else begin
    fTerrain.MakeNewMap(aSizeX, aSizeY);
    fPlayers := TKMAllPlayers.Create(MAX_PLAYERS); //Create MAX players
    MyPlayer := fPlayers.Player[1];
    MyPlayer.PlayerType := pt_Human; //Make Player1 human by default
    fGameName := 'New Mission';
  end;

  for i:=1 to MAX_PLAYERS do //Reveal all players since we'll swap between them in MapEd
    fTerrain.RevealWholeMap(TPlayerID(i));

  Form1.StatusBar1.Panels[0].Text:='Map size: '+inttostr(fTerrain.MapX)+' x '+inttostr(fTerrain.MapY);

  fLog.AppendLog('Gameplay initialized',true);

  fRender.RenderResize(ScreenX,ScreenY,rm2D);
  fViewport.SetVisibleScreenArea(ScreenX,ScreenY);
  fViewport.SetZoom(1);

  fGameplayTickCount := 0; //Restart counter

  GameState := gsEditor;
end;


//DoExpandPath means that input is a mission name which should be expanded into:
//ExeDir+'Maps\'+MissionName+'\'+MissionName.dat
//ExeDir+'Maps\'+MissionName+'\'+MissionName.map
procedure TKMGame.MapEditorSave(aMissionName:string; DoExpandPath:boolean);
var fMissionParser: TMissionParser;
begin
  if aMissionName = '' then exit;
  if DoExpandPath then begin
    CreateDir(ExeDir+'Maps');
    CreateDir(ExeDir+'Maps\'+aMissionName);
    fTerrain.SaveToMapFile(KMMapNameToPath(aMissionName, 'map'));
    fMissionParser := TMissionParser.Create(mpm_Editor);
    fMissionParser.SaveDATFile(KMMapNameToPath(aMissionName, 'dat'));
    FreeAndNil(fMissionParser);
    fGameName := aMissionName;
  end else
    Assert(false,'SaveMapEditor call with DoExpandPath=false');
end;


procedure TKMGame.ViewReplay(Sender:TObject);
begin
  CopyFile(PChar(KMSlotToSaveName(99,'bas')), PChar(KMSlotToSaveName(99,'sav')), false);
  Load(99); //We load what was saved right before starting Recording
  FreeAndNil(fGameInputProcess); //Override GIP from savegame
  
  fGameInputProcess := TGameInputProcess.Create(gipReplaying);
  fGameInputProcess.LoadFromFile(KMSlotToSaveName(99,'rpl'));

  RandSeed := 4; //Random after StartGame and ViewReplay should match
  GameState := gsReplay;
end;


function TKMGame.GetMissionTime:cardinal;
begin
  //Treat 10 ticks as 1 sec irregardless of user-set pace
  Result := MyPlayer.fMissionSettings.GetMissionTime + (GetTickCount div 10);
end;


//Tests whether time has past
function TKMGame.CheckTime(aTimeTicks:cardinal):boolean;
begin
  Result := (GetTickCount >= aTimeTicks);
end;


function TKMGame.GetNewID():cardinal;
begin
  inc(ID_Tracker);
  Result := ID_Tracker;
end;


//Saves the game and returns string for savegame name OR empty if save failed
//Base savegame gets copied from save99.bas
//Saves command log to RPL file
function TKMGame.Save(SlotID:shortint):string;
var
  SaveStream:TKMemoryStream;
  i:integer;
begin
  fLog.AppendLog('Saving game');
  case GameState of
    gsNoGame:   exit; //Don't need to save the game if we are in menu. Never call Save from menu anyhow
    gsEditor:   exit; //MapEd gets saved differently from SaveMapEd
    gsOnHold:   exit; //No sense to save from victory?
    gsReplay:   exit;
    gsPaused,gsRunning: //Can't save from Paused state yet, but we could add it later
    begin
      SaveStream := TKMemoryStream.Create;
      SaveStream.Write('KaM_Savegame');
      SaveStream.Write(SAVE_VERSION); //This is savegame version
      SaveStream.Write(fMissionFile); //Save game mission file
      SaveStream.Write(fGameName); //Save game title
      SaveStream.Write(fGameplayTickCount); //Required to be saved, e.g. messages being shown after a time
      SaveStream.Write(ID_Tracker); //Units-Houses ID tracker

      fTerrain.Save(SaveStream); //Saves the map
      fPlayers.Save(SaveStream); //Saves all players properties individually
      fProjectiles.Save(SaveStream);

      fViewport.Save(SaveStream); //Saves viewed area settings
      //Don't include fGameSettings.Save it's not required for settings are Game-global, not mission
      fGamePlayInterface.Save(SaveStream); //Saves message queue and school/barracks selected units

      CreateDir(ExeDir+'Saves\'); //Makes the folder incase it was deleted

      if SlotID = AUTOSAVE_SLOT then begin //Backup earlier autosaves
        DeleteFile(KMSlotToSaveName(AUTOSAVE_SLOT+5,'sav'));
        for i:=AUTOSAVE_SLOT+5 downto AUTOSAVE_SLOT+1 do //15 to 11
          RenameFile(KMSlotToSaveName(i-1,'sav'), KMSlotToSaveName(i,'sav'));
      end;

      SaveStream.SaveToFile(KMSlotToSaveName(SlotID,'sav')); //Some 70ms for TPR7 map
      SaveStream.Free;

      if SlotID <> AUTOSAVE_SLOT then begin //Backup earlier autosaves
        CopyFile(PChar(KMSlotToSaveName(99,'bas')), PChar(KMSlotToSaveName(SlotID,'bas')), false); //replace Replay base savegame
        fGameInputProcess.SaveToFile(KMSlotToSaveName(SlotID,'rpl')); //Adds command queue to savegame
      end;//

      Result := GetGameName + ' ' + int2time(GetMissionTime);
      if (fGlobalSettings.IsAutosave) and (SlotID = AUTOSAVE_SLOT) then
        Result := fTextLibrary.GetTextString(203); //Autosave
    end;
  end;
  fLog.AppendLog('Saving game',true);
end;


function TKMGame.Load(SlotID:shortint):string;
var
  LoadStream:TKMemoryStream;
  s,FileName:string;
begin
  fLog.AppendLog('Loading game');
  Result := '';
  FileName := KMSlotToSaveName(SlotID,'sav'); //Full path

  //Check if file exists early so that current game will not be lost if user tries to load an empty save
  if not FileExists(FileName) then
  begin
    Result := 'Savegame file not found';
    exit;
  end;

  if GameState in [gsRunning, gsPaused] then GameStop(gr_Silent);

  LoadStream := TKMemoryStream.Create; //Read data from file into stream
  case GameState of
    gsEditor, gsPaused, gsOnHold, gsRunning, gsReplay:   exit;
    gsNoGame: begin  //Load only from menu or stopped game
      try //Catch exceptions
        LoadStream.LoadFromFile(FileName);
        LoadStream.Seek(0, soFromBeginning);

        //Raise some exceptions if the file is invalid or the wrong save version
        LoadStream.Read(s); if s <> 'KaM_Savegame' then Raise Exception.Create('Not a valid KaM Remake save file');
        LoadStream.Read(s); if s <> SAVE_VERSION then Raise Exception.CreateFmt('Incompatible save version ''%s''. This version is ''%s''',[s,SAVE_VERSION]);

        //Create empty environment
        GameInit();

        //Substitute tick counter and id tracker
        LoadStream.Read(fMissionFile); //Savegame mission file
        LoadStream.Read(fGameName); //Savegame title
        LoadStream.Read(fGameplayTickCount);
        LoadStream.Read(ID_Tracker);

        fPlayers := TKMAllPlayers.Create(MAX_PLAYERS);
        MyPlayer := fPlayers.Player[1];

        //Load the data into the game
        fTerrain.Load(LoadStream);
        fPlayers.Load(LoadStream);
        fProjectiles.Load(LoadStream);

        fViewport.Load(LoadStream);
        fGamePlayInterface.Load(LoadStream);

        LoadStream.Free;

        fGameInputProcess := TGameInputProcess.Create(gipRecording);
        fGameInputProcess.LoadFromFile(KMSlotToSaveName(99,'rpl'));

        CopyFile(PChar(KMSlotToSaveName(SlotID,'bas')), PChar(KMSlotToSaveName(99,'bas')), false); //replace Replay base savegame

        fGamePlayInterface.EnableOrDisableMenuIcons(not (fPlayers.fMissionMode = mm_Tactic)); //Preserve disabled icons
        fPlayers.SyncLoad(); //Should parse all Unit-House ID references and replace them with actual pointers
        Result := ''; //Loading has now completed successfully :)
        Form1.StatusBar1.Panels[0].Text:='Map size: '+inttostr(fTerrain.MapX)+' x '+inttostr(fTerrain.MapY);
      except
        on E : Exception do
        begin
          //Trap the exception and show the user. Note: While debugging, Delphi will still stop execution for the exception, but normally the dialouge won't show.
          Result := 'An error was encountered while parsing the file '+FileName+'.|Details of the error:|'+
                        E.ClassName+' error raised with message: '+E.Message;
          if GameState in [gsRunning, gsPaused] then GameStop(gr_Silent); //Stop the game so that the main menu error can be shown
          exit;
        end;
      end;
    end;
  end;

  GameState := gsRunning;
  fLog.AppendLog('Loading game',true);
end;


procedure TKMGame.UpdateState;
var i:integer;
begin
  inc(GlobalTickCount);
  case GameState of
    gsPaused:   exit;
    gsOnHold:   exit;
    gsNoGame:   begin
                  fMainMenuInterface.UpdateState;
                  if GlobalTickCount mod 10 = 0 then //Once a sec
                  if fMusicLib.IsMusicEnded then
                    fMusicLib.PlayMenuTrack(not fGlobalSettings.IsMusic); //Menu tune
                  if DO_PERF_TEST and (GlobalTickCount >= 180) then
                    Form1.Close;
                end;
    gsRunning,
    gsReplay:   begin
                  for i:=1 to GameSpeed do
                  begin
                    inc(fGameplayTickCount); //Thats our tick counter for gameplay events
                    fTerrain.UpdateState;
                    fPlayers.UpdateState(fGameplayTickCount); //Quite slow
                    if GameState = gsNoGame then exit; //Quit the update if game was stopped by MyPlayer defeat
                    fProjectiles.UpdateState; //If game has stopped it's NIL

                    if (fGameplayTickCount mod 600 = 0) and fGlobalSettings.IsAutosave then //Each 1min of gameplay time
                      Save(AUTOSAVE_SLOT); //Autosave slot
                        
                    if GameState = gsReplay then
                      fGameInputProcess.Tick(fGameplayTickCount);

                    if DO_PERF_TEST and (fGameplayTickCount >= 1800) then
                      Form1.Close;
                  end;

                  fGamePlayInterface.UpdateState;

                  if GlobalTickCount mod 10 = 0 then //Every 1000ms
                    fTerrain.RefreshMinimapData(); //Since this belongs to UI it should refresh at UI refresh rate, not Terrain refresh (which is affected by game speed-up)

                  if GlobalTickCount mod 10 = 0 then
                    if fMusicLib.IsMusicEnded then
                      fMusicLib.PlayNextTrack(); //Feed new music track
                end;
    gsEditor:   begin
                  fMapEditorInterface.UpdateState;
                  fTerrain.IncAnimStep;
                  fPlayers.IncAnimStep;
                  if GlobalTickCount mod 10 = 0 then //Every 500ms
                    fTerrain.RefreshMinimapData(); //Since this belongs to UI it should refresh at UI refresh rate, not Terrain refresh (which is affected by game speed-up)
                end;
    end;

end;


{This is our real-time thread, use it wisely}
procedure TKMGame.UpdateStateIdle(aFrameTime:cardinal);
begin
  case GameState of
    gsRunning,
    gsReplay:   begin
                  fViewport.DoScrolling(aFrameTime); //Check to see if we need to scroll
                end;
    gsEditor:   begin
                  fViewport.DoScrolling(aFrameTime); //Check to see if we need to scroll
                  case CursorMode.Mode of
                    cm_Height:
                              if (ssLeft in GameCursor.SState) or (ssRight in GameCursor.SState) then
                              fTerrain.MapEdHeight(GameCursor.Float, CursorMode.Tag1, CursorMode.Tag2, ssLeft in GameCursor.SState);
                    cm_Tiles:
                              if (ssLeft in GameCursor.SState) then
                              fTerrain.MapEdTile(GameCursor.Cell, CursorMode.Tag1);
                  end;
                end;
  end;
end;


procedure TKMGame.PaintInterface;
begin
  case GameState of
    gsNoGame:  fMainMenuInterface.Paint;
    gsPaused:  fGameplayInterface.Paint;
    gsOnHold:  fGameplayInterface.Paint;
    gsRunning: fGameplayInterface.Paint;
    gsReplay:  fGameplayInterface.Paint;
    gsEditor:  fMapEditorInterface.Paint;
  end;
end;


end.
