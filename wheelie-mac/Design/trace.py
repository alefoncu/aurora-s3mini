"""Tracing helpers: draw a vehicle body over a reference photo.
Points are given in PHOTO PIXELS; Ref converts them to the game's units (rear axle at 0,0, y down), levelling the
photo so both axles share a height. Paths are Catmull-Rom smooth with optional corners; output is SVG path data."""
import math,re
INK='#141B20'
class Ref:
    def __init__(self,rear,front,wheelbase,lift=(15,45,0,0)):
        self.lift=lift; self.W=wheelbase
        self.a=rear; dx,dy=front[0]-rear[0],front[1]-rear[1]
        self.flip=dx<0
        if self.flip: dx=-dx
        self.al=math.atan2(dy,dx); self.k=wheelbase/math.hypot(dx,dy); self.c=math.cos(self.al); self.s=math.sin(self.al)
    def p(self,pt,lift=True):
        dx,dy=pt[0]-self.a[0],pt[1]-self.a[1]
        if self.flip: dx=-dx
        x=(dx*self.c+dy*self.s)*self.k; y=(-dx*self.s+dy*self.c)*self.k
        y0,y1,a,b=self.lift; up=-y; t=max(0,min(1,(up-y0)/(y1-y0))) if y1>y0 else 0
        u=max(0,min(1,(x-25)/(0.8*self.W-25))); d=a+(b-a)*u
        return (x,y-d*t) if lift else (x,y)
    def rad(self,L,axle_px,s):
        c=self.p(axle_px,False); out=[]
        for q in L:
            x,y=self.p(q[:2],False); out.append((c[0]+(x-c[0])*s,c[1]+(y-c[1])*s)+((1,) if len(q)>2 and q[2] else ()))
        return out
    def pts(self,L): return [self.p(q[:2])+((1,) if len(q)>2 and q[2] else ()) for q in L]
def f(v): return f'{v:.2f}'.rstrip('0').rstrip('.') if '.' in f'{v:.2f}' else f'{v:.2f}'
def smooth(P,closed=True):
    n=len(P)
    def tan(i):
        if len(P[i])>2: return (0,0)
        a=P[(i-1)%n] if closed else P[max(0,i-1)]; b=P[(i+1)%n] if closed else P[min(n-1,i+1)]
        return ((b[0]-a[0])/2,(b[1]-a[1])/2)
    d=f'M{f(P[0][0])} {f(P[0][1])}'
    for i in range(n if closed else n-1):
        j=(i+1)%n; t0=tan(i); t1=tan(j)
        d+=f'C{f(P[i][0]+t0[0]/3)} {f(P[i][1]+t0[1]/3)} {f(P[j][0]-t1[0]/3)} {f(P[j][1]-t1[1]/3)} {f(P[j][0])} {f(P[j][1])}'
    return d+('Z' if closed else '')
def poly(P): return 'M'+'L'.join(f'{f(p[0])} {f(p[1])}' for p in P)+'Z'
def line(P): return 'M'+'L'.join(f'{f(p[0])} {f(p[1])}' for p in P)
# SVG element builders
def panel(d,fill,sw=.9,op=1): return f'<path d="{d}" fill="url(#{fill})" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round"'+(f' opacity="{op}"' if op!=1 else '')+'/>'
def tube(d,w,core='#47535A'): return f'<path d="{d}" stroke="#12191D" stroke-width="{w+1.7:g}" fill="none" stroke-linecap="round"/><path d="{d}" stroke="{core}" stroke-width="{w:g}" fill="none" stroke-linecap="round"/>'
def pipe(d,w=4): return f'<path d="{d}" stroke="#12191D" stroke-width="{w+1.8:g}" fill="none" stroke-linecap="round"/><path d="{d}" stroke="#B9C2C6" stroke-width="{w:g}" fill="none" stroke-linecap="round"/><path d="{d}" stroke="#FFFFFF" stroke-width=".9" fill="none" stroke-linecap="round" opacity=".8" transform="translate(-.6 -.8)"/>'
def stroke(d,w,c,op=1): return f'<path d="{d}" stroke="{c}" stroke-width="{w:g}" fill="none" stroke-linecap="round"'+(f' opacity="{op}"' if op!=1 else '')+'/>'
def circ(x,y,r,fill,sw=.7): return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="url(#{fill})" stroke="{INK}" stroke-width="{sw}"/>'
def set_group(path,gid,content):
    s=open(path).read(); s=re.sub(r'<g id="'+gid+r'">[\s\S]*?</g>','<g id="'+gid+'">\n'+content+'\n</g>',s,count=1); open(path,'w').write(s)
def overlay(photo,ref,shapes,out,scale=1):
    """shapes: list of point lists in photo px (closed polylines) drawn on the photo for alignment checks."""
    from PIL import Image,ImageDraw
    im=Image.open(photo).convert('RGB'); d=ImageDraw.Draw(im)
    for L,col in shapes: d.line([q[:2] for q in L]+[L[0][:2]],fill=col,width=2)
    for pt in (ref.a,):
        d.ellipse([pt[0]-5,pt[1]-5,pt[0]+5,pt[1]+5],outline='red',width=2)
    im.save(out)
