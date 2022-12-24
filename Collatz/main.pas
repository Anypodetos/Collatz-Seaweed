unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Spin, Buttons, Math, GL, OpenGLContext, Types, StrUtils, LclIntf, About;

type

  { TMainForm }

  TMainForm = class(TForm)
    Label7: TLabel;
    LightnessCombo: TComboBox;
    Label6: TLabel;
    SaturationCombo: TComboBox;
    HueCombo: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    OpenGLBox: TOpenGLControl;
    Panel: TPanel;
    MaxSpin: TSpinEdit;
    EvenAngleSpin: TSpinEdit;
    OddAngleSpin: TSpinEdit;
    InfoText: TStaticText;
    AngleLockButton: TSpeedButton;
    AboutButton: TSpeedButton;
    Timer: TTimer;
    procedure AboutButtonClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure UpdateColl(Sender: TObject);
    procedure OpenGLBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OpenGLBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure OpenGLBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OpenGLBoxMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure OpenGLBoxPaint(Sender: TObject);
    procedure OpenGLBoxResize(Sender: TObject);
  private
    OpenGLInitialised, MouseMoved, Draw, InUpdate: Boolean;
    ViewX, ViewY, Phi0, Zoom, curX, curY: Double;
    OldX, OldY, AtCur, StepsAtCur, OldEven, OldOdd, Hue, Saturation, Lightness, TimerStep: Integer;
    function InitOpenGL: Boolean;
    procedure Coll(n: Integer; x, y, phi: Double; steps: Integer);
  public

  end;

var
  MainForm: TMainForm;

const
  CompileDate = {$I %DATE%};

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.UpdateColl(Sender: TObject);
begin
  if OldEven=0 then begin         ///////
    OldEven:=EvenAngleSpin.Value;
    OldOdd:=OddAngleSpin.Value;
  end;
  if not InUpdate and AngleLockButton.Down then begin
    InUpdate:=True;
    if   Sender=EvenAngleSpin then OddAngleSpin .Value:=OddAngleSpin .Value+EvenAngleSpin.Value-OldEven else
      if Sender=OddAngleSpin  then EvenAngleSpin.Value:=EvenAngleSpin.Value+OddAngleSpin .Value-OldOdd;
    InUpdate:=False;
  end;
  OldEven:=EvenAngleSpin.Value;
  OldOdd:=OddAngleSpin.Value;
  HueCombo.Enabled:=SaturationCombo.ItemIndex<>1;
  Timer.Enabled:=LightnessCombo.ItemIndex=4;
  TimerStep:=0;
  OpenGLBox.Invalidate;
end;

{----------------------------------------------Mouse-------------------------------------------------------------}

procedure TMainForm.OpenGLBoxResize(Sender: TObject);
var d: Double;
begin
  if OpenGLInitialised and OpenGLBox.MakeCurrent then begin
    glViewport(0, 0, OpenGLBox.Width, OpenGLBox.Height);
    glMatrixMode(GL_Projection);
    glLoadIdentity;
    glTranslateF(ViewX, ViewY, 1);
    with OpenGLBox do if Height>0 then d:=Width/Height else d:=1;
    glOrtho(-d/Zoom, d/Zoom, -1/Zoom, 1/Zoom, 1, 3);
    OpenGLBox.Invalidate;
  end;
end;

procedure TMainForm.OpenGLBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  MouseMoved:=False;
end;

procedure TMainForm.OpenGLBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var h: Boolean;
begin
  if ssLeft in Shift then begin
    h:=False;
    if ssCtrl in Shift then OpenGLBoxMouseWheel(Sender, Shift-[ssLeft, ssCtrl], OldY-Y, Point(X, Y), h) else begin
      ViewX+=2*(X-OldX)/OpenGLBox.Width;
      ViewY-=2*(Y-OldY)/OpenGLBox.Height;
      OpenGLBoxResize(nil);
    end;
  end;
  OldX:=X;
  OldY:=Y;
  MouseMoved:=True;
  InfoText.Hide;
//  if Shift=[] then NotifyLabel.Hide;
end;

procedure TMainForm.OpenGLBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  with OpenGLBox do begin
    curX:=2*(X-Width/2*(1+ViewX))  /Height/Zoom;
    curY:=2*(Height /2*(1-ViewY)-Y)/Height/Zoom;
  end;
  AtCur:=0;
  Draw:=False;
  Coll(1, 0, 0, Phi0, 0);
  with InfoText do begin
    Caption:=IfThen(AtCur>0, IntToStr(AtCur)+#13#10+IntToStr(StepsAtCur)+' step'+IfThen(StepsAtCur<>1, 's')+#13#10)
      +'('+FloatToStrF(curX, ffFixed, 0, 3)+'; '
          +FloatToStrF(curY, ffFixed, 0, 3)+')';
    Left:=Min(X, OpenGLBox.Width-Width);
    Top:=Y+Panel.Height-Height;
    Show;
  end;
end;

procedure TMainForm.OpenGLBoxMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if Shift=[] then Zoom:=Zoom*Exp(WheelDelta/2000) else if Shift=[ssShift] then Zoom:=Round(4*Zoom+Sign(WheelDelta))/4;
  Zoom:=Min(Max(Zoom, 0.001), 0.1);
//  NotifyLabel.Caption:='Zoom: '+FloatToStrF(Zoom, ffFixed, 0, 2)+' / r = '+IntToStr(Round(OpenGLBox.Height/2*Zoom))+'px';
 // NotifyLabel.Show;
  OpenGLBoxResize(nil);
end;

{----------------------------------------------Draw-------------------------------------------------------------}

function TMainForm.InitOpenGL: Boolean;
begin
  Result:=OpenGLBox.MakeCurrent;
  if Result and not OpenGLInitialised then begin
    Zoom:=0.025;
    ViewX:=-0.4;
    Phi0:=pi/2;
    glEnable(GL_Point_Smooth);
    glHint(GL_Point_Smooth_Hint, GL_Nicest);
    glEnable(GL_Line_Smooth);
    glHint(GL_Line_Smooth_Hint, GL_Nicest);
    glEnable(GL_Blend);
    glBlendFunc(GL_Src_Alpha, GL_One_Minus_Src_Alpha);
    OpenGLInitialised:=True;
    OpenGLBoxResize(nil);
  end;
end;

procedure TMainForm.TimerTimer(Sender: TObject);
begin
  TimerStep:=(TimerStep+1) mod 300;
  OpenGLBox.Invalidate;
end;

procedure TMainForm.Coll(n: Integer; x, y, phi: Double; steps: Integer);

  procedure Color; { Hue [0,360[ ; Saturation [0,1] ; Lightness [0,1] }
  var i: Integer;
      h, s, l, p, q: Double;
      t, c: array[0..2] of Double;    {r,g,b}
  begin
    case Hue of
      0: h:=n/MaxSpin.Value*360;
      1: h:=phi*180/pi;
      2: h:=3*steps;
    end;
    case Saturation of
      0: s:=1;
      1: s:=0;
      2: s:=n/MaxSpin.Value;
      3: s:=phi/2/pi;
      4: s:=steps/100;
    end;
    case Lightness of
      0: l:=0.5;
      1: l:=1-n/MaxSpin.Value;
      2: l:=1-phi/2/pi;
      3: l:=1-steps/100;
      4: l:=0.2+0.8*Ord(Abs(n/MaxSpin.Value-TimerStep/300)<0.02);
    end;
    //h:=(h+360) mod 360;
    //s:=1;//Max(Min(s, 1), 0);
   // l:=0.5;//Max(Min(l, 1), 0);
    if l<1/2 then q:=l*(1+s) else q:=s+l*(1-s);
    p:=2*l-q;
    t[1]:=h/360;
    t[0]:=t[1]+1/3;
    t[2]:=t[1]-1/3;
    for i:=0 to 2 do begin
      if t[i]<0 then t[i]:=t[i]+1 else if t[i]>1 then t[i]:=t[i]-1;
      if t[i]<1/6 then c[i]:=p+(q-p)*6*t[i] else
        if t[i]<1/2 then c[i]:=q else
        if t[i]<2/3 then c[i]:=p+(q-p)*6*(2/3-t[i]) else
        c[i]:=p;
    end;
    glColor3F(c[0], c[1], c[2]);
  end;
//    glColorHSL(Round(n/MaxSpin.Value*360), 1, 0.5);//Round(phi*180/pi), 1, 0.5{1-n/MaxSpin.Value}); //(n*100) mod $1000000;//    iter

var delta1, delta2: Double;
begin
  if Draw then begin
    Color;
    glVertex2F(x, y)
  end else if (Abs(curX-x)<0.2) and (Abs(curY-y)<0.2) then begin
    AtCur:=n;
    StepsAtCur:=steps;
    curX:=x;
    curY:=y;
  end;
  if n<MaxSpin.Value div 2 then begin
    delta1:=phi-EvenAngleSpin.Value/180*pi;
    delta2:=phi+OddAngleSpin.Value/180*pi;
    Coll(2*n, x+sin(delta1), y+cos(delta1), delta1, steps+1);
    if (n>2) and ((2*n-1) mod 3 = 0) then begin
      if Draw then begin
        glEnd;
        glBegin(GL_Line_Strip);
        Color;
        glVertex2F(x, y);
      end;
     Coll((2*n-1) div 3, x+sin(delta2), y+cos(delta2), delta2, steps+1);
    end;
  end;
end;

procedure TMainForm.OpenGLBoxPaint(Sender: TObject);
begin
  if InitOpenGL then begin
    glMatrixMode(gl_ModelView);
    glClearColor(0, 0, 0, 1);
    glClear(GL_Color_Buffer_Bit or GL_Depth_Buffer_Bit);
    glLineWidth(0.5);
    glBegin(GL_Line_Strip);
      Hue:=HueCombo.ItemIndex;
      Saturation:=SaturationCombo.ItemIndex;
      Lightness:=LightnessCombo.ItemIndex;
      Draw:=True;
      Coll(1, 0, 0, Phi0, 0);
    glEnd;
    OpenGLBox.SwapBuffers;
  end;
end;

procedure TMainForm.AboutButtonClick(Sender: TObject);
begin
  AboutForm.ShowModal;
end;

end.

