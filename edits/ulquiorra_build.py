import numpy as np, subprocess, sys
from PIL import Image
U="/root/.claude/uploads/7dbe55ae-06c5-5975-8bab-eea8e9ad71ce/"
SRC=U+"ece48de9-d5a08f3962dfaf4ef0e9743b9c824c33.mp4"; MUS=U+"3c926439-1fe8189e27f442718dd8f1134576898c.mp3"
FPS=30; W,H=960,720; OUT=720
# (song cut time, src start, speed, crop_x[0..240], ramp(start speed) or None, src shot end)
# every cut sits on a measured attack in the track: 808 note starts and lead-melody hits
# (intro 0-2.7, track empties 2.7-4.1, comes back at 4.10, drop at 4.96, fade from 12.3)
S=[
 (0.00,  0.40, 0.85,120,None,  5.13),  # low angle walk-in
 (0.76, 11.92, 1.00,150,None, 14.03),  # extreme eye close-up
 (1.63, 14.31, 1.00,160,None, 18.03),  # close-up purple bg
 (2.07,  5.90, 1.00,110,None,  7.80),  # side face, eye opens
 (2.55, 21.25, 0.80,120,None, 23.40),  # wide, looking up -> zoom in on him while the track empties
 (4.10, 20.10, 1.00,120,None, 21.20),  # his face close, on the return
 (4.40, 33.15, 1.00,120,None, 34.20),  # cero charges
 (4.65, 18.10, 1.00,100,None, 20.07),  # cero clash on face
 (4.96, 62.40, 1.00,120,None, 64.43),  # drop: resurreccion
 (5.79, 37.10, 1.00,120,None, 42.43),  # released face
 (6.04, 42.50, 1.00,120,None, 48.00),  # "4" torso
 (6.61, 52.85, 1.00,170,None, 56.70),  # blood streaks
 (6.92, 56.75, 1.00,120,3.0,  61.00),  # tilt up chest -> face (velocity)
 (7.34, 83.05, 1.00,120,None, 84.83),  # silhouette on the moon -> zoom in
 (7.89, 64.68, 1.00,120,None, 66.77),  # segunda etapa eyes (eye change lands on the 8.14 hit)
 (8.36, 69.10, 1.00,150,None, 70.63),  # head turn, horns
 (8.94, 70.70, 1.00,120,None, 75.50),  # full segunda etapa -> zoom in
 (9.42, 75.60, 1.00,140,None, 79.67),  # face close
 (9.67, 91.95, 1.00, 60,None, 94.07),  # cero oscuras
 (9.96, 79.75, 1.00,120,None, 82.83),  # eyes
 (10.37,86.90, 1.00,140,None, 88.17),  # hair turn
 (10.74,88.25, 1.00,140,None, 91.40),  # face in shadow
 (11.21,94.40, 1.00,120,None, 96.97),  # eyes close
 (11.70,114.75,1.00,120,None,119.40),  # hand / him behind
 (11.98,119.45,0.80,120,None,126.50),  # turning to ash, over the fade
]
END=12.95
# zoom copied from the user's own edit: the wide shot holds still, then in the last
# 6 frames the camera dives into his face (1x -> ~2.5x, slow-fast-settle, with zoom
# blur) and hard-cuts to the close-up on the beat.
# shot index -> (face x, face y in source px, final zoom)
ZOOM={4:(528,125,2.6), 13:(512,300,2.6), 16:(264,192,2.4)}
DIVE=[0.0,0.054,0.29,0.62,0.88,0.98,1.0]   # measured curve (log-zoom fraction per frame)
# last shot: slow push 1x -> 1.45x easing out, like the end of the user's edit
PUSH={24:(12.22,15,1.45)}
def zoom_at(i,cx,a,kf,n):
    base=(cx+OUT/2,H/2)
    if i in ZOOM:
        fx,fy,zm=ZOOM[i]; j=kf-(n-len(DIVE))
        if j<=0: return base,1.0
        lo=int(np.floor(j)); hi=min(lo+1,len(DIVE)-1); fr=j-lo
        p=DIVE[min(lo,len(DIVE)-1)]*(1-fr)+DIVE[hi]*fr
        z=zm**p; e=(z-1)/(zm-1)
        return (base[0]+(fx-base[0])*e, base[1]+(fy-base[1])*e), z
    if i in PUSH:
        t0,m,zm=PUSH[i]; u=(a+kf)/FPS-t0
        if u<=0: return base,1.0
        u=min(1,u*FPS/m); return base,1+(zm-1)*(1-(1-u)**3)
    return base,1.0
def render(img,c,z):
    w=OUT/z; x0=min(max(c[0]-w/2,0),W-w); y0=min(max(c[1]-w/2,0),H-w)
    return img.transform((OUT,OUT),Image.EXTENT,(x0,y0,x0+w,y0+w),Image.BICUBIC)
shots=[]
for i,(t0,s0,sp,cx,ramp,send) in enumerate(S):
    t1=S[i+1][0] if i+1<len(S) else END
    a=round(t0*FPS); b=round(t1*FPS); n=b-a
    idx=[]
    for k in range(n):
        u=k/n; d=k/FPS
        if ramp:  # smooth velocity: fast -> settles at sp (ease-out)
            D=n/FPS; x=u
            off=D*(sp*x + (ramp-sp)*(1-(1-x)**3)/3)
        else: off=sp*d
        idx.append(int(round((s0+off)*FPS)))
    assert idx[-1] < send*FPS-1, (i, idx[-1]/FPS, send)
    shots.append((a,b,cx,idx,i))
need={}
for a,b,cx,idx,_ in shots:
    for f in idx: need.setdefault(f,set()).add(cx)
dec=subprocess.Popen(["ffmpeg","-v","error","-i",SRC,"-f","rawvideo","-pix_fmt","rgb24","-"],stdout=subprocess.PIPE)
cache={}; f=0; mx=max(need)
while f<=mx:
    buf=dec.stdout.read(W*H*3)
    if len(buf)<W*H*3: break
    if f in need: cache[f]=np.frombuffer(buf,np.uint8).reshape(H,W,3)
    f+=1
dec.kill()
enc=subprocess.Popen(["ffmpeg","-v","error","-y","-f","rawvideo","-pix_fmt","rgb24","-s",f"{OUT}x{OUT}","-r",str(FPS),"-i","-",
  "-ss","0","-i",MUS,"-map","0:v","-map","1:a","-c:v","libx264","-preset","slow","-crf","16","-pix_fmt","yuv420p",
  "-c:a","aac","-b:a","192k","-shortest","-movflags","+faststart",sys.argv[1]],stdin=subprocess.PIPE)
for a,b,cx,idx,si in shots:
    n=len(idx)
    for k,fi in enumerate(idx):
        src=Image.fromarray(cache[fi])
        c,z=zoom_at(si,cx,a,k,n); cp,zp=zoom_at(si,cx,a,k-1,n)
        if si in ZOOM and z/zp>1.05:   # zoom blur on the fast frames only (settles sharp before the cut)
            acc=np.zeros((OUT,OUT,3),np.float32)
            for f in np.linspace(0,1,10):
                cc,zz=zoom_at(si,cx,a,k-1+f,n); acc+=np.asarray(render(src,cc,zz),np.float32)
            frame=(acc/10).astype(np.uint8)
        else: frame=np.asarray(render(src,c,z))
        enc.stdin.write(frame.tobytes())
enc.stdin.close(); enc.wait()
print("cuts at", [round(sh[0]/FPS,3) for sh in shots])
