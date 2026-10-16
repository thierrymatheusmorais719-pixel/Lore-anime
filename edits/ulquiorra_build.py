import numpy as np, subprocess, sys
U="/root/.claude/uploads/7dbe55ae-06c5-5975-8bab-eea8e9ad71ce/"
SRC=U+"ece48de9-d5a08f3962dfaf4ef0e9743b9c824c33.mp4"; MUS=U+"7737a87a-d8c3c56779be64e26911ffc4aeab1b90.mp3"
FPS=30; W,H=960,720; OUT=720
# (song cut time, src start, speed, crop_x[0..240], ramp(start speed) or None, src shot end)
# cuts sit on the 808 hits / accents found in the track (136 BPM, 3-3-2 bass pattern)
S=[
 (0.00,  0.40, 0.85,120,None,  5.13),  # low angle walk-in (slight slow)
 (1.51, 11.92, 1.00,150,None, 14.03),  # extreme eye close-up on first 808
 (2.41,  5.40, 1.00,110,None,  7.80),  # side face, eye opens
 (3.75, 14.20, 1.00,160,None, 18.03),  # close-up purple bg
 (4.64, 26.00, 1.00,120,2.2,  29.57),  # chest-hole tilt (velocity)
 (5.76, 31.40, 1.00,120,None, 33.10),  # raises hand
 (6.92, 33.15, 1.00,120,None, 34.20),  # cero charges
 (7.77, 18.10, 1.00,100,None, 20.07),  # cero clash on face
 (8.66, 35.20, 1.00, 40,None, 36.97),  # walks out of dust
 (9.56, 21.25, 0.80,140,None, 23.40),  # wide, purple sky (slow)
 (10.89,62.40, 1.00,120,None, 64.43),  # resurreccion - big hit
 (12.23,37.10, 1.00,120,None, 42.43),  # released face
 (13.51,42.50, 1.00,120,None, 48.00),  # "4" torso
 (14.45,48.05, 1.00,120,None, 49.40),  # stare
 (15.35,52.85, 1.00,170,None, 56.70),  # blood streaks
 (15.80,56.75, 1.00,120,2.0,  61.00),  # tilt up chest -> face (velocity)
 (17.15,83.05, 1.00,120,None, 84.83),  # silhouette on the moon
 (18.03,64.62, 1.00,120,None, 66.77),  # segunda etapa eyes
 (19.38,69.10, 1.00,150,None, 70.63),  # head turn, horns
 (20.72,70.70, 1.00,120,None, 75.50),  # full segunda etapa
 (21.22,75.60, 1.00,140,None, 79.67),  # face close
 (21.61,91.95, 1.00, 60,None, 94.07),  # cero oscuras
 (22.94,79.75, 1.00,120,None, 82.83),  # eyes
 (23.70,86.40, 1.00,140,None, 88.17),  # hair turn
 (24.30,94.40, 1.00,120,None, 96.97),  # eyes close (break)
 (24.75,88.25, 0.80,140,None, 91.40),  # drop -> calm part (slow)
 (26.08,101.45,1.00,120,None,103.67),  # chest hole frontal
 (27.41,103.75,0.85,120,None,107.00),  # night
 (28.75,107.05,1.00,120,None,110.37),  # arm reaching
 (30.10,111.25,0.65,120,None,112.17),  # hands almost touch (slow)
 (31.44,112.42,0.70,120,None,113.20),  # her hand (slow)
 (32.33,114.75,0.75,120,None,119.40),  # hand / him behind (slow)
 (34.56,119.45,1.00,120,None,126.50),  # turning to ash
 (37.23,126.55,0.85,120,None,129.40),  # aftermath
]
END=39.30
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
    shots.append((a,b,cx,idx))
need={}
for a,b,cx,idx in shots:
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
for a,b,cx,idx in shots:
    for fi in idx:
        enc.stdin.write(np.ascontiguousarray(cache[fi][:,cx:cx+OUT]).tobytes())
enc.stdin.close(); enc.wait()
print("cuts at", [round(a/FPS,3) for a,_,_,_ in shots])
