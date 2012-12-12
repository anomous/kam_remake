unit Unit_Finder;
interface
uses Types, Math, SysUtils,

  Unit_Heap;


const
  MAX_SIZE = 256;

type
  TJPSPoint = class
    x,y: Word;
    h: Word;
    g, f: Single;
    opened, closed: Boolean;
    parent: TJPSPoint;
  end;

  TPointArray = array of TPoint;

  //Jump-Point-Search pathfinder
  //based on JavaScript implementation by aniero / https://github.com/aniero
  TFinder = class
  private
    startNode, endNode: TJPSPoint;
    Heap: THeap;

    function HeapCmp(A,B: Pointer): Boolean;

    function getNodeAt(x, y: SmallInt): TJPSPoint;
    function backtrace(aEnd: TJPSPoint): TPointArray;
    procedure identifySuccessors(node: TJPSPoint);
    function findNeighbors(const node: TJPSPoint): TPointArray;
    function jump(x, y, px, py: SmallInt): TPoint;
  public
    constructor Create;
    destructor Destroy; override;
    function MakeRoute(aStart, aEnd: TPoint): TPointArray;
  end;


  TGrid = class
  public
    Map: array [0 .. MAX_SIZE - 1, 0 .. MAX_SIZE - 1] of Boolean;
    Nodes: array [0 .. MAX_SIZE - 1, 0 .. MAX_SIZE - 1] of TJPSPoint;
    function IsInside(x, y: SmallInt): Boolean;
    function IsWalkableAt(x, y: SmallInt): Boolean;
    function CanWalkDiagonaly(ax, ay, tx, ty: SmallInt): Boolean;
  end;


var
  Grid: TGrid;


implementation


{ TMap }
function TGrid.CanWalkDiagonaly(ax, ay, tx, ty: SmallInt): Boolean;
begin
  Result := True;
end;


function TGrid.IsInside(x, y: SmallInt): Boolean;
begin
  Result := InRange(x, 0, MAX_SIZE-1) and InRange(y, 0, MAX_SIZE-1);
end;


function TGrid.IsWalkableAt(x, y: SmallInt): Boolean;
begin
  Result := InRange(x, 0, MAX_SIZE-1) and InRange(y, 0, MAX_SIZE-1) and Map[y,x];
end;


{ TFinder }
constructor TFinder.Create;
begin
  inherited;

  Heap := THeap.Create;
  Heap.Cmp := HeapCmp;
end;


destructor TFinder.Destroy;
begin
  Heap.Free;

  inherited;
end;


function TFinder.HeapCmp(A, B: Pointer): Boolean;
begin
  if A = nil then
    Result := True
  else
    Result := (B = nil) or (TJPSPoint(A).f < TJPSPoint(B).f);
end;


function TFinder.MakeRoute(aStart, aEnd: TPoint): TPointArray;
var
  I,K: Integer;
  Node: TJPSPoint;
begin
  for I := 0 to MAX_SIZE - 1 do
    for K := 0 to MAX_SIZE - 1 do
      FreeAndNil(Grid.Nodes[I, K]);

  endNode := getNodeAt(aEnd.X, aEnd.Y);
  startNode := getNodeAt(aStart.X, aStart.Y);

  startNode.g := 0;
  startNode.f := 0;

  Heap.Push(startNode);
  startNode.opened := True;

  while (not Heap.IsEmpty) do
  begin
    // pop the position of node which has the minimum `f` value.
    Node := Heap.Pop;
    Node.closed := True;

    if (Node.X = endNode.X) and (Node.Y = endNode.Y) then
      Result := backtrace(endNode);

    identifySuccessors(Node);
  end;
end;


function TFinder.getNodeAt(x, y: SmallInt): TJPSPoint;
begin
  if Grid.Nodes[y,x] = nil then
  begin
    Grid.Nodes[y,x] := TJPSPoint.Create;
    Grid.Nodes[y,x].x := x;
    Grid.Nodes[y,x].y := y;
  end;

  Result := Grid.Nodes[y,x];
end;


function TFinder.backtrace(aEnd: TJPSPoint): TPointArray;
var
  Node: TJPSPoint;
  I: Integer;
  T: TPoint;
begin
  Node := aEnd;

  while Node.parent <> nil do
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].X := Node.X;
    Result[High(Result)].Y := Node.Y;
    Node := Node.parent;
  end;

  SetLength(Result, Length(Result) + 1);
  Result[High(Result)].X := Node.X;
  Result[High(Result)].Y := Node.Y;

  //Reverse the array
  for I := 0 to High(Result) div 2 do
  begin
    T := Result[I];
    Result[I] := Result[High(Result) - I];
    Result[High(Result) - I] := T;
  end;
end;


{**
 * Identify successors for the given node. Runs a jump point search in the
 * direction of each available neighbor, adding any points found to the open
 * list.
 * @protected
 *}
procedure TFinder.identifySuccessors(node: TJPSPoint);
var
  endX, endY: SmallInt;
  x,y,jx,jy: SmallInt;
  neighbors: TPointArray;
  neighbor, jumpPoint: TPoint;
  jumpNode: TJPSPoint;
  I: Integer;
  d, ng: Single;
begin
    endX := endNode.X;
    endY := endNode.Y;
    x := node.X;
    y := node.Y;

    neighbors := findNeighbors(node);
    for I := 0 to High(neighbors) do
    begin
        neighbor := neighbors[i];
        jumpPoint := jump(neighbor.X, neighbor.Y, x, y);
        if (jumpPoint.X <> -1) then
        begin

            jx := jumpPoint.X;
            jy := jumpPoint.Y;
            jumpNode := getNodeAt(jx, jy);

            if (jumpNode.closed) then
                Continue;

            // include distance, as parent may not be immediately adjacent:
            d := sqrt(sqr(jx - x) + sqr(jy - y));
            ng := node.g + d; // next `g` value

            if (not jumpNode.opened) or (ng < jumpNode.g) then
            begin
                jumpNode.g := ng;
                if jumpNode.h = 0 then
                  jumpNode.h := (abs(jx - endX) + abs(jy - endY));
                jumpNode.f := jumpNode.g + jumpNode.h;
                jumpNode.parent := node;

                if not jumpNode.opened then
                begin
                    Heap.Push(jumpNode);
                    jumpNode.opened := True;
                end
                else
                begin
                    Heap.UpdateItem(jumpNode);
                end;
            end;
        end;
    end;
end;


{**
 Search recursively in the direction (parent -> child), stopping only when a
 * jump point is found.
 * @protected
 * @return Array.<[number, number]> The x, y coordinate of the jump point
 *     found, or null if not found
 *}
function TFinder.jump(x, y, px, py: SmallInt): TPoint;
var
  dx, dy: SmallInt;
  jx, jy: TPoint;
begin
  if not Grid.IsWalkableAt(x, y) then
  begin
    Result := Point(-1, -1);
    Exit;
  end
  else
  if (x = endNode.x) and (y = endNode.y) then
  begin
    Result := Point(x, y);
    Exit;
  end;

  dx := x - px;
  dy := y - py;

  // check for forced neighbors
  // along the diagonal
  if (dx <> 0) and (dy <> 0) then
  begin
    if ((Grid.isWalkableAt(x - dx, y + dy) and not Grid.isWalkableAt(x - dx, y)) or
        (Grid.isWalkableAt(x + dx, y - dy) and not Grid.isWalkableAt(x, y - dy))) then
    begin
      Result := Point(x, y);
      Exit;
    end;
  end
  // horizontally/vertically
  else begin
    if( dx <> 0 ) then // moving along x
    begin
      if((Grid.isWalkableAt(x + dx, y + 1) and not Grid.isWalkableAt(x, y + 1)) or
         (Grid.isWalkableAt(x + dx, y - 1) and not Grid.isWalkableAt(x, y - 1))) then
      begin
        Result := Point(x, y);
        Exit;
      end;
    end
    else begin
      if((Grid.isWalkableAt(x + 1, y + dy) and not Grid.isWalkableAt(x + 1, y)) or
         (Grid.isWalkableAt(x - 1, y + dy) and not Grid.isWalkableAt(x - 1, y))) then
      begin
        Result := Point(x, y);
        Exit;
      end;
    end;
  end;

  // when moving diagonally, must check for vertical/horizontal jump points
  if (dx <> 0) and (dy <> 0) then
  begin
    jx := jump(x + dx, y, x, y);
    jy := jump(x, y + dy, x, y);
    if (jx.x <> -1) or (jy.x <> -1) then
    begin
      Result := Point(x, y);
      Exit;
    end;
  end;

  // moving diagonally, must make sure one of the vertical/horizontal
  // neighbors is open to allow the path
  if (Grid.isWalkableAt(x + dx, y) or Grid.isWalkableAt(x, y + dy)) then
    Result := jump(x + dx, y + dy, x, y)
  else
    Result := Point(-1, -1);
end;


//Find the neighbors for the given node. If the node has a parent,
//prune the neighbors based on the jump point search algorithm, otherwise
//return all available neighbors.
//@return {Array.<[number, number]>} The neighbors found.
function TFinder.findNeighbors(const node: TJPSPoint): TPointArray;
var
  count: SmallInt;
  procedure Add(ax,ay: SmallInt);
  begin
    Result[count].X := ax;
    Result[count].Y := ay;
    Inc(count);
  end;
var
  parent: TJPSPoint;
  x,y: SmallInt;
  px, py, dx, dy: SmallInt;
begin
  count := 0;
  SetLength(Result, 8);

  parent := node.parent;
  x := node.x;
  y := node.y;

    // directed pruning: can ignore most neighbors, unless forced.
    if (parent <> nil) then
    begin
        px := parent.x;
        py := parent.y;
        // get the normalized direction of travel
        dx := Round((x - px) / max(abs(x - px), 1));
        dy := Round((y - py) / max(abs(y - py), 1));

        // search diagonally
        if (dx <> 0) and (dy <> 0) then
        begin
            if Grid.IsWalkableAt(x, y + dy) then
              Add(x, y + dy);
            if Grid.IsWalkableAt(x + dx, y) then
              Add(x + dx, y);
            if Grid.IsWalkableAt(x, y + dy) or Grid.IsWalkableAt(x + dx, y) then
              Add(x + dx, y + dy);
            if (not Grid.IsWalkableAt(x - dx, y)) and (not Grid.IsWalkableAt(x, y + dy)) then
              Add(x - dx, y + dy);
            if (not Grid.IsWalkableAt(x, y - dy)) and (not Grid.IsWalkableAt(x + dx, y)) then
              Add(x + dx, y - dy);
        end
        // search horizontally/vertically
        else
        begin
            if (dx = 0) then
            begin
                if Grid.IsWalkableAt(x, y + dy) then
                begin
                    if Grid.IsWalkableAt(x, y + dy) then
                      Add(x, y + dy);
                    if not Grid.IsWalkableAt(x + 1, y) then
                      Add(x + 1, y + dy);
                    if not Grid.IsWalkableAt(x - 1, y) then
                      Add(x - 1, y + dy);
                end;
            end
            else
            begin
                if Grid.IsWalkableAt(x + dx, y) then
                begin
                    if Grid.IsWalkableAt(x + dx, y) then
                      Add(x + dx, y);
                    if not Grid.IsWalkableAt(x, y + 1) then
                      Add(x + dx, y + 1);
                    if not Grid.IsWalkableAt(x, y - 1) then
                      Add(x + dx, y - 1);
                end;
            end;
        end;
    end
    // return all neighbors (if parent = nil)
    else
    begin
      if Grid.IsWalkableAt(x, y-1) then
        Add(x, y-1);
      if Grid.IsWalkableAt(x+1, y) then
        Add(x+1, y);
      if Grid.IsWalkableAt(x, y+1) then
        Add(x, y+1);
      if Grid.IsWalkableAt(x-1, y) then
        Add(x-1, y);

      if Grid.IsWalkableAt(x-1, y-1) then
        Add(x-1, y-1);
      if Grid.IsWalkableAt(x+1, y-1) then
        Add(x+1, y-1);
      if Grid.IsWalkableAt(x+1, y+1) then
        Add(x+1, y+1);
      if Grid.IsWalkableAt(x-1, y+1) then
        Add(x-1, y+1);
    end;

    //Invert array since we should have Pushed values to it, not appended
    SetLength(Result, count);
end;


end.