unit KM_GUIMapEdTown;
{$I KaM_Remake.inc}
interface
uses
   Classes, Controls, KromUtils, Math, StrUtils, SysUtils,
   KM_Controls, KM_Defaults, KM_Pics, KM_Maps, KM_Houses, KM_Units, KM_UnitGroups, KM_MapEditor,
   KM_Points, KM_InterfaceDefaults, KM_AIAttacks, KM_AIGoals, KM_Terrain,
   KM_GUIMapEdTownHouses,
   KM_GUIMapEdTownUnits,
   KM_GUIMapEdTownScript,
   KM_GUIMapEdTownDefence,
   KM_GUIMapEdTownOffence;

type
  TKMTownTab = (ttHouses, ttUnits, ttScript, ttDefences, ttOffence);

  TKMMapEdTown = class
  private
    fOnPageChange: TNotifyEvent;

    fGuiHouses: TKMMapEdTownHouses;
    fGuiUnits: TKMMapEdTownUnits;
    fGuiScript: TKMMapEdTownScript;
    fGuiDefence: TKMMapEdTownDefence;
    fGuiOffence: TKMMapEdTownOffence;

    procedure PageChange(Sender: TObject);
  protected
    Panel_Town: TKMPanel;
    Button_Town: array [TKMTownTab] of TKMButton;
  public
    constructor Create(aParent: TKMPanel; aOnPageChange: TNotifyEvent);
    destructor Destroy; override;

    procedure Show;
    function Visible(aPage: TKMTownTab): Boolean; overload;
    function Visible: Boolean; overload;
    procedure UpdateState;
  end;


implementation
uses
  KM_CommonClasses, KM_PlayersCollection, KM_ResTexts, KM_Game, KM_Main, KM_GameCursor,
  KM_GameApp, KM_Resource, KM_TerrainDeposits, KM_ResCursors, KM_Utils,
  KM_AIDefensePos, KM_ResHouses, KM_RenderUI, KM_Sound, KM_ResSound,
  KM_ResWares, KM_ResFonts;

const
  GROUP_TEXT: array [TGroupType] of Integer = (
    TX_MAPED_AI_ATTACK_TYPE_MELEE, TX_MAPED_AI_ATTACK_TYPE_ANTIHORSE,
    TX_MAPED_AI_ATTACK_TYPE_RANGED, TX_MAPED_AI_ATTACK_TYPE_MOUNTED);

  GROUP_IMG: array [TGroupType] of Word = (
    371, 374,
    376, 377);


{Switch between pages}
procedure TKMapEdInterface.SwitchPage(Sender: TObject);
begin
  //Reset cursor mode
  GameCursor.Mode := cmNone;
  GameCursor.Tag1 := 0;

  //If the user clicks on the tab that is open, it closes it (main buttons only)
  if ((Sender = Button_Main[1]) and fGuiTerrain.Visible) or
     ((Sender = Button_Main[2]) and Panel_Town.Visible) or
     ((Sender = Button_Main[3]) and Panel_Player.Visible) or
     ((Sender = Button_Main[4]) and Panel_Mission.Visible) or
     ((Sender = Button_Main[5]) and Panel_Menu.Visible) then
    Sender := nil;

  //Reset shown item if user clicked on any of the main buttons
  if (Sender=Button_Main[1])or(Sender=Button_Main[2])or
     (Sender=Button_Main[3])or(Sender=Button_Main[4])or
     (Sender=Button_Main[5])or
     (Sender=Button_Menu_Settings)or(Sender=Button_Menu_Quit) then
    MySpectator.Selected := nil;

  if (Sender = Button_Main[1]) then
  begin
    HidePages;
    fGuiTerrain.Show;
  end
  else

  if (Sender = Button_Main[2]) or (Sender = Button_Town[ttHouses]) then
  begin
    Town_BuildRefresh;
    DisplayPage(Panel_Build);
  end else
  if (Sender = Button_Town[ttUnits]) then
    DisplayPage(Panel_Units)
  else
  if (Sender = Button_Town[ttScript]) then
    DisplayPage(Panel_Script)
  else
  if (Sender = Button_Town[ttDefences]) then
    DisplayPage(Panel_Defence)
  else
  if (Sender = Button_Town[ttOffence]) then
    DisplayPage(Panel_Offence)
  else

  if (Sender = Button_Main[3])or(Sender = Button_Player[ptGoals]) then
    DisplayPage(Panel_Goals)
  else
  if (Sender = Button_Player[ptColor]) then
    DisplayPage(Panel_Color)
  else
  if (Sender = Button_Player[ptBlockHouse]) then
    DisplayPage(Panel_BlockHouse)
  else
  if (Sender = Button_Player[ptBlockTrade]) then
    DisplayPage(Panel_BlockTrade)
  else
  if (Sender = Button_Player[ptMarkers]) then
    DisplayPage(Panel_Markers)
  else

  if (Sender = Button_Main[4])or(Sender = Button_Mission[1]) then
    DisplayPage(Panel_Mode)
  else
  if (Sender = Button_Mission[2]) then
    DisplayPage(Panel_Alliances)
  else
  if (Sender = Button_Mission[3]) then
    DisplayPage(Panel_PlayerTypes)
  else

  if (Sender = Button_Main[5]) or
     (Sender = Button_Quit_No) or
     (Sender = Button_LoadCancel) or
     (Sender = Button_SaveCancel) then
    DisplayPage(Panel_Menu)
  else
  if Sender = Button_Menu_Quit then
    DisplayPage(Panel_Quit)
  else
  if Sender = Button_Menu_Save then
    DisplayPage(Panel_Save)
  else
  if Sender = Button_Menu_Load then
  begin
    Menu_LoadUpdate;
    DisplayPage(Panel_Load)
  end;
end;


procedure TKMapEdInterface.HidePages;
var I,K: Integer;
begin
  //Hide all existing pages (2 levels)
  for I := 1 to Panel_Common.ChildCount do
  if Panel_Common.Childs[I] is TKMPanel then
  begin
    Panel_Common.Childs[I].Hide;
    for K := 1 to TKMPanel(Panel_Common.Childs[I]).ChildCount do
    if TKMPanel(Panel_Common.Childs[I]).Childs[K] is TKMPanel then
      TKMPanel(Panel_Common.Childs[I]).Childs[K].Hide;
  end;
end;


procedure TKMapEdInterface.DisplayPage(aPage: TKMPanel);
begin
  HidePages;

  if aPage = Panel_Build then
    Town_BuildRefresh
  else
  if aPage = Panel_Units then
    Town_UnitRefresh
  else
  if aPage = Panel_Script then
    Town_ScriptRefresh
  else
  if aPage = Panel_Defence then
  begin
    Town_DefenceAddClick(nil);
    Town_DefenceRefresh;
  end
  else
  if aPage = Panel_Offence then
    Attacks_Refresh
  else

  if aPage = Panel_Goals then
    Goals_Refresh
  else
  if aPage = Panel_Color then

  else
  if aPage = Panel_BlockHouse then
    Player_BlockHouseRefresh
  else
  if aPage = Panel_BlockTrade then
    Player_BlockTradeRefresh
  else
  if aPage = Panel_Markers then
    Player_MarkerClick(nil)
  else

  if aPage = Panel_Mode then
    Mission_ModeUpdate
  else
  if aPage = Panel_Alliances then
    Mission_AlliancesChange(nil)
  else
  if aPage = Panel_PlayerTypes then
    Mission_PlayerTypesUpdate
  else

  if aPage = Panel_Menu then
  else
  if aPage = Panel_Save then
  begin
    Edit_SaveName.Text := fGame.GameName;
    Menu_SaveClick(Edit_SaveName);
  end else
  if aPage = Panel_Load then
    Panel_Load.Show;

  //Display the panel (and its parents)
  fActivePage := aPage;
  if aPage <> nil then
    aPage.Show;

  //Update list of visible layers with regard to active page and checkboxes
  Layers_UpdateVisibility;
end;


procedure TKMapEdInterface.DisplayHint(Sender: TObject);
begin
  if (fPrevHint = Sender) then exit; //Hint didn't changed

  if (Sender = nil) or (TKMControl(Sender).Hint = '') then
  begin
    Label_Hint.Caption := '';
    Bevel_HintBG.Hide;
  end
  else
  begin
    Label_Hint.Caption := TKMControl(Sender).Hint;
    Bevel_HintBG.Show;
    Bevel_HintBG.Width := 8 + fResource.Fonts.GetTextSize(Label_Hint.Caption, Label_Hint.Font).X;
  end;

  fPrevHint := Sender;
end;


procedure TKMapEdInterface.Formations_Show(Sender: TObject);
var
  GT: TGroupType;
begin
  //Fill UI
  Image_FormationsFlag.FlagColor := gPlayers[MySpectator.PlayerIndex].FlagColor;
  for GT := Low(TGroupType) to High(TGroupType) do
  begin
    NumEdit_FormationsCount[GT].Value := gPlayers[MySpectator.PlayerIndex].AI.General.DefencePositions.TroopFormations[GT].NumUnits;
    NumEdit_FormationsColumns[GT].Value := gPlayers[MySpectator.PlayerIndex].AI.General.DefencePositions.TroopFormations[GT].UnitsPerRow;
  end;

  Panel_Formations.Show;
end;


procedure TKMapEdInterface.Formations_Close(Sender: TObject);
var
  GT: TGroupType;
begin
  Assert(Image_FormationsFlag.FlagColor = gPlayers[MySpectator.PlayerIndex].FlagColor, 'Cheap test to see if active player didn''t changed');

  if Sender = Button_Formations_Ok then
    //Save settings
    for GT := Low(TGroupType) to High(TGroupType) do
    begin
      gPlayers[MySpectator.PlayerIndex].AI.General.DefencePositions.TroopFormations[GT].NumUnits := NumEdit_FormationsCount[GT].Value;
      gPlayers[MySpectator.PlayerIndex].AI.General.DefencePositions.TroopFormations[GT].UnitsPerRow := NumEdit_FormationsColumns[GT].Value;
    end;

  Panel_Formations.Hide;
end;


//Update viewport position when user interacts with minimap
procedure TKMapEdInterface.Minimap_Update(Sender: TObject; const X,Y: Integer);
begin
  fGame.Viewport.Position := KMPointF(X,Y);
end;


constructor TKMapEdInterface.Create(aScreenX, aScreenY: Word);
var
  I: Integer;
begin
  inherited;

  fDragScrolling := False;
  fDragScrollingCursorPos.X := 0;
  fDragScrollingCursorPos.Y := 0;
  fDragScrollingViewportPos.X := 0;
  fDragScrollingViewportPos.Y := 0;
  fMaps := TKMapsCollection.Create(False);
  fMapsMP := TKMapsCollection.Create(True);

  //CompactMapElements;

  //Parent Page for whole toolbar in-game
  Panel_Main := TKMPanel.Create(fMyControls, 0, 0, aScreenX, aScreenY);

    TKMImage.Create(Panel_Main,0,   0,224,200,407); //Minimap place
    TKMImage.Create(Panel_Main,0, 200,224,400,404);
    TKMImage.Create(Panel_Main,0, 600,224,400,404);
    TKMImage.Create(Panel_Main,0,1000,224,400,404); //For 1600x1200 this is needed

    MinimapView := TKMMinimapView.Create(Panel_Main, 10, 10, 176, 176);
    MinimapView.OnChange := Minimap_Update;

    Label_MissionName := TKMLabel.Create(Panel_Main, 230, 10, 184, 10, NO_TEXT, fnt_Grey, taLeft);
    Label_Coordinates := TKMLabel.Create(Panel_Main, 230, 30, 'X: Y:', fnt_Grey, taLeft);
    Label_Stat := TKMLabel.Create(Panel_Main, 230, 50, 0, 0, '', fnt_Outline, taLeft);

    TKMLabel.Create(Panel_Main, TB_PAD, 190, TB_WIDTH, 0, gResTexts[TX_MAPED_PLAYERS], fnt_Outline, taLeft);
    for I := 0 to MAX_PLAYERS - 1 do
    begin
      Button_PlayerSelect[I]         := TKMFlatButtonShape.Create(Panel_Main, 8 + I*23, 210, 21, 21, IntToStr(I+1), fnt_Grey, $FF0000FF);
      Button_PlayerSelect[I].Tag     := I;
      Button_PlayerSelect[I].OnClick := Player_ChangeActive;
    end;
    Button_PlayerSelect[0].Down := True; //First player selected by default

  //Must be created before Hint so it goes over them
  Create_Extra;
  Create_Message;

    Bevel_HintBG := TKMBevel.Create(Panel_Main,224+32,Panel_Main.Height-23,300,21);
    Bevel_HintBG.BackAlpha := 0.5;
    Bevel_HintBG.Hide;
    Bevel_HintBG.Anchors := [akLeft, akBottom];

    Label_Hint := TKMLabel.Create(Panel_Main, 224 + 36, Panel_Main.Height - 21, 0, 0, '', fnt_Outline, taLeft);
    Label_Hint.Anchors := [akLeft, akBottom];

  Panel_Common := TKMPanel.Create(Panel_Main,TB_PAD,255,TB_WIDTH,768);

    {5 big tabs}
    Button_Main[1] := TKMButton.Create(Panel_Common, BIG_PAD_W*0, 0, BIG_TAB_W, BIG_TAB_H, 381, rxGui, bsGame);
    Button_Main[2] := TKMButton.Create(Panel_Common, BIG_PAD_W*1, 0, BIG_TAB_W, BIG_TAB_H, 589, rxGui, bsGame);
    Button_Main[3] := TKMButton.Create(Panel_Common, BIG_PAD_W*2, 0, BIG_TAB_W, BIG_TAB_H, 392, rxGui, bsGame);
    Button_Main[4] := TKMButton.Create(Panel_Common, BIG_PAD_W*3, 0, BIG_TAB_W, BIG_TAB_H, 441, rxGui, bsGame);
    Button_Main[5] := TKMButton.Create(Panel_Common, BIG_PAD_W*4, 0, BIG_TAB_W, BIG_TAB_H, 389, rxGui, bsGame);
    Button_Main[1].Hint := gResTexts[TX_MAPED_TERRAIN];
    Button_Main[2].Hint := gResTexts[TX_MAPED_VILLAGE];
    Button_Main[3].Hint := gResTexts[TX_MAPED_SCRIPTS_VISUAL];
    Button_Main[4].Hint := gResTexts[TX_MAPED_SCRIPTS_GLOBAL];
    Button_Main[5].Hint := gResTexts[TX_MAPED_MENU];
    for I := 1 to 5 do
      Button_Main[I].OnClick := SwitchPage;

{I plan to store all possible layouts on different pages which gets displayed one at a time}
{==========================================================================================}
  fGuiTerrain := TKMMapEdTerrain.Create(Panel_Common, PageChanged);
  Create_Town;
  Create_Player;
  Create_Mission;

  Create_Menu;
    Create_MenuSave;
    Create_MenuLoad;
    Create_MenuQuit;

  Create_Unit;

  fGuiHouse := TKMMapEdHouse.Create(Panel_Common);

  Create_Marker;

  Image_Extra := TKMImage.Create(Panel_Main, TOOLBAR_WIDTH, Panel_Main.Height - 48, 30, 48, 494);
  Image_Extra.Anchors := [akLeft, akBottom];
  Image_Extra.HighlightOnMouseOver := True;
  Image_Extra.OnClick := ExtraMessage_Switch;

  Image_Message := TKMImage.Create(Panel_Main, TOOLBAR_WIDTH, Panel_Main.Height - 48*2, 30, 48, 496);
  Image_Message.Anchors := [akLeft, akBottom];
  Image_Message.HighlightOnMouseOver := True;
  Image_Message.OnClick := ExtraMessage_Switch;
  Image_Message.Hide; //Hidden by default, only visible when a message is shown

  //Pages that need to be on top of everything
  Create_AttackPopUp;
  Create_FormationsPopUp;
  Create_GoalPopUp;

  fMyControls.OnHint := DisplayHint;

  DisplayPage(nil); //Update
end;


destructor TKMapEdInterface.Destroy;
begin
  fGuiHouse.Free;
  fGuiTerrain.Free;

  fMaps.Free;
  fMapsMP.Free;
  SHOW_TERRAIN_WIRES := false; //Don't show it in-game if they left it on in MapEd
  SHOW_TERRAIN_PASS := 0; //Don't show it in-game if they left it on in MapEd
  inherited;
end;


//Update Hint position and etc..
procedure TKMapEdInterface.Resize(X,Y: Word);
begin
  Panel_Main.Width := X;
  Panel_Main.Height := Y;
end;


{Build page}
procedure TKMapEdInterface.Create_Town;
const
  TabGlyph: array [TKMTownTab] of Word    = (391,   141,   62,        43,    53);
  TabRXX  : array [TKMTownTab] of TRXType = (rxGui, rxGui, rxGuiMain, rxGui, rxGui);
  TabHint : array [TKMTownTab] of Word = (
    TX_MAPED_VILLAGE,
    TX_MAPED_UNITS,
    TX_MAPED_AI_TITLE,
    TX_MAPED_AI_DEFENSE_OPTIONS,
    TX_MAPED_AI_ATTACK);
var
  I: Integer;
  VT: TKMTownTab;
begin
  Panel_Town := TKMPanel.Create(Panel_Common, 0, 45, TB_WIDTH, 28);

    for VT := Low(TKMTownTab) to High(TKMTownTab) do
    begin
      Button_Town[VT] := TKMButton.Create(Panel_Town, SMALL_PAD_W * Byte(VT), 0, SMALL_TAB_W, SMALL_TAB_H, TabGlyph[VT], TabRXX[VT], bsGame);
      Button_Town[VT].Hint := gResTexts[TabHint[VT]];
      Button_Town[VT].OnClick := SwitchPage;
    end;

    //Town placement
    Panel_Build := TKMPanel.Create(Panel_Town,0,28,TB_WIDTH,400);
      TKMLabel.Create(Panel_Build,0,PAGE_TITLE_Y,TB_WIDTH,0,gResTexts[TX_MAPED_ROAD_TITLE],fnt_Outline,taCenter);
      Button_BuildRoad   := TKMButtonFlat.Create(Panel_Build,  0,28,33,33,335);
      Button_BuildField  := TKMButtonFlat.Create(Panel_Build, 37,28,33,33,337);
      Button_BuildWine   := TKMButtonFlat.Create(Panel_Build, 74,28,33,33,336);
      Button_BuildCancel := TKMButtonFlat.Create(Panel_Build,148,28,33,33,340);
      Button_BuildRoad.OnClick  := Town_BuildChange;
      Button_BuildField.OnClick := Town_BuildChange;
      Button_BuildWine.OnClick  := Town_BuildChange;
      Button_BuildCancel.OnClick:= Town_BuildChange;
      Button_BuildRoad.Hint     := gResTexts[TX_BUILD_ROAD_HINT];
      Button_BuildField.Hint    := gResTexts[TX_BUILD_FIELD_HINT];
      Button_BuildWine.Hint     := gResTexts[TX_BUILD_WINE_HINT];
      Button_BuildCancel.Hint   := gResTexts[TX_BUILD_CANCEL_HINT];

      TKMLabel.Create(Panel_Build,0,65,TB_WIDTH,0,gResTexts[TX_MAPED_HOUSES_TITLE],fnt_Outline,taCenter);
      for I:=1 to GUI_HOUSE_COUNT do
        if GUIHouseOrder[I] <> ht_None then begin
          Button_Build[I]:=TKMButtonFlat.Create(Panel_Build, ((I-1) mod 5)*37,83+((I-1) div 5)*37,33,33,fResource.HouseDat[GUIHouseOrder[I]].GUIIcon);
          Button_Build[I].OnClick:=Town_BuildChange;
          Button_Build[I].Hint := fResource.HouseDat[GUIHouseOrder[I]].HouseName;
        end;

    //Units placement
    Panel_Units := TKMPanel.Create(Panel_Town,0,28,TB_WIDTH,400);

      for I := 0 to High(Button_Citizen) do
      begin
        Button_Citizen[I] := TKMButtonFlat.Create(Panel_Units,(I mod 5)*37,8+(I div 5)*37,33,33,fResource.UnitDat[School_Order[I]].GUIIcon); //List of tiles 5x5
        Button_Citizen[I].Hint := fResource.UnitDat[School_Order[I]].GUIName;
        Button_Citizen[I].Tag := Byte(School_Order[I]); //Returns unit ID
        Button_Citizen[I].OnClick := Town_UnitChange;
      end;
      Button_UnitCancel := TKMButtonFlat.Create(Panel_Units,((High(Button_Citizen)+1) mod 5)*37,8+(length(Button_Citizen) div 5)*37,33,33,340);
      Button_UnitCancel.Hint := gResTexts[TX_BUILD_CANCEL_HINT];
      Button_UnitCancel.Tag := 255; //Erase
      Button_UnitCancel.OnClick := Town_UnitChange;

      for I := 0 to High(Button_Warriors) do
      begin
        Button_Warriors[I] := TKMButtonFlat.Create(Panel_Units,(I mod 5)*37,124+(I div 5)*37,33,33, MapEd_Icon[I], rxGui);
        Button_Warriors[I].Hint := fResource.UnitDat[MapEd_Order[I]].GUIName;
        Button_Warriors[I].Tag := Byte(MapEd_Order[I]); //Returns unit ID
        Button_Warriors[I].OnClick := Town_UnitChange;
      end;

      for I := 0 to High(Button_Animals) do
      begin
        Button_Animals[I] := TKMButtonFlat.Create(Panel_Units,(I mod 5)*37,240+(I div 5)*37,33,33, Animal_Icon[I], rxGui);
        Button_Animals[I].Hint := fResource.UnitDat[Animal_Order[I]].GUIName;
        Button_Animals[I].Tag := Byte(Animal_Order[I]); //Returns animal ID
        Button_Animals[I].OnClick := Town_UnitChange;
      end;

    //Town settings
    Panel_Script := TKMPanel.Create(Panel_Town, 0, 28, TB_WIDTH, 400);
      TKMLabel.Create(Panel_Script, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_AI_TITLE], fnt_Outline, taCenter);
      CheckBox_AutoBuild := TKMCheckBox.Create(Panel_Script, 0, 30, TB_WIDTH, 20, gResTexts[TX_MAPED_AI_AUTOBUILD], fnt_Metal);
      CheckBox_AutoBuild.OnClick := Town_ScriptChange;
      CheckBox_AutoRepair := TKMCheckBox.Create(Panel_Script, 0, 50, TB_WIDTH, 20, gResTexts[TX_MAPED_AI_AUTOREPAIR], fnt_Metal);
      CheckBox_AutoRepair.OnClick := Town_ScriptChange;
      TrackBar_SerfsPer10Houses := TKMTrackBar.Create(Panel_Script, 0, 70, TB_WIDTH, 1, 50);
      TrackBar_SerfsPer10Houses.Caption := gResTexts[TX_MAPED_AI_SERFS_PER_10_HOUSES];
      TrackBar_SerfsPer10Houses.OnChange := Town_ScriptChange;
      TrackBar_WorkerCount := TKMTrackBar.Create(Panel_Script, 0, 110, TB_WIDTH, 0, 30);
      TrackBar_WorkerCount.Caption := gResTexts[TX_MAPED_AI_WORKERS];
      TrackBar_WorkerCount.OnChange := Town_ScriptChange;

    //Defence settings
    Panel_Defence := TKMPanel.Create(Panel_Town, 0, 28, TB_WIDTH, 400);
      TKMLabel.Create(Panel_Defence, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_AI_DEFENSE], fnt_Outline, taCenter);
      Button_DefencePosAdd := TKMButtonFlat.Create(Panel_Defence, 0, 30, 33, 33, 338);
      Button_DefencePosAdd.OnClick := Town_DefenceAddClick;
      Button_DefencePosAdd.Hint    := gResTexts[TX_MAPED_AI_DEFENSE_HINT];

      TKMLabel.Create(Panel_Defence, 0, 65, TB_WIDTH, 0, gResTexts[TX_MAPED_AI_DEFENSE_OPTIONS], fnt_Outline, taCenter);
      CheckBox_AutoDefence := TKMCheckBox.Create(Panel_Defence, 0, 90, TB_WIDTH, 20, gResTexts[TX_MAPED_AI_DEFENSE_AUTO], fnt_Metal);
      CheckBox_AutoDefence.Hint := gResTexts[TX_MAPED_AI_DEFENSE_AUTO_HINT];
      CheckBox_AutoDefence.OnClick := Town_DefenceChange;

      TrackBar_EquipRateLeather := TKMTrackBar.Create(Panel_Defence, 0, 120, TB_WIDTH, 10, 300);
      TrackBar_EquipRateLeather.Caption := gResTexts[TX_MAPED_AI_DEFENSE_EQUIP_LEATHER];
      TrackBar_EquipRateLeather.Step := 5;
      TrackBar_EquipRateLeather.OnChange := Town_DefenceChange;

      TrackBar_EquipRateIron := TKMTrackBar.Create(Panel_Defence, 0, 164, TB_WIDTH, 10, 300);
      TrackBar_EquipRateIron.Caption := gResTexts[TX_MAPED_AI_DEFENSE_EQUIP_IRON];
      TrackBar_EquipRateIron.Step := 5;
      TrackBar_EquipRateIron.OnChange := Town_DefenceChange;

      TrackBar_RecruitCount := TKMTrackBar.Create(Panel_Defence, 0, 208, TB_WIDTH, 1, 20);
      TrackBar_RecruitCount.Caption := gResTexts[TX_MAPED_AI_RECRUITS];
      TrackBar_RecruitCount.Hint := gResTexts[TX_MAPED_AI_RECRUITS_HINT];
      TrackBar_RecruitCount.OnChange := Town_DefenceChange;

      TrackBar_RecruitDelay := TKMTrackBar.Create(Panel_Defence, 0, 252, TB_WIDTH, 0, 500);
      TrackBar_RecruitDelay.Caption := gResTexts[TX_MAPED_AI_RECRUIT_DELAY];
      TrackBar_RecruitDelay.Hint := gResTexts[TX_MAPED_AI_RECRUIT_DELAY_HINT];
      TrackBar_RecruitDelay.Step := 5;
      TrackBar_RecruitDelay.OnChange := Town_DefenceChange;

      CheckBox_MaxSoldiers := TKMCheckBox.Create(Panel_Defence, 0, 296, TB_WIDTH, 20, gResTexts[TX_MAPED_AI_MAX_SOLDIERS], fnt_Metal);
      CheckBox_MaxSoldiers.Hint := gResTexts[TX_MAPED_AI_MAX_SOLDIERS_ENABLE_HINT];
      CheckBox_MaxSoldiers.OnClick := Town_DefenceChange;
      TrackBar_MaxSoldiers := TKMTrackBar.Create(Panel_Defence, 20, 314, TB_WIDTH - 20, 0, 500);
      TrackBar_MaxSoldiers.Caption := '';
      TrackBar_MaxSoldiers.Hint := gResTexts[TX_MAPED_AI_MAX_SOLDIERS_HINT];
      TrackBar_MaxSoldiers.Step := 5;
      TrackBar_MaxSoldiers.OnChange := Town_DefenceChange;

      Button_EditFormations := TKMButton.Create(Panel_Defence, 0, 344, TB_WIDTH, 25, gResTexts[TX_MAPED_AI_FORMATIONS], bsGame);
      Button_EditFormations.OnClick := Formations_Show;

    //Offence settings
    Panel_Offence := TKMPanel.Create(Panel_Town, 0, 28, TB_WIDTH, 400);
      TKMLabel.Create(Panel_Offence, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_AI_ATTACK], fnt_Outline, taCenter);

      CheckBox_AutoAttack := TKMCheckBox.Create(Panel_Offence, 0, 30, TB_WIDTH, 20, gResTexts[TX_MAPED_AI_ATTACK_AUTO], fnt_Metal);
      CheckBox_AutoAttack.Disable;

      ColumnBox_Attacks := TKMColumnBox.Create(Panel_Offence, 0, 50, TB_WIDTH, 210, fnt_Game, bsGame);
      ColumnBox_Attacks.SetColumns(fnt_Outline,
        [gResTexts[TX_MAPED_AI_ATTACK_COL_TYPE],
         gResTexts[TX_MAPED_AI_ATTACK_COL_DELAY],
         gResTexts[TX_MAPED_AI_ATTACK_COL_MEN],
         gResTexts[TX_MAPED_AI_ATTACK_COL_TARGET],
         gResTexts[TX_MAPED_AI_ATTACK_COL_LOC]], [0, 20, 60, 100, 130]);
      ColumnBox_Attacks.OnClick := Attacks_ListClick;
      ColumnBox_Attacks.OnDoubleClick := Attacks_ListDoubleClick;

      Button_AttacksAdd := TKMButton.Create(Panel_Offence, 0, 270, 25, 25, '+', bsGame);
      Button_AttacksAdd.OnClick := Attacks_Add;
      Button_AttacksDel := TKMButton.Create(Panel_Offence, 30, 270, 25, 25, 'X', bsGame);
      Button_AttacksDel.OnClick := Attacks_Del;
end;


procedure TKMapEdInterface.Create_Player;
const
  TabGlyph: array [TKMPlayerTab] of Word    = (8,         1159,     38,    327,   393);
  TabRXX  : array [TKMPlayerTab] of TRXType = (rxGuiMain, rxHouses, rxGui, rxGui, rxGui);
  TabHint : array [TKMPlayerTab] of Word = (
    TX_MAPED_GOALS,
    TX_MAPED_PLAYER_COLORS,
    TX_MAPED_BLOCK_HOUSES,
    TX_MAPED_BLOCK_TRADE,
    TX_MAPED_FOG);
var
  I: Integer;
  Col: array [0..255] of TColor4;
  PT: TKMPlayerTab;
begin
  Panel_Player := TKMPanel.Create(Panel_Common,0,45, TB_WIDTH,28);

    for PT := Low(TKMPlayerTab) to High(TKMPlayerTab) do
    begin
      Button_Player[PT] := TKMButton.Create(Panel_Player, SMALL_PAD_W * Byte(PT), 0, SMALL_TAB_W, SMALL_TAB_H,  TabGlyph[PT], TabRXX[PT], bsGame);
      Button_Player[PT].Hint := gResTexts[TabHint[PT]];
      Button_Player[PT].OnClick := SwitchPage;
    end;

    //Goals
    Panel_Goals := TKMPanel.Create(Panel_Player,0,28,TB_WIDTH,400);
      TKMLabel.Create(Panel_Goals, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_GOALS], fnt_Outline, taCenter);
      ColumnBox_Goals := TKMColumnBox.Create(Panel_Goals, 0, 30, TB_WIDTH, 230, fnt_Game, bsGame);
      ColumnBox_Goals.SetColumns(fnt_Outline,
        [gResTexts[TX_MAPED_GOALS_TYPE],
         gResTexts[TX_MAPED_GOALS_CONDITION],
         gResTexts[TX_MAPED_GOALS_PLAYER],
         gResTexts[TX_MAPED_GOALS_TIME],
         gResTexts[TX_MAPED_GOALS_MESSAGE]], [0, 20, 120, 140, 160]);
      ColumnBox_Goals.OnClick := Goals_ListClick;
      ColumnBox_Goals.OnDoubleClick := Goals_ListDoubleClick;

      Button_GoalsAdd := TKMButton.Create(Panel_Goals, 0, 270, 25, 25, '+', bsGame);
      Button_GoalsAdd.OnClick := Goals_Add;
      Button_GoalsDel := TKMButton.Create(Panel_Goals, 30, 270, 25, 25, 'X', bsGame);
      Button_GoalsDel.OnClick := Goals_Del;

    //Players color
    Panel_Color := TKMPanel.Create(Panel_Player, 0, 28, TB_WIDTH, 400);
      TKMLabel.Create(Panel_Color, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_PLAYER_COLORS], fnt_Outline, taCenter);
      TKMBevel.Create(Panel_Color, 0, 30, TB_WIDTH, 210);
      ColorSwatch_Color := TKMColorSwatch.Create(Panel_Color, 0, 32, 16, 16, 11);
      for I := 0 to 255 do Col[I] := fResource.Palettes.DefDal.Color32(I);
      ColorSwatch_Color.SetColors(Col);
      ColorSwatch_Color.OnClick := Player_ColorClick;

    //Allow/Block house building
    Panel_BlockHouse := TKMPanel.Create(Panel_Player, 0, 28, TB_WIDTH, 400);
      TKMLabel.Create(Panel_BlockHouse, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_BLOCK_HOUSES], fnt_Outline, taCenter);
      for I := 1 to GUI_HOUSE_COUNT do
      if GUIHouseOrder[I] <> ht_None then
      begin
        Button_BlockHouse[I] := TKMButtonFlat.Create(Panel_BlockHouse, ((I-1) mod 5)*37, 30 + ((I-1) div 5)*37,33,33,fResource.HouseDat[GUIHouseOrder[I]].GUIIcon);
        Button_BlockHouse[I].Hint := fResource.HouseDat[GUIHouseOrder[I]].HouseName;
        Button_BlockHouse[I].OnClick := Player_BlockHouseClick;
        Button_BlockHouse[I].Tag := I;
        Image_BlockHouse[I] := TKMImage.Create(Panel_BlockHouse, ((I-1) mod 5)*37 + 13, 30 + ((I-1) div 5)*37 + 13, 16, 16, 0, rxGuiMain);
        Image_BlockHouse[I].Hitable := False;
        Image_BlockHouse[I].ImageCenter;
      end;

    //Allow/Block ware trading
    Panel_BlockTrade := TKMPanel.Create(Panel_Player, 0, 28, TB_WIDTH, 400);
      TKMLabel.Create(Panel_BlockTrade, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_BLOCK_TRADE], fnt_Outline, taCenter);
      for I := 1 to STORE_RES_COUNT do
      begin
        Button_BlockTrade[I] := TKMButtonFlat.Create(Panel_BlockTrade, ((I-1) mod 5)*37, 30 + ((I-1) div 5)*37,33,33, 0);
        Button_BlockTrade[I].TexID := fResource.Wares[StoreResType[I]].GUIIcon;
        Button_BlockTrade[I].Hint := fResource.Wares[StoreResType[I]].Title;
        Button_BlockTrade[I].OnClick := Player_BlockTradeClick;
        Button_BlockTrade[I].Tag := I;
        Image_BlockTrade[I] := TKMImage.Create(Panel_BlockTrade, ((I-1) mod 5)*37 + 13, 30 + ((I-1) div 5)*37 + 13, 16, 16, 0, rxGuiMain);
        Image_BlockTrade[I].Hitable := False;
        Image_BlockTrade[I].ImageCenter;
      end;

    //FOW settings
    Panel_Markers := TKMPanel.Create(Panel_Player, 0, 28, TB_WIDTH, 400);
      TKMLabel.Create(Panel_Markers, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_FOG], fnt_Outline, taCenter);
      Button_Reveal         := TKMButtonFlat.Create(Panel_Markers, 0, 30, 33, 33, 394);
      Button_Reveal.Hint    := gResTexts[TX_MAPED_FOG_HINT];
      Button_Reveal.OnClick := Player_MarkerClick;
      TrackBar_RevealNewSize  := TKMTrackBar.Create(Panel_Markers, 37, 35, 140, 1, 64);
      TrackBar_RevealNewSize.OnChange := Player_MarkerClick;
      TrackBar_RevealNewSize.Position := 8;
      CheckBox_RevealAll          := TKMCheckBox.Create(Panel_Markers, 0, 75, 140, 20, gResTexts[TX_MAPED_FOG_ALL], fnt_Metal);
      CheckBox_RevealAll.OnClick  := Player_MarkerClick;
      TKMLabel.Create(Panel_Markers, 0, 100, TB_WIDTH, 0, gResTexts[TX_MAPED_FOG_CENTER], fnt_Outline, taCenter);
      Button_CenterScreen         := TKMButtonFlat.Create(Panel_Markers, 0, 120, 33, 33, 391);
      Button_CenterScreen.Hint    := gResTexts[TX_MAPED_FOG_CENTER_HINT];
      Button_CenterScreen.OnClick := Player_MarkerClick;
      Button_PlayerCenterScreen    := TKMButton.Create(Panel_Markers, 40, 120, 80, 33, '[X,Y]', bsGame);
      Button_PlayerCenterScreen.OnClick := Player_MarkerClick;
      Button_PlayerCenterScreen.Hint := gResTexts[TX_MAPED_FOG_CENTER_JUMP];
end;


procedure TKMapEdInterface.Create_Mission;
var I,K: Integer;
begin
  Panel_Mission := TKMPanel.Create(Panel_Common, 0, 45, TB_WIDTH, 28);
    Button_Mission[1] := TKMButton.Create(Panel_Mission, SMALL_PAD_W * 0, 0, SMALL_TAB_W, SMALL_TAB_H, 41, rxGui, bsGame);
    Button_Mission[1].Hint := gResTexts[TX_MAPED_MISSION_MODE];
    Button_Mission[2] := TKMButton.Create(Panel_Mission, SMALL_PAD_W * 1, 0, SMALL_TAB_W, SMALL_TAB_H, 386, rxGui, bsGame);
    Button_Mission[2].Hint := gResTexts[TX_MAPED_ALLIANCE];
    Button_Mission[3] := TKMButton.Create(Panel_Mission, SMALL_PAD_W * 2, 0, SMALL_TAB_W, SMALL_TAB_H, 656, rxGui, bsGame);
    Button_Mission[3].Hint := gResTexts[TX_MAPED_PLAYERS_TYPE];
    for I := 1 to 3 do Button_Mission[I].OnClick := SwitchPage;

    Panel_Mode := TKMPanel.Create(Panel_Mission,0,28,TB_WIDTH,400);
      TKMLabel.Create(Panel_Mode, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_MISSION_MODE], fnt_Outline, taCenter);
      Radio_MissionMode := TKMRadioGroup.Create(Panel_Mode, 0, 30, TB_WIDTH, 40, fnt_Metal);
      Radio_MissionMode.Add(gResTexts[TX_MAPED_MISSION_NORMAL]);
      Radio_MissionMode.Add(gResTexts[TX_MAPED_MISSION_TACTIC]);
      Radio_MissionMode.OnChange := Mission_ModeChange;

    Panel_Alliances := TKMPanel.Create(Panel_Mission,0,28,TB_WIDTH,400);
      TKMLabel.Create(Panel_Alliances, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_ALLIANCE], fnt_Outline, taCenter);
      for I := 0 to MAX_PLAYERS - 1 do
      begin
        TKMLabel.Create(Panel_Alliances,24+I*20+2,30,20,20,inttostr(I+1),fnt_Outline,taLeft);
        TKMLabel.Create(Panel_Alliances,4,50+I*25,20,20,inttostr(I+1),fnt_Outline,taLeft);
        for K := 0 to MAX_PLAYERS - 1 do
        begin
          CheckBox_Alliances[I,K] := TKMCheckBox.Create(Panel_Alliances, 20+K*20, 46+I*25, 20, 20, '', fnt_Metal);
          CheckBox_Alliances[I,K].Tag       := I * MAX_PLAYERS + K;
          CheckBox_Alliances[I,K].OnClick   := Mission_AlliancesChange;
        end;
      end;

      //It does not have OnClick event for a reason:
      // - we don't have a rule to make alliances symmetrical yet
      CheckBox_AlliancesSym := TKMCheckBox.Create(Panel_Alliances, 0, 50+MAX_PLAYERS*25, TB_WIDTH, 20, gResTexts[TX_MAPED_ALLIANCE_SYMMETRIC], fnt_Metal);
      CheckBox_AlliancesSym.Checked := true;
      CheckBox_AlliancesSym.Disable;

    Panel_PlayerTypes := TKMPanel.Create(Panel_Mission, 0, 28, TB_WIDTH, 400);
      TKMLabel.Create(Panel_PlayerTypes, 0, PAGE_TITLE_Y, TB_WIDTH, 0, gResTexts[TX_MAPED_PLAYERS_TYPE], fnt_Outline, taCenter);
      TKMLabel.Create(Panel_PlayerTypes,  4, 30, 20, 20, '#',       fnt_Grey, taLeft);
      TKMLabel.Create(Panel_PlayerTypes, 24, 30, 60, 20, gResTexts[TX_MAPED_PLAYERS_DEFAULT], fnt_Grey, taLeft);
      TKMImage.Create(Panel_PlayerTypes,104, 30, 60, 20, 588, rxGui);
      TKMImage.Create(Panel_PlayerTypes,164, 30, 20, 20,  62, rxGuiMain);
      for I := 0 to MAX_PLAYERS - 1 do
      begin
        TKMLabel.Create(Panel_PlayerTypes,  4, 50+I*25, 20, 20, IntToStr(I+1), fnt_Outline, taLeft);
        for K := 0 to 2 do
        begin
          CheckBox_PlayerTypes[I,K] := TKMCheckBox.Create(Panel_PlayerTypes, 44+K*60, 48+I*25, 20, 20, '', fnt_Metal);
          CheckBox_PlayerTypes[I,K].Tag       := I;
          CheckBox_PlayerTypes[I,K].OnClick   := Mission_PlayerTypesChange;
        end;
      end;
end;


{Menu page}
procedure TKMapEdInterface.Create_Menu;
begin
  Panel_Menu := TKMPanel.Create(Panel_Common, 0, 45, TB_WIDTH, 400);
    Button_Menu_Load := TKMButton.Create(Panel_Menu, 0, 20, TB_WIDTH, 30, gResTexts[TX_MAPED_LOAD_TITLE], bsGame);
    Button_Menu_Load.OnClick := SwitchPage;
    Button_Menu_Load.Hint := gResTexts[TX_MAPED_LOAD_TITLE];
    Button_Menu_Save := TKMButton.Create(Panel_Menu, 0, 60, TB_WIDTH, 30, gResTexts[TX_MAPED_SAVE_TITLE], bsGame);
    Button_Menu_Save.OnClick := SwitchPage;
    Button_Menu_Save.Hint := gResTexts[TX_MAPED_SAVE_TITLE];
    Button_Menu_Settings := TKMButton.Create(Panel_Menu, 0, 100, TB_WIDTH, 30, gResTexts[TX_MENU_SETTINGS], bsGame);
    Button_Menu_Settings.Hint := gResTexts[TX_MENU_SETTINGS];
    Button_Menu_Settings.Disable;
    Button_Menu_Quit := TKMButton.Create(Panel_Menu, 0, 180, TB_WIDTH, 30, gResTexts[TX_MENU_QUIT_MAPED], bsGame);
    Button_Menu_Quit.Hint := gResTexts[TX_MENU_QUIT_MAPED];
    Button_Menu_Quit.OnClick := SwitchPage;
end;


{Save page}
procedure TKMapEdInterface.Create_MenuSave;
begin
  Panel_Save := TKMPanel.Create(Panel_Common,0,45,TB_WIDTH,400);
    TKMBevel.Create(Panel_Save, 0, 30, TB_WIDTH, 37);
    Radio_Save_MapType  := TKMRadioGroup.Create(Panel_Save,4,32,TB_WIDTH,35,fnt_Grey);
    Radio_Save_MapType.ItemIndex := 0;
    Radio_Save_MapType.Add(gResTexts[TX_MENU_MAPED_SPMAPS]);
    Radio_Save_MapType.Add(gResTexts[TX_MENU_MAPED_MPMAPS]);
    Radio_Save_MapType.OnChange := Menu_SaveClick;
    TKMLabel.Create(Panel_Save,0,90,TB_WIDTH,20,gResTexts[TX_MAPED_SAVE_TITLE],fnt_Outline,taCenter);
    Edit_SaveName       := TKMEdit.Create(Panel_Save,0,110,TB_WIDTH,20, fnt_Grey);
    Edit_SaveName.AllowedChars := acFileName;
    Label_SaveExists    := TKMLabel.Create(Panel_Save,0,140,TB_WIDTH,0,gResTexts[TX_MAPED_SAVE_EXISTS],fnt_Outline,taCenter);
    CheckBox_SaveExists := TKMCheckBox.Create(Panel_Save,0,160,TB_WIDTH,20,gResTexts[TX_MAPED_SAVE_OVERWRITE], fnt_Metal);
    Button_SaveSave     := TKMButton.Create(Panel_Save,0,180,TB_WIDTH,30,gResTexts[TX_MAPED_SAVE],bsGame);
    Button_SaveCancel   := TKMButton.Create(Panel_Save,0,220,TB_WIDTH,30,gResTexts[TX_MAPED_SAVE_CANCEL],bsGame);
    Edit_SaveName.OnChange      := Menu_SaveClick;
    CheckBox_SaveExists.OnClick := Menu_SaveClick;
    Button_SaveSave.OnClick     := Menu_SaveClick;
    Button_SaveCancel.OnClick   := SwitchPage;
end;


{Load page}
procedure TKMapEdInterface.Create_MenuLoad;
begin
  Panel_Load := TKMPanel.Create(Panel_Common,0,45,TB_WIDTH,400);
    TKMLabel.Create(Panel_Load, 0, PAGE_TITLE_Y, TB_WIDTH, 30, gResTexts[TX_MAPED_LOAD_TITLE], fnt_Outline, taLeft);
    TKMBevel.Create(Panel_Load, 0, 30, TB_WIDTH, 38);
    Radio_Load_MapType := TKMRadioGroup.Create(Panel_Load,0,32,TB_WIDTH,35,fnt_Grey);
    Radio_Load_MapType.ItemIndex := 0;
    Radio_Load_MapType.Add(gResTexts[TX_MENU_MAPED_SPMAPS]);
    Radio_Load_MapType.Add(gResTexts[TX_MENU_MAPED_MPMAPS]);
    Radio_Load_MapType.OnChange := Menu_LoadChange;
    ListBox_Load := TKMListBox.Create(Panel_Load, 0, 85, TB_WIDTH, 205, fnt_Grey, bsGame);
    ListBox_Load.ItemHeight := 18;
    ListBox_Load.AutoHideScrollBar := True;
    Button_LoadLoad     := TKMButton.Create(Panel_Load,0,300,TB_WIDTH,30,gResTexts[TX_MAPED_LOAD],bsGame);
    Button_LoadCancel   := TKMButton.Create(Panel_Load,0,335,TB_WIDTH,30,gResTexts[TX_MAPED_LOAD_CANCEL],bsGame);
    Button_LoadLoad.OnClick     := Menu_LoadClick;
    Button_LoadCancel.OnClick   := SwitchPage;
end;


{Quit page}
procedure TKMapEdInterface.Create_MenuQuit;
begin
  Panel_Quit := TKMPanel.Create(Panel_Common, 0, 45, TB_WIDTH, 400);
    TKMLabel.Create(Panel_Quit, 0, 40, TB_WIDTH, 60, gResTexts[TX_MAPED_LOAD_UNSAVED], fnt_Outline, taCenter);
    Button_Quit_Yes := TKMButton.Create(Panel_Quit, 0, 100, TB_WIDTH, 30, gResTexts[TX_MENU_QUIT_MAPED], bsGame);
    Button_Quit_No  := TKMButton.Create(Panel_Quit, 0, 140, TB_WIDTH, 30, gResTexts[TX_MENU_DONT_QUIT_MISSION], bsGame);
    Button_Quit_Yes.Hint    := gResTexts[TX_MENU_QUIT_MAPED];
    Button_Quit_No.Hint     := gResTexts[TX_MENU_DONT_QUIT_MISSION];
    Button_Quit_Yes.OnClick := Menu_QuitClick;
    Button_Quit_No.OnClick  := SwitchPage;
end;


procedure TKMapEdInterface.Create_Extra;
begin
  Panel_Extra := TKMPanel.Create(Panel_Main, TOOLBAR_WIDTH, Panel_Main.Height - 190, 600, 190);
  Panel_Extra.Anchors := [akLeft, akBottom];
  Panel_Extra.Hide;

    with TKMImage.Create(Panel_Extra, 0, 0, 600, 190, 409) do
    begin
      Anchors := [akLeft, akTop, akBottom];
      ImageAnchors := [akLeft, akRight, akTop];
    end;

    Image_ExtraClose := TKMImage.Create(Panel_Extra, 600 - 76, 24, 32, 32, 52);
    Image_ExtraClose.Anchors := [akTop, akRight];
    Image_ExtraClose.Hint := gResTexts[TX_MSG_CLOSE_HINT];
    Image_ExtraClose.OnClick := ExtraMessage_Switch;
    Image_ExtraClose.HighlightOnMouseOver := True;

    TrackBar_Passability := TKMTrackBar.Create(Panel_Extra, 50, 70, 180, 0, Byte(High(TPassability)));
    TrackBar_Passability.Font := fnt_Antiqua;
    TrackBar_Passability.Caption := gResTexts[TX_MAPED_VIEW_PASSABILITY];
    TrackBar_Passability.Position := 0; //Disabled by default
    TrackBar_Passability.OnChange := Extra_Change;
    Label_Passability := TKMLabel.Create(Panel_Extra, 50, 114, 180, 0, gResTexts[TX_MAPED_PASSABILITY_OFF], fnt_Antiqua, taLeft);

    CheckBox_ShowObjects := TKMCheckBox.Create(Panel_Extra, 250, 70, 180, 20, gResTexts[TX_MAPED_VIEW_OBJECTS], fnt_Antiqua);
    CheckBox_ShowObjects.Checked := True; //Enabled by default
    CheckBox_ShowObjects.OnClick := Extra_Change;
    CheckBox_ShowHouses := TKMCheckBox.Create(Panel_Extra, 250, 90, 180, 20, gResTexts[TX_MAPED_VIEW_HOUSES], fnt_Antiqua);
    CheckBox_ShowHouses.Checked := True; //Enabled by default
    CheckBox_ShowHouses.OnClick := Extra_Change;
    CheckBox_ShowUnits := TKMCheckBox.Create(Panel_Extra, 250, 110, 180, 20, gResTexts[TX_MAPED_VIEW_UNITS], fnt_Antiqua);
    CheckBox_ShowUnits.Checked := True; //Enabled by default
    CheckBox_ShowUnits.OnClick := Extra_Change;
    CheckBox_ShowDeposits := TKMCheckBox.Create(Panel_Extra, 250, 130, 180, 20, gResTexts[TX_MAPED_VIEW_DEPOSISTS], fnt_Antiqua);
    CheckBox_ShowDeposits.Checked := True; //Enabled by default
    CheckBox_ShowDeposits.OnClick := Extra_Change;

    //dropdown list needs to be ontop other buttons created on Panel_Main
    Dropbox_PlayerFOW := TKMDropList.Create(Panel_Extra, 460, 70, 160, 20, fnt_Metal, '', bsGame);
    Dropbox_PlayerFOW.Hint := gResTexts[TX_REPLAY_PLAYER_PERSPECTIVE];
    Dropbox_PlayerFOW.OnChange := Player_FOWChange;
    //todo: This feature isn't working properly yet so it's hidden. FOW should be set by
    //revealers list and current locations of units/houses (must update when they move)
    Dropbox_PlayerFOW.Hide;
end;


procedure TKMapEdInterface.Create_Message;
begin
  Panel_Message := TKMPanel.Create(Panel_Main, TOOLBAR_WIDTH, Panel_Main.Height - 190, Panel_Main.Width - TOOLBAR_WIDTH, 190);
  Panel_Message.Anchors := [akLeft, akBottom];
  Panel_Message.Hide;

    with TKMImage.Create(Panel_Message, 0, 0, 800, 190, 409) do
    begin
      Anchors := [akLeft, akTop, akBottom];
      ImageStretch;
    end;

    Image_MessageClose := TKMImage.Create(Panel_Message, 800-35, 20, 32, 32, 52);
    Image_MessageClose.Anchors := [akTop, akRight];
    Image_MessageClose.Hint := gResTexts[TX_MSG_CLOSE_HINT];
    Image_MessageClose.OnClick := ExtraMessage_Switch;
    Image_MessageClose.HighlightOnMouseOver := True;

    Label_Message := TKMLabel.Create(Panel_Message, 40, 50, 7000, 0, '', fnt_Grey, taLeft);
end;


procedure TKMapEdInterface.Create_AttackPopUp;
const
  SIZE_X = 570;
  SIZE_Y = 360;
var
  GT: TGroupType;
begin
  Panel_Attack := TKMPanel.Create(Panel_Main, 362, 250, SIZE_X, SIZE_Y);
  Panel_Attack.Anchors := [];
  Panel_Attack.Hide;

    TKMBevel.Create(Panel_Attack, -1000,  -1000, 4000, 4000);
    with TKMImage.Create(Panel_Attack, -20, -50, SIZE_X+40, SIZE_Y+60, 15, rxGuiMain) do ImageStretch;
    TKMBevel.Create(Panel_Attack,   0,  0, SIZE_X, SIZE_Y);
    TKMLabel.Create(Panel_Attack, SIZE_X div 2, 10, gResTexts[TX_MAPED_AI_ATTACK_INFO], fnt_Outline, taCenter);

    TKMLabel.Create(Panel_Attack, 20, 40, gResTexts[TX_MAPED_AI_ATTACK_COL_TYPE], fnt_Metal, taLeft);
    Radio_AttackType := TKMRadioGroup.Create(Panel_Attack, 20, 60, 80, 40, fnt_Metal);
    Radio_AttackType.Add(gResTexts[TX_MAPED_AI_ATTACK_TYPE_ONCE]);
    Radio_AttackType.Add(gResTexts[TX_MAPED_AI_ATTACK_TYPE_REP]);
    Radio_AttackType.OnChange := Attack_Change;

    TKMLabel.Create(Panel_Attack, 130, 40, gResTexts[TX_MAPED_AI_ATTACK_DELAY], fnt_Metal, taLeft);
    NumEdit_AttackDelay := TKMNumericEdit.Create(Panel_Attack, 130, 60, 0, High(SmallInt));
    NumEdit_AttackDelay.OnChange := Attack_Change;

    TKMLabel.Create(Panel_Attack, 240, 40, gResTexts[TX_MAPED_AI_ATTACK_COL_MEN], fnt_Metal, taLeft);
    NumEdit_AttackMen := TKMNumericEdit.Create(Panel_Attack, 240, 60, 0, 1000);
    NumEdit_AttackMen.OnChange := Attack_Change;

    TKMLabel.Create(Panel_Attack, 340, 40, gResTexts[TX_MAPED_AI_ATTACK_COUNT], fnt_Metal, taLeft);
    for GT := Low(TGroupType) to High(TGroupType) do
    begin
      TKMLabel.Create(Panel_Attack, 425, 60 + Byte(GT) * 20, 0, 0, gResTexts[GROUP_TEXT[GT]], fnt_Metal, taLeft);
      NumEdit_AttackAmount[GT] := TKMNumericEdit.Create(Panel_Attack, 340, 60 + Byte(GT) * 20, 0, 255);
      NumEdit_AttackAmount[GT].OnChange := Attack_Change;
    end;

    CheckBox_AttackTakeAll := TKMCheckBox.Create(Panel_Attack, 340, 145, 160, 20, gResTexts[TX_MAPED_AI_ATTACK_TAKE_ALL], fnt_Metal);
    CheckBox_AttackTakeAll.OnClick := Attack_Change;

    //Second row

    TKMLabel.Create(Panel_Attack, 20, 170, gResTexts[TX_MAPED_AI_ATTACK_COL_TARGET], fnt_Metal, taLeft);
    Radio_AttackTarget := TKMRadioGroup.Create(Panel_Attack, 20, 190, 160, 80, fnt_Metal);
    Radio_AttackTarget.Add(gResTexts[TX_MAPED_AI_TARGET_CLOSEST]);
    Radio_AttackTarget.Add(gResTexts[TX_MAPED_AI_TARGET_HOUSE1]);
    Radio_AttackTarget.Add(gResTexts[TX_MAPED_AI_TARGET_HOUSE2]);
    Radio_AttackTarget.Add(gResTexts[TX_MAPED_AI_TARGET_CUSTOM]);
    Radio_AttackTarget.OnChange := Attack_Change;

    TKMLabel.Create(Panel_Attack, 200, 170, gResTexts[TX_MAPED_AI_TARGET_POS], fnt_Metal, taLeft);
    NumEdit_AttackLocX := TKMNumericEdit.Create(Panel_Attack, 200, 190, 0, MAX_MAP_SIZE);
    NumEdit_AttackLocX.OnChange := Attack_Change;
    NumEdit_AttackLocY := TKMNumericEdit.Create(Panel_Attack, 200, 210, 0, MAX_MAP_SIZE);
    NumEdit_AttackLocY.OnChange := Attack_Change;

    TKMLabel.Create(Panel_Attack, 200, 240, 'Range (untested)', fnt_Metal, taLeft);
    TrackBar_AttackRange := TKMTrackBar.Create(Panel_Attack, 200, 260, 100, 0, 255);
    TrackBar_AttackRange.Disable;
    TrackBar_AttackRange.OnChange := Attack_Change;

    Button_AttackOk := TKMButton.Create(Panel_Attack, SIZE_X-20-320-10, SIZE_Y - 50, 160, 30, gResTexts[TX_MAPED_OK], bsMenu);
    Button_AttackOk.OnClick := Attack_Close;
    Button_AttackCancel := TKMButton.Create(Panel_Attack, SIZE_X-20-160, SIZE_Y - 50, 160, 30, gResTexts[TX_MAPED_CANCEL], bsMenu);
    Button_AttackCancel.OnClick := Attack_Close;
end;


procedure TKMapEdInterface.Create_FormationsPopUp;
const
  T: array [TGroupType] of Integer = (TX_MAPED_AI_ATTACK_TYPE_MELEE, TX_MAPED_AI_ATTACK_TYPE_ANTIHORSE, TX_MAPED_AI_ATTACK_TYPE_RANGED, TX_MAPED_AI_ATTACK_TYPE_MOUNTED);  SIZE_X = 570;
  SIZE_Y = 200;
var
  GT: TGroupType;
  Img: TKMImage;
begin
  Panel_Formations := TKMPanel.Create(Panel_Main, 362, 250, SIZE_X, SIZE_Y);
  Panel_Formations.Anchors := [];
  Panel_Formations.Hide;

    TKMBevel.Create(Panel_Formations, -1000,  -1000, 4000, 4000);
    Img := TKMImage.Create(Panel_Formations, -20, -50, SIZE_X+40, SIZE_Y+60, 15, rxGuiMain);
    Img.ImageStretch;
    TKMBevel.Create(Panel_Formations,   0,  0, SIZE_X, SIZE_Y);
    TKMLabel.Create(Panel_Formations, SIZE_X div 2, 10, gResTexts[TX_MAPED_AI_FORMATIONS_TITLE], fnt_Outline, taCenter);

    Image_FormationsFlag := TKMImage.Create(Panel_Formations, 10, 10, 0, 0, 30, rxGuiMain);

    TKMLabel.Create(Panel_Formations, 20, 70, 80, 0, gResTexts[TX_MAPED_AI_FORMATIONS_COUNT], fnt_Metal, taLeft);
    TKMLabel.Create(Panel_Formations, 20, 95, 80, 0, gResTexts[TX_MAPED_AI_FORMATIONS_COLUMNS], fnt_Metal, taLeft);

    for GT := Low(TGroupType) to High(TGroupType) do
    begin
      TKMLabel.Create(Panel_Formations, 130 + Byte(GT) * 110 + 32, 50, 0, 0, gResTexts[T[GT]], fnt_Metal, taCenter);
      NumEdit_FormationsCount[GT] := TKMNumericEdit.Create(Panel_Formations, 130 + Byte(GT) * 110, 70, 1, 255);
      NumEdit_FormationsColumns[GT] := TKMNumericEdit.Create(Panel_Formations, 130 + Byte(GT) * 110, 95, 1, 255);
    end;

    Button_Formations_Ok := TKMButton.Create(Panel_Formations, SIZE_X-20-320-10, 150, 160, 30, gResTexts[TX_MAPED_OK], bsMenu);
    Button_Formations_Ok.OnClick := Formations_Close;
    Button_Formations_Cancel := TKMButton.Create(Panel_Formations, SIZE_X-20-160, 150, 160, 30, gResTexts[TX_MAPED_CANCEL], bsMenu);
    Button_Formations_Cancel.OnClick := Formations_Close;
end;


procedure TKMapEdInterface.Create_GoalPopUp;
const
  SIZE_X = 600;
  SIZE_Y = 300;
var
  Img: TKMImage;
begin
  Panel_Goal := TKMPanel.Create(Panel_Main, 362, 250, SIZE_X, SIZE_Y);
  Panel_Goal.Anchors := [];
  Panel_Goal.Hide;

    TKMBevel.Create(Panel_Goal, -1000,  -1000, 4000, 4000);
    Img := TKMImage.Create(Panel_Goal, -20, -50, SIZE_X+40, SIZE_Y+60, 15, rxGuiMain);
    Img.ImageStretch;
    TKMBevel.Create(Panel_Goal,   0,  0, SIZE_X, SIZE_Y);
    TKMLabel.Create(Panel_Goal, SIZE_X div 2, 10, gResTexts[TX_MAPED_GOALS_TITLE], fnt_Outline, taCenter);

    Image_GoalFlag := TKMImage.Create(Panel_Goal, 10, 10, 0, 0, 30, rxGuiMain);

    TKMLabel.Create(Panel_Goal, 20, 40, 100, 0, gResTexts[TX_MAPED_GOALS_TYPE], fnt_Metal, taLeft);
    Radio_GoalType := TKMRadioGroup.Create(Panel_Goal, 20, 60, 100, 60, fnt_Metal);
    Radio_GoalType.Add(gResTexts[TX_MAPED_GOALS_TYPE_NONE]);
    Radio_GoalType.Add(gResTexts[TX_MAPED_GOALS_TYPE_VICTORY]);
    Radio_GoalType.Add(gResTexts[TX_MAPED_GOALS_TYPE_SURVIVE]);
    Radio_GoalType.OnChange := Goal_Change;

    TKMLabel.Create(Panel_Goal, 140, 40, 180, 0, gResTexts[TX_MAPED_GOALS_CONDITION], fnt_Metal, taLeft);
    Radio_GoalCondition := TKMRadioGroup.Create(Panel_Goal, 140, 60, 180, 180, fnt_Metal);
    Radio_GoalCondition.Add(gResTexts[TX_MAPED_GOALS_CONDITION_NONE], False);
    Radio_GoalCondition.Add(gResTexts[TX_MAPED_GOALS_CONDITION_TUTORIAL], False);
    Radio_GoalCondition.Add(gResTexts[TX_MAPED_GOALS_CONDITION_TIME], False);
    Radio_GoalCondition.Add(gResTexts[TX_MAPED_GOALS_CONDITION_BUILDS]);
    Radio_GoalCondition.Add(gResTexts[TX_MAPED_GOALS_CONDITION_TROOPS]);
    Radio_GoalCondition.Add(gResTexts[TX_MAPED_GOALS_CONDITION_UNKNOWN], False);
    Radio_GoalCondition.Add(gResTexts[TX_MAPED_GOALS_CONDITION_ASSETS]);
    Radio_GoalCondition.Add(gResTexts[TX_MAPED_GOALS_CONDITION_SERFS]);
    Radio_GoalCondition.Add(gResTexts[TX_MAPED_GOALS_CONDITION_ECONOMY]);
    Radio_GoalCondition.OnChange := Goal_Change;

    TKMLabel.Create(Panel_Goal, 330, 40, gResTexts[TX_MAPED_GOALS_PLAYER], fnt_Metal, taLeft);
    NumEdit_GoalPlayer := TKMNumericEdit.Create(Panel_Goal, 330, 60, 1, MAX_PLAYERS);
    NumEdit_GoalPlayer.OnChange := Goal_Change;

    TKMLabel.Create(Panel_Goal, 480, 40, gResTexts[TX_MAPED_GOALS_TIME], fnt_Metal, taLeft);
    NumEdit_GoalTime := TKMNumericEdit.Create(Panel_Goal, 480, 60, 0, 32767);
    NumEdit_GoalTime.OnChange := Goal_Change;
    NumEdit_GoalTime.SharedHint := 'This setting is deprecated, use scripts instead';

    TKMLabel.Create(Panel_Goal, 480, 90, gResTexts[TX_MAPED_GOALS_MESSAGE], fnt_Metal, taLeft);
    NumEdit_GoalMessage := TKMNumericEdit.Create(Panel_Goal, 480, 110, 0, 0);
    NumEdit_GoalMessage.SharedHint := 'This setting is deprecated, use scripts instead';

    Button_GoalOk := TKMButton.Create(Panel_Goal, SIZE_X-20-320-10, SIZE_Y - 50, 160, 30, gResTexts[TX_MAPED_OK], bsMenu);
    Button_GoalOk.OnClick := Goal_Close;
    Button_GoalCancel := TKMButton.Create(Panel_Goal, SIZE_X-20-160, SIZE_Y - 50, 160, 30, gResTexts[TX_MAPED_CANCEL], bsMenu);
    Button_GoalCancel.OnClick := Goal_Close;
end;


{Unit page}
procedure TKMapEdInterface.Create_Unit;
begin
  Panel_Unit := TKMPanel.Create(Panel_Common, 0, 45, TB_WIDTH, 400);
    Label_UnitName        := TKMLabel.Create(Panel_Unit,0,16,TB_WIDTH,0,'',fnt_Outline,taCenter);
    Image_UnitPic         := TKMImage.Create(Panel_Unit,0,38,54,100,521);
    Label_UnitCondition   := TKMLabel.Create(Panel_Unit,65,40,116,0,gResTexts[TX_UNIT_CONDITION],fnt_Grey,taCenter);
    KMConditionBar_Unit   := TKMPercentBar.Create(Panel_Unit,65,55,116,15);
    Label_UnitDescription := TKMLabel.Create(Panel_Unit,0,152,TB_WIDTH,200,'',fnt_Grey,taLeft); //Taken from LIB resource
    Label_UnitDescription.AutoWrap := True;

    Panel_Army := TKMPanel.Create(Panel_Unit, 0, 160, TB_WIDTH, 400);
    Button_Army_RotCCW  := TKMButton.Create(Panel_Army,       0,  0, 56, 40, 23, rxGui, bsGame);
    Button_Army_RotCW   := TKMButton.Create(Panel_Army,     124,  0, 56, 40, 24, rxGui, bsGame);
    Button_Army_ForUp   := TKMButton.Create(Panel_Army,       0, 46, 56, 40, 33, rxGui, bsGame);
    ImageStack_Army     := TKMImageStack.Create(Panel_Army,  62, 46, 56, 40, 43, 50);
    Label_ArmyCount     := TKMLabel.Create(Panel_Army,       62, 60, 56, 20, '-', fnt_Outline, taCenter);
    Button_Army_ForDown := TKMButton.Create(Panel_Army,     124, 46, 56, 40, 32, rxGui, bsGame);
    Button_Army_RotCW.OnClick   := Unit_ArmyChange1;
    Button_Army_RotCCW.OnClick  := Unit_ArmyChange1;
    Button_Army_ForUp.OnClick   := Unit_ArmyChange1;
    Button_Army_ForDown.OnClick := Unit_ArmyChange1;

    Button_ArmyDec      := TKMButton.Create(Panel_Army,  0,92,56,40,'-', bsGame);
    Button_ArmyFood     := TKMButton.Create(Panel_Army, 62,92,56,40,29, rxGui, bsGame);
    Button_ArmyInc      := TKMButton.Create(Panel_Army,124,92,56,40,'+', bsGame);
    Button_ArmyDec.OnClickEither  := Unit_ArmyChange2;
    Button_ArmyFood.OnClick       := Unit_ArmyChange1;
    Button_ArmyInc.OnClickEither  := Unit_ArmyChange2;

    //Group order
    //todo: Orders should be placed with a cursor (but keep numeric input as well?)
    TKMLabel.Create(Panel_Army, 0, 140, TB_WIDTH, 0, gResTexts[TX_MAPED_GROUP_ORDER], fnt_Outline, taLeft);
    DropBox_ArmyOrder   := TKMDropList.Create(Panel_Army, 0, 160, TB_WIDTH, 20, fnt_Metal, '', bsGame);
    DropBox_ArmyOrder.Add(gResTexts[TX_MAPED_GROUP_ORDER_NONE]);
    DropBox_ArmyOrder.Add(gResTexts[TX_MAPED_GROUP_ORDER_WALK]);
    DropBox_ArmyOrder.Add(gResTexts[TX_MAPED_GROUP_ORDER_ATTACK]);
    DropBox_ArmyOrder.OnChange := Unit_ArmyChange1;
    TKMLabel.Create(Panel_Army, 0, 185, 'X:', fnt_Grey, taLeft);
    Edit_ArmyOrderX := TKMNumericEdit.Create(Panel_Army, 20, 185, 0, 255);
    Edit_ArmyOrderX.OnChange := Unit_ArmyChange1;
    TKMLabel.Create(Panel_Army, 0, 205, 'Y:', fnt_Grey, taLeft);
    Edit_ArmyOrderY := TKMNumericEdit.Create(Panel_Army, 20, 205, 0, 255);
    Edit_ArmyOrderY.OnChange := Unit_ArmyChange1;
    TKMLabel.Create(Panel_Army, 110, 185, gResTexts[TX_MAPED_GROUP_ORDER_DIRECTION], fnt_Grey, taLeft);
    Edit_ArmyOrderDir := TKMNumericEdit.Create(Panel_Army, 110, 205, 0, 7);
    Edit_ArmyOrderDir.OnChange := Unit_ArmyChange1;
end;


procedure TKMapEdInterface.Create_Marker;
begin
  Panel_Marker := TKMPanel.Create(Panel_Common, 0, 50, TB_WIDTH, 400);

  Label_MarkerType := TKMLabel.Create(Panel_Marker, 32, 10, TB_WIDTH, 0, '', fnt_Outline, taLeft);
  Image_MarkerPic := TKMImage.Create(Panel_Marker, 0, 10, 32, 32, 338);

    Panel_MarkerReveal := TKMPanel.Create(Panel_Marker, 0, 46, TB_WIDTH, 400);
      TrackBar_RevealSize := TKMTrackBar.Create(Panel_MarkerReveal, 0, 0, TB_WIDTH, 1, 64);
      TrackBar_RevealSize.Caption := gResTexts[TX_MAPED_FOG_RADIUS];
      TrackBar_RevealSize.OnChange := Marker_Change;
      Button_RevealDelete := TKMButton.Create(Panel_MarkerReveal, 0, 55, 25, 25, 340, rxGui, bsGame);
      Button_RevealDelete.Hint := gResTexts[TX_MAPED_DELETE_REVEALER_HINT];
      Button_RevealDelete.OnClick := Marker_Change;
      Button_RevealClose := TKMButton.Create(Panel_MarkerReveal, TB_WIDTH-100, 55, 100, 25, gResTexts[TX_MAPED_CLOSE], bsGame);
      Button_RevealClose.Hint := gResTexts[TX_MAPED_CLOSE_REVEALER_HINT];
      Button_RevealClose.OnClick := Marker_Change;

    Panel_MarkerDefence := TKMPanel.Create(Panel_Marker, 0, 46, TB_WIDTH, 400);
      DropList_DefenceGroup := TKMDropList.Create(Panel_MarkerDefence, 0, 10, TB_WIDTH, 20, fnt_Game, '', bsGame);
      DropList_DefenceGroup.Add(gResTexts[TX_MAPED_AI_ATTACK_TYPE_MELEE]);
      DropList_DefenceGroup.Add(gResTexts[TX_MAPED_AI_ATTACK_TYPE_ANTIHORSE]);
      DropList_DefenceGroup.Add(gResTexts[TX_MAPED_AI_ATTACK_TYPE_RANGED]);
      DropList_DefenceGroup.Add(gResTexts[TX_MAPED_AI_ATTACK_TYPE_MOUNTED]);
      DropList_DefenceGroup.OnChange := Marker_Change;
      DropList_DefenceType := TKMDropList.Create(Panel_MarkerDefence, 0, 40, TB_WIDTH, 20, fnt_Game, '', bsGame);
      DropList_DefenceType.Add(gResTexts[TX_MAPED_AI_DEFENCE_FRONTLINE]);
      DropList_DefenceType.Add(gResTexts[TX_MAPED_AI_DEFENCE_BACKLINE]);
      DropList_DefenceType.OnChange := Marker_Change;
      TrackBar_DefenceRad := TKMTrackBar.Create(Panel_MarkerDefence, 0, 70, TB_WIDTH, 1, 128);
      TrackBar_DefenceRad.Caption := gResTexts[TX_MAPED_AI_DEFENCE_RADIUS];
      TrackBar_DefenceRad.OnChange := Marker_Change;
      Button_DefenceCCW  := TKMButton.Create(Panel_MarkerDefence, 0, 120, 50, 35, 23, rxGui, bsGame);
      Button_DefenceCCW.OnClick := Marker_Change;
      Button_DefenceCW := TKMButton.Create(Panel_MarkerDefence, 130, 120, 50, 35, 24, rxGui, bsGame);
      Button_DefenceCW.OnClick := Marker_Change;
      Button_DefenceDelete := TKMButton.Create(Panel_MarkerDefence, 0, 165, 25, 25, 340, rxGui, bsGame);
      Button_DefenceDelete.Hint := gResTexts[TX_MAPED_AI_DEFENCE_DELETE_HINT];
      Button_DefenceDelete.OnClick := Marker_Change;
      Button_DefenceClose := TKMButton.Create(Panel_MarkerDefence, TB_WIDTH-100, 165, 100, 25, gResTexts[TX_MAPED_CLOSE], bsGame);
      Button_DefenceClose.Hint := gResTexts[TX_MAPED_AI_DEFENCE_CLOSE_HINT];
      Button_DefenceClose.OnClick := Marker_Change;
end;


//Should update any items changed by game (resource counts, hp, etc..)
procedure TKMapEdInterface.UpdateState(aTickCount: Cardinal);
const
  CAP_COLOR: array [Boolean] of TColor4 = ($80808080, $FFFFFFFF);
var
  I: Integer;
begin
  //Show players without assets in grey
  if aTickCount mod 10 = 0 then
  for I := 0 to MAX_PLAYERS - 1 do
    Button_PlayerSelect[I].FontColor := CAP_COLOR[gPlayers[I].HasAssets];

  fGuiTerrain.UpdateState;

  if fMaps <> nil then fMaps.UpdateState;
  if fMapsMP <> nil then fMapsMP.UpdateState;
end;


//Update UI state according to game state
procedure TKMapEdInterface.SyncUI;
begin
  Player_UpdateColors;
  UpdateAITabsEnabled;

  Label_MissionName.Caption := fGame.GameName;

  MinimapView.SetMinimap(fGame.Minimap);
  MinimapView.SetViewport(fGame.Viewport);
end;


procedure TKMapEdInterface.PageChanged(Sender: TObject);
begin
  //Child panels visibility changed, that affects visible layers
  Layers_UpdateVisibility;
end;


procedure TKMapEdInterface.Paint;
  procedure PaintTextInShape(aText: string; X,Y: SmallInt; aLineColor: Cardinal);
  var
    W: Integer;
  begin
    //Paint the background
    W := 10 + 10 * Length(aText);
    TKMRenderUI.WriteShape(X - W div 2, Y - 10, W, 20, $80000000);
    TKMRenderUI.WriteOutline(X - W div 2, Y - 10, W, 20, 2, aLineColor);

    //Paint the label on top of the background
    TKMRenderUI.WriteText(X, Y - 7, 0, aText, fnt_Metal, taCenter, $FFFFFFFF);
  end;
const
  DefenceLine: array [TAIDefencePosType] of Cardinal = ($FF80FF00, $FFFF8000);
var
  I, K: Integer;
  R: TRawDeposit;
  DP: TAIDefencePosition;
  LocF: TKMPointF;
  ScreenLoc: TKMPointI;
begin
  if mlDeposits in fGame.MapEditor.VisibleLayers then
  begin
    for R := Low(TRawDeposit) to High(TRawDeposit) do
      for I := 0 to fGame.MapEditor.Deposits.Count[R] - 1 do
      //Ignore water areas with 0 fish in them
      if fGame.MapEditor.Deposits.Amount[R, I] > 0 then
      begin
        LocF := gTerrain.FlatToHeight(fGame.MapEditor.Deposits.Location[R, I]);
        ScreenLoc := fGame.Viewport.MapToScreen(LocF);

        //At extreme zoom coords may become out of range of SmallInt used in controls painting
        if KMInRect(ScreenLoc, fGame.Viewport.ViewRect) then
          PaintTextInShape(IntToStr(fGame.MapEditor.Deposits.Amount[R, I]), ScreenLoc.X, ScreenLoc.Y, DEPOSIT_COLORS[R]);
      end;
  end;

  if mlDefences in fGame.MapEditor.VisibleLayers then
  begin
    for I := 0 to gPlayers.Count - 1 do
      for K := 0 to gPlayers[I].AI.General.DefencePositions.Count - 1 do
      begin
        DP := gPlayers[I].AI.General.DefencePositions[K];
        LocF := gTerrain.FlatToHeight(KMPointF(DP.Position.Loc.X-0.5, DP.Position.Loc.Y-0.5));
        ScreenLoc := fGame.Viewport.MapToScreen(LocF);

        if KMInRect(ScreenLoc, fGame.Viewport.ViewRect) then
        begin
          PaintTextInShape(IntToStr(K+1), ScreenLoc.X, ScreenLoc.Y - 15, DefenceLine[DP.DefenceType]);
          TKMRenderUI.WritePicture(ScreenLoc.X, ScreenLoc.Y, 0, 0, [], rxGui, GROUP_IMG[DP.GroupType]);
        end;
      end;
  end;

  inherited;
end;


procedure TKMapEdInterface.Town_DefenceAddClick(Sender: TObject);
begin
  //Press the button
  Button_DefencePosAdd.Down := not Button_DefencePosAdd.Down and (Sender = Button_DefencePosAdd);

  if Button_DefencePosAdd.Down then
  begin
    GameCursor.Mode := cmMarkers;
    GameCursor.Tag1 := MARKER_DEFENCE;
  end
  else
  begin
    GameCursor.Mode := cmNone;
    GameCursor.Tag1 := 0;
  end;
end;


procedure TKMapEdInterface.Town_DefenceChange(Sender: TObject);
begin
  gPlayers[MySpectator.PlayerIndex].AI.Setup.AutoDefend := CheckBox_AutoDefence.Checked;
  gPlayers[MySpectator.PlayerIndex].AI.Setup.EquipRateLeather := TrackBar_EquipRateLeather.Position * 10;
  gPlayers[MySpectator.PlayerIndex].AI.Setup.EquipRateIron := TrackBar_EquipRateIron.Position * 10;
  gPlayers[MySpectator.PlayerIndex].AI.Setup.RecruitCount := TrackBar_RecruitCount.Position;
  gPlayers[MySpectator.PlayerIndex].AI.Setup.RecruitDelay := TrackBar_RecruitDelay.Position * 600;

  if not CheckBox_MaxSoldiers.Checked then
    gPlayers[MySpectator.PlayerIndex].AI.Setup.MaxSoldiers := -1
  else
    gPlayers[MySpectator.PlayerIndex].AI.Setup.MaxSoldiers := TrackBar_MaxSoldiers.Position;

  Town_DefenceRefresh;
end;


procedure TKMapEdInterface.Town_DefenceRefresh;
begin
  CheckBox_AutoDefence.Checked := gPlayers[MySpectator.PlayerIndex].AI.Setup.AutoDefend;
  TrackBar_EquipRateLeather.Position := gPlayers[MySpectator.PlayerIndex].AI.Setup.EquipRateLeather div 10;
  TrackBar_EquipRateIron.Position := gPlayers[MySpectator.PlayerIndex].AI.Setup.EquipRateIron div 10;
  TrackBar_RecruitCount.Position := gPlayers[MySpectator.PlayerIndex].AI.Setup.RecruitCount;
  TrackBar_RecruitDelay.Position := Round(gPlayers[MySpectator.PlayerIndex].AI.Setup.RecruitDelay / 600);

  CheckBox_MaxSoldiers.Checked := (gPlayers[MySpectator.PlayerIndex].AI.Setup.MaxSoldiers >= 0);
  TrackBar_MaxSoldiers.Enabled := CheckBox_MaxSoldiers.Checked;
  TrackBar_MaxSoldiers.Position := Max(gPlayers[MySpectator.PlayerIndex].AI.Setup.MaxSoldiers, 0);
end;


procedure TKMapEdInterface.Town_ScriptRefresh;
begin
  CheckBox_AutoBuild.Checked := gPlayers[MySpectator.PlayerIndex].AI.Setup.AutoBuild;
  CheckBox_AutoRepair.Checked := gPlayers[MySpectator.PlayerIndex].AI.Mayor.AutoRepair;
  TrackBar_SerfsPer10Houses.Position := Round(10*gPlayers[MySpectator.PlayerIndex].AI.Setup.SerfsPerHouse);
  TrackBar_WorkerCount.Position := gPlayers[MySpectator.PlayerIndex].AI.Setup.WorkerCount;
end;


procedure TKMapEdInterface.Town_ScriptChange(Sender: TObject);
begin
  gPlayers[MySpectator.PlayerIndex].AI.Setup.AutoBuild := CheckBox_AutoBuild.Checked;
  gPlayers[MySpectator.PlayerIndex].AI.Mayor.AutoRepair := CheckBox_AutoRepair.Checked;
  gPlayers[MySpectator.PlayerIndex].AI.Setup.SerfsPerHouse := TrackBar_SerfsPer10Houses.Position / 10;
  gPlayers[MySpectator.PlayerIndex].AI.Setup.WorkerCount := TrackBar_WorkerCount.Position;
end;


procedure TKMapEdInterface.Player_UpdateColors;
var
  I: Integer;
  PrevIndex: Integer;
begin
  //Set player colors
  for I := 0 to MAX_PLAYERS - 1 do
    Button_PlayerSelect[I].ShapeColor := gPlayers[I].FlagColor;

  //Update pages that have colored elements to match new players color
  Button_Town[ttUnits].FlagColor := gPlayers[MySpectator.PlayerIndex].FlagColor;
  for I := Low(Button_Citizen) to High(Button_Citizen) do
    Button_Citizen[I].FlagColor := gPlayers[MySpectator.PlayerIndex].FlagColor;
  for I := Low(Button_Warriors) to High(Button_Warriors) do
    Button_Warriors[I].FlagColor := gPlayers[MySpectator.PlayerIndex].FlagColor;
  Button_Player[ptColor].FlagColor := gPlayers[MySpectator.PlayerIndex].FlagColor;
  Button_Reveal.FlagColor := gPlayers[MySpectator.PlayerIndex].FlagColor;

  PrevIndex := Dropbox_PlayerFOW.ItemIndex;
  Dropbox_PlayerFOW.Clear;
  Dropbox_PlayerFOW.Add('Show all', -1);
  for I := 0 to MAX_PLAYERS - 1 do
    Dropbox_PlayerFOW.Add('[$' + IntToHex(FlagColorToTextColor(gPlayers[I].FlagColor) and $00FFFFFF, 6) + ']' + gPlayers[I].GetFormattedPlayerName, I);
  if PrevIndex = -1 then
    PrevIndex := 0; //Select Show All
  Dropbox_PlayerFOW.ItemIndex := PrevIndex;
end;


procedure TKMapEdInterface.Player_ChangeActive(Sender: TObject);
begin
  //If we had selected House or Unit - discard them
  fGuiHouse.Hide;

  //If we had selected House or Unit - discard them
  if Panel_Unit.Visible or Panel_Marker.Visible then
    fActivePage := nil;

  if MySpectator.Selected <> nil then
    MySpectator.Selected := nil;

  SetActivePlayer(TKMControl(Sender).Tag);

  //Refresh per-player settings
  DisplayPage(fActivePage);
end;





procedure TKMapEdInterface.SetActivePlayer(aIndex: TPlayerIndex);
var
  I: Integer;
begin
  MySpectator.PlayerIndex := aIndex;

  for I := 0 to MAX_PLAYERS - 1 do
    Button_PlayerSelect[I].Down := (I = MySpectator.PlayerIndex);

  Player_UpdateColors;
  UpdateAITabsEnabled;
end;


procedure TKMapEdInterface.Attack_Change(Sender: TObject);
var
  GT: TGroupType;
begin
  //Settings get saved on close, now we just toggle fields
  //because certain combinations can't coexist

  for GT := Low(TGroupType) to High(TGroupType) do
    NumEdit_AttackAmount[GT].Enabled := not CheckBox_AttackTakeAll.Checked;

  NumEdit_AttackLocX.Enabled := (TAIAttackTarget(Radio_AttackTarget.ItemIndex) = att_CustomPosition);
  NumEdit_AttackLocY.Enabled := (TAIAttackTarget(Radio_AttackTarget.ItemIndex) = att_CustomPosition);
end;


procedure TKMapEdInterface.Attack_Close(Sender: TObject);
var
  I: Integer;
  AA: TAIAttack;
  GT: TGroupType;
begin
  if Sender = Button_AttackOk then
  begin
    //Attack we are editing
    I := ColumnBox_Attacks.ItemIndex;

    //Copy attack info from controls to Attacks
    AA.AttackType := TAIAttackType(Radio_AttackType.ItemIndex);
    AA.Delay := NumEdit_AttackDelay.Value * 10;
    AA.TotalMen := NumEdit_AttackMen.Value;
    for GT := Low(TGroupType) to High(TGroupType) do
      AA.GroupAmounts[GT] := NumEdit_AttackAmount[GT].Value;
    AA.TakeAll := CheckBox_AttackTakeAll.Checked;
    AA.Target := TAIAttackTarget(Radio_AttackTarget.ItemIndex);
    AA.Range := TrackBar_AttackRange.Position;
    AA.CustomPosition := KMPoint(NumEdit_AttackLocX.Value, NumEdit_AttackLocY.Value);

    gPlayers[MySpectator.PlayerIndex].AI.General.Attacks[I] := AA;
  end;

  Panel_Attack.Hide;
  Attacks_Refresh;
end;


procedure TKMapEdInterface.Attack_Refresh(aAttack: TAIAttack);
var
  GT: TGroupType;
begin
  //Set attack properties to UI
  Radio_AttackType.ItemIndex := Byte(aAttack.AttackType);
  NumEdit_AttackDelay.Value := aAttack.Delay div 10;
  NumEdit_AttackMen.Value := aAttack.TotalMen;
  for GT := Low(TGroupType) to High(TGroupType) do
    NumEdit_AttackAmount[GT].Value := aAttack.GroupAmounts[GT];
  CheckBox_AttackTakeAll.Checked := aAttack.TakeAll;
  Radio_AttackTarget.ItemIndex := Byte(aAttack.Target);
  TrackBar_AttackRange.Position := aAttack.Range;
  NumEdit_AttackLocX.Value := aAttack.CustomPosition.X;
  NumEdit_AttackLocY.Value := aAttack.CustomPosition.Y;

  //Certain values disable certain controls
  Attack_Change(nil);
end;


//Add a dummy attack and let mapmaker edit it
procedure TKMapEdInterface.Attacks_Add(Sender: TObject);
var
  AA: TAIAttack;
begin
  FillChar(AA, SizeOf(AA), #0);
  gPlayers[MySpectator.PlayerIndex].AI.General.Attacks.AddAttack(AA);

  Attacks_Refresh;
  ColumnBox_Attacks.ItemIndex := gPlayers[MySpectator.PlayerIndex].AI.General.Attacks.Count - 1;

  //Edit the attack we have just appended
  Attacks_Edit(ColumnBox_Attacks.ItemIndex);
end;


procedure TKMapEdInterface.Attacks_Del(Sender: TObject);
var I: Integer;
begin
  I := ColumnBox_Attacks.ItemIndex;
  if InRange(I, 0, gPlayers[MySpectator.PlayerIndex].AI.General.Attacks.Count - 1) then
    gPlayers[MySpectator.PlayerIndex].AI.General.Attacks.Delete(I);

  Attacks_Refresh;
end;


procedure TKMapEdInterface.Attacks_Edit(aIndex: Integer);
begin
  Assert(InRange(aIndex, 0, gPlayers[MySpectator.PlayerIndex].AI.General.Attacks.Count - 1));
  Attack_Refresh(gPlayers[MySpectator.PlayerIndex].AI.General.Attacks[aIndex]);
  Panel_Attack.Show;
end;


procedure TKMapEdInterface.Attacks_ListClick(Sender: TObject);
var
  I: Integer;
begin
  I := ColumnBox_Attacks.ItemIndex;
  Button_AttacksDel.Enabled := InRange(I, 0, gPlayers[MySpectator.PlayerIndex].AI.General.Attacks.Count - 1);
end;


procedure TKMapEdInterface.Attacks_ListDoubleClick(Sender: TObject);
var
  I: Integer;
begin
  I := ColumnBox_Attacks.ItemIndex;

  //Check if user double-clicked on an existing item (not on an empty space)
  if InRange(I, 0, gPlayers[MySpectator.PlayerIndex].AI.General.Attacks.Count - 1) then
    Attacks_Edit(I);
end;


procedure TKMapEdInterface.Attacks_Refresh;
const
  Typ: array [TAIAttackType] of string = ('O', 'R');
  Tgt: array [TAIAttackTarget] of string = ('U', 'H1', 'H2', 'Pos');
var
  I: Integer;
  A: TAIAttack;
begin
  ColumnBox_Attacks.Clear;

  for I := 0 to gPlayers[MySpectator.PlayerIndex].AI.General.Attacks.Count - 1 do
  begin
    A := gPlayers[MySpectator.PlayerIndex].AI.General.Attacks[I];
    ColumnBox_Attacks.AddItem(MakeListRow([Typ[A.AttackType], IntToStr(A.Delay div 10), IntToStr(A.TotalMen), Tgt[A.Target], TypeToString(A.CustomPosition)]));
  end;

  Attacks_ListClick(nil);
end;


procedure TKMapEdInterface.Goal_Change(Sender: TObject);
begin
  //Settings get saved on close, now we just toggle fields
  //because certain combinations can't coexist

  NumEdit_GoalTime.Enabled := TGoalCondition(Radio_GoalCondition.ItemIndex) = gc_Time;
  NumEdit_GoalPlayer.Enabled := TGoalCondition(Radio_GoalCondition.ItemIndex) <> gc_Time;
end;


procedure TKMapEdInterface.Goal_Close(Sender: TObject);
var
  I: Integer;
  G: TKMGoal;
begin
  if Sender = Button_GoalOk then
  begin
    //Goal we are editing
    I := ColumnBox_Goals.ItemIndex;

    //Copy Goal info from controls to Goals
    G.GoalType := TGoalType(Radio_GoalType.ItemIndex);
    G.GoalCondition := TGoalCondition(Radio_GoalCondition.ItemIndex);
    if G.GoalType = glt_Survive then
      G.GoalStatus := gs_True
    else
      G.GoalStatus := gs_False;
    G.GoalTime := NumEdit_GoalTime.Value * 10;
    G.MessageToShow := NumEdit_GoalMessage.Value;
    G.PlayerIndex := NumEdit_GoalPlayer.Value - 1;

    gPlayers[MySpectator.PlayerIndex].AI.Goals[I] := G;
  end;

  Panel_Goal.Hide;
  Goals_Refresh;
end;


procedure TKMapEdInterface.Goal_Refresh(aGoal: TKMGoal);
begin
  Image_GoalFlag.FlagColor := gPlayers[MySpectator.PlayerIndex].FlagColor;

  Radio_GoalType.ItemIndex := Byte(aGoal.GoalType);
  Radio_GoalCondition.ItemIndex := Byte(aGoal.GoalCondition);
  NumEdit_GoalTime.Value := aGoal.GoalTime div 10;
  NumEdit_GoalMessage.Value := aGoal.MessageToShow;
  NumEdit_GoalPlayer.Value := aGoal.PlayerIndex + 1;

  //Certain values disable certain controls
  Goal_Change(nil);
end;


//Add a dummy goal and let mapmaker edit it
procedure TKMapEdInterface.Goals_Add(Sender: TObject);
var
  G: TKMGoal;
begin
  FillChar(G, SizeOf(G), #0);
  gPlayers[MySpectator.PlayerIndex].AI.Goals.AddGoal(G);

  Goals_Refresh;
  ColumnBox_Goals.ItemIndex := gPlayers[MySpectator.PlayerIndex].AI.Goals.Count - 1;

  //Edit the attack we have just appended
  Goals_Edit(ColumnBox_Goals.ItemIndex);
end;


procedure TKMapEdInterface.Goals_Del(Sender: TObject);
var I: Integer;
begin
  I := ColumnBox_Goals.ItemIndex;
  if InRange(I, 0, gPlayers[MySpectator.PlayerIndex].AI.Goals.Count - 1) then
    gPlayers[MySpectator.PlayerIndex].AI.Goals.Delete(I);
  Goals_Refresh;
end;


procedure TKMapEdInterface.Goals_Edit(aIndex: Integer);
begin
  Assert(InRange(aIndex, 0, gPlayers[MySpectator.PlayerIndex].AI.Goals.Count - 1));
  Goal_Refresh(gPlayers[MySpectator.PlayerIndex].AI.Goals[aIndex]);
  Panel_Goal.Show;
end;


procedure TKMapEdInterface.Goals_ListClick(Sender: TObject);
var
  I: Integer;
begin
  I := ColumnBox_Goals.ItemIndex;
  Button_GoalsDel.Enabled := InRange(I, 0, gPlayers[MySpectator.PlayerIndex].AI.Goals.Count - 1);
end;


procedure TKMapEdInterface.Goals_ListDoubleClick(Sender: TObject);
var
  I: Integer;
begin
  I := ColumnBox_Goals.ItemIndex;

  //Check if user double-clicked on an existing item (not on an empty space)
  if InRange(I, 0, gPlayers[MySpectator.PlayerIndex].AI.Goals.Count - 1) then
    Goals_Edit(I);
end;


procedure TKMapEdInterface.Goals_Refresh;
const
  Typ: array [TGoalType] of string = ('-', 'V', 'S');
  Cnd: array [TGoalCondition] of string = (
    'None', 'BuildTutorial', 'Time', 'Buildings', 'Troops', 'Unknown',
    'MilitaryAssets', 'SerfsAndSchools', 'EconomyBuildings');
var
  I: Integer;
  G: TKMGoal;
begin
  ColumnBox_Goals.Clear;

  for I := 0 to gPlayers[MySpectator.PlayerIndex].AI.Goals.Count - 1 do
  begin
    G := gPlayers[MySpectator.PlayerIndex].AI.Goals[I];
    ColumnBox_Goals.AddItem(MakeListRow([Typ[G.GoalType],
                                    Cnd[G.GoalCondition],
                                    IntToStr(G.PlayerIndex + 1),
                                    IntToStr(G.GoalTime div 10),
                                    IntToStr(G.MessageToShow)]));
  end;

  Goals_ListClick(nil);
end;


procedure TKMapEdInterface.Town_BuildChange(Sender: TObject);
var I: Integer;
begin
  //Reset cursor and see if it needs to be changed
  GameCursor.Mode := cmNone;
  GameCursor.Tag1 := 0;

  if Sender = Button_BuildCancel then
    GameCursor.Mode := cmErase
  else
  if Sender = Button_BuildRoad then
    GameCursor.Mode := cmRoad
  else
  if Sender = Button_BuildField then
    GameCursor.Mode := cmField
  else
  if Sender = Button_BuildWine then
    GameCursor.Mode := cmWine
  else

  for I := 1 to GUI_HOUSE_COUNT do
  if GUIHouseOrder[I] <> ht_None then
  if Sender = Button_Build[I] then
  begin
    GameCursor.Mode := cmHouses;
    GameCursor.Tag1 := Byte(GUIHouseOrder[I]);
  end;

  Town_BuildRefresh;
end;


procedure TKMapEdInterface.Town_BuildRefresh;
var
  I: Integer;
begin
  Button_BuildCancel.Down := (GameCursor.Mode = cmErase);
  Button_BuildRoad.Down   := (GameCursor.Mode = cmRoad);
  Button_BuildField.Down  := (GameCursor.Mode = cmField);
  Button_BuildWine.Down   := (GameCursor.Mode = cmWine);

  for I := 1 to GUI_HOUSE_COUNT do
  if GUIHouseOrder[I] <> ht_None then
    Button_Build[I].Down := (GameCursor.Mode = cmHouses) and (GameCursor.Tag1 = Byte(GUIHouseOrder[I]));
end;


procedure TKMapEdInterface.Town_UnitChange(Sender: TObject);
begin
  GameCursor.Mode := cmUnits;
  GameCursor.Tag1 := Byte(TKMButtonFlat(Sender).Tag);

  Town_UnitRefresh;
end;


procedure TKMapEdInterface.Town_UnitRefresh;
var
  I: Integer;
  B: TKMButtonFlat;
begin
  for I := 1 to Panel_Units.ChildCount do
  if Panel_Units.Childs[I] is TKMButtonFlat then
  begin
    B := TKMButtonFlat(Panel_Units.Childs[I]);
    B.Down := (GameCursor.Mode = cmUnits) and (GameCursor.Tag1 = B.Tag);
  end;
end;


procedure TKMapEdInterface.Extra_Change(Sender: TObject);
begin
  SHOW_TERRAIN_WIRES := TrackBar_Passability.Position <> 0;
  SHOW_TERRAIN_PASS := TrackBar_Passability.Position;

  if TrackBar_Passability.Position <> 0 then
    Label_Passability.Caption := GetEnumName(TypeInfo(TPassability), SHOW_TERRAIN_PASS)
  else
    Label_Passability.Caption := gResTexts[TX_MAPED_PASSABILITY_OFF];

  Layers_UpdateVisibility;
end;


//Set which layers are visible and which are not
//Layer is always visible if corresponding editing page is active (to see what gets placed)
procedure TKMapEdInterface.Layers_UpdateVisibility;
begin
  if fGame = nil then Exit; //Happens on init

  fGame.MapEditor.VisibleLayers := [];

  if Panel_Markers.Visible or Panel_MarkerReveal.Visible then
    fGame.MapEditor.VisibleLayers := fGame.MapEditor.VisibleLayers + [mlRevealFOW, mlCenterScreen];

  if Panel_Defence.Visible or Panel_MarkerDefence.Visible then
    fGame.MapEditor.VisibleLayers := fGame.MapEditor.VisibleLayers + [mlDefences];

  if CheckBox_ShowObjects.Checked or fGuiTerrain.Visible(ttObject) then
    fGame.MapEditor.VisibleLayers := fGame.MapEditor.VisibleLayers + [mlObjects];

  if CheckBox_ShowHouses.Checked or Panel_Build.Visible or fGuiHouse.Visible then
    fGame.MapEditor.VisibleLayers := fGame.MapEditor.VisibleLayers + [mlHouses];

  if CheckBox_ShowUnits.Checked or Panel_Units.Visible or Panel_Unit.Visible then
    fGame.MapEditor.VisibleLayers := fGame.MapEditor.VisibleLayers + [mlUnits];

  if fGuiTerrain.Visible(ttSelection) then
    fGame.MapEditor.VisibleLayers := fGame.MapEditor.VisibleLayers + [mlSelection];

  if CheckBox_ShowDeposits.Checked then
    fGame.MapEditor.VisibleLayers := fGame.MapEditor.VisibleLayers + [mlDeposits];
end;


procedure TKMapEdInterface.ShowUnitInfo(Sender: TKMUnit);
begin
  if Sender = nil then
  begin
    DisplayPage(nil);
    Exit;
  end;

  SetActivePlayer(Sender.Owner);

  DisplayPage(Panel_Unit);
  Label_UnitName.Caption := fResource.UnitDat[Sender.UnitType].GUIName;
  Image_UnitPic.TexID := fResource.UnitDat[Sender.UnitType].GUIScroll;
  Image_UnitPic.FlagColor := gPlayers[Sender.Owner].FlagColor;
  KMConditionBar_Unit.Position := Sender.Condition / UNIT_MAX_CONDITION;

  Label_UnitDescription.Caption := fResource.UnitDat[Sender.UnitType].Description;
  Label_UnitDescription.Show;
end;


procedure TKMapEdInterface.ShowGroupInfo(Sender: TKMUnitGroup);
begin
  if (Sender = nil) or Sender.IsDead then
  begin
    DisplayPage(nil);
    Exit;
  end;

  SetActivePlayer(Sender.Owner);

  DisplayPage(Panel_Unit);
  Label_UnitName.Caption := fResource.UnitDat[Sender.UnitType].GUIName;
  Image_UnitPic.TexID := fResource.UnitDat[Sender.UnitType].GUIScroll;
  Image_UnitPic.FlagColor := gPlayers[Sender.Owner].FlagColor;
  KMConditionBar_Unit.Position := Sender.Condition / UNIT_MAX_CONDITION;

  //Warrior specific
  Label_UnitDescription.Hide;
  ImageStack_Army.SetCount(Sender.MapEdCount, Sender.UnitsPerRow, Sender.UnitsPerRow div 2 + 1);
  Label_ArmyCount.Caption := IntToStr(Sender.MapEdCount);
  DropBox_ArmyOrder.ItemIndex := Byte(Sender.MapEdOrder.Order);
  Edit_ArmyOrderX.Value := Sender.MapEdOrder.Pos.Loc.X;
  Edit_ArmyOrderY.Value := Sender.MapEdOrder.Pos.Loc.Y;
  Edit_ArmyOrderDir.Value := Max(Byte(Sender.MapEdOrder.Pos.Dir) - 1, 0);
  Unit_ArmyChange1(nil);
  Panel_Army.Show;
end;


procedure TKMapEdInterface.ShowMarkerInfo(aMarker: TKMMapEdMarker);
begin
  fGame.MapEditor.ActiveMarker := aMarker;

  if (aMarker.MarkerType = mtNone) or (aMarker.Owner = PLAYER_NONE) or (aMarker.Index = -1) then
  begin
    DisplayPage(nil);
    Exit;
  end;

  SetActivePlayer(aMarker.Owner);
  Image_MarkerPic.FlagColor := gPlayers[aMarker.Owner].FlagColor;

  case aMarker.MarkerType of
    mtDefence:    begin
                    Label_MarkerType.Caption := gResTexts[TX_MAPED_AI_DEFENCE_POSITION];
                    Image_MarkerPic.TexID := 338;
                    DropList_DefenceGroup.ItemIndex := Byte(gPlayers[aMarker.Owner].AI.General.DefencePositions[aMarker.Index].GroupType);
                    DropList_DefenceType.ItemIndex := Byte(gPlayers[aMarker.Owner].AI.General.DefencePositions[aMarker.Index].DefenceType);
                    TrackBar_DefenceRad.Position := gPlayers[aMarker.Owner].AI.General.DefencePositions[aMarker.Index].Radius;
                    DisplayPage(Panel_MarkerDefence);
                  end;
    mtRevealFOW:  begin
                    Label_MarkerType.Caption := gResTexts[TX_MAPED_FOG];
                    Image_MarkerPic.TexID := 393;
                    TrackBar_RevealSize.Position := fGame.MapEditor.Revealers[aMarker.Owner].Tag[aMarker.Index];
                    DisplayPage(Panel_MarkerReveal);
                  end;
  end;
end;


procedure TKMapEdInterface.ShowMessage(aText: string);
begin
  Label_Message.Caption := aText;
  Panel_Message.Show;
  Image_Message.Show; //Hidden by default, only visible when a message is shown
end;


procedure TKMapEdInterface.Menu_SaveClick(Sender: TObject);
var
  SaveName: string;
begin
  SaveName := TKMapsCollection.FullPath(Trim(Edit_SaveName.Text), '.dat', Radio_Save_MapType.ItemIndex = 1);

  if (Sender = Edit_SaveName) or (Sender = Radio_Save_MapType) then
  begin
    CheckBox_SaveExists.Enabled := FileExists(SaveName);
    Label_SaveExists.Visible := CheckBox_SaveExists.Enabled;
    CheckBox_SaveExists.Checked := False;
    Button_SaveSave.Enabled := not CheckBox_SaveExists.Enabled;
  end;

  if Sender = CheckBox_SaveExists then
    Button_SaveSave.Enabled := CheckBox_SaveExists.Checked;

  if Sender = Button_SaveSave then
  begin
    fGame.SaveMapEditor(SaveName);

    Player_UpdateColors;
    Label_MissionName.Caption := fGame.GameName;

    SwitchPage(Button_SaveCancel); //return to previous menu
  end;
end;


procedure TKMapEdInterface.Marker_Change(Sender: TObject);
var
  Marker: TKMMapEdMarker;
  DP: TAIDefencePosition;
  Rev: TKMPointTagList;
begin
  Marker := fGame.MapEditor.ActiveMarker;

  case Marker.MarkerType of
    mtDefence:    begin
                    DP := gPlayers[Marker.Owner].AI.General.DefencePositions[Marker.Index];
                    DP.Radius := TrackBar_DefenceRad.Position;
                    DP.DefenceType := TAIDefencePosType(DropList_DefenceType.ItemIndex);
                    DP.GroupType := TGroupType(DropList_DefenceGroup.ItemIndex);

                    if Sender = Button_DefenceCW then
                      DP.Position := KMPointDir(DP.Position.Loc, KMNextDirection(DP.Position.Dir));
                    if Sender = Button_DefenceCCW then
                      DP.Position := KMPointDir(DP.Position.Loc, KMPrevDirection(DP.Position.Dir));

                    if Sender = Button_DefenceDelete then
                    begin
                      gPlayers[Marker.Owner].AI.General.DefencePositions.Delete(Marker.Index);
                      SwitchPage(Button_Town[ttDefences]);
                    end;

                    if Sender = Button_DefenceClose then
                      SwitchPage(Button_Town[ttDefences]);
                  end;
    mtRevealFOW:  begin
                    //Shortcut to structure we update
                    Rev := fGame.MapEditor.Revealers[Marker.Owner];

                    if Sender = TrackBar_RevealSize then
                      Rev.Tag[Marker.Index] := TrackBar_RevealSize.Position;

                    if Sender = Button_RevealDelete then
                    begin
                      Rev.Delete(Marker.Index);
                      SwitchPage(Button_Player[ptMarkers]);
                    end;

                    if Sender = Button_RevealClose then
                      SwitchPage(Button_Player[ptMarkers]);
                  end;
  end;
end;


//Mission loading dialog
procedure TKMapEdInterface.Menu_LoadClick(Sender: TObject);
var
  MapName: string;
  IsMulti: Boolean;
begin
  if ListBox_Load.ItemIndex = -1 then Exit;

  MapName := ListBox_Load.Item[ListBox_Load.ItemIndex];
  IsMulti := Radio_Load_MapType.ItemIndex = 1;
  fGameApp.NewMapEditor(TKMapsCollection.FullPath(MapName, '.dat', IsMulti), 0, 0);

  //Keep MP/SP selected in the new map editor interface
  //this one is destroyed already by `fGameApp.NewMapEditor`
  if (fGame <> nil) and (fGame.MapEditorInterface <> nil) then
    fGame.MapEditorInterface.SetLoadMode(IsMulti);
end;


{Quit the mission and return to main menu}
procedure TKMapEdInterface.Menu_QuitClick(Sender: TObject);
begin
  fGameApp.Stop(gr_MapEdEnd);
end;


procedure TKMapEdInterface.Menu_LoadChange(Sender: TObject);
begin
  Menu_LoadUpdate;
end;


procedure TKMapEdInterface.Menu_LoadUpdate;
begin
  fMaps.TerminateScan;
  fMapsMP.TerminateScan;

  ListBox_Load.Clear;
  ListBox_Load.ItemIndex := -1;

  if Radio_Load_MapType.ItemIndex = 0 then
    fMaps.Refresh(Menu_LoadUpdateDone)
  else
    fMapsMP.Refresh(Menu_LoadUpdateDone);
end;


procedure TKMapEdInterface.Menu_LoadUpdateDone(Sender: TObject);
var
  I: Integer;
  PrevMap: string;
  PrevTop: Integer;
  M: TKMapsCollection;
begin
  if Radio_Load_MapType.ItemIndex = 0 then
    M := fMaps
  else
    M := fMapsMP;

  //Remember previous map
  if ListBox_Load.ItemIndex <> -1 then
    PrevMap := M.Maps[ListBox_Load.ItemIndex].FileName
  else
    PrevMap := '';
  PrevTop := ListBox_Load.TopIndex;

  ListBox_Load.Clear;

  M.Lock;
  try
    for I := 0 to M.Count - 1 do
    begin
      ListBox_Load.Add(M.Maps[I].FileName);
      if M.Maps[I].FileName = PrevMap then
        ListBox_Load.ItemIndex := I;
    end;
  finally
    M.Unlock;
  end;

  ListBox_Load.TopIndex := PrevTop;
end;


//This function will be called if the user right clicks on the screen.
procedure TKMapEdInterface.RightClick_Cancel;
begin
  //We should drop the tool but don't close opened tab. This allows eg:
  //Place a warrior, right click so you are not placing more warriors,
  //select the placed warrior.

  //Terrain height uses both buttons for relief changing, tile rotation etc.
  if fGuiTerrain.Visible(ttHeights) then Exit;
  //Terrain tiles uses right click for choosing tile rotation
  if fGuiTerrain.Visible(ttTile) then Exit;

  GameCursor.Mode := cmNone;
  GameCursor.Tag1 := 0;

  //Display page will hide the army panel
  if Panel_Army.Visible then Exit;

  DisplayPage(fActivePage);
end;


procedure TKMapEdInterface.UpdateAITabsEnabled;
begin
  if fGame.MapEditor.PlayerAI[MySpectator.PlayerIndex] then
  begin
    Button_Town[ttScript].Enable;
    Button_Town[ttDefences].Enable;
    Button_Town[ttOffence].Enable;
  end
  else
  begin
    Button_Town[ttScript].Disable;
    Button_Town[ttDefences].Disable;
    Button_Town[ttOffence].Disable;
    if Panel_Script.Visible or Panel_Defence.Visible or Panel_Offence.Visible then
      Button_Town[ttHouses].Click; //Change back to first tab
  end;
end;


procedure TKMapEdInterface.SetLoadMode(aMultiplayer: Boolean);
begin
  if aMultiplayer then
  begin
    Radio_Load_MapType.ItemIndex := 1;
    Radio_Save_MapType.ItemIndex := 1;
  end
  else
  begin
    Radio_Load_MapType.ItemIndex := 0;
    Radio_Save_MapType.ItemIndex := 0;
  end;
end;


procedure TKMapEdInterface.Unit_ArmyChange1(Sender: TObject);
var
  Group: TKMUnitGroup;
begin
  if not (MySpectator.Selected is TKMUnitGroup) then Exit;

  Group := TKMUnitGroup(MySpectator.Selected);
  if Sender = Button_Army_ForUp then Group.UnitsPerRow := Group.UnitsPerRow - 1;
  if Sender = Button_Army_ForDown then Group.UnitsPerRow := Group.UnitsPerRow + 1;

  ImageStack_Army.SetCount(Group.MapEdCount, Group.UnitsPerRow, Group.UnitsPerRow div 2 + 1);
  Label_ArmyCount.Caption := IntToStr(Group.MapEdCount);

  if Sender = Button_Army_RotCW then  Group.Direction := KMNextDirection(Group.Direction);
  if Sender = Button_Army_RotCCW then Group.Direction := KMPrevDirection(Group.Direction);
  Group.ResetAnimStep;

  //Toggle between full and half condition
  if Sender = Button_ArmyFood then
  begin
    if Group.Condition = UNIT_MAX_CONDITION then
      Group.Condition := UNIT_MAX_CONDITION div 2
    else
      Group.Condition := UNIT_MAX_CONDITION;
    KMConditionBar_Unit.Position := Group.Condition / UNIT_MAX_CONDITION;
  end;

  Group.MapEdOrder.Order := TKMInitialOrder(DropBox_ArmyOrder.ItemIndex);
  Group.MapEdOrder.Pos.Loc.X := Edit_ArmyOrderX.Value;
  Group.MapEdOrder.Pos.Loc.Y := Edit_ArmyOrderY.Value;
  Group.MapEdOrder.Pos.Dir := TKMDirection(Edit_ArmyOrderDir.Value + 1);

  if DropBox_ArmyOrder.ItemIndex = 0 then
  begin
    Edit_ArmyOrderX.Disable;
    Edit_ArmyOrderY.Disable;
    Edit_ArmyOrderDir.Disable;
  end
  else
    if DropBox_ArmyOrder.ItemIndex = 2 then
    begin
      Edit_ArmyOrderX.Enable;
      Edit_ArmyOrderY.Enable;
      Edit_ArmyOrderDir.Disable; //Attack position doesn't let you set direction
    end
    else
    begin
      Edit_ArmyOrderX.Enable;
      Edit_ArmyOrderY.Enable;
      Edit_ArmyOrderDir.Enable;
    end;
end;


procedure TKMapEdInterface.Unit_ArmyChange2(Sender: TObject; AButton: TMouseButton);
var
  NewCount: Integer;
  Group: TKMUnitGroup;
begin
  if not (MySpectator.Selected is TKMUnitGroup) then Exit;

  Group := TKMUnitGroup(MySpectator.Selected);

  if Sender = Button_ArmyDec then //Decrease
    NewCount := Group.MapEdCount - ORDER_CLICK_AMOUNT[AButton]
  else //Increase
    NewCount := Group.MapEdCount + ORDER_CLICK_AMOUNT[AButton];

  Group.MapEdCount := EnsureRange(NewCount, 1, 200); //Limit max members
  ImageStack_Army.SetCount(Group.MapEdCount, Group.UnitsPerRow, Group.UnitsPerRow div 2 + 1);
  Label_ArmyCount.Caption := IntToStr(Group.MapEdCount);
end;


procedure TKMapEdInterface.ExtraMessage_Switch(Sender: TObject);
begin
  //Don't use DisplayPage because that hides other stuff
  if Sender = Image_Extra then
  begin
    if Panel_Extra.Visible then
    begin
      Panel_Extra.Hide;
      gSoundPlayer.Play(sfxn_MPChatClose);
    end
    else
    begin
      Panel_Extra.Show;
      Panel_Message.Hide;
      gSoundPlayer.Play(sfxn_MPChatOpen);
    end;
  end
  else
  if Sender = Image_ExtraClose then
  begin
    Panel_Extra.Hide;
    gSoundPlayer.Play(sfxn_MPChatClose);
  end;
  if Sender = Image_Message then
  begin
    if Panel_Message.Visible then
    begin
      Panel_Message.Hide;
      gSoundPlayer.Play(sfxn_MPChatClose);
    end
    else
    begin
      Panel_Message.Show;
      Panel_Extra.Hide;
      gSoundPlayer.Play(sfxn_MPChatOpen);
    end;
  end
  else
  if Sender = Image_MessageClose then
  begin
    Panel_Message.Hide;
    gSoundPlayer.Play(sfxn_MPChatClose);
  end;
end;


procedure TKMapEdInterface.Player_ColorClick(Sender: TObject);
begin
  if not (Sender = ColorSwatch_Color) then exit;
  gPlayers[MySpectator.PlayerIndex].FlagColor := ColorSwatch_Color.GetColor;
  Player_UpdateColors;
end;


procedure TKMapEdInterface.Player_FOWChange(Sender: TObject);
begin
  MySpectator.FOWIndex := Dropbox_PlayerFOW.GetTag(Dropbox_PlayerFOW.ItemIndex);
  fGame.Minimap.Update(False); //Force update right now so FOW doesn't appear to lag
end;


procedure TKMapEdInterface.Player_BlockHouseClick(Sender: TObject);
var
  I: Integer;
  H: THouseType;
begin
  I := TKMButtonFlat(Sender).Tag;
  H := GUIHouseOrder[I];

  //Loop through states CanBuild > CantBuild > Released
  if not gPlayers[MySpectator.PlayerIndex].Stats.HouseBlocked[H] and not gPlayers[MySpectator.PlayerIndex].Stats.HouseGranted[H] then
  begin
    gPlayers[MySpectator.PlayerIndex].Stats.HouseBlocked[H] := True;
    gPlayers[MySpectator.PlayerIndex].Stats.HouseGranted[H] := False;
  end else
  if gPlayers[MySpectator.PlayerIndex].Stats.HouseBlocked[H] and not gPlayers[MySpectator.PlayerIndex].Stats.HouseGranted[H] then
  begin
    gPlayers[MySpectator.PlayerIndex].Stats.HouseBlocked[H] := False;
    gPlayers[MySpectator.PlayerIndex].Stats.HouseGranted[H] := True;
  end else
  begin
    gPlayers[MySpectator.PlayerIndex].Stats.HouseBlocked[H] := False;
    gPlayers[MySpectator.PlayerIndex].Stats.HouseGranted[H] := False;
  end;

  Player_BlockHouseRefresh;
end;


procedure TKMapEdInterface.Player_BlockHouseRefresh;
var
  I: Integer;
  H: THouseType;
begin
  for I := 1 to GUI_HOUSE_COUNT do
  begin
    H := GUIHouseOrder[I];
    if gPlayers[MySpectator.PlayerIndex].Stats.HouseBlocked[H] and not gPlayers[MySpectator.PlayerIndex].Stats.HouseGranted[H] then
      Image_BlockHouse[I].TexID := 32
    else
    if gPlayers[MySpectator.PlayerIndex].Stats.HouseGranted[H] and not gPlayers[MySpectator.PlayerIndex].Stats.HouseBlocked[H] then
      Image_BlockHouse[I].TexID := 33
    else
    if not gPlayers[MySpectator.PlayerIndex].Stats.HouseGranted[H] and not gPlayers[MySpectator.PlayerIndex].Stats.HouseBlocked[H] then
      Image_BlockHouse[I].TexID := 0
    else
      Image_BlockHouse[I].TexID := 24; //Some erroneous value
  end;
end;


procedure TKMapEdInterface.Player_BlockTradeClick(Sender: TObject);
var
  I: Integer;
  R: TWareType;
begin
  I := TKMButtonFlat(Sender).Tag;
  R := StoreResType[I];

  gPlayers[MySpectator.PlayerIndex].Stats.AllowToTrade[R] := not gPlayers[MySpectator.PlayerIndex].Stats.AllowToTrade[R];

  Player_BlockTradeRefresh;
end;


procedure TKMapEdInterface.Player_BlockTradeRefresh;
var
  I: Integer;
  R: TWareType;
begin
  for I := 1 to STORE_RES_COUNT do
  begin
    R := StoreResType[I];
    if gPlayers[MySpectator.PlayerIndex].Stats.AllowToTrade[R] then
      Image_BlockTrade[I].TexID := 0
    else
      Image_BlockTrade[I].TexID := 32; //Red cross
  end;
end;


procedure TKMapEdInterface.Player_MarkerClick(Sender: TObject);
begin
  //Press the button
  if Sender = Button_Reveal then
  begin
    Button_Reveal.Down := not Button_Reveal.Down;
    Button_CenterScreen.Down := False;
  end;
  if Sender = Button_CenterScreen then
  begin
    Button_CenterScreen.Down := not Button_CenterScreen.Down;
    Button_Reveal.Down := False;
  end;

  if (Sender = nil) and (GameCursor.Mode = cmNone) then
  begin
    Button_Reveal.Down := False;
    Button_CenterScreen.Down := False;
  end;

  if Button_Reveal.Down then
  begin
    GameCursor.Mode := cmMarkers;
    GameCursor.Tag1 := MARKER_REVEAL;
    GameCursor.MapEdSize := TrackBar_RevealNewSize.Position;
  end
  else
  if Button_CenterScreen.Down then
  begin
    GameCursor.Mode := cmMarkers;
    GameCursor.Tag1 := MARKER_CENTERSCREEN;
  end
  else
  begin
    GameCursor.Mode := cmNone;
    GameCursor.Tag1 := 0;
  end;

  if Sender = CheckBox_RevealAll then
    fGame.MapEditor.RevealAll[MySpectator.PlayerIndex] := CheckBox_RevealAll.Checked
  else
    CheckBox_RevealAll.Checked := fGame.MapEditor.RevealAll[MySpectator.PlayerIndex];

  if Sender = Button_PlayerCenterScreen then
    fGame.Viewport.Position := KMPointF(gPlayers[MySpectator.PlayerIndex].CenterScreen); //Jump to location

  Button_PlayerCenterScreen.Caption := TypeToString(gPlayers[MySpectator.PlayerIndex].CenterScreen);
end;


procedure TKMapEdInterface.Mission_AlliancesChange(Sender: TObject);
var I,K: Integer;
begin
  if Sender = nil then
  begin
    for I:=0 to gPlayers.Count-1 do
    for K:=0 to gPlayers.Count-1 do
      if (gPlayers[I]<>nil)and(gPlayers[K]<>nil) then
        CheckBox_Alliances[I,K].Checked := (gPlayers.CheckAlliance(gPlayers[I].PlayerIndex, gPlayers[K].PlayerIndex)=at_Ally)
      else
        CheckBox_Alliances[I,K].Disable; //Player does not exist?
    exit;
  end;

  I := TKMCheckBox(Sender).Tag div gPlayers.Count;
  K := TKMCheckBox(Sender).Tag mod gPlayers.Count;
  if CheckBox_Alliances[I,K].Checked then gPlayers[I].Alliances[K] := at_Ally
                                     else gPlayers[I].Alliances[K] := at_Enemy;

  //Copy status to symmetrical item
  if CheckBox_AlliancesSym.Checked then
  begin
    CheckBox_Alliances[K,I].Checked := CheckBox_Alliances[I,K].Checked;
    gPlayers[K].Alliances[I] := gPlayers[I].Alliances[K];
  end;
end;


procedure TKMapEdInterface.Mission_ModeChange(Sender: TObject);
begin
  fGame.MissionMode := TKMissionMode(Radio_MissionMode.ItemIndex);
end;


procedure TKMapEdInterface.Mission_ModeUpdate;
begin
  Radio_MissionMode.ItemIndex := Byte(fGame.MissionMode);
end;


procedure TKMapEdInterface.Mission_PlayerTypesUpdate;
var I: Integer;
begin
  for I := 0 to gPlayers.Count - 1 do
  begin
    CheckBox_PlayerTypes[I, 0].Enabled := gPlayers[I].HasAssets;
    CheckBox_PlayerTypes[I, 1].Enabled := gPlayers[I].HasAssets;
    CheckBox_PlayerTypes[I, 2].Enabled := gPlayers[I].HasAssets;

    CheckBox_PlayerTypes[I, 0].Checked := gPlayers[I].HasAssets and (fGame.MapEditor.DefaultHuman = I);
    CheckBox_PlayerTypes[I, 1].Checked := gPlayers[I].HasAssets and fGame.MapEditor.PlayerHuman[I];
    CheckBox_PlayerTypes[I, 2].Checked := gPlayers[I].HasAssets and fGame.MapEditor.PlayerAI[I];
  end;
end;


procedure TKMapEdInterface.Mission_PlayerTypesChange(Sender: TObject);
var PlayerId: Integer;
begin
  PlayerId := TKMCheckBox(Sender).Tag;

  //There should be exactly one default human player
  if Sender = CheckBox_PlayerTypes[PlayerId, 0] then
    fGame.MapEditor.DefaultHuman := PlayerId;

  if Sender = CheckBox_PlayerTypes[PlayerId, 1] then
    fGame.MapEditor.PlayerHuman[PlayerId] := CheckBox_PlayerTypes[PlayerId, 1].Checked;

  if Sender = CheckBox_PlayerTypes[PlayerId, 2] then
    fGame.MapEditor.PlayerAI[PlayerId] := CheckBox_PlayerTypes[PlayerId, 2].Checked;

  Mission_PlayerTypesUpdate;
  UpdateAITabsEnabled;
end;


procedure TKMapEdInterface.KeyDown(Key: Word; Shift: TShiftState);
begin
  if fMyControls.KeyDown(Key, Shift) then
  begin
    fGame.Viewport.ReleaseScrollKeys; //Release the arrow keys when you open a window with an edit to stop them becoming stuck
    Exit; //Handled by Controls
  end;

  //DoPress is not working properly yet. GamePlay only uses DoClick so MapEd can be the same for now.
  //1-5 game menu shortcuts
  //if Key in [49..53] then
  //  Button_Main[Key-48].DoPress;

  //For now enter can open up Extra panel
  if Key = VK_RETURN then
    ExtraMessage_Switch(Image_Extra);

  if Key = VK_ESCAPE then
    if Image_MessageClose.Click
    or Image_ExtraClose.Click then ;

  //Scrolling
  if Key = VK_LEFT  then fGame.Viewport.ScrollKeyLeft  := True;
  if Key = VK_RIGHT then fGame.Viewport.ScrollKeyRight := True;
  if Key = VK_UP    then fGame.Viewport.ScrollKeyUp    := True;
  if Key = VK_DOWN  then fGame.Viewport.ScrollKeyDown  := True;
end;


procedure TKMapEdInterface.KeyUp(Key: Word; Shift: TShiftState);
begin
  if fMyControls.KeyUp(Key, Shift) then Exit; //Handled by Controls

  //1-5 game menu shortcuts
  if Key in [49..53] then
    Button_Main[Key-48].Click;

  //Scrolling
  if Key = VK_LEFT  then fGame.Viewport.ScrollKeyLeft  := False;
  if Key = VK_RIGHT then fGame.Viewport.ScrollKeyRight := False;
  if Key = VK_UP    then fGame.Viewport.ScrollKeyUp    := False;
  if Key = VK_DOWN  then fGame.Viewport.ScrollKeyDown  := False;

  //Backspace resets the zoom and view, similar to other RTS games like Dawn of War.
  //This is useful because it is hard to find default zoom using the scroll wheel, and if not zoomed 100% things can be scaled oddly (like shadows)
  if Key = VK_BACK  then fGame.Viewport.ResetZoom;
end;


procedure TKMapEdInterface.MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
var MyRect: TRect;
begin
  fMyControls.MouseDown(X,Y,Shift,Button);

  if fMyControls.CtrlOver <> nil then
    Exit;

  if (Button = mbMiddle) and (fMyControls.CtrlOver = nil) then
  begin
     fDragScrolling := True;
     //Restrict the cursor to the window, for now.
     //TODO: Allow one to drag out of the window, and still capture.
     {$IFDEF MSWindows}
       MyRect := fMain.ClientRect;
       ClipCursor(@MyRect);
     {$ENDIF}
     fDragScrollingCursorPos.X := X;
     fDragScrollingCursorPos.Y := Y;
     fDragScrollingViewportPos.X := fGame.Viewport.Position.X;
     fDragScrollingViewportPos.Y := fGame.Viewport.Position.Y;
     fResource.Cursors.Cursor := kmc_Drag;
     Exit;
  end;

  if Button = mbRight then
    RightClick_Cancel;

  //So terrain brushes start on mouse down not mouse move
  fGame.UpdateGameCursor(X, Y, Shift);

  fGame.MapEditor.MouseDown(Button);
end;


procedure TKMapEdInterface.MouseMove(Shift: TShiftState; X,Y: Integer);
var
  Marker: TKMMapEdMarker;
  VP: TKMPointF;
begin
  if fDragScrolling then
  begin
    VP.X := fDragScrollingViewportPos.X + (fDragScrollingCursorPos.X - X) / (CELL_SIZE_PX * fGame.Viewport.Zoom);
    VP.Y := fDragScrollingViewportPos.Y + (fDragScrollingCursorPos.Y - Y) / (CELL_SIZE_PX * fGame.Viewport.Zoom);
    fGame.Viewport.Position := VP;
    Exit;
  end;

  fMyControls.MouseMove(X,Y,Shift);

  if fMyControls.CtrlOver <> nil then
  begin
    //kmc_Edit and kmc_DragUp are handled by Controls.MouseMove (it will reset them when required)
    if not fGame.Viewport.Scrolling and not (fResource.Cursors.Cursor in [kmc_Edit,kmc_DragUp]) then
      fResource.Cursors.Cursor := kmc_Default;
    GameCursor.SState := []; //Don't do real-time elevate when the mouse is over controls, only terrain
    Exit;
  end
  else
    DisplayHint(nil); //Clear shown hint

  fGame.UpdateGameCursor(X,Y,Shift);
  if GameCursor.Mode = cmNone then
  begin
    Marker := fGame.MapEditor.HitTest(GameCursor.Cell.X, GameCursor.Cell.Y);
    if Marker.MarkerType <> mtNone then
      fResource.Cursors.Cursor := kmc_Info
    else
    if MySpectator.HitTestCursor <> nil then
      fResource.Cursors.Cursor := kmc_Info
    else
    if not fGame.Viewport.Scrolling then
      fResource.Cursors.Cursor := kmc_Default;
  end;

  Label_Coordinates.Caption := Format('X: %d, Y: %d', [GameCursor.Cell.X, GameCursor.Cell.Y]);

  fGame.MapEditor.MouseMove;
end;


procedure TKMapEdInterface.MouseUp(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
var
  DP: TAIDefencePosition;
  Marker: TKMMapEdMarker;
begin
  if fDragScrolling then
  begin
    if Button = mbMiddle then
    begin
      fDragScrolling := False;
      fResource.Cursors.Cursor := kmc_Default; //Reset cursor
      fMain.ApplyCursorRestriction;
    end;
    Exit;
  end;

  if fMyControls.CtrlOver <> nil then
  begin
    fMyControls.MouseUp(X,Y,Shift,Button);
    Exit; //We could have caused fGame reinit, so exit at once
  end;

  case Button of
    mbLeft:   if GameCursor.Mode = cmNone then
              begin
                //If there are some additional layers we first HitTest them
                //since they are rendered ontop of Houses/Objects
                Marker := fGame.MapEditor.HitTest(GameCursor.Cell.X, GameCursor.Cell.Y);
                if Marker.MarkerType <> mtNone then
                  ShowMarkerInfo(Marker)
                else
                begin
                  MySpectator.UpdateSelect;

                  if MySpectator.Selected is TKMHouse then
                  begin
                    HidePages;
                    SetActivePlayer(TKMHouse(MySpectator.Selected).Owner);
                    fGuiHouse.Show(TKMHouse(MySpectator.Selected));
                  end;
                  if MySpectator.Selected is TKMUnit then
                    ShowUnitInfo(TKMUnit(MySpectator.Selected));
                  if MySpectator.Selected is TKMUnitGroup then
                    ShowGroupInfo(TKMUnitGroup(MySpectator.Selected));
                end;
              end;
    mbRight:  begin
                //Right click performs some special functions and shortcuts
                if GameCursor.Mode = cmTiles then
                  GameCursor.MapEdDir := (GameCursor.MapEdDir + 1) mod 4; //Rotate tile direction

                //Move the selected object to the cursor location
                if MySpectator.Selected is TKMHouse then
                  TKMHouse(MySpectator.Selected).SetPosition(GameCursor.Cell); //Can place is checked in SetPosition

                if MySpectator.Selected is TKMUnit then
                  TKMUnit(MySpectator.Selected).SetPosition(GameCursor.Cell);

                if MySpectator.Selected is TKMUnitGroup then
                  TKMUnitGroup(MySpectator.Selected).Position := GameCursor.Cell;

                if Panel_Marker.Visible then
                begin
                  Marker := fGame.MapEditor.ActiveMarker;
                  case Marker.MarkerType of
                    mtDefence:   begin
                                   DP := gPlayers[Marker.Owner].AI.General.DefencePositions[Marker.Index];
                                   DP.Position := KMPointDir(GameCursor.Cell, DP.Position.Dir);
                                 end;
                    mtRevealFOW: fGame.MapEditor.Revealers[Marker.Owner][Marker.Index] := GameCursor.Cell;
                  end;
                end;
              end;
  end;

  fGame.UpdateGameCursor(X, Y, Shift); //Updates the shift state

  fGame.MapEditor.MouseUp(Button);
end;


end.