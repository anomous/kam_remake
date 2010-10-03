unit KM_Houses;
{$I KaM_Remake.inc}
interface
uses Classes, KromUtils, Math, SysUtils, Windows,
     KM_CommonTypes, KM_Defaults, KM_Utils;

  {Everything related to houses is here}
type
  TKMHouse = class;

  THouseAction = class(TObject)
  private
    fHouse:TKMHouse;
    fHouseState: THouseState;
    fSubAction: THouseActionSet;
  public
    constructor Create(aHouse:TKMHouse; aHouseState: THouseState);
    procedure SetState(aHouseState: THouseState);
    procedure SubActionWork(aActionSet: THouseActionType);
    function GetWorkID():byte;
    procedure SubActionAdd(aActionSet: THouseActionSet);
    procedure SubActionRem(aActionSet: THouseActionSet);
    property ActionType: THouseState read fHouseState;
    procedure Save(SaveStream:TKMemoryStream);
    procedure Load(LoadStream:TKMemoryStream);
  end;


  TKMHouse = class(TObject)
  private
    fHouseType: THouseType; //House type
    fPosition: TKMPoint; //House position on map, kinda virtual thing cos it doesn't match with entrance
    fBuildState: THouseBuildState; // = (hbs_Glyph, hbs_NoGlyph, hbs_Wood, hbs_Stone, hbs_Done);
    fOwner: TPlayerID; //House owner player, determines flag color as well

    fBuildSupplyWood: byte; //How much Wood was delivered to house building site
    fBuildSupplyStone: byte; //How much Stone was delivered to house building site
    fBuildReserve: byte; //Take one build supply resource into reserve and "build from it"
    fBuildingProgress: word; //That is how many efforts were put into building (Wooding+Stoning)
    fDamage: word; //Damaged inflicted to house

    fHasOwner: boolean; //which is some TKMUnit
    fBuildingRepair: boolean; //If on and the building is damaged then labourers will come and repair it
    fRepairID:integer; //Switch to remember TaskID of asked repair
    fWareDelivery: boolean; //If on then no wares will be delivered here

    fResourceIn:array[1..4] of byte; //Resource count in input
    fResourceDeliveryCount:array[1..4] of byte; //Count of the resources we have ordered for the input (used for ware distribution)
    fResourceOut:array[1..4]of byte; //Resource count in output
    fResourceOrder:array[1..4]of word; //If HousePlaceOrders=true then here are production orders

    FlagAnimStep: cardinal; //Used for Flags and Burning animation
    WorkAnimStep: cardinal; //Used for Work and etc.. which is not in sync with Flags

    fIsDestroyed:boolean;
    RemoveRoadWhenDemolish:boolean;
    fPointerCount:integer;
    fTimeSinceUnoccupiedReminder:integer;
    procedure SetWareDelivery(AVal:boolean);

    procedure MakeSound();
    function GetResDistribution(aID:byte):byte; //Will use GetRatio from mission settings to find distribution amount
  public
    ID:integer; //unique ID, used for save/load to sync to
    fCurrentAction: THouseAction; //Current action, withing HouseTask or idle
    ResourceDepletedMsgIssued: boolean;
    DoorwayUse: byte; //number of units using our door way. Used for sliding.

    constructor Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
    constructor Load(LoadStream:TKMemoryStream); virtual;
    destructor Destroy; override;
    function GetHousePointer:TKMHouse; //Returns self and adds one to the pointer counter
    procedure ReleaseHousePointer; //Decreases the pointer counter
    property GetPointerCount:integer read fPointerCount;
    procedure CloseHouse(IsEditor:boolean=false); virtual;

    procedure Activate(aWasBuilt:boolean);
    procedure DemolishHouse(DoSilent:boolean; NoRubble:boolean=false);

    property GetPosition:TKMPoint read fPosition;
    function GetEntrance:TKMPoint;
    procedure GetListOfCellsAround(Cells:TKMPointDirList; aPassability:TPassability);
    function HitTest(X, Y: Integer): Boolean;
    property GetHouseType:THouseType read fHouseType;
    property BuildingRepair:boolean read fBuildingRepair write fBuildingRepair;
    property WareDelivery:boolean read fWareDelivery write SetWareDelivery;
    property GetHasOwner:boolean read fHasOwner write fHasOwner;
    property GetOwner:TPlayerID read fOwner;
    function GetHealth():word;

    procedure SetBuildingState(aState: THouseBuildState);
    property GetBuildingState: THouseBuildState read fBuildState;
    procedure IncBuildingProgress;
    function GetMaxHealth():word;
    procedure AddDamage(aAmount:word);
    procedure AddRepair(aAmount:word=5);
    procedure UpdateDamage();
    procedure EnableRepair();
    procedure DisableRepair();
    procedure RepairToggle();

    function IsStarted:boolean;
    function IsStone:boolean;
    function IsComplete:boolean;
    function IsDamaged:boolean;
    property IsDestroyed:boolean read fIsDestroyed;
    property GetDamage:word read fDamage;

    procedure SetState(aState: THouseState);
    function GetState:THouseState;

    function CheckResIn(aResource:TResourceType):word; virtual;
    function CheckResOut(aResource:TResourceType):byte;
    function CheckResOrder(aID:byte):word;
    function CheckResToBuild():boolean;
    procedure ResAddToIn(aResource:TResourceType; const aCount:integer=1); virtual; //override for School and etc..
    procedure ResAddToOut(aResource:TResourceType; const aCount:integer=1);
    procedure ResAddToBuild(aResource:TResourceType);
    function ResTakeFromIn(aResource:TResourceType; aCount:byte=1):boolean;
    function ResTakeFromOut(aResource:TResourceType; const aCount:integer=1):boolean;
    procedure ResEditOrder(aID:byte; Amount:integer);

    procedure Save(SaveStream:TKMemoryStream); virtual;

    procedure IncAnimStep;
    procedure UpdateResRequest;
    procedure UpdateState;
    procedure Paint; virtual;
  end;

  {SwineStable has unique property - it needs to accumulate some resource before production begins, also special animation}
  TKMHouseSwineStable = class(TKMHouse)
  public
    BeastAge:array[1..5]of byte; //Each beasts "age". Once Best reaches age 3+1 it's ready
    constructor Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
    constructor Load(LoadStream:TKMemoryStream); override;
    function FeedBeasts():byte;
    procedure TakeBeast(aID:byte);
    procedure Save(SaveStream:TKMemoryStream); override;
    procedure Paint; override;
  end;

  TKMHouseInn = class(TKMHouse)
  private
    Eater:array[1..6]of record //only 6 units are allowed in the inn
      UnitType:TUnitType;
      FoodKind:byte; //What kind of food eater eats
      AnimStep:cardinal;
    end;
  public
    constructor Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
    constructor Load(LoadStream:TKMemoryStream); override;
    function EaterGetsInside(aUnitType:TUnitType):byte;
    procedure UpdateEater(aID:byte; aFoodKind:byte);
    procedure EatersGoesOut(aID:byte);
    function HasFood:boolean;
    function HasSpace:boolean;
    procedure Save(SaveStream:TKMemoryStream); override;
    procedure Paint(); override; //Render all eaters
  end;

  {School has one unique property - queue of units to be trained, 1 wip + 5 in line}
  TKMHouseSchool = class(TKMHouse)
  private
    UnitWIP:Pointer;  //can't replace with TKMUnit since it will lead to circular reference in KM_House-KM_Units
    HideOneGold:boolean; //Hide the gold incase Player cancels the training, then we won't need to tweak DeliverQueue order
    UnitTrainProgress:byte; //Was it 150 steps in KaM?
  public
    UnitQueue:array[1..6]of TUnitType; //Also used in UI
    constructor Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
    constructor Load(LoadStream:TKMemoryStream); override;
    procedure CloseHouse(IsEditor:boolean=false); override;
    procedure ResAddToIn(aResource:TResourceType; const aCount:integer=1); override;
    procedure AddUnitToQueue(aUnit:TUnitType); //Should add unit to queue if there's a place
    procedure RemUnitFromQueue(aID:integer); //Should remove unit from queue and shift rest up
    procedure StartTrainingUnit; //This should Create new unit and start training cycle
    procedure UnitTrainingComplete; //This should shift queue filling rest with ut_None
    function GetTrainingProgress():byte;
    procedure Save(SaveStream:TKMemoryStream); override;
  end;

  {Barracks has 11 resources and Recruits}
  TKMHouseBarracks = class(TKMHouse)
  private
    ResourceCount:array[1..11]of word;
  public
    RecruitsInside:integer;
    constructor Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
    constructor Load(LoadStream:TKMemoryStream); override;
    procedure AddMultiResource(aResource:TResourceType; const aCount:word=1);
    function CheckResIn(aResource:TResourceType):word; override;
    function CanEquip(aUnitType: TUnitType):boolean;
    procedure Equip(aUnitType: TUnitType);
    procedure Save(SaveStream:TKMemoryStream); override;
  end;

  {Storehouse keeps all the resources and flags for them}
  TKMHouseStore = class(TKMHouse)
  private
    ResourceCount:array[1..28]of word;
  public
    NotAcceptFlag:array[1..28]of boolean;
    constructor Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
    constructor Load(LoadStream:TKMemoryStream); override;
    procedure ToggleAcceptFlag(aRes:TResourceType);
    procedure AddMultiResource(aResource:TResourceType; const aCount:word=1);
    function CheckResIn(aResource:TResourceType):word; override;
    procedure Save(SaveStream:TKMemoryStream); override;
  end;


  TKMHousesCollection = class(TKMList)
  private
    fSelectedHouse: TKMHouse;
    function AddToCollection(aHouseType: THouseType; PosX,PosY:integer; aOwner: TPlayerID; aHBS:THouseBuildState):TKMHouse;
    function GetHouse(Index: Integer): TKMHouse;
    procedure SetHouse(Index: Integer; Item: TKMHouse);
    property Houses[Index: Integer]: TKMHouse read GetHouse write SetHouse; //Use instead of Items[.]
  public
    function AddHouse(aHouseType: THouseType; PosX,PosY:integer; aOwner: TPlayerID):TKMHouse;
    function AddPlan(aHouseType: THouseType; PosX,PosY:integer; aOwner: TPlayerID):TKMHouse;
    function Rem(aHouse:TKMHouse):boolean;
    function HitTest(X, Y: Integer): TKMHouse;
    function GetHouseByID(aID: Integer): TKMHouse;
    function FindEmptyHouse(aUnitType:TUnitType; Loc:TKMPoint): TKMHouse;
    function FindHouse(aType:THouseType; X,Y:word; const Index:byte=1): TKMHouse;
    function GetTotalPointers: integer;
    property SelectedHouse: TKMHouse read fSelectedHouse write fSelectedHouse;
    procedure Save(SaveStream:TKMemoryStream);
    procedure Load(LoadStream:TKMemoryStream);
    procedure SyncLoad();
    procedure IncAnimStep;
    procedure UpdateState;
    procedure Paint();
  end;

implementation
uses KM_UnitTaskSelfTrain, KM_DeliverQueue, KM_Terrain, KM_Render, KM_Units, KM_Units_Warrior, KM_PlayersCollection, KM_Sound, KM_Viewport, KM_Game, KM_LoadLib, KM_UnitActionStay, KM_Player;


{ TKMHouse }
constructor TKMHouse.Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
var i: byte;
begin
  Inherited Create;
  fPosition   := KMPoint (PosX, PosY);
  fHouseType  := aHouseType;
  fBuildState := aBuildState;
  fOwner      := aOwner;

  fBuildSupplyWood  := 0;
  fBuildSupplyStone := 0;
  fBuildReserve     := 0;
  fBuildingProgress := 0;
  fDamage           := 0; //Undamaged yet

  fHasOwner         := false;
  //Initially repair is [off]. But for PC it's controlled by a command in DAT script
  fBuildingRepair   := (fPlayers.Player[byte(fOwner)].PlayerType = pt_Computer) and (fPlayers.PlayerAI[byte(fOwner)].GetHouseRepair);
  DoorwayUse        := 0;
  fRepairID         := 0;
  fWareDelivery     := true;

  for i:=1 to 4 do
  begin
    fResourceIn[i]  := 0;
    fResourceDeliveryCount[i] := 0;
    fResourceOut[i] := 0;
    fResourceOrder[i]:=0;
  end;

  fIsDestroyed      := false;
  RemoveRoadWhenDemolish := fTerrain.Land[GetEntrance.Y, GetEntrance.X].TileOverlay <> to_Road;
  fPointerCount     := 0;
  fTimeSinceUnoccupiedReminder   := TIME_BETWEEN_MESSAGES;

  ID    := fGame.GetNewID;
  ResourceDepletedMsgIssued := false;

  if aBuildState = hbs_Done then //House was placed on map already Built e.g. in mission maker
  begin 
    Self.Activate(false);
    fBuildingProgress := HouseDAT[byte(fHouseType)].MaxHealth;
    fTerrain.SetHouse(fPosition, fHouseType, hs_Built, fOwner, fGame.GameState <> gsEditor); //Sets passability and flattens terrain if we're not in the map editor
  end else
    fTerrain.SetHouse(fPosition, fHouseType, hs_Plan, play_None); //Terrain remains neutral yet
end;


constructor TKMHouse.Load(LoadStream:TKMemoryStream);
var i:integer; HasAct:boolean;
begin
  Inherited Create;
  LoadStream.Read(fHouseType, SizeOf(fHouseType));
  LoadStream.Read(fPosition);
  LoadStream.Read(fBuildState, SizeOf(fBuildState));
  LoadStream.Read(fOwner, SizeOf(fOwner));
  LoadStream.Read(fBuildSupplyWood);
  LoadStream.Read(fBuildSupplyStone);
  LoadStream.Read(fBuildReserve);
  LoadStream.Read(fBuildingProgress, SizeOf(fBuildingProgress));
  LoadStream.Read(fDamage, SizeOf(fDamage));
  LoadStream.Read(fHasOwner);
  LoadStream.Read(fBuildingRepair);
  LoadStream.Read(fRepairID, SizeOf(fRepairID));
  LoadStream.Read(fWareDelivery);
  for i:=1 to 4 do LoadStream.Read(fResourceIn[i]);
  for i:=1 to 4 do LoadStream.Read(fResourceDeliveryCount[i]);
  for i:=1 to 4 do LoadStream.Read(fResourceOut[i]);
  for i:=1 to 4 do LoadStream.Read(fResourceOrder[i], SizeOf(fResourceOrder[i]));
  LoadStream.Read(FlagAnimStep, SizeOf(FlagAnimStep));
  LoadStream.Read(WorkAnimStep, SizeOf(WorkAnimStep));
  LoadStream.Read(fIsDestroyed);
  LoadStream.Read(RemoveRoadWhenDemolish);
  LoadStream.Read(fPointerCount);
  LoadStream.Read(fTimeSinceUnoccupiedReminder);
  LoadStream.Read(ID);
  LoadStream.Read(HasAct);
  if HasAct then begin
    fCurrentAction := THouseAction.Create(nil, hst_Empty); //Create placeholder to fill
    fCurrentAction.Load(LoadStream);
  end;
  LoadStream.Read(ResourceDepletedMsgIssued);
  LoadStream.Read(DoorwayUse);
end;


destructor TKMHouse.Destroy;
begin
  FreeAndNil(fCurrentAction);
  Inherited;
end;


{Returns self and adds on to the pointer counter}
function TKMHouse.GetHousePointer:TKMHouse;
begin
  inc(fPointerCount);
  Result := Self;
end;


{Decreases the pointer counter}
procedure TKMHouse.ReleaseHousePointer;
begin
  dec(fPointerCount);
end;


procedure TKMHouse.CloseHouse(IsEditor:boolean=false);
begin
  fIsDestroyed := true;
  BuildingRepair := false; //Otherwise labourers will take task to repair when the house is destroyed
  if (RemoveRoadWhenDemolish) and (not (GetBuildingState in [hbs_Stone, hbs_Done]) or IsEditor) then
  begin
    if fTerrain.Land[GetEntrance.Y,GetEntrance.X].TileOverlay = to_Road then
    begin
      fTerrain.RemRoad(Self.GetEntrance);
      if not IsEditor then
        fTerrain.Land[GetEntrance.Y,GetEntrance.X].TileOverlay := to_Dig3; //Remove road and leave dug earth behind
    end;
  end;
  FreeAndNil(fCurrentAction);
  //Leave disposing of units inside the house to themselves
end;


procedure TKMHouse.Activate(aWasBuilt:boolean);
var i:integer; Res:TResourceType;
begin
  fPlayers.Player[byte(fOwner)].CreatedHouse(fHouseType,aWasBuilt); //Only activated houses count
  fTerrain.RevealCircle(fPosition, HouseDAT[byte(fHouseType)].Sight, FOG_OF_WAR_INC, fOwner);

  fCurrentAction:=THouseAction.Create(Self, hst_Empty);
  fCurrentAction.SubActionAdd([ha_FlagShtok,ha_Flag1..ha_Flag3]);

  for i:=1 to 4 do
  begin
    Res := HouseInput[byte(fHouseType),i];
    with fPlayers.Player[byte(fOwner)].DeliverList do
    case Res of
      rt_None:    ;
      rt_Warfare: AddNewDemand(Self, nil, Res, 1, dt_Always, di_Norm);
      rt_All:     AddNewDemand(Self, nil, Res, 1, dt_Always, di_Norm);
      else
      begin
        AddNewDemand(Self, nil, Res, GetResDistribution(i), dt_Once,   di_Norm); //Every new house needs 5 resourceunits
        inc(fResourceDeliveryCount[i],GetResDistribution(i)); //Keep track of how many resources we have on order (for distribution of wares)
      end;
    end;
  end;

end;

                             
procedure TKMHouse.DemolishHouse(DoSilent:boolean; NoRubble:boolean=false);
begin
  if fPlayers.Selected = Self then fPlayers.Selected := nil;
  if (fGame.fGamePlayInterface <> nil) and (fGame.fGamePlayInterface.GetShownHouse = Self) then fGame.fGamePlayInterface.ShowHouseInfo(nil);

  if not DoSilent then
    if (GetBuildingState = hbs_Glyph)or(NoRubble) then fSoundLib.Play(sfx_click)
    else fSoundLib.Play(sfx_HouseDestroy,GetPosition);
  //Dispose of delivery tasks performed in DeliverQueue unit
  fPlayers.Player[byte(fOwner)].DeliverList.RemoveOffer(Self);
  fPlayers.Player[byte(fOwner)].DeliverList.RemoveDemand(Self);
  fPlayers.Player[byte(fOwner)].BuildList.RemoveHouseRepair(Self);
  fTerrain.SetHouse(fPosition,fHouseType,hs_None,play_none);
  //Road is removed in CloseHouse
  if not NoRubble then fTerrain.AddHouseRemainder(fPosition,fHouseType,fBuildState);
  
  if (fBuildState=hbs_Done) and Assigned(fPlayers) and Assigned(fPlayers.Player[byte(fOwner)]) then
    fPlayers.Player[byte(fOwner)].DestroyedHouse(fHouseType);

  CloseHouse(NoRubble);
end;


{Return Entrance of the house, which is different than house position sometimes}
function TKMHouse.GetEntrance():TKMPoint;
begin
  Result.X:=GetPosition.X + HouseDAT[byte(fHouseType)].EntranceOffsetX;
  Result.Y:=GetPosition.Y;
end;


procedure TKMHouse.GetListOfCellsAround(Cells:TKMPointDirList; aPassability:TPassability);
var
  i,k:integer;
  ht:byte;
  Loc:TKMPoint;

  procedure AddLoc(X,Y:word; Dir:TKMDirection);
  begin
    //First check that the passabilty is correct, as the house may be placed against blocked terrain
    if not fTerrain.CheckPassability(KMPoint(X,Y),aPassability) then exit;
    Cells.AddEntry(KMPointDir(KMPoint(X,Y),word(Dir)));
  end;

begin

  Cells.Clearup;
  ht := byte(fHouseType); //array needs byte id
  Loc := fPosition;

  for i:=1 to 4 do for k:=1 to 4 do
  if HousePlanYX[ht,i,k]<>0 then
  begin
    if (i=1)or(HousePlanYX[ht,i-1,k]=0) then
      AddLoc(Loc.X + k - 3, Loc.Y + i - 4 - 1, dir_S); //Above
    if (i=4)or(HousePlanYX[ht,i+1,k]=0) then
      AddLoc(Loc.X + k - 3, Loc.Y + i - 4 + 1, dir_N); //Below
    if (k=4)or(HousePlanYX[ht,i,k+1]=0) then
      AddLoc(Loc.X + k - 3 + 1, Loc.Y + i - 4, dir_W); //FromRight
    if (k=1)or(HousePlanYX[ht,i,k-1]=0) then
      AddLoc(Loc.X + k - 3 - 1, Loc.Y + i - 4, dir_E); //FromLeft
  end;
end;


function TKMHouse.HitTest(X, Y: Integer): Boolean;
begin
  Result:=false;
  if (X-fPosition.X+3 in [1..4])and(Y-fPosition.Y+4 in [1..4]) then
  if HousePlanYX[integer(fHouseType),Y-fPosition.Y+4,X-fPosition.X+3]<>0 then begin
    Result:=true;
    exit;
  end;
end;


function TKMHouse.GetHealth():word;
begin
  Result:=EnsureRange(fBuildingProgress-fDamage,0,maxword);
end;


procedure TKMHouse.SetBuildingState(aState: THouseBuildState);
begin
  fBuildState:=aState;
end;


{Increase building progress of house. When it reaches some point Stoning replaces Wooding
 and then it's done and house should be finalized}
 {Keep track on stone/wood reserve here as well}
procedure TKMHouse.IncBuildingProgress;
begin
  if IsComplete then exit;

  if (fBuildState=hbs_Wood)and(fBuildReserve = 0) then begin
    dec(fBuildSupplyWood);
    inc(fBuildReserve,50);
  end;
  if (fBuildState=hbs_Stone)and(fBuildReserve = 0) then begin
    dec(fBuildSupplyStone);
    inc(fBuildReserve,50);
  end;

  inc(fBuildingProgress,5); //is how many effort was put into building nevermind applied damage
  dec(fBuildReserve,5); //This is reserve we build from

  if (fBuildState=hbs_Wood)and(fBuildingProgress = HouseDAT[byte(fHouseType)].WoodCost*50) then begin
    fBuildState:=hbs_Stone;
    //fBuildingProgress:=0;
  end;
  if (fBuildState=hbs_Stone)and(fBuildingProgress-HouseDAT[byte(fHouseType)].WoodCost*50 = HouseDAT[byte(fHouseType)].StoneCost*50) then begin
    fBuildState:=hbs_Done;
    Activate(true);
  end;
end;


function TKMHouse.GetMaxHealth():word;
begin
  Result := HouseDAT[byte(fHouseType)].WoodCost*50 + HouseDAT[byte(fHouseType)].StoneCost*50;
end;


{Add damage to the house, positive number}
procedure TKMHouse.AddDamage(aAmount:word);
begin
  fDamage := Math.min(fDamage + aAmount, GetMaxHealth);
  if BuildingRepair and (fRepairID = 0) then
    fRepairID := fPlayers.Player[byte(fOwner)].BuildList.AddHouseRepair(Self);
  UpdateDamage();
end;


{Add repair to the house}
procedure TKMHouse.AddRepair(aAmount:word=5);
begin
  fDamage:= EnsureRange(fDamage - aAmount,0,maxword);
  if (fDamage=0)and(fRepairID<>0) then begin
    fPlayers.Player[integer(fOwner)].BuildList.CloseHouseRepair(fRepairID);
    fRepairID:=0;
  end;
  UpdateDamage();
end;


{Update house damage animation}
procedure TKMHouse.UpdateDamage();
begin
  fCurrentAction.SubActionRem([ha_Fire1,ha_Fire2,ha_Fire3,ha_Fire4,ha_Fire5,ha_Fire6,ha_Fire7,ha_Fire8]);
  if fDamage >   0 then fCurrentAction.SubActionAdd([ha_Fire1]);
  if fDamage >  50 then fCurrentAction.SubActionAdd([ha_Fire2]);
  if fDamage > 100 then fCurrentAction.SubActionAdd([ha_Fire3]);
  if fDamage > 150 then fCurrentAction.SubActionAdd([ha_Fire4]);
  if fDamage > 200 then fCurrentAction.SubActionAdd([ha_Fire5]);
  if fDamage > 250 then fCurrentAction.SubActionAdd([ha_Fire6]);
  if fDamage > 300 then fCurrentAction.SubActionAdd([ha_Fire7]);
  if fDamage > 350 then fCurrentAction.SubActionAdd([ha_Fire8]);
  {House gets destroyed in UpdateState loop}
end;


{if house is damaged then add repair to buildlist}
procedure TKMHouse.EnableRepair();
begin
  BuildingRepair := true;
  AddDamage(0); //Shortcut to refresh of damage
end;


{if house is damaged then remove repair from buildlist and free up workers}
procedure TKMHouse.DisableRepair();
begin
  BuildingRepair := false;
  AddRepair(0); //Shortcut to refresh of damage
end;


procedure TKMHouse.RepairToggle();
begin
  if BuildingRepair then DisableRepair else EnableRepair;
end;


{Check if house is started to build, so to know if we need to init the building site or not}
function TKMHouse.IsStarted():boolean;
begin
  Result := fBuildingProgress > 0;
end;


function TKMHouse.IsStone:boolean;
begin
  Result := fBuildState = hbs_Stone;
end;


{Check if house is completely built, nevermind the damage}
function TKMHouse.IsComplete():boolean;
begin
  Result := fBuildState = hbs_Done;
end;


{Check if house is damaged}
function TKMHouse.IsDamaged():boolean;
begin
  Result := fDamage <> 0;
end;


procedure TKMHouse.SetState(aState: THouseState);
begin
  fCurrentAction.SetState(aState);
end;


function TKMHouse.GetState:THouseState;
begin
  Result := fCurrentAction.fHouseState;
end;


{How much resources house has in Input}
function TKMHouse.CheckResIn(aResource:TResourceType):word;
var i:integer;
begin
Result:=0;
  for i:=1 to 4 do
  if (aResource = HouseInput[byte(fHouseType),i])or(aResource=rt_All) then
    inc(Result,fResourceIn[i]);
end;


{How much resources house has in Output}
function TKMHouse.CheckResOut(aResource:TResourceType):byte;
var i:integer;
begin
Result:=0;
  for i:=1 to 4 do
  if (aResource = HouseOutput[byte(fHouseType),i])or(aResource=rt_All) then
    inc(Result,fResourceOut[i]);
end;


{Check amount of placed order for given ID}
function TKMHouse.CheckResOrder(aID:byte):word;
begin
  //AI always order production of everything. Could be changed later with a script command to only make certain things
  if (fPlayers.Player[byte(fOwner)].PlayerType = pt_Computer) and (HouseOutput[byte(fHouseType),aID] <> rt_None) then
    Result := 1
  else
    Result := fResourceOrder[aID];
end;


{Check if house has enough resource supply to be built depending on it's state}
function TKMHouse.CheckResToBuild():boolean;
begin
  Result:=false;
  if fBuildState=hbs_Wood then
    Result:=(fBuildSupplyWood>0)or(fBuildReserve>0);
  if fBuildState=hbs_Stone then
    Result:=(fBuildSupplyStone>0)or(fBuildReserve>0);
end;


procedure TKMHouse.ResAddToIn(aResource:TResourceType; const aCount:integer=1);
var i:integer;
begin
  if aResource=rt_None then exit;
  if HouseInput[byte(fHouseType),1]=rt_All then
    TKMHouseStore(Self).AddMultiResource(aResource, aCount)
  else
  if HouseInput[byte(fHouseType),1]=rt_Warfare then
    TKMHouseBarracks(Self).AddMultiResource(aResource, aCount)
  else
    for i:=1 to 4 do
    if aResource = HouseInput[byte(fHouseType),i] then
      inc(fResourceIn[i],aCount);
end;


procedure TKMHouse.ResAddToOut(aResource:TResourceType; const aCount:integer=1);
var i:integer;
begin
  if aResource=rt_None then exit;
  for i:=1 to 4 do
  if aResource = HouseOutput[byte(fHouseType),i] then
    begin
      inc(fResourceOut[i],aCount);
      fPlayers.Player[byte(fOwner)].DeliverList.AddNewOffer(Self,aResource,aCount);
    end;
end;


{Add resources to building process}
procedure TKMHouse.ResAddToBuild(aResource:TResourceType);
begin
  case aResource of
    rt_Wood: inc(fBuildSupplyWood);
    rt_Stone: inc(fBuildSupplyStone);
  else fGame.GameError(GetPosition, 'WIP house is not supposed to recieve '+TypeToString(aResource)+', right?');
  end;
end;


function TKMHouse.ResTakeFromIn(aResource:TResourceType; aCount:byte=1):boolean;
var i,k:integer;
begin
Result:=false;
if aResource=rt_None then exit;
  for i:=1 to 4 do
  if aResource = HouseInput[byte(fHouseType),i] then begin
    fLog.AssertToLog(fResourceIn[i]>=aCount,'fResourceIn[i]>0');
    dec(fResourceIn[i],aCount);
    dec(fResourceDeliveryCount[i],aCount);
    //Only request a new resource if it is allowed by the distribution of wares for our parent player
    for k:=1 to aCount do
      if fResourceDeliveryCount[i] < GetResDistribution(i) then
      begin
        fPlayers.Player[byte(fOwner)].DeliverList.AddNewDemand(Self,nil,aResource,1,dt_Once,di_Norm);
        inc(fResourceDeliveryCount[i]);
      end;
    Result:=true;
  end;
end;


function TKMHouse.ResTakeFromOut(aResource:TResourceType; const aCount:integer=1):boolean;
var i:integer;
begin
  Result:=false;
  if aResource=rt_None then exit;
  case fHouseType of
    ht_Store: if TKMHouseStore(Self).ResourceCount[byte(aResource)]>0 then begin
                TKMHouseStore(Self).ResourceCount[byte(aResource)] := Math.max(TKMHouseStore(Self).ResourceCount[byte(aResource)] - aCount, 0);
                Result:=true;
              end;
    ht_Barracks: if TKMHouseBarracks(Self).ResourceCount[byte(aResource)-16]>0 then begin
                TKMHouseBarracks(Self).ResourceCount[byte(aResource)-16] := Math.max(TKMHouseBarracks(Self).ResourceCount[byte(aResource)-16] - aCount, 0);
                Result:=true;
              end;
    else
              for i:=1 to 4 do
              if aResource = HouseOutput[byte(fHouseType),i] then begin
                fResourceOut[i] := Math.max(fResourceOut[i] - aCount, 0);
                Result:=true;
                exit;
              end;
    end;
end;


{ Edit production order as + / - }
procedure TKMHouse.ResEditOrder(aID:byte; Amount:integer);
begin
  fResourceOrder[aID] := EnsureRange(fResourceOrder[aID]+Amount,0,MAX_ORDER);
end;


function TKMHouse.GetResDistribution(aID:byte):byte;
begin
  Result := fPlayers.Player[byte(fOwner)].fMissionSettings.GetRatio(HouseInput[byte(fHouseType),aID],fHouseType);
end;


procedure TKMHouse.MakeSound();
var WorkID,Step:byte;
begin
  //Do not play sounds if house is invisible to MyPlayer
  if fTerrain.CheckTileRevelation(fPosition.X, fPosition.Y, MyPlayer.PlayerID) < 255 then exit;
  if fCurrentAction = nil then exit; //no action means no sound ;)

  WorkID := fCurrentAction.GetWorkID;

  if WorkID=0 then exit;

  Step:=HouseDAT[byte(fHouseType)].Anim[WorkID].Count;
  if Step=0 then exit;
  Step:=WorkAnimStep mod Step;

  case fHouseType of //Various buildings and HouseActions producing sounds
    ht_School:        if (WorkID = 5)and(Step = 28) then fSoundLib.Play(sfx_SchoolDing,GetPosition); //Ding as the clock strikes 12
    ht_Mill:          if (WorkID = 2)and(Step = 0) then fSoundLib.Play(sfx_mill,GetPosition);
    ht_CoalMine:      if (WorkID = 1)and(Step = 5) then fSoundLib.Play(sfx_coaldown,GetPosition)
                      else if (WorkID = 1)and(Step = 24) then fSoundLib.Play(sfx_CoalMineThud,GetPosition,true,0.8)
                      else if (WorkID = 2)and(Step = 7) then fSoundLib.Play(sfx_mine,GetPosition)
                      else if (WorkID = 2)and(Step = 8) then fSoundLib.Play(sfx_mine,GetPosition,true,0.4) //echo
                      else if (WorkID = 5)and(Step = 1) then fSoundLib.Play(sfx_coaldown,GetPosition);
    ht_IronMine:      if (WorkID = 2)and(Step = 7) then fSoundLib.Play(sfx_mine,GetPosition)
                      else if (WorkID = 2)and(Step = 8) then fSoundLib.Play(sfx_mine,GetPosition,true,0.4); //echo
    ht_GoldMine:      if (WorkID = 2)and(Step = 5) then fSoundLib.Play(sfx_mine,GetPosition)
                      else if (WorkID = 2)and(Step = 6) then fSoundLib.Play(sfx_mine,GetPosition,true,0.4); //echo
    ht_SawMill:       if (WorkID = 2)and(Step = 1) then fSoundLib.Play(sfx_saw,GetPosition);
    ht_Wineyard:      if (WorkID = 2)and(Step in [1,7,13,19]) then fSoundLib.Play(sfx_wineStep,GetPosition)
                      else if (WorkID = 5)and(Step = 14) then fSoundLib.Play(sfx_wineDrain,GetPosition,true,1.5)
                      else if (WorkID = 1)and(Step = 10) then fSoundLib.Play(sfx_wineDrain,GetPosition,true,1.5);
    ht_Bakery:        if (WorkID = 3)and(Step in [6,25]) then fSoundLib.Play(sfx_BakerSlap,GetPosition);
    ht_Quary:         if (WorkID = 2)and(Step in [4,13]) then fSoundLib.Play(sfx_QuarryClink,GetPosition)
                      else if (WorkID = 5)and(Step in [4,13,22]) then fSoundLib.Play(sfx_QuarryClink,GetPosition);
    ht_WeaponSmithy:  if (WorkID = 1)and(Step in [17,22]) then fSoundLib.Play(sfx_BlacksmithFire,GetPosition)
                      else if (WorkID = 2)and(Step in [10,25]) then fSoundLib.Play(sfx_BlacksmithBang,GetPosition)
                      else if (WorkID = 3)and(Step in [10,25]) then fSoundLib.Play(sfx_BlacksmithBang,GetPosition)
                      else if (WorkID = 4)and(Step in [8,22]) then fSoundLib.Play(sfx_BlacksmithFire,GetPosition)
                      else if (WorkID = 5)and(Step = 12) then fSoundLib.Play(sfx_BlacksmithBang,GetPosition);
    ht_ArmorSmithy:   if (WorkID = 2)and(Step in [13,28]) then fSoundLib.Play(sfx_BlacksmithBang,GetPosition)
                      else if (WorkID = 3)and(Step in [13,28]) then fSoundLib.Play(sfx_BlacksmithBang,GetPosition)
                      else if (WorkID = 4)and(Step in [8,22]) then fSoundLib.Play(sfx_BlacksmithFire,GetPosition)
                      else if (WorkID = 5)and(Step in [8,22]) then fSoundLib.Play(sfx_BlacksmithFire,GetPosition);
    ht_Metallurgists: if (WorkID = 3)and(Step = 6) then fSoundLib.Play(sfx_metallurgists,GetPosition)
                      else if (WorkID = 4)and(Step in [16,20]) then fSoundLib.Play(sfx_wineDrain,GetPosition);
    ht_IronSmithy:    if (WorkID = 2)and(Step in [1,16]) then fSoundLib.Play(sfx_metallurgists,GetPosition)
                      else if (WorkID = 3)and(Step = 1) then fSoundLib.Play(sfx_metallurgists,GetPosition)
                      else if (WorkID = 3)and(Step = 13) then fSoundLib.Play(sfx_wineDrain,GetPosition);
    ht_WeaponWorkshop:if (WorkID = 2)and(Step in [1,10,19]) then fSoundLib.Play(sfx_saw,GetPosition)
                      else if (WorkID = 3)and(Step in [10,21]) then fSoundLib.Play(sfx_CarpenterHammer,GetPosition)
                      else if (WorkID = 4)and(Step in [2,13]) then fSoundLib.Play(sfx_CarpenterHammer,GetPosition);
    ht_ArmorWorkshop: if (WorkID = 2)and(Step in [3,13,23]) then fSoundLib.Play(sfx_saw,GetPosition)
                      else if (WorkID = 3)and(Step in [17,28]) then fSoundLib.Play(sfx_CarpenterHammer,GetPosition)
                      else if (WorkID = 4)and(Step in [10,20]) then fSoundLib.Play(sfx_CarpenterHammer,GetPosition);
    ht_Tannery:       if (WorkID = 2)and(Step = 5) then fSoundLib.Play(sfx_Leather,GetPosition,true,0.8);
    ht_Butchers:      if (WorkID = 2)and(Step in [8,16,24]) then fSoundLib.Play(sfx_ButcherCut,GetPosition)
                      else if (WorkID = 3)and(Step in [9,21]) then fSoundLib.Play(sfx_SausageString,GetPosition);
    ht_Swine:         if ((WorkID = 2)and(Step in [10,20]))or((WorkID = 3)and(Step = 1)) then fSoundLib.Play(sfx_ButcherCut,GetPosition);
    ht_WatchTower:    if (WorkID = 2)and(Step = 0) then fSoundLib.Play(sfx_RockThrow,GetPosition); //@Krom: This occours 5 times because the animation does not change unlike other actions. Can I move this to TTaskThrowRock or do you have a better idea?
  end;
end;


procedure TKMHouse.Save(SaveStream:TKMemoryStream);
var i:integer; HasAct:boolean;
begin
  SaveStream.Write(fHouseType, SizeOf(fHouseType));
  SaveStream.Write(fPosition);
  SaveStream.Write(fBuildState, SizeOf(fBuildState));
  SaveStream.Write(fOwner, SizeOf(fOwner));
  SaveStream.Write(fBuildSupplyWood);
  SaveStream.Write(fBuildSupplyStone);
  SaveStream.Write(fBuildReserve);
  SaveStream.Write(fBuildingProgress, SizeOf(fBuildingProgress));
  SaveStream.Write(fDamage, SizeOf(fDamage));
  SaveStream.Write(fHasOwner);
  SaveStream.Write(fBuildingRepair);
  SaveStream.Write(fRepairID, SizeOf(fRepairID));
  SaveStream.Write(fWareDelivery);
  for i:=1 to 4 do SaveStream.Write(fResourceIn[i]);
  for i:=1 to 4 do SaveStream.Write(fResourceDeliveryCount[i]);
  for i:=1 to 4 do SaveStream.Write(fResourceOut[i]);
  for i:=1 to 4 do SaveStream.Write(fResourceOrder[i], SizeOf(fResourceOrder[i]));
  SaveStream.Write(FlagAnimStep, SizeOf(FlagAnimStep));
  SaveStream.Write(WorkAnimStep, SizeOf(WorkAnimStep));
  SaveStream.Write(fIsDestroyed);
  SaveStream.Write(RemoveRoadWhenDemolish);
  SaveStream.Write(fPointerCount);
  SaveStream.Write(fTimeSinceUnoccupiedReminder);
  SaveStream.Write(ID);
  HasAct := fCurrentAction <> nil;
  SaveStream.Write(HasAct);
  if HasAct then fCurrentAction.Save(SaveStream);
  SaveStream.Write(ResourceDepletedMsgIssued);
  SaveStream.Write(DoorwayUse);
end;


procedure TKMHouse.IncAnimStep;
begin
  inc(FlagAnimStep);
  inc(WorkAnimStep);
  //FlagAnimStep is a sort of counter to reveal terrain once a sec
  if FOG_OF_WAR_ENABLE then
  if FlagAnimStep mod 10 = 0 then fTerrain.RevealCircle(fPosition,HouseDAT[byte(fHouseType)].Sight, FOG_OF_WAR_INC, fOwner);
end;


//todo: sort this out for cases when distribution increases and decreases(!)
//Request more resources (if distribution of wares has changed)
procedure TKMHouse.UpdateResRequest;
var i:byte;
begin
  for i:=1 to 4 do
    if not (HouseInput[byte(fHouseType),i] in [rt_All, rt_Warfare, rt_None]) then
    if fResourceDeliveryCount[i] < GetResDistribution(i) then
    begin
      fPlayers.Player[byte(fOwner)].DeliverList.AddNewDemand(Self,nil,HouseInput[byte(fHouseType),i],
             GetResDistribution(i)-fResourceDeliveryCount[i] ,dt_Once,di_Norm);

      inc(fResourceDeliveryCount[i],GetResDistribution(i)-fResourceDeliveryCount[i]);
    end;
end;


procedure TKMHouse.UpdateState;
begin
  if fBuildState<>hbs_Done then exit; //Don't update unbuilt houses

  if (GetHealth=0)and(fBuildState>=hbs_Wood) then DemolishHouse(false);

  if not fIsDestroyed then
    UpdateResRequest; //Request more resources (if distribution of wares has changed)

  //Show unoccupied message if needed and house belongs to human player and can have owner at all and not a barracks
  if (not fHasOwner) and (fOwner = MyPlayer.PlayerID) and (HouseDAT[byte(GetHouseType)].OwnerType<>-1) and (fHouseType <> ht_Barracks) then
  begin
    dec(fTimeSinceUnoccupiedReminder);
    if fTimeSinceUnoccupiedReminder = 0 then
    begin
      fGame.fGamePlayInterface.MessageIssue(msgHouse,fTextLibrary.GetTextString(295),GetEntrance);
      fTimeSinceUnoccupiedReminder := TIME_BETWEEN_MESSAGES; //Don't show one again until it is time
    end;
  end
  else
    fTimeSinceUnoccupiedReminder := TIME_BETWEEN_MESSAGES;

  if not fIsDestroyed then MakeSound(); //Make some sound/noise along the work

  IncAnimStep;
end;


procedure TKMHouse.Paint();
begin
case fBuildState of
  hbs_Glyph: fRender.RenderHouseBuild(byte(fHouseType),fPosition.X, fPosition.Y);
  hbs_NoGlyph:; //Nothing
  hbs_Wood:
    begin
      fRender.RenderHouseWood(byte(fHouseType),
      fBuildingProgress/50/HouseDAT[byte(fHouseType)].WoodCost, //0...1 range
      fPosition.X, fPosition.Y);
      fRender.RenderHouseBuildSupply(byte(fHouseType), fBuildSupplyWood, fBuildSupplyStone, fPosition.X, fPosition.Y);
    end;
  hbs_Stone:
    begin
      fRender.RenderHouseStone(byte(fHouseType),
      (fBuildingProgress/50-HouseDAT[byte(fHouseType)].WoodCost)/HouseDAT[byte(fHouseType)].StoneCost, //0...1 range
      fPosition.X, fPosition.Y);
      fRender.RenderHouseBuildSupply(byte(fHouseType), fBuildSupplyWood, fBuildSupplyStone, fPosition.X, fPosition.Y);
    end;
  else begin
    fRender.RenderHouseStone(byte(fHouseType),1,fPosition.X, fPosition.Y);
    fRender.RenderHouseSupply(byte(fHouseType),fResourceIn,fResourceOut,fPosition.X, fPosition.Y);
    if fCurrentAction=nil then exit;
    fRender.RenderHouseWork(byte(fHouseType),integer(fCurrentAction.fSubAction),WorkAnimStep,byte(fOwner),fPosition.X, fPosition.Y);
  end;
end;
end;

procedure TKMHouse.SetWareDelivery(AVal:boolean);
begin
  fWareDelivery := AVal;
end;


{TKMHouseSwineStable}
constructor TKMHouseSwineStable.Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
var i:integer;
begin
  Inherited;
  for i:=1 to length(BeastAge) do
    BeastAge[i]:=0;
end;


constructor TKMHouseSwineStable.Load(LoadStream:TKMemoryStream);
var i:integer;
begin
  Inherited;
  for i:=1 to 5 do
    LoadStream.Read(BeastAge[i]);
end;


//Return ID of beast that has grown up
function TKMHouseSwineStable.FeedBeasts():byte;
var i:integer;
begin
  Result:=0;
  inc(BeastAge[Random(5)+1]); //Let's hope it never overflows MAX
  for i:=1 to length(BeastAge) do
    if BeastAge[i]>3 then
      Result:=i;
end;


procedure TKMHouseSwineStable.TakeBeast(aID:byte);
begin
  if (aID<>0) and (BeastAge[aID]>3) then
    BeastAge[aID] := 0;
end;


procedure TKMHouseSwineStable.Save(SaveStream:TKMemoryStream);
var i:integer;
begin
  Inherited;
  for i:=1 to 5 do
    SaveStream.Write(BeastAge[i]);
end;


procedure TKMHouseSwineStable.Paint;
var i:integer;
begin
  inherited;
  if (fBuildState<>hbs_Done) then exit;
  for i:=1 to 5 do
    if BeastAge[i]>0 then
      fRender.RenderHouseStableBeasts(byte(fHouseType), i, min(BeastAge[i],3), WorkAnimStep, fPosition.X, fPosition.Y);
  if (fCurrentAction<>nil) then //Overlay, not entirely correct, but works ok
  fRender.RenderHouseWork(byte(fHouseType),integer(fCurrentAction.fSubAction),WorkAnimStep,byte(fOwner),fPosition.X, fPosition.Y);
end;


constructor TKMHouseInn.Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
var i:integer;
begin
  Inherited;
  for i:=low(Eater) to high(Eater) do
    Eater[i].UnitType:=ut_None;
end;


constructor TKMHouseInn.Load(LoadStream:TKMemoryStream);
var i:integer;
begin
  Inherited;
  for i:=1 to 6 do
  with Eater[i] do
  begin
    LoadStream.Read(UnitType, SizeOf(UnitType));
    LoadStream.Read(FoodKind, SizeOf(FoodKind));
    LoadStream.Read(AnimStep, SizeOf(AnimStep));
  end;
end;


function TKMHouseInn.EaterGetsInside(aUnitType:TUnitType):byte;
var i:integer;
begin
  Result:=0;
  for i:=low(Eater) to high(Eater) do
  if Eater[i].UnitType=ut_None then
  begin
    Eater[i].UnitType:=aUnitType;
    Eater[i].FoodKind:=0;
    Eater[i].AnimStep:=FlagAnimStep;
    Result:=i;
    exit;
  end;
end;


procedure TKMHouseInn.UpdateEater(aID:byte; aFoodKind:byte);
begin
  if aID=0 then exit;
  Eater[aID].FoodKind:=aFoodKind; //Order is Wine-Bread-Sausages-Fish
  Eater[aID].AnimStep:=0;
end;


procedure TKMHouseInn.EatersGoesOut(aID:byte);
begin
  if aID=0 then exit;
  Eater[aID].UnitType:=ut_None;
end;


function TKMHouseInn.HasFood:boolean;
begin
  Result:=(CheckResIn(rt_Sausages)+CheckResIn(rt_Bread)+CheckResIn(rt_Wine)+CheckResIn(rt_Fish)>0);
end;

function TKMHouseInn.HasSpace:boolean;
var
  i: integer;
begin
  Result:=false;
  for i:=low(Eater) to high(Eater) do
    Result := Result or (Eater[i].UnitType=ut_None);
end;


procedure TKMHouseInn.Save(SaveStream:TKMemoryStream);
var i:integer;
begin
  inherited;
  for i:=1 to 6 do
  with Eater[i] do
  begin
    SaveStream.Write(UnitType, SizeOf(UnitType));
    SaveStream.Write(FoodKind, SizeOf(FoodKind));
    SaveStream.Write(AnimStep, SizeOf(AnimStep));
  end;
end;


procedure TKMHouseInn.Paint;
const
  offX:array[1..3]of single = (-0.5, 0.0, 0.5);
  offY:array[1..3]of single = ( 0.35, 0.4, 0.45);
var i:integer; UnitType,AnimAct,AnimDir:byte; AnimStep:cardinal;
begin
  inherited;
  if (fBuildState<>hbs_Done) then exit;

  for i:=1 to 6 do
  if (Eater[i].UnitType<>ut_None)and(Eater[i].FoodKind<>0) then
  begin
    UnitType:=byte(Eater[i].UnitType);
    AnimAct:=byte(ua_Eat);
    AnimDir:=Eater[i].FoodKind*2 - 1 + ((i-1) div 3);
    fLog.AssertToLog(InRange(AnimDir,1,8),'InRange(AnimDir,1,8)');
    AnimStep:=FlagAnimStep-Eater[i].AnimStep; //Delta is our AnimStep
    fRender.RenderUnit(UnitType, AnimAct, AnimDir, AnimStep, byte(fOwner),
      fPosition.X+offX[(i-1) mod 3 +1],
      fPosition.Y+offY[(i-1) mod 3 +1], false);
  end;
end;


constructor TKMHouseSchool.Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
var i:integer;
begin
  Inherited;
  for i:=1 to length(UnitQueue) do
    UnitQueue[i]:=ut_None;
  UnitWIP:=nil;
end;


constructor TKMHouseSchool.Load(LoadStream:TKMemoryStream);
var i:integer;
begin
  Inherited;
  LoadStream.Read(UnitWIP, 4);
  UnitWIP := fPlayers.GetUnitByID(cardinal(UnitWIP)); //Units get loaded before houses ;)
  LoadStream.Read(HideOneGold);
  LoadStream.Read(UnitTrainProgress);
  for i:=1 to 6 do LoadStream.Read(UnitQueue[i], SizeOf(UnitQueue[i]));
end;


procedure TKMHouseSchool.CloseHouse(IsEditor:boolean=false);
var i:integer;
begin
  for i:=2 to length(UnitQueue) do UnitQueue[i]:=ut_None; //Remove all queue units
  RemUnitFromQueue(1); //Remove WIP unit
  Inherited;
end;


procedure TKMHouseSchool.ResAddToIn(aResource:TResourceType; const aCount:integer=1);
begin
  Inherited;
  if UnitWIP=nil then StartTrainingUnit;
end;


procedure TKMHouseSchool.AddUnitToQueue(aUnit:TUnitType);
var i:integer;
begin
  for i:=1 to length(UnitQueue) do
  if UnitQueue[i]=ut_None then begin
    UnitQueue[i]:=aUnit;
    if i=1 then StartTrainingUnit; //If thats the first unit then start training it
    break;
  end;
end;


//DoCancelTraining and remove untrained unit
procedure TKMHouseSchool.RemUnitFromQueue(aID:integer);
var i:integer;
begin
  if UnitQueue[aID]=ut_None then exit; //Ignore clicks on empty queue items

  if aID = 1 then begin
    SetState(hst_Idle);
    if UnitWIP<>nil then begin
      TKMUnit(UnitWIP).CloseUnit; //Make sure unit started training
      HideOneGold:=false;
    end;
    UnitWIP:=nil;
  end;

  for i:=aID to length(UnitQueue)-1 do UnitQueue[i]:=UnitQueue[i+1]; //Shift by one
  UnitQueue[length(UnitQueue)]:=ut_None; //Set the last one empty

  if aID = 1 then
    if UnitQueue[1]<>ut_None then StartTrainingUnit;
end;


procedure TKMHouseSchool.StartTrainingUnit;
begin
  //If there's yet no unit in training
  if UnitQueue[1]=ut_None then exit;
  if CheckResIn(rt_Gold)=0 then exit;
  HideOneGold:=true;
  UnitWIP:=fPlayers.Player[byte(fOwner)].TrainUnit(UnitQueue[1],GetEntrance);//Create Unit
  TKMUnit(UnitWIP).SetUnitTask := TTaskSelfTrain.Create(UnitWIP,Self);
end;


//To be called only by Unit itself when it's trained!
procedure TKMHouseSchool.UnitTrainingComplete;
var i:integer;
begin
  UnitWIP:=nil;
  ResTakeFromIn(rt_Gold); //Do the goldtaking
  HideOneGold:=false;
  for i:=1 to length(UnitQueue)-1 do UnitQueue[i]:=UnitQueue[i+1]; //Shift by one
  UnitQueue[length(UnitQueue)]:=ut_None; //Set the last one empty
  if UnitQueue[1]<>ut_None then StartTrainingUnit;
  UnitTrainProgress:=0;
end;


function TKMHouseSchool.GetTrainingProgress():byte;
begin
  Result:=0;
  if UnitWIP=nil then exit;
  Result:=EnsureRange(round(
  ((fCurrentAction.GetWorkID-1)*30+30-TUnitActionStay(TKMUnit(UnitWIP).GetUnitAction).HowLongLeftToStay)
  /1.5),0,100); //150 steps into 0..100 range
  //Substeps could be asked from Unit.ActionStay.TimeToStay, but it's a private field now
end;


procedure TKMHouseSchool.Save(SaveStream:TKMemoryStream);
var i:integer;
begin
  inherited;
  if TKMUnit(UnitWIP) <> nil then
    SaveStream.Write(TKMUnit(UnitWIP).ID) //Store ID, then substitute it with reference on SyncLoad
  else
    SaveStream.Write(Zero);
  SaveStream.Write(HideOneGold);
  SaveStream.Write(UnitTrainProgress);
  for i:=1 to 6 do SaveStream.Write(UnitQueue[i], SizeOf(UnitQueue[i]));
end;


constructor TKMHouseStore.Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
var i:integer;
begin
  Inherited;
  for i:=1 to length(ResourceCount) do begin
    ResourceCount[i] := 0;
    NotAcceptFlag[i] := false;
  end;
end;


constructor TKMHouseStore.Load(LoadStream:TKMemoryStream);
var i:integer;
begin
  Inherited;
  for i:=1 to 28 do LoadStream.Read(ResourceCount[i], SizeOf(ResourceCount[i]));
  for i:=1 to 28 do LoadStream.Read(NotAcceptFlag[i]);
end;


procedure TKMHouseStore.AddMultiResource(aResource:TResourceType; const aCount:word=1);
var i:integer;
begin
  case aResource of
    rt_All:     for i:=1 to length(ResourceCount) do begin
                  ResourceCount[i] := EnsureRange(ResourceCount[i]+aCount,0,MAXWORD);
                  fPlayers.Player[byte(fOwner)].DeliverList.AddNewOffer(Self,TResourceType(i),aCount);
                end;
    rt_Trunk..
    rt_Fish:    begin
                  ResourceCount[byte(aResource)]:=EnsureRange(ResourceCount[byte(aResource)]+aCount,0,MAXWORD);
                  fPlayers.Player[byte(fOwner)].DeliverList.AddNewOffer(Self,aResource,aCount);
                end;
    else        fGame.GameError(GetPosition, 'Cant''t add '+TypeToString(aResource));
  end;
end;


function TKMHouseStore.CheckResIn(aResource:TResourceType):word;
begin
  if aResource in [rt_Trunk..rt_Fish] then
    Result := ResourceCount[byte(aResource)]
  else
    Result := 0;
end;


procedure TKMHouseStore.ToggleAcceptFlag(aRes:TResourceType);
var i:integer; ApplyCheat:boolean;
begin
  Assert(aRes in [rt_Trunk .. rt_Fish]); //Dunno why thats happening sometimes..

  if CHEATS_ENABLED then begin
    ApplyCheat := true;

    for i:=1 to length(ResourceCount) do
      ApplyCheat := ApplyCheat and (NotAcceptFlag[i] = bool(CheatStorePattern[i]));

    if ApplyCheat and (aRes = rt_Arbalet) then begin
      AddMultiResource(rt_All, 10);
      exit;
    end;
  end;

  NotAcceptFlag[byte(aRes)] := not NotAcceptFlag[byte(aRes)];
end;


procedure TKMHouseStore.Save(SaveStream:TKMemoryStream);
var i:integer;
begin
  Inherited;
  for i:=1 to 28 do SaveStream.Write(ResourceCount[i], SizeOf(ResourceCount[i]));
  for i:=1 to 28 do SaveStream.Write(NotAcceptFlag[i]);
end;


constructor TKMHouseBarracks.Create(aHouseType:THouseType; PosX,PosY:integer; aOwner:TPlayerID; aBuildState:THouseBuildState);
var i:integer;
begin
  Inherited;
  for i:=1 to length(ResourceCount) do
    ResourceCount[i]:=0;
  RecruitsInside:=0;
end;


constructor TKMHouseBarracks.Load(LoadStream:TKMemoryStream);
var i:integer;
begin
  Inherited;
  for i:=1 to 11 do LoadStream.Read(ResourceCount[i], SizeOf(ResourceCount[i]));
  LoadStream.Read(RecruitsInside);
end;


procedure TKMHouseBarracks.AddMultiResource(aResource:TResourceType; const aCount:word=1);
var i:integer;
begin
  case aResource of
    rt_Warfare: for i:=1 to length(ResourceCount) do
                ResourceCount[i] := EnsureRange(ResourceCount[i]+aCount,0,MAXWORD);
    rt_Shield..
    rt_Horse:   ResourceCount[byte(aResource)-16]:=EnsureRange(ResourceCount[byte(aResource)-16]+aCount,0,MAXWORD)
    else        fGame.GameError(GetPosition, 'Cant''t add '+TypeToString(aResource));
  end;
end;


function TKMHouseBarracks.CheckResIn(aResource:TResourceType):word;
begin
  if aResource in [rt_Shield..rt_Horse] then
    Result:=ResourceCount[byte(aResource)-16]
  else
    Result:=0;
end;


function TKMHouseBarracks.CanEquip(aUnitType: TUnitType):boolean;
var i, k, Tmp: integer;
begin
  Result := true;
  for i:=1 to 12 do
  begin
    if i in [1..11] then Tmp:=ResourceCount[i]
                    else Tmp:=RecruitsInside;
    for k:=1 to 4 do
      if i = TroopCost[aUnitType,k] then
        if Tmp=0 then CanEquip := false; //Can't equip if we don't have a required resource
  end;
end;


procedure TKMHouseBarracks.Equip(aUnitType: TUnitType);
var i,k: integer;
    Soldier: TKMUnitWarrior;
    LinkUnit:TKMUnitWarrior;
begin
  //Equip a new soldier and make him walk out of the house
  //First make sure unit is valid and we have resources to equip him
  if (not (aUnitType in [ut_Militia..ut_Barbarian])) or (not CanEquip(aUnitType)) then exit;

  //Take resources
  for i:=1 to 12 do
    for k:=1 to 4 do
      if i = TroopCost[aUnitType,k] then
        if i in [1..11] then dec(ResourceCount[i]);
  dec(RecruitsInside); //All units take a recruit

  //Make new unit
  Soldier := TKMUnitWarrior(fPlayers.Player[byte(fOwner)].AddUnit(aUnitType,GetEntrance,false,true));
  Soldier.SetVisibility := false; //Make him invisible as he is inside the barracks
  Soldier.SetCondition := Round(TROOPS_TRAINED_CONDITION*UNIT_MAX_CONDITION); //All soldiers start with 3/4, so groups get hungry at the same time

  Soldier.SetActionGoIn(ua_Walk, gd_GoOutside, Self);

  LinkUnit := Soldier.FindLinkUnit(GetEntrance);
  Soldier.LinkTo(LinkUnit);
  //todo: Try to Link ourselves to some group
end;


procedure TKMHouseBarracks.Save(SaveStream:TKMemoryStream);
var i:integer;
begin
  Inherited;
  for i:=1 to 11 do SaveStream.Write(ResourceCount[i], SizeOf(ResourceCount[i]));
  SaveStream.Write(RecruitsInside);
end;


{ THouseAction }
constructor THouseAction.Create(aHouse:TKMHouse; aHouseState: THouseState);
begin
  Inherited Create;
  fHouse := aHouse;
  SetState(aHouseState);
end;


procedure THouseAction.SetState(aHouseState: THouseState);
begin
  fHouseState := aHouseState;
  if aHouseState=hst_Idle then begin
    SubActionRem([ha_Work1..ha_Smoke]); //remove all work attributes
    SubActionAdd([ha_Idle]);
  end;
  if aHouseState=hst_Work then begin
    SubActionRem([ha_Idle]);
  end;
  if aHouseState=hst_Empty then begin
    SubActionRem([ha_Idle]);
  end;
end;


procedure THouseAction.SubActionWork(aActionSet: THouseActionType);
begin
  SubActionRem([ha_Work1..ha_Work5]); //Remove all work
  fSubAction := fSubAction + [aActionSet];
  if fHouse.fHouseType <> ht_Mill then fHouse.WorkAnimStep := 0; //Exception for mill so that the windmill doesn't jump frames
end;


function THouseAction.GetWorkID():byte;
begin
  if ha_Work1 in fSubAction then Result := 1 else
  if ha_Work2 in fSubAction then Result := 2 else
  if ha_Work3 in fSubAction then Result := 3 else
  if ha_Work4 in fSubAction then Result := 4 else
  if ha_Work5 in fSubAction then Result := 5 else
    Result := 0;
end;


procedure THouseAction.SubActionAdd(aActionSet: THouseActionSet);
begin
  fSubAction := fSubAction + aActionSet;
end;


procedure THouseAction.SubActionRem(aActionSet: THouseActionSet);
begin
  fSubAction := fSubAction - aActionSet;
end;


procedure THouseAction.Save(SaveStream:TKMemoryStream);
begin
  if fHouse <> nil then
    SaveStream.Write(fHouse.ID)
  else
    SaveStream.Write(Zero);
  SaveStream.Write(fHouseState, SizeOf(fHouseState));
  SaveStream.Write(fSubAction, SizeOf(fSubAction));
end;


procedure THouseAction.Load(LoadStream:TKMemoryStream);
begin
  LoadStream.Read(fHouse, 4);
  LoadStream.Read(fHouseState, SizeOf(fHouseState));
  LoadStream.Read(fSubAction, SizeOf(fSubAction));
end;


{ TKMHousesCollection }
function TKMHousesCollection.AddToCollection(aHouseType: THouseType; PosX,PosY:integer; aOwner: TPlayerID; aHBS:THouseBuildState):TKMHouse;
var T:integer;
begin
  case aHouseType of
    ht_Swine:    T := Inherited Add(TKMHouseSwineStable.Create(aHouseType,PosX,PosY,aOwner,aHBS));
    ht_Stables:  T := Inherited Add(TKMHouseSwineStable.Create(aHouseType,PosX,PosY,aOwner,aHBS));
    ht_Inn:      T := Inherited Add(TKMHouseInn.Create(aHouseType,PosX,PosY,aOwner,aHBS));
    ht_School:   T := Inherited Add(TKMHouseSchool.Create(aHouseType,PosX,PosY,aOwner,aHBS));
    ht_Barracks: T := Inherited Add(TKMHouseBarracks.Create(aHouseType,PosX,PosY,aOwner,aHBS));
    ht_Store:    T := Inherited Add(TKMHouseStore.Create(aHouseType,PosX,PosY,aOwner,aHBS));
    else         T := Inherited Add(TKMHouse.Create(aHouseType,PosX,PosY,aOwner,aHBS));
  end;
    if T=-1 then Result := nil else Result := Items[T];
end;


function TKMHousesCollection.GetHouse(Index: Integer): TKMHouse;
begin
  Result := TKMHouse(Items[Index])
end;


procedure TKMHousesCollection.SetHouse(Index: Integer; Item: TKMHouse);
begin
  Items[Index] := Item;
end;


function TKMHousesCollection.AddHouse(aHouseType: THouseType; PosX,PosY:integer; aOwner: TPlayerID):TKMHouse;
begin
  Result := AddToCollection(aHouseType,PosX,PosY,aOwner,hbs_Done);
end;


{Add a plan for house}
function TKMHousesCollection.AddPlan(aHouseType: THouseType; PosX,PosY:integer; aOwner: TPlayerID):TKMHouse;
begin
  Result := AddToCollection(aHouseType,PosX,PosY,aOwner,hbs_Glyph);
end;


function TKMHousesCollection.Rem(aHouse:TKMHouse):boolean;
begin
  Remove(aHouse);
  Result := true;
end;


function TKMHousesCollection.HitTest(X, Y: Integer): TKMHouse;
var i:integer;
begin
  Result:= nil;
  for I := 0 to Count - 1 do
    if Houses[i].HitTest(X, Y) and (not Houses[i].IsDestroyed) then
    begin
      Result:= TKMHouse(Items[I]);
      Break;
    end;
end;


function TKMHousesCollection.GetHouseByID(aID: Integer): TKMHouse;
var i:integer;
begin
  Result := nil;
  for i := 0 to Count-1 do
    if aID = Houses[i].ID then
    begin
      Result := Houses[i];
      exit;
    end;
end;


//Should find closest house to Loc
function TKMHousesCollection.FindEmptyHouse(aUnitType:TUnitType; Loc:TKMPoint): TKMHouse;
var i:integer;
  Dist,Bid:single;
begin
  Result:= nil;
  Bid:=0;

  for I := 0 to Count - 1 do
    if (TUnitType(HouseDAT[byte(Houses[i].fHouseType)].OwnerType+1)=aUnitType)and //If Unit can work in here
       (not Houses[i].fHasOwner)and                              //If there's yet no owner
       (not Houses[i].IsDestroyed)and
       (Houses[i].IsComplete) then                               //If house is built
    begin

      Dist:=KMLength(Loc,Houses[i].GetPosition);

      //Always prefer Towers to Barracks by making Barracks Bid much less attractive
      if Houses[i].GetHouseType = ht_Barracks then Dist:=Dist*1000;

      if (Bid=0)or(Bid>Dist) then
      begin
        Bid:=Dist;
        Result := Houses[i];
      end;

    end;

 if Result<>nil then
 if Result.fHouseType<>ht_Barracks then Result.fHasOwner:=true; //Become owner except Barracks;
end;


function TKMHousesCollection.FindHouse(aType:THouseType; X,Y:word; const Index:byte=1): TKMHouse;
var
  i,id: integer;
  UsePosition: boolean;
  BestMatch,Dist: single;
begin
  Result := nil;
  id := 0;
  BestMatch := -1; //Use -1 value to init variable on first run
  UsePosition := X*Y<>0; //Calculate this once to save computing lots of multiplications
  fLog.AssertToLog((not UsePosition)or(Index=1), 'Can''t find house basing both on Position and Index');

  for I := 0 to Count - 1 do
  if Items[I] <> nil then
  if (Houses[i].fHouseType=aType) and (Houses[i].IsComplete) then
  begin
      inc(id);
      if UsePosition then
      begin
          Dist := GetLength(Houses[i].GetPosition,KMPoint(X,Y));
          if BestMatch = -1 then BestMatch := Dist; //Initialize for first use
          if Dist < BestMatch then begin
            BestMatch := Dist;
            Result := Houses[i];
          end;
      end else
          if Index = id then begin//Take the N-th result
            Result := Houses[i];
            exit;
          end;
  end;
end;


procedure TKMHousesCollection.Save(SaveStream:TKMemoryStream);
var i:integer;
begin
  SaveStream.Write('Houses');
  if fSelectedHouse <> nil then
    SaveStream.Write(fSelectedHouse.ID) //Store ID, then substitute it with reference on SyncLoad
  else
    SaveStream.Write(Zero);
  SaveStream.Write(Count);
  for i := 0 to Count - 1 do
    Houses[i].Save(SaveStream);
end;


procedure TKMHousesCollection.Load(LoadStream:TKMemoryStream);
var i,HouseCount:integer; s:string; HouseType:THouseType;
begin
  LoadStream.Read(s); if s <> 'Houses' then exit;
  LoadStream.Read(fSelectedHouse, 4);
  LoadStream.Read(HouseCount);
  for i := 0 to HouseCount - 1 do
  begin
    LoadStream.Read(HouseType, SizeOf(HouseType));
    LoadStream.Seek(-SizeOf(HouseType), soFromCurrent); //rewind
    case HouseType of //Create some placeholder unit
      ht_Swine:    Inherited Add(TKMHouseSwineStable.Load(LoadStream));
      ht_Stables:  Inherited Add(TKMHouseSwineStable.Load(LoadStream));
      ht_Inn:      Inherited Add(TKMHouseInn.Load(LoadStream));
      ht_School:   Inherited Add(TKMHouseSchool.Load(LoadStream));
      ht_Barracks: Inherited Add(TKMHouseBarracks.Load(LoadStream));
      ht_Store:    Inherited Add(TKMHouseStore.Load(LoadStream));
      else         Inherited Add(TKMHouse.Load(LoadStream));
//    else fLog.AssertToLog(false, 'Uknown house type in Savegame')
    end;
  end;
end;


procedure TKMHousesCollection.SyncLoad();
var i:integer;
begin
  fSelectedHouse := fPlayers.GetHouseByID(cardinal(fSelectedHouse));
  for i := 0 to Count - 1 do
    if Houses[i].fCurrentAction<>nil then
      Houses[i].fCurrentAction.fHouse := fPlayers.GetHouseByID(cardinal(Houses[i].fCurrentAction.fHouse));
end;


procedure TKMHousesCollection.UpdateState;
var
  I, ID: Integer;
  IDsToDelete: array of integer;
begin
  ID := 0;
  for I := 0 to Count - 1 do
  if not Houses[i].IsDestroyed then
    Houses[i].UpdateState
  else //Else try to destroy the house object if all pointers are freed
    if FREE_POINTERS and (Houses[i].GetPointerCount = 0) then
    begin
      SetLength(IDsToDelete,ID+1);
      IDsToDelete[ID] := I;
      inc(ID);
    end;
  //Must remove list entry after for loop is complete otherwise the indexes change
  if ID <> 0 then
    for I := ID-1 downto 0 do
    begin
      TKMHouse(Items[IDsToDelete[I]]).Free; //Because no one needs this anymore it must DIE!!!!! :D
      Delete(IDsToDelete[I]);
    end;
end;


procedure TKMHousesCollection.IncAnimStep;
var
  i:integer;
begin
  for i := 0 to Count - 1 do
    Houses[i].IncAnimStep;
end;

function TKMHousesCollection.GetTotalPointers: integer;
var i:integer;
begin
  Result:=0;
  for I := 0 to Count - 1 do
    Result:=Result+Houses[i].GetPointerCount;
end;


procedure TKMHousesCollection.Paint();
var i:integer; x1,x2,y1,y2,Margin:integer;
begin
  if TEST_VIEW_CLIP_INSET then Margin:=-3 else Margin:=3;
  x1:=fViewport.GetClip.Left-Margin;  x2:=fViewport.GetClip.Right+Margin;
  y1:=fViewport.GetClip.Top -Margin;  y2:=fViewport.GetClip.Bottom+Margin;

  for I := 0 to Count - 1 do
  if not Houses[i].IsDestroyed then
  if (InRange(Houses[i].fPosition.X,x1,x2) and InRange(Houses[i].fPosition.Y,y1,y2)) then
    Houses[i].Paint();
end;



end.
