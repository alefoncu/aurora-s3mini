"""Shared bodywork for the two supersports (Sport 600 and Hyper R 1000).
Tail, seat, tank, screen, fender, lamp and mirror keep the original trace (photo pixels through Ref).
Fairing, belly, engine and exhaust are drawn directly in game units (rear axle 0,0, y down, wheel radius 25)
so the engine shows below the fairing and each bike keeps its own exhaust:
  sport -> short side can above the swingarm; hyper -> underbelly exhaust, winglets and a lower nose."""
import sys; sys.path.insert(0,'..')
from trace import *

def build(kind):
    W=114 if kind=='hyper' else 110
    R=Ref((158,445),(806,480),W,lift=(15,45,9,12))
    def S(L,closed=True): return smooth(R.pts(L),closed)
    k=W/114
    def G(L,closed=True): return smooth([(x*k,y)+tuple(r) for x,y,*r in L],closed)
    def GL(L): return line([(x*k,y) for x,y in L])
    tail=[(45,127),(100,138),(160,165),(215,195),(300,235),(395,262),(385,275),(300,268),(240,245),(180,215),(120,180),(70,150),(46,134)]
    seat=[(215,172),(250,182),(310,205),(375,232),(410,248),(405,262),(340,250),(270,225),(225,198),(212,182)]
    hump=[(86,125),(150,126),(200,132),(228,150),(220,170),(190,178),(140,170),(95,148)]
    tank=[(388,225),(398,190),(430,160),(485,143),(555,145),(605,160),(635,185),(625,205),(560,215),(470,225)]
    screen=[(672,95),(705,85),(742,112),(790,150),(740,150),(700,140)]
    spar=[(400,262),(520,205),(560,208),(430,300),(400,330)]
    fender=[(680,395),(700,372),(745,355),(810,350),(865,362),(885,385),(850,378),(800,372),(750,380),(705,400)]
    lamp=[(805,215),(835,225),(840,248),(812,250)]
    mirror=[(712,28),(747,35),(748,68),(722,70)]
    stalk=[(735,100),(738,65)]

    # engine: inline four, cylinders tilted forward, crankcase and sump visible under the fairing
    crank=[(40,-27),(70,-29),(78,-21,1),(77,-7),(69,0),(47,0),(39,-8,1)]
    cyl=[(56,-27),(60,-47),(80,-52),(81,-29)]
    cover=[(46,-18),(52,-21),(58,-18),(58,-11),(52,-8),(46,-11)]
    fins=GL([(62,-32),(78,-35)])+GL([(61,-37),(79,-40)])+GL([(60,-42),(80,-45)])
    z0=panel(G(cyl),'gMd')+stroke(fins,.6,'#2A343A',.8)+panel(G(crank),'gMd')+panel(G(cover),'gMe',.7)+panel(S(spar),'gMe')

    if kind=='hyper':
        headers=GL([(80,-33),(85,-21),(83,-8),(74,2),(60,5)])
        box=[(41,-1),(64,-1),(70,3),(66,9),(44,9),(39,5)]
        tip=[(36,1),(42,0),(43,7),(37,7)]
        ex=pipe(headers,3.2)+panel(G(box),'gDk')+panel(G(tip),'gCh',.7)
    else:
        link=smooth([(66*k,1),(48*k,6),(30*k,4),(19*k,-4)],False)
        can=[(22,-3),(25,-9),(5,-23),(-1,-22),(-2,-16),(3,-12)]
        cap=[(5,-23),(0,-25),(-4,-21),(-1,-16),(-2,-16),(-1,-22)]
        ex=pipe(link,3)+panel(G(can),'gCh')+panel(G(cap),'gDk',.7)
    z1=ex+panel(S(tail),'gP')+panel(S(seat),'gSeat')+panel(S(hump),'gSeat')+panel(S(tank),'gP')

    # upper fairing: nose, side panel ending at the knee, open below so the engine shows
    nose_y=-45 if kind=='hyper' else -47
    fair=[(117,nose_y-1),(115,-56),(109,-66),(99,-72),(88,-69),(78,-58),(71,-50),(65,-42),(61,-34,1),
          (70,-32),(80,-30),(89,-28),(96,-31),(103,-37),(110,nose_y+3),(116,nose_y+2)]
    vent=[(72,-45),(84,-41),(93,-39),(87,-36),(74,-39)]
    stripe=GL([(66,-38),(80,-35),(96,-35),(108,nose_y)])
    lower=[(80,-31),(92,-30),(95,-22),(90,-10),(84,-2),(74,4),(62,6),(58,2),(66,-4),(73,-14),(76,-25)]
    lip=[(62,6),(74,4),(84,-2),(83,1),(74,7),(63,8)]
    z2=panel(S(fender),'gBk' if kind=='hyper' else 'gP')+panel(S(screen),'gGlass',.8,.9)
    z2+=panel(G(lower),'gP',.95)+panel(G(lip),'gBk',.7)+panel(G(fair),'gP',.95)+panel(G(vent),'gBk',.7)
    z2+=stroke(stripe,.8,'#FFFFFF',.55)
    if kind=='hyper':
        wing=[(97,-49),(110,-48),(113,-45),(99,-45)]
        wing2=[(95,-43),(106,-42),(108,-40),(96,-40)]
        z2+=panel(G(wing),'gBk',.7)+panel(G(wing2),'gBk',.7)
    z2+=panel(S(lamp),'gDk',.8)+tube(line(R.pts(stalk)),1.6,'#39454D')+panel(S(mirror),'gDk',.8)
    return z0,z1,z2

def write(kind,board):
    z0,z1,z2=build(kind)
    for g,c in (('z0',z0),('z1',z1),('z2',z2)): set_group('../canvas/project/'+board,g,c)
