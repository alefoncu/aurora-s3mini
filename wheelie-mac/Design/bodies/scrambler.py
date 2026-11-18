import sys; sys.path.insert(0,'..')
from trace import *
R=Ref((212,405),(757,402),112,lift=(14,50,10,9))
PH='/private/tmp/claude-501/refs/scr_11.png'
def S(L,closed=True): return smooth(R.pts(L),closed)
def Ln(L): return line(R.pts(L))
tank=[(432,235),(445,205),(480,182),(540,165),(595,162),(640,172),(665,198),(668,225),(640,240),(585,250),(520,262),(470,268)]
seat=[(205,198),(260,200),(330,215),(400,212),(440,222),(448,250),(420,262),(350,258),(300,248),(250,232),(210,220)]
rcyl=[(435,285),(485,282),(492,332),(440,338)]
fcyl=[(500,270),(580,268),(598,332),(515,338)]
case=[(415,330),(470,322),(540,335),(578,355),(562,405),(520,426),(470,421),(430,400)]
muff=[(285,372),(322,366),(408,418),(414,440),(370,442),(300,396)]
rfend=[(120,335),(135,300),(190,282),(240,285),(255,300),(205,300),(160,312),(136,345)]
ffend=[(655,312),(690,286),(740,272),(790,280),(802,296),(750,291),(706,306),(676,336)]
lamp=[(662,148),(700,140),(714,170),(702,205),(670,208),(660,180)]
tubes=[[(215,224),(330,252),(445,262)],[(262,240),(350,300),(432,336)],[(650,190),(540,255),(440,325)],[(630,228),(600,335)],[(440,250),(430,335)]]
pipe1=[(556,335),(578,380),(560,420),(520,436),(455,436)]
pipe2=[(436,420),(380,426),(340,396),(300,362)]
z0=''.join(tube(smooth(R.pts(t),False),3.2) for t in tubes)+panel(S(case),'gMe')+panel(S(rcyl),'gMd')+panel(S(fcyl),'gMd')+''.join(stroke(Ln([(x0,y),(x1,y)]),.9,'#0E1316',.85) for (x0,x1,y) in ((437,490,300),(437,490,315),(505,590,290),(510,595,306),(512,598,320)))+circ(*R.p((462,280)),4,'gCh')+circ(*R.p((500,385)),5.5,'gCh')
z1=pipe(smooth(R.pts(pipe1),False),3.4)+pipe(smooth(R.pts(pipe2),False),3.4)+panel(S(muff),'gCh')+panel(smooth(R.rad(rfend,(212,405),.9)),'gP')+panel(S(seat),'gSeat')+panel(S(tank),'gP')+stroke(Ln([(470,225),(560,190),(640,195)]),1.3,'#FFFFFF',.6)
z2=panel(smooth(R.rad(ffend,(757,402),.9)),'gP')+panel(S(lamp),'gCh')+'<ellipse cx="%s" cy="%s" rx="1.8" ry="5.4" fill="url(#gLamp)" stroke="#141B20" stroke-width=".5"/>'%tuple(f'{v:.2f}' for v in R.p((712,172)))
for g,c in (('z0',z0),('z1',z1),('z2',z2),('z3','')): set_group('../canvas/project/Scrambler.dc.html',g,c)
overlay(PH,R,[(tank,'lime'),(seat,'cyan'),(muff,'magenta'),(case,'white'),(fcyl,'orange'),(ffend,'red'),(lamp,'blue')],'/private/tmp/claude-501/refs/ov5.png')
