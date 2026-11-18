import sys; sys.path.insert(0,'..')
from trace import *
R=Ref((140,455),(772,478),94,lift=(20,60,-3,8))
PH='/private/tmp/claude-501/refs/bmx4_9.png'
def S(L,closed=True): return smooth(R.pts(L),closed)
def Ln(L): return line(R.pts(L))
P='#E9AD27'
top=[(365,290),(450,262),(560,238),(680,215)]
down=[(690,252),(600,312),(500,366),(405,412)]
seattube=[(365,290),(378,350),(388,424)]
cs=[(385,434),(260,441),(150,446)]
ss=[(362,305),(250,380),(156,440)]
post=[(318,165),(340,250),(365,290)]
seat=[(222,152),(260,120),(330,94),(382,96),(384,116),(332,142),(272,172),(230,186)]
stem=[(645,156),(700,148),(718,172),(660,184)]
z0=tube(smooth(R.pts(ss),False),2.8,P)+tube(smooth(R.pts(cs),False),3.4,P)+tube(smooth(R.pts(seattube),False),3.8,P)
z1=tube(smooth(R.pts(top),False),4.2,P)+tube(smooth(R.pts(down),False),4.6,P)+tube(smooth(R.pts(post),False),2.4,'#C7CED1')+panel(S(seat),'gSeat')+panel(S(stem),'gMe',.8)+circ(*R.p((405,440)),8.4,'gBk',.8)+circ(*R.p((405,440)),2.4,'gCh',.6)
for g,c in (('z0',z0),('z1',z1),('z2',''),('z3','')): set_group('../canvas/project/BMX.dc.html',g,c)
overlay(PH,R,[(seat,'lime'),(stem,'cyan')],'/private/tmp/claude-501/refs/ov10.png')
