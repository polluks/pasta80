(* ===================================================================== *)
(* === Amstrad CPC run-time library ====================================== *)
(* ===================================================================== *)

{$i system.pas  }

{$l amstrad.asm }

(* --------------------------------------------------------------------- *)
(* --- CPC firmware console support ------------------------------------ *)
(* --------------------------------------------------------------------- *)

const
  ScreenWidth = 80;

  ScreenHeight = 25;

  LineBreak = #13#10;

procedure ConOut(C: Char); register;        external '__conout';

procedure ClrScr; register;                 external '__clrscr';

procedure ClrEol; register;                 external '__clreol';

procedure GotoXY(X, Y: Integer); register;  external '__gotoxy';

function WhereX: Integer; register; external '__wherex';

function WhereY: Integer; register; external '__wherey';

procedure CursorOn; register;               external '__cursor_on';

procedure CursorOff; register;              external '__cursor_off';

procedure ClrEos; register; external '__clreos';

procedure InsLine; register; inline
(
  $c9                         (* ret (TODO) *)
);

procedure DelLine; register; inline
(
  $c9                         (* ret (TODO) *)
);

procedure TextColor(I: Integer); register;      external '__textfg';

procedure TextBackground(I: Integer); register; external '__textbg';

procedure HighVideo; register; inline
(
  $c9
);

procedure LowVideo; register; inline
(
  $c9
);

procedure NormVideo; register; inline
(
  $c9
);

(* -------------------------------------------------------------------------- *)
(* --- Keyboard support ----------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

function KeyPressed: Boolean; register; external '__keypressed';

function ReadKey: Char; register; external '__readkey_fw';

procedure DelayVSync; register; external '__delayvsync';

procedure Delay(Duration: Integer);
var
  Ticks: Integer;
begin
  Ticks := Duration div 20;
  while Ticks > 0 do
  begin
    DelayVSync;
    Dec(Ticks);
  end;
end;

(* -------------------------------------------------------------------------- *)
(* --- Command-line parameters ---------------------------------------------- *)
(* -------------------------------------------------------------------------- *)

function ParamCount: Byte;
var
  CmdLine: String absolute $80;
  C, D: Boolean;
  I, J: Byte;
begin
  C := True;
  J := 0;

  for I := 1 to Length(CmdLine) do
  begin
    D := CmdLine[I] > ' ';
    if not C and D then Inc(J);
    C := D;
  end;

  ParamCount := J;
end;

function ParamStr(I: Byte): String;
var
  CmdLine: String absolute $80;
  C, D: Boolean;
  J, K: Byte;
begin
  C := True;
  K := 1;

  for J := 1 to Length(CmdLine) do
  begin
    D := CmdLine[J] > ' ';

    if not C and D then
      K := J
    else if C and not D then
    begin
      if I = 0 then
      begin
        Dec(J);
        Break;
      end;

      Dec(I);
    end;

    C := D;
  end;

  if I = 0 then
    ParamStr := Copy(CmdLine, K, J - K + 1)
  else
    ParamStr := '';
end;

(* -------------------------------------------------------------------------- *)
(* --- AMSDOS BDOS interface including error handling ----------------------- *)
(* -------------------------------------------------------------------------- *)

const
  LastError: Byte = 0;

function IOResult: Byte;
begin
  IOResult := LastError;
  LastError := 0;
end;

procedure BDosCatch(Func: Byte; Param: Integer);
var
  A: Byte;
begin
  if LastError <> 0 then Exit;
  A := BDos(Func, Param);
  if A <> 0 then LastError := A;
end;

procedure BDosThrow;
begin
  if LastError <> 0 then
  begin
    WriteLn('AMSDOS error ', LastError);
    Halt;
  end;
end;

(* --------------------------------------------------------------------- *)
(* --- Internal implementation of "raw" untyped files ------------------ *)
(* --------------------------------------------------------------------- *)

type
  FileControlBlock = record
    DR: Byte;
    FN: array[0..7] of Char;
    TN: array[0..2] of Char;
    EX, S1, S2, RC: Byte;
    AL: array[0..15] of Byte;
    CR: Byte;
    RL: Integer; RH: Byte;
    SL: Integer; SH: Byte;
  end;

procedure BlockAssign(var F: FileControlBlock; S: String);
var
  I, L, P, Q: Integer;
begin
  if LastError <> 0 then Exit;

  with F do
  begin
    L := Length(S);

    if (L > 1) and (S[2] = ':') then
    begin
      DR := Ord(UpCase(S[1])) - 64;
      Delete(S, 1, 2);
      Dec(L, 2);
    end
    else DR := 0;

    P := Pos('.', S);
    if P = 0 then P := L + 1;

    Q := P - 1;
    if Q > 8 then Q := 8;

    for I := 1 to Q do FN[I - 1] := UpCase(S[I]);
    for I := Q + 1 to 8 do FN[I - 1] := ' ';

    Q := L - P;
    if Q > 3 then Q := 3;

    for I := 1 to Q do TN[I - 1] := UpCase(S[P + I]);
    for I := Q + 1 to 3 do TN[I - 1] := ' ';
  end;
end;

procedure BlockErase(var F: FileControlBlock);
begin
  if LastError <> 0 then Exit;
  BDosCatch(19, Addr(F));
end;

procedure BlockRename(var F: FileControlBlock; S: String);
var
  G: FileControlBlock;
  A: Byte;
begin
  if LastError <> 0 then Exit;
  BlockAssign(G, S);
  if LastError <> 0 then Exit;
  Move(G, F.AL, 12);
  BDosCatch(23, Addr(F));
end;

procedure BlockReset(var F: FileControlBlock);
var
  A: Byte;
begin
  if LastError <> 0 then Exit;

  with F do
  begin
    EX := 0;
    S1 := 0;
    S2 := 0;
    RC := 0;
    CR := 0;

    RL := 0;
    RH := 0;

    BDosCatch(15, Addr(F));
    BDosCatch(35, Addr(F));

    SL := RL; SH := RH;

    RL := 0;
    RH := 0;
 end;
end;

procedure BlockRewrite(var F: FileControlBlock);
var
  A: Byte;
begin
  if LastError <> 0 then Exit;

  with F do
  begin
    EX := 0;
    S1 := 0;
    S2 := 0;
    RC := 0;
    CR := 0;

    RL := 0;
    RH := 0;

    SL := 0;
    SH := 0;
  end;

  A := BDos(19, Addr(F));
  BDosCatch(22, Addr(F));
end;

procedure BlockClose(var F: FileControlBlock);
begin
  BDosCatch(16, Addr(F));
end;

function BlockFilePos(var F: FileControlBlock): Integer;
begin
  BlockFilePos := F.RL;
end;

function BlockFileSize(var F: FileControlBlock): Integer;
var
  I: Integer;
begin
  BlockFileSize := F.SL;
end;

function BlockEof(var F: FileControlBlock): Boolean;
begin
  with F do
    BlockEof := (RL = SL) and (RH = SH);
end;

procedure BlockSeek(var F: FileControlBlock; I: Integer);
begin
  if LastError <> 0 then Exit;

  F.RL := I;
end;

procedure BlockBlockRead(var F: FileControlBlock; var Buffer; Count: Integer; var Actual: Integer);
var
  DMA: Integer;
begin
  if LastError <> 0 then Exit;

  DMA := Addr(Buffer);
  Actual := 0;

  while Count > 0 do
  begin
    BDosCatch(26, DMA);
    BDosCatch(33, Addr(F));

    if LastError = 1 then
    begin
      LastError := 0;
      Exit;
    end;

    if LastError <> 0 then Exit;

    Inc(F.RL);
    Inc(DMA, 128);
    Inc(Actual);
    Dec(Count);
  end;
end;

procedure BlockBlockWrite(var F: FileControlBlock; var Buffer; Count: Integer; var Actual: Integer);
var
  DMA: Integer;
begin
  if LastError <> 0 then Exit;

  DMA := Addr(Buffer);
  Actual := 0;

  while Count > 0 do
  begin
    BDosCatch(26, DMA);
    BDosCatch(34, Addr(F));

    if LastError <> 0 then Exit;

    Inc(F.RL);
    Inc(DMA, 128);
    Inc(Actual);
    Dec(Count);

    if F.RL > F.SL then F.SL := F.RL;
  end;
end;

{$i files.pas}

end.
