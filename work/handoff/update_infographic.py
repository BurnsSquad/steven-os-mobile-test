from reportlab.lib.pagesizes import landscape, letter
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.pdfbase.pdfmetrics import stringWidth
from pypdf import PdfReader, PdfWriter
from pathlib import Path
import html
root=Path(__file__).parent
out=root/'project-map-updated.pdf'; page=root/'current-status-infographic.pdf'
W,H=landscape(letter)
navy=colors.HexColor('#173d34'); green=colors.HexColor('#286149'); pale=colors.HexColor('#e8efe4'); cream=colors.HexColor('#f5f6f0'); muted=colors.HexColor('#557169'); amber=colors.HexColor('#c77935')
def wrap(c,text,x,y,maxw,size=10,leading=14,color=navy):
 c.setFont('Helvetica',size); c.setFillColor(color); words=text.split(); line=''; yy=y
 for w in words:
  test=(line+' '+w).strip()
  if stringWidth(test,'Helvetica',size)>maxw and line:
   c.drawString(x,yy,line); yy-=leading; line=w
  else: line=test
 if line:c.drawString(x,yy,line); yy-=leading
 return yy
c=Canvas(str(page),pagesize=(W,H)); c.setFillColor(cream); c.rect(0,0,W,H,fill=1,stroke=0); c.setFillColor(green); c.rect(0,H-9,W,9,fill=1,stroke=0)
c.setFillColor(muted); c.setFont('Helvetica-Bold',9); c.drawString(36,H-35,'BURNS BASE / STEVEN OS · DEVELOPMENT HANDOFF')
c.setFillColor(navy); c.setFont('Helvetica-Bold',25); c.drawString(36,H-70,'Where the system is now')
c.setFont('Helvetica',10); c.setFillColor(muted); c.drawString(36,H-88,'Updated October 25, 2026 · Preview only · Production unchanged')
# timeline cards
cards=[('1','FOUNDATION','Original OS protected; private records, tabs, charts and backups kept separate.'),('2','SHARED PLANNER','Real accounts, household roles, tasks, activities, calendar and goals sync through Supabase.'),('3','FINANCE','Amanda\'s rules are installed as parent-only review and paycheck planning workflow.'),('4','BANKING NOW','Plaid Sandbox wiring is in place; final provider credential acceptance is the current checkpoint.')]
for i,(n,title,body) in enumerate(cards):
 x=36+(i%2)*370; y=H-190-(i//2)*118
 c.setFillColor(colors.white); c.roundRect(x,y,342,94,10,fill=1,stroke=0); c.setStrokeColor(colors.HexColor('#d6e0d4')); c.roundRect(x,y,342,94,10,fill=0,stroke=1)
 c.setFillColor(pale); c.circle(x+25,y+69,14,fill=1,stroke=0); c.setFillColor(green); c.setFont('Helvetica-Bold',9); c.drawCentredString(x+25,y+66,n)
 c.setFillColor(navy); c.setFont('Helvetica-Bold',11); c.drawString(x+48,y+72,title); wrap(c,body,x+18,y+48,305,9,12,muted)
# diagnostic panel
py=H-430; c.setFillColor(green); c.roundRect(36,py,704,104,12,fill=1,stroke=0); c.setFillColor(colors.white); c.setFont('Helvetica-Bold',12); c.drawString(54,py+78,'CURRENT BANKING DIAGNOSIS')
wrap(c,'Finance and Supabase returned successfully. The first error was browser CSP blocking the app\'s own API. That is fixed in 7373c68. The next error, PLAID_UNAVAILABLE, is now a Plaid Sandbox credential/request rejection. The actual PLAID_SECRET was replaced in Vercel Preview; no secret was shared here.',54,py+59,660,9,12,colors.white)
# path panel
py=H-570; c.setFillColor(colors.white); c.roundRect(36,py,704,112,12,fill=1,stroke=0); c.setStrokeColor(colors.HexColor('#d6e0d4')); c.roundRect(36,py,704,112,12,fill=0,stroke=1); c.setFillColor(navy); c.setFont('Helvetica-Bold',12); c.drawString(54,py+84,'NEXT CHECKPOINT')
steps=['Open the stable preview in a new tab.','Sign in as Dad or Mom → Finance Center → Connect bank · Sandbox.','If Plaid opens, complete the Sandbox institution flow and test Sync bank transactions.','If it rejects again, record only the provider error code; never share secrets or tokens.']
for i,s in enumerate(steps): c.setFillColor(green); c.setFont('Helvetica-Bold',9); c.drawString(56,py+62-i*16,f'{i+1}.'); c.setFillColor(navy); c.setFont('Helvetica',9); c.drawString(72,py+62-i*16,s)
# footer
c.setFillColor(muted); c.setFont('Helvetica',8); c.drawString(36,38,'Stable preview: steven-os-mobile-test-banking-preview.vercel.app/preview/planner-pilot/')
c.drawRightString(W-36,38,'Entry302 · Recovery path documented in CURRENT_STATUS.md')
c.save()
# append to existing project-map PDF
writer=PdfWriter()
for f in [root/'project-map.pdf',page]:
 for p in PdfReader(str(f)).pages: writer.add_page(p)
with open(out,'wb') as fh: writer.write(fh)
# companion SVG for easy viewing/sharing
svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="900" viewBox="0 0 1100 900"><style>text{{font-family:Arial,sans-serif;fill:#173d34}}.small{{font-size:16px}}.body{{font-size:19px}}.title{{font-size:36px;font-weight:700}}.head{{font-size:18px;font-weight:700;letter-spacing:2px}}</style><rect width="1100" height="900" fill="#f5f6f0"/><rect width="1100" height="10" fill="#286149"/><text x="40" y="52" class="head" fill="#557169">BURNS BASE / STEVEN OS · DEVELOPMENT HANDOFF</text><text x="40" y="105" class="title">Where the system is now</text><text x="40" y="132" class="small">Updated October 25, 2026 · Preview only · Production unchanged</text>'''
for i,(n,t,b) in enumerate(cards):
 x=40+(i%2)*520;y=170+(i//2)*120; svg+=f'<rect x="{x}" y="{y}" width="480" height="95" rx="12" fill="white" stroke="#d6e0d4"/><circle cx="{x+28}" cy="{y+28}" r="15" fill="#e8efe4"/><text x="{x+23}" y="{y+34}" class="small" fill="#286149">{n}</text><text x="{x+55}" y="{y+34}" class="head">{html.escape(t)}</text><text x="{x+20}" y="{y+66}" class="small">{html.escape(b[:72])}</text>'
svg+='''<rect x="40" y="430" width="1020" height="145" rx="14" fill="#286149"/><text x="64" y="465" class="head" fill="white">CURRENT BANKING DIAGNOSIS</text><text x="64" y="495" class="body" fill="white">Finance and Supabase work. CSP was blocking the app's own API; 7373c68 fixed it.</text><text x="64" y="525" class="body" fill="white">PLAID_UNAVAILABLE now means Plaid Sandbox rejected credentials/request validation.</text><text x="64" y="555" class="body" fill="white">The actual PLAID_SECRET was replaced in Vercel Preview. Never share secrets here.</text><rect x="40" y="610" width="1020" height="190" rx="14" fill="white" stroke="#d6e0d4"/><text x="64" y="645" class="head">NEXT CHECKPOINT</text><text x="64" y="682" class="body">1. Open the stable preview in a new tab.</text><text x="64" y="715" class="body">2. Dad or Mom → Finance Center → Connect bank · Sandbox.</text><text x="64" y="748" class="body">3. Complete the Sandbox institution flow, then test Sync bank transactions.</text><text x="64" y="781" class="body">4. If it rejects, record only the provider code; never share secrets or tokens.</text></svg>'''
(root/'current-status-infographic.svg').write_text(svg)
print(out)
