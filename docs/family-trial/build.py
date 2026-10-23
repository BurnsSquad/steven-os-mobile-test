from pathlib import Path
import html,json,hashlib,base64,textwrap
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
p=Path('work/family-trial');W,H=800,1100
pdfmetrics.registerFont(TTFont('D','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('DB','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))
p.mkdir(parents=True,exist_ok=True)
c=canvas.Canvas(str(p/'first-week.pdf'),pagesize=(W,H));c.setTitle('Burns Base | First family trial and feedback')
ink='#173F39';green='#235E51';mint='#DCEBE0';cream='#F6F5ED';gold='#E9BD66';blue='#DDE9F4';gray='#527169';s=[]
def rect(x,y,w,h,fill,r=18):
 c.setFillColor(fill);c.roundRect(x,H-y-h,w,h,r,stroke=0,fill=1);s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"/>')
def text(x,y,txt,size=15,b=False,color=ink,width=680):
 font='DB' if b else 'D'; words=txt.split();lines=[];line=''
 for word in words:
  test=(line+' '+word).strip()
  if pdfmetrics.stringWidth(test,font,size)>width and line:lines.append(line);line=word
  else:line=test
 lines.append(line)
 for i,l in enumerate(lines):
  yy=y+i*size*1.45;c.setFillColor(color);c.setFont(font,size);c.drawString(x,H-yy-size,l)
  s.append(f'<text x="{x}" y="{yy+size}" font-family="DejaVu Sans, sans-serif" font-size="{size}" font-weight="{700 if b else 400}" fill="{color}">{html.escape(l)}</text>')
 return y+len(lines)*size*1.45

def line(x,y,x2,y2,color=green,thick=3):
 c.setStrokeColor(color);c.setLineWidth(thick);c.line(x,H-y,x2,H-y2);s.append(f'<path d="M{x} {y} L{x2} {y2}" stroke="{color}" stroke-width="{thick}"/>')
def circle(x,y,r,fill):
 c.setFillColor(fill);c.circle(x,H-y,r,stroke=0,fill=1);s.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"/>')
def badge(x,y,label,fill=green):
 rect(x,y,29+pdfmetrics.stringWidth(label,'DB',11),28,fill,14);text(x+14,y+6,label,11,True,'#FFFFFF')
def page(n,tag,title,sub):
 global s
 s=['<svg xmlns="http://www.w3.org/2000/svg" width="800" height="1100" viewBox="0 0 800 1100">'];rect(0,0,W,H,cream,0);rect(0,0,W,10,green,0)
 text(44,36,'BURNS BASE  /  '+tag,11,True,gray);text(44,75,title,37,True);text(44,135,sub,16,width=705)
 text(44,1060,'OCT 17, 2026  •  FIRST FAMILY TRIAL',10,color=gray);text(700,1060,f'{n} / 2',10,color=gray)
def finish(n):
 s.append('</svg>');(p/f'page-{n}.svg').write_text(''.join(s));c.showPage()
def card(x,y,w,h,title,body,fill='#FFFFFF',num=None):
 rect(x,y,w,h,fill)
 if num:circle(x+29,y+31,16,green);text(x+20,y+20,num,15,True,'#FFFFFF');tx=x+56
 else:tx=x+20
 text(tx,y+18,title,18,True,width=w-(tx-x)-16);text(x+20,y+65,body,14,width=w-40)

page(1,'YOUR FIRST ROUTINE','Prepare for tomorrow.','A starter checklist is now in your shared Tasks planner.')
card(44,212,346,170,'Each child','Pack what you need for tomorrow. Each child has their own Individual Task.',mint,'1')
card(410,212,346,170,'Either parent','Review tomorrow’s family plan. One parent can finish this Household Task once.',blue,'2')
text(44,421,'HOW TO TRY IT',13,True,gray)
for y,n,head,body in [(459,'1','Open Tasks','Sign in with your own username and refresh the list.'),(571,'2','Do your part','Children complete their own packing Task. A parent completes the plan review.'),(683,'3','Check the family view','Look for the completion and who recorded it on another device.')]:
 circle(72,y+26,23,green);text(65,y+11,n,20,True,'#FFFFFF');text(113,y+3,head,20,True);text(113,y+43,body,15,width=628)
rect(44,817,712,109,gold);text(64,835,'ONE SET, NOT AN AUTOMATIC DAILY SCHEDULE',13,True)
text(64,868,'These Tasks do not reset or repeat by themselves. A later evening needs fresh Tasks. Completed history stays in place.',15,width=670)
text(44,958,'After the first try: choose one useful improvement together.',16,True)
text(44,999,'Your original dashboard and Finance records remain separate.',12,color=gray)
finish(1)
page(2,'PRIVATE FEEDBACK','What made the day easier?','Use the fillable PDF privately. Nothing on this sheet is submitted to the website.')
text(44,211,'A LIGHT FIRST-WEEK PLAN',13,True,gray)
for x,title,body in [(44,'First evening','Try one checklist set.'),(286,'Following days','Notice friction; add fresh Tasks when needed.'),(528,'End of week','Pick one change together.')]:
 rect(x,248,228,114,mint);text(x+15,264,title,17,True,width=198);text(x+15,300,body,13,width=198)
from reportlab.lib.colors import HexColor
for y,label,name in [(393,'What helped?','helped'),(533,'What was confusing or took too many taps?','friction'),(673,'What should change next?','next_change')]:
 text(44,y,label,17,True)
 rect(44,y+35,712,83,'#FFFFFF',8)
 c.acroForm.textfield(name=name,tooltip=label,x=54,y=H-(y+108),width=692,height=65,fontName='Helvetica',fontSize=12,textColor=HexColor(ink),borderWidth=0,fillColor=HexColor('#FFFFFF'),fieldFlags='multiline')
rect(44,835,712,142,blue);text(64,853,'THE NEXT BUILDING DECISIONS',13,True,gray)
text(64,886,'1. Choose whether routines should repeat daily or on selected days.',14)
text(64,917,'2. Map Finance’s existing calculations, storage, permissions and backups with its creator.',14,width=660)
text(44,1004,'Keep passwords, reset links and private family details out of public development notes.',11,color=gray)
finish(2);c.save()
body=''.join(f'<section><img src="page-{i}.svg" alt="First family trial guide page {i}"></section>' for i in range(1,3))
(p/'index.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>Burns Base | First family trial</title><style>body{margin:0;background:#e6eade;font:18px Arial;color:#173f39}main{max-width:850px;margin:auto;padding:20px}nav{padding:15px;display:flex;gap:20px;flex-wrap:wrap}a{color:#235e51}img{width:100%;display:block}section{margin:20px 0}</style><main><nav><a href="first-week.pdf">Download fillable first-week PDF</a><a href="https://steven-os-mobile-test-nh3jrn97g-burns6.vercel.app/">Open household planner</a></nav>'+body+'</main></html>')
(p/'vercel.json').write_text(json.dumps({'version':2,'headers':[{'source':'/(.*)','headers':[{'key':'X-Robots-Tag','value':'noindex, nofollow'}]}]}))
files=[]
for name in ['index.html','first-week.pdf','page-1.svg','page-2.svg','vercel.json']:
 b=(p/name).read_bytes();files.append({'file':name,'sha':hashlib.sha1(b).hexdigest(),'size':len(b),'data':base64.b64encode(b).decode()})
(p/'uploads.json').write_text(json.dumps(files));print('Created first-week guide and fillable feedback PDF')
