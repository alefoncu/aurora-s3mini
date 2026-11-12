package com.scratch.wheelie;

import android.app.Activity;
import android.os.Bundle;
import android.content.SharedPreferences;
import android.graphics.*;
import android.view.*;
import java.util.HashMap;

public class GameActivity extends Activity {
    private RideView game;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        game = new RideView(); setContentView(game);
    }
    @Override protected void onPause() { super.onPause(); game.suspend(); }
    @Override protected void onResume() { super.onResume(); game.resume(); }
    @Override protected void onDestroy() { game.sound.close(); super.onDestroy(); }
    @Override public void onBackPressed() { game.back(); }

    private class RideView extends View {
        final Paint p = new Paint(3);
        final Typeface regular = Typeface.create("sans-serif",Typeface.NORMAL);
        final Typeface boldFace = Typeface.create("sans-serif",Typeface.BOLD);
        final Path path = new Path();
        final RectF rect = new RectF();
        final BikePhysics bike = new BikePhysics();
        final RunProgress progress = new RunProgress();
        final EngineSound sound = new EngineSound();
        final SharedPreferences prefs = getSharedPreferences("ride", 0);
        final HashMap<Integer,Integer> fingers = new HashMap<Integer,Integer>();
        final int ink=Color.rgb(27,57,60), cream=Color.rgb(255,246,221), gold=Color.rgb(247,189,79);
        final int[] colors = {0xffe76943, 0xff56c1b0, 0xffe9b845, 0xffa4a2e6};
        int state=0, color, route, vehicle; // garage, riding, paused, result, falling
        final String[] vehicles={"TRAIL 125", "STREET 250", "BMX"};
        final String[] traits={"Ágil y equilibrada", "Más velocidad, más peso", "Ligera y fácil de levantar"};
        boolean audio;
        boolean active=true, obstacles=true;
        boolean hitCone;
        long lastTime;
        float scale=1, cam, runTime, record, recordWheelie, crashTime;
        int totalCoins, highScore;
        static final float WORLD=42;
        final Runnable frame = new Runnable() { public void run() {
            if (!active) return;
            long now=System.nanoTime();
            float dt=lastTime==0 ? 0 : Math.min(.05f,(now-lastTime)/1e9f);
            lastTime=now;
            boolean redraw=state==1||state==4;
            if(state==1) {
                // Small fixed substeps make torque and collision behavior stable at 30 fps.
                int n=Math.max(1,(int)Math.ceil(dt/.008f));
                for(int i=0;i<n;i++) {
                    float previousX=bike.x+1.76f*(float)Math.cos(bike.angle);
                    bike.update(dt/n,held(3),held(0),held(1),held(2));
                    float frontX=bike.x+1.76f*(float)Math.cos(bike.angle);
                    if(obstacles && RunProgress.hitsCone(previousX,frontX,bike.angle,bike.speed)) {bike.crashed=true;hitCone=true;break;}
                }
                runTime+=dt;
                progress.update(dt,bike.distance,bike.speed,bike.angle,bike.wheelieDistance,bike.bestWheelie,bike.finished);
                sound.set(bike.speed,held(3),vehicle);
                if(bike.crashed) {state=4;crashTime=0;fingers.clear();sound.pause();}
                else if(bike.finished) finishRun();
            } else if(state==4) {
                crashTime+=dt;
                if(crashTime>.85f)finishRun();
            }
            if(redraw) invalidate(); postDelayed(this, 33);
        }};
        RideView() {
            super(GameActivity.this); setFocusable(true);
            color=prefs.getInt("color",0); route=prefs.getInt("route",0);
            record=prefs.getFloat("record",0); recordWheelie=prefs.getFloat("wheelie",0);
            totalCoins=prefs.getInt("coins",0); obstacles=prefs.getBoolean("obstacles",true);
            vehicle=Math.max(0,Math.min(2,prefs.getInt("vehicle",0)));audio=prefs.getBoolean("audio",true);
            highScore=prefs.getInt("score",0);
        }
        void resume() { active=true; lastTime=0; removeCallbacks(frame); post(frame); invalidate(); }
        void suspend() { active=false; removeCallbacks(frame); fingers.clear(); sound.pause(); if(state==1)state=2; }
        void back() { fingers.clear(); if(state==1){state=2;sound.pause();} else if(state==2){state=1;sound.setEnabled(audio);lastTime=0;} else if(state==3)state=0; else if(state!=4)GameActivity.this.finish(); invalidate(); }
        boolean held(int id) { return fingers.containsValue(id); }
        void start() { bike.setProfile(vehicle);bike.reset();progress.reset();runTime=0;hitCone=false;fingers.clear();state=1;lastTime=0;sound.setEnabled(audio); }
        void finishRun() {
            state=3; fingers.clear();sound.pause();
            record=Math.max(record,bike.distance); recordWheelie=Math.max(recordWheelie,bike.bestWheelie);
            totalCoins+=progress.earned;highScore=Math.max(highScore,(int)progress.score);
            prefs.edit().putFloat("record",record).putFloat("wheelie",recordWheelie).putInt("coins",totalCoins).putInt("score",highScore).apply();
        }
        int c(String s) { return Color.parseColor(s); }
        void fill(int color) { p.setColor(color); p.setStyle(Paint.Style.FILL); p.setStrokeWidth(1); }
        void box(Canvas g,float x,float y,float w,float h,float r,int col) { fill(col);rect.set(x,y,x+w,y+h);g.drawRoundRect(rect,r,r,p); }
        void line(Canvas g,float a,float b,float x,float y,float width,int col) { fill(col);p.setStrokeWidth(width);p.setStrokeCap(Paint.Cap.ROUND);g.drawLine(a,b,x,y,p); }
        void circle(Canvas g,float x,float y,float r,int col) { fill(col);g.drawCircle(x,y,r,p); }
        void text(Canvas g,String s,float x,float y,float size,int col,boolean bold) {
            fill(col);p.setTypeface(bold?boldFace:regular);p.setTextSize(size);g.drawText(s,x,y,p);
        }
        void centered(Canvas g,String s,float x,float y,float size,int col,boolean bold) {
            p.setTypeface(bold?boldFace:regular);p.setTextSize(size);
            text(g,s,x-p.measureText(s)/2,y,size,col,bold);
        }
        @Override protected void onDraw(Canvas g) {
            scale=Math.min(getWidth()/800f,getHeight()/480f);
            g.drawColor(ink);g.save();g.translate((getWidth()-800*scale)/2,(getHeight()-480*scale)/2);g.scale(scale,scale);
            cam=state==0?0:bike.x*WORLD;
            scenery(g);
            if(state==0) garage(g); else {
                road(g);
                float gy=groundY(bike.x);
                if(route==1){path.reset();path.moveTo(298,gy-55);path.lineTo(580,gy-34);path.lineTo(510,gy+5);path.close();fill(0x24fff3b5);g.drawPath(path,p);}
                fill(0x26334135);g.drawOval(207,gy-2,312,gy+8,p);
                if(bike.speed>3)for(int k=0;k<5;k++){float phase=(runTime*2+k*.21f)%1;circle(g,222-phase*72,gy-4-phase*11,2+phase*4,route==1?0x338b947e:0x55eee0bd);}
                if(state==4){drawBike(g,230+crashTime*50,gy-16,1.45f,bike.angle+crashTime*2);centered(g,hitCone?"¡CONO!":"¡TE HAS PASADO!",400,204,25,cream,true);}
                else drawBike(g,230,gy-16,1.45f,bike.angle);
                hud(g); controls(g);
                if(state==2) pause(g);
                if(state==3) results(g);
            }
            g.restore();
        }
        float groundY(float meters) { return 345-BikePhysics.ground(meters)*30; }
        void scenery(Canvas g) {
            boolean night=route==1;
            g.drawColor(night?0xff152c46:0xffb8dfdc);
            circle(g,641,91,35,night?0xfff3e8bc:0xffffe7a5);
            if(night) { for(int i=0;i<30;i++)circle(g,(i*103+19)%800,(i*37)%185+15,1.2f,0xffc3d4db); }
            else {
                for(int i=-1;i<5;i++) {
                    float x=i*250-(cam*.09f)%250;
                    box(g,x,57+i%2*25,97,14,8,0xffe9f3df);
                    box(g,x+25,45+i%2*25,45,22,12,0xffe9f3df);
                }
            }
            for(int layer=0;layer<2;layer++) {
                path.reset();path.moveTo(-10,480);
                for(int x=-10;x<=810;x+=12) {
                    float y=245+layer*51+(float)Math.sin((x+cam*(.09f+layer*.12f))/160)*33+(float)Math.cos((x+cam*.16)/90)*13;
                    path.lineTo(x,y);
                }
                path.lineTo(810,480);path.close();fill(night?(layer==0?0xff294757:0xff365958):(layer==0?0xff8db9a0:0xff70a58a));g.drawPath(path,p);
            }
            // Sparse trees and farm houses move slower than the road.
            for(int i=-1;i<7;i++) {
                float x=i*180-(cam*.42f)%180;
                line(g,x,260,x,315,5,night?0xff304a4a:0xff50775d);
                circle(g,x,258,24,night?0xff2d5653:0xff579578);
                circle(g,x-15,271,17,night?0xff2d5653:0xff579578);
            }
            float house=650-(cam*.25f)%1100;
            box(g,house,263,83,49,2,night?0xff3b555a:0xffeee4c2);
            path.reset();path.moveTo(house-9,266);path.lineTo(house+39,232);path.lineTo(house+93,266);path.close();fill(night?0xff273e4d:0xffb7775b);g.drawPath(path,p);
            box(g,house+14,280,15,32,1,night?0xffc1ad77:0xff698c84);box(g,house+50,278,19,16,1,night?0xffe3c681:0xff94c4ba);
            for(int i=-1;i<5;i++){float x=i*290-(cam*.55f)%290;line(g,x,210,x,327,3,night?0xff314b50:0xff617e6d);line(g,x-17,224,x+17,224,3,night?0xff314b50:0xff617e6d);line(g,x,215,x+290,215,1,night?0xff39555e:0xff7f9d8d);}
        }
        void road(Canvas g) {
            path.reset();path.moveTo(-10,490);
            for(int px=-10;px<=810;px+=8)path.lineTo(px,groundY(bike.x+(px-230)/WORLD));
            path.lineTo(810,490);path.close();fill(route==1?0xff6e7161:0xffd7bb86);g.drawPath(path,p);
            for(int px=-8;px<808;px+=8) {
                float a=groundY(bike.x+(px-230)/WORLD), b=groundY(bike.x+(px+8-230)/WORLD);
                line(g,px,a,px+8,b,5,route==1?0xff95a774:0xffedf0bd);
            }
            for(int i=-1;i<16;i++) {
                float x=i*65-cam%65;
                float gy=groundY(bike.x+(x-230)/WORLD);
                line(g,x,gy+30,x+15,gy+30,2,route==1?0xff7f806a:0xffbba277);
            }
            float begin=bike.x-6,end=bike.x+14;
            for(int m=Math.max(80,(int)(begin/80)*80);m<end+80;m+=80) {
                if(m<begin || m>end)continue;
                float x=230+(m-bike.x)*WORLD,y=groundY(m)-55;
                if(m>bike.x+.8) {circle(g,x,y,10,gold);centered(g,"+",x,y+5,16,ink,true);}
            }
            if(obstacles) for(int m=65;m<1230;m+=90) {
                if(m<begin||m>end)continue;
                float x=230+(m+.45f-bike.x)*WORLD,y=groundY(m);
                path.reset();path.moveTo(x-18,y);path.lineTo(x,y-18);path.lineTo(x+18,y);path.close();fill(0xffe8794f);g.drawPath(path,p);
                line(g,x-6,y-9,x+6,y-9,3,cream);
            }
            for(int m=250;m<=1200;m+=250){if(m<begin||m>end)continue;float x=230+(m-bike.x)*WORLD,y=groundY(m);line(g,x,y,x,y-64,3,ink);box(g,x-27,y-79,54,26,4,cream);centered(g,m+" m",x,y-61,12,ink,true);}
            if(bike.x>1184){float x=230+(1200-bike.x)*WORLD,y=groundY(1200);line(g,x,y,x,y-135,4,ink);for(int a=0;a<4;a++)for(int b=0;b<3;b++)box(g,x+a*12,y-135+b*12,12,12,0,(a+b)%2==0?cream:ink);}
        }
        void wheel(Canvas g,float x,float y,float r) {
            circle(g,x,y,r,0xff263b3d);circle(g,x,y,r-4,0xffe6d9b8);circle(g,x,y,r-7,0xff536666);
            float rot=-bike.x*2.94f;
            for(int j=0;j<6;j++){float a=rot+j*(float)Math.PI/3;line(g,x,y,x+(float)Math.cos(a)*(r-6),y+(float)Math.sin(a)*(r-6),1,0xffdddfce);}
            circle(g,x,y,3,cream);
        }
        void drawBike(Canvas g,float x,float y,float zoom,float angle) {
            g.save();g.translate(x,y);g.scale(zoom,zoom);g.rotate(-(angle+(state==0?0:(float)Math.atan(BikePhysics.slope(bike.x)*30/WORLD)))*57.2958f);
            wheel(g,0,0,11);wheel(g,51,0,11);
            line(g,0,0,19,-20,4,colors[color]);line(g,19,-20,35,-4,4,colors[color]);line(g,35,-4,0,0,4,colors[color]);
            line(g,35,-4,43,-29,3,cream);line(g,43,-29,51,0,4,0xffb7c7bc);
            if(vehicle!=2){
                box(g,vehicle==1?15:20,-29,vehicle==1?30:21,13,5,colors[color]);
                circle(g,26,-10,7,0xff8a9a90);line(g,22,-13,30,-13,1,cream);line(g,22,-10,30,-10,1,cream);
                line(g,7,-5,24,-5,5,0xffa7b7ae);line(g,4,-12,19,-12,5,ink);
                line(g,vehicle==1?3:0,-18,vehicle==1?14:10,-19,3,colors[color]);
                line(g,44,-14,55,-12,3,colors[color]);circle(g,45,-29,3,cream);
            }else{circle(g,23,-4,4,cream);line(g,23,-4,29,1,2,ink);line(g,28,1,32,1,3,ink);}
            line(g,9,-28,25,-28,5,ink);line(g,39,-31,46,-31,3,ink);
            line(g,18,-19,13,-7,2,cream);
            // Articulated rider: boots, bent legs, jacket, arms and helmet.
            line(g,22,-8,11,-21,6,ink);line(g,11,-21,17,-38,7,0xff354d63);
            float lean=state==0?0:held(1)?-4:held(2)?5:0;
            line(g,17,-38,22+lean,-56,13,route==1?0xffd6c7a1:0xfff3edd8);
            line(g,22+lean,-51,34,-40,5,0xffe4ad82);line(g,34,-40,43,-31,4,0xffe4ad82);
            circle(g,24+lean,-66,11,colors[color]);box(g,26+lean,-70,12,6,2,ink);line(g,19+lean,-73,27+lean,-76,2,cream);
            line(g,20,-7,26,-7,3,ink);
            g.restore();
        }
        void button(Canvas g,String label,float x,float y,float w,float h,int bg,int fg) {
            box(g,x,y,w,h,12,bg);centered(g,label,x+w/2,y+h/2+6,18,fg,true);
        }
        void garage(Canvas g) {
            if(route==1)box(g,20,16,360,451,18,0xeafff6dd);
            text(g,"TALLER  /  02",38,39,12,ink,true);
            text(g,"WHEELIE",35,108,61,ink,true);text(g,"RIDE",37,164,61,ink,true);
            text(g,"El equilibrio lo es todo.",40,195,17,ink,false);
            text(g,"ACELERA · LEVANTA · MANTÉN",40,224,11,ink,true);
            box(g,40,250,320,60,12,0xeafff6dd);
            text(g,"RÉCORD",56,272,10,ink,true);text(g,Math.round(record)+" m",56,297,22,ink,true);
            text(g,"MEJOR CABALLITO",188,272,10,ink,true);text(g,Math.round(recordWheelie)+" m",188,297,22,ink,true);
            // Hero motorbike sits on a small platform.
            centered(g,vehicles[vehicle],599,38,21,route==1?cream:ink,true);centered(g,traits[vehicle],599,59,12,route==1?cream:ink,false);
            box(g,442,267,299,7,4,ink);drawBike(g,515,250,2.25f,.23f);
            for(int i=0;i<3;i++){box(g,443+i*107,282,100,31,8,vehicle==i?ink:cream);centered(g,new String[]{"TRAIL","STREET","BMX"}[i],493+i*107,302,12,vehicle==i?cream:ink,true);}
            text(g,"COLOR",445,335,11,route==1?cream:ink,true);
            for(int i=0;i<4;i++) {circle(g,514+i*40,331,i==color?15:12,cream);circle(g,514+i*40,331,10,colors[i]);}
            button(g,route==0?"☀  CAMPO":"LUNA  /  NOCHE",443,357,151,43,cream,ink);
            button(g,obstacles?"CON CONOS":"PRÁCTICA",604,357,153,43,cream,ink);
            button(g,"SALIR A RODAR  →",40,337,320,63,ink,cream);
            button(g,audio?"SONIDO: SÍ":"SONIDO: NO",40,416,151,40,cream,ink);
            text(g,highScore+" pts · "+totalCoins+" monedas",205,441,12,ink,true);
            text(g,"GAS + LEVANTAR para hacer un caballito",443,431,12,route==1?cream:ink,true);
            text(g,"Suelta LEVANTAR y corrige con BAJAR o FRENO.",443,451,11,route==1?cream:ink,false);
        }
        void hud(Canvas g) {
            box(g,20,18,334,65,13,0xeafff6dd);
            text(g,"DISTANCIA",36,38,10,ink,true);text(g,Math.round(bike.distance)+" m",36,66,25,ink,true);
            text(g,"VELOCIDAD",159,38,10,ink,true);text(g,Math.round(bike.speed*3.6f)+" km/h",159,65,23,ink,true);
            button(g,"Ⅱ",724,18,56,51,cream,ink);
            float a=bike.angle;
            box(g,374,18,202,49,12,0xeafff6dd);text(g,"EQUILIBRIO",388,35,10,ink,true);
            box(g,388,45,174,7,3,0xffcccfb8);box(g,433,45,77,7,3,0xff91ba83);
            circle(g,388+Math.min(1,a/1.55f)*174,48,6,ink);
            box(g,586,18,125,65,13,0xeafff6dd);
            text(g,(int)progress.score+" pts",596,40,18,ink,true);text(g,"×"+progress.combo+"  /  "+progress.earned+" monedas",596,61,11,ink,true);
            box(g,20,91,220,38,9,0xdffff6dd);
            String goal=(progress.missions&2)==0?"OBJETIVO: 25 m de caballito":(progress.missions&1)==0?"OBJETIVO: recorre 250 m":"OBJETIVO: llega a 1.200 m";
            text(g,goal,31,107,11,ink,true);
            float fraction=(progress.missions&2)==0?Math.min(1,bike.bestWheelie/25):(progress.missions&1)==0?Math.min(1,bike.distance/250):bike.distance/1200;
            box(g,31,116,197,4,2,0xffced1b8);box(g,31,116,197*fraction,4,2,0xff6e9e78);
            box(g,266,91,514,4,2,0x55708e81);box(g,266,91,514*bike.distance/1200,4,2,gold);
            if(a>.22f && bike.speed>1) {
                centered(g,"CABALLITO  ×"+progress.combo,495,126,17,route==1?cream:ink,true);
                centered(g,Math.round(bike.wheelieDistance)+" m",495,157,28,route==1?cream:ink,true);
            } else if(bike.x<35) centered(g,"GAS para rodar · LEVANTAR para el caballito",490,128,13,route==1?cream:ink,true);
            if(bike.angle>1.15f&&state==1){box(g,334,174,324,34,9,0xffbd533e);centered(g,"¡BAJA!  Estás perdiendo el equilibrio",496,196,14,cream,true);}
            else if(obstacles && bike.x>45 && (65-bike.x%90+90)%90<12)centered(g,"¡Levanta la rueda para pasar el cono!",490,188,15,ink,true);
            if(progress.noticeTime>0){box(g,276,216,440,38,10,gold);centered(g,progress.notice,496,241,15,ink,true);}
        }
        void controls(Canvas g) {
            String[] labels={"FRENO","LEVANTAR","BAJAR","GAS"};
            float[] xs={20,139,542,661};
            for(int i=0;i<4;i++) {
                box(g,xs[i],378,119-10,82,16,held(i)?gold:(i==3?ink:0xeafff6dd));
                String symbol=i==0?"−":i==1?"↶":i==2?"↷":"+";
                int fg=i==3&&!held(i)?cream:ink;
                centered(g,symbol,xs[i]+54,417,29,fg,true);centered(g,labels[i],xs[i]+54,443,11,fg,true);
            }
        }
        void dim(Canvas g) { fill(0xa6163035);g.drawRect(0,0,800,480,p); }
        void pause(Canvas g) {
            dim(g);box(g,212,99,376,282,22,cream);
            centered(g,"Un respiro",400,147,30,ink,true);
            centered(g,"Tu ruta sigue aquí.",400,177,15,ink,false);
            button(g,"CONTINUAR",244,201,312,52,ink,cream);
            button(g,"EMPEZAR DE NUEVO",244,264,312,43,gold,ink);
            centered(g,"VOLVER AL TALLER",400,349,13,ink,true);
        }
        void results(Canvas g) {
            dim(g);box(g,187,58,426,364,23,cream);
            centered(g,bike.finished?"¡Ruta completada!":"Cada intento cuenta",400,102,27,ink,true);
            centered(g,(int)progress.score+" pts",400,151,43,ink,true);
            centered(g,Math.round(bike.distance)+" m  ·  Caballito: "+Math.round(bike.bestWheelie)+" m  ·  +"+progress.earned+" monedas",400,184,15,ink,false);
            String[] goals={"250 m","Caballito 25 m","Meta"};int[] bits={1,2,4};
            for(int i=0;i<3;i++){box(g,211+i*128,199,122,24,7,(progress.missions&bits[i])!=0?0xffaaca98:0xffe5dcc4);centered(g,((progress.missions&bits[i])!=0?"✓ ":"○ ")+goals[i],272+i*128,216,11,ink,true);}
            centered(g,hitCone?"Levanta la rueda para superar los conos.":bike.crashed?"Corrige con BAJAR antes de volcar.":"Has recorrido los 1.200 metros.",400,238,14,ink,false);
            button(g,"OTRA RONDA  →",223,264,354,57,ink,cream);
            button(g,"VOLVER AL TALLER",223,337,354,48,0xffe9dec0,ink);
        }
        float localX(MotionEvent e,int i) {return (e.getX(i)-(getWidth()-800*scale)/2)/scale;}
        float localY(MotionEvent e,int i) {return (e.getY(i)-(getHeight()-480*scale)/2)/scale;}
        int control(float x,float y) {
            if(y<370||y>480)return -1;
            if(x<134)return 0;if(x<270)return 1;if(x>654)return 3;if(x>529)return 2;return -1;
        }
        @Override public boolean onTouchEvent(MotionEvent e) {
            int action=e.getActionMasked(),i=e.getActionIndex(),id=e.getPointerId(i);
            float x=localX(e,i),y=localY(e,i);
            if(action==MotionEvent.ACTION_CANCEL) {fingers.clear();return true;}
            if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_POINTER_UP) {fingers.remove(id);return true;}
            if(action==MotionEvent.ACTION_MOVE) {
                if(state==1)for(int j=0;j<e.getPointerCount();j++) {int hit=control(localX(e,j),localY(e,j));if(hit<0)fingers.remove(e.getPointerId(j));else fingers.put(e.getPointerId(j),hit);}
                return true;
            }
            if(action!=MotionEvent.ACTION_DOWN&&action!=MotionEvent.ACTION_POINTER_DOWN)return true;
            if(state==0) {
                if(x>=40&&x<=360&&y>=337&&y<=400)start();
                else if(x>=443&&x<=757&&y>=282&&y<=313){vehicle=Math.min(2,(int)((x-443)/107));prefs.edit().putInt("vehicle",vehicle).apply();}
                else if(x>=490&&x<=655&&y>=316&&y<=350){color=Math.max(0,Math.min(3,Math.round((x-514)/40)));prefs.edit().putInt("color",color).apply();}
                else if(x>=443&&x<=594&&y>=357&&y<=400){route=1-route;prefs.edit().putInt("route",route).apply();}
                else if(x>=604&&x<=757&&y>=357&&y<=400){obstacles=!obstacles;prefs.edit().putBoolean("obstacles",obstacles).apply();}
                else if(x>=40&&x<=191&&y>=416&&y<=456){audio=!audio;prefs.edit().putBoolean("audio",audio).apply();}
            } else if(state==1) {
                if(x>=714&&y<=78){state=2;fingers.clear();sound.pause();}
                else {int hit=control(x,y);if(hit>=0)fingers.put(id,hit);}
            } else if(state==2&&x>=244&&x<=556) {
                if(y>=201&&y<=253){state=1;lastTime=0;sound.setEnabled(audio);}
                else if(y>=264&&y<=307)start();else if(y>=325&&y<=370)state=0;
            } else if(state==3&&x>=223&&x<=577) {
                if(y>=264&&y<=321)start();else if(y>=337&&y<=385)state=0;
            }
            invalidate();return true;
        }
    }
}
