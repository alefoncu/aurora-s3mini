import sys; sys.path.insert(0,'..')
from trace import *
R=Ref((205,470),(738,480),108,lift=(14,50,20,22))
PH='/private/tmp/claude-501/refs/gasgas_4.png'
def S(L,closed=True): return smooth(R.pts(L),closed)
def Ln(L): return line(R.pts(L))
rfend=[(60,270),(85,245),(150,235),(230,245),(290,270),(305,290),(260,282),(200,270),(130,268),(80,282)]
seat=[(305,285),(350,268),(410,266),(452,284),(442,302),(380,300),(320,302)]
body=[(300,288),(350,268),(430,258),(480,238),(540,230),(595,235),(603,262),(585,300),(540,312),(470,312),(400,305),(330,300)]
cyl=[(470,312),(556,322),(552,372),(470,376)]
case=[(400,360),(480,346),(562,382),(562,442),(522,472),(440,472),(400,432)]
pipe_=[(560,316),(592,332),(596,382),(560,412)]
ffend=[(610,420),(625,385),(670,360),(740,345),(790,340),(776,351),(735,359),(685,381),(642,430)]
tubes=[[(615,195),(590,260),(540,340),(520,410)],[(300,290),(350,400),(392,472)],[(430,302),(380,432)]]
spar=smooth([(84,-70),(68,-54),(54,-38),(45,-18)],False)
down=smooth([(86,-66),(80,-40),(73,-12)],False)
sub_=smooth([(52,-40),(36,-48),(20,-54)],False)
z0=tube(down,2.2,'#D6342A')+tube(sub_,2,'#D6342A')+panel(S(case),'gBk')+panel(S(cyl),'gMd')+''.join(stroke(Ln([(472,322+i*12),(554,330+i*11)]),.9,'#6A1010',.9) for i in range(4))+circ(*R.p((480,420)),6,'gCh')
bodyN=[(82,-71),(72,-67),(56,-61),(38,-58),(24,-55),(26,-50),(44,-50),(60,-52),(72,-56),(80,-62)]
rfendN=[(26,-55),(10,-58),(-8,-61),(-26,-64),(-30,-61),(-14,-56),(2,-52),(18,-49),(27,-50)]
z1=tube(spar,4.2,'#D6342A')+pipe(smooth(R.pts(pipe_),False),4)+panel(smooth(rfendN),'gW')+panel(smooth(bodyN),'gW')+panel(S(seat),'gSeat')+stroke(line([(62,-60),(76,-65)]),1.6,'#D6342A')
z2=panel(smooth(R.rad(ffend,(738,480),.95)),'gW')
for g,c in (('z0',z0),('z1',z1),('z2',z2),('z3','')): set_group('../canvas/project/Trial.dc.html',g,c)
overlay(PH,R,[(rfend,'lime'),(seat,'cyan'),(body,'orange'),(case,'white'),(ffend,'blue')],'/private/tmp/claude-501/refs/ov9.png')
e=open('electric.py').read()
e=e.replace("z2=panel(smooth(R.rad(ffend,(190,490),.95)),'gP')+panel(S(screen),'gGlass',.7,.85)+panel(S(cowl),'gDk',.9)","lampb=[(205,190),(262,170),(302,215),(262,258),(215,248)]\nz2=panel(smooth(R.rad(ffend,(190,490),.95)),'gP')+panel(S(lampb),'gDk',.9)+'<ellipse cx=\"%s\" cy=\"%s\" rx=\"1.8\" ry=\"5\" fill=\"url(#gLamp)\" stroke=\"#141B20\" stroke-width=\".5\"/>'%tuple(f'{v:.2f}' for v in R.p((296,214)))")
open('electric.py','w').write(e)
