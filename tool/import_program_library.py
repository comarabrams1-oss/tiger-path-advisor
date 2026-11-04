from pathlib import Path
import re,json,subprocess
import argparse
parser=argparse.ArgumentParser(description='Index and render all program-of-study source pages from a catalogue.')
parser.add_argument('--pdf',required=True)
parser.add_argument('--text-dir',required=True,help='Folder of page_NNN.txt files extracted from this same PDF')
parser.add_argument('--output',default='assets/programs')
args=parser.parse_args()
source=Path(args.text_dir);out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
entries=[]
for p in sorted(source.glob('page_*.txt')):
 text=p.read_text(); m=re.search(r'^\s*PROGRAM OF STUDY (?:IN|ASSOCIATE OF SCIENCE:|FOR CERTIFICATE IN)\s*(.+)?$',text,re.M)
 if not m: continue
 page=int(p.stem.split('_')[1]); title=(m.group(1) or '').strip()
 if not title: title=next((s.strip() for s in text[m.end():].splitlines() if s.strip()),'Program')
 name=title.title().replace(' And ',' and ')
 continuation = page+1 if 'FRESHMAN' not in text and 'FRESHMAN' in (source/f'page_{page+1:03}.txt').read_text() else None
 entries.append({'continuationPage':continuation,'id':f'catalogue-2025-{page}','name':name,'page':page,'year':'2025–2026','text':text.strip(),'image':f'assets/programs/page-{page}.jpg'})
 # Preserve the original source-table layout rather than reconstructing it.
 target=out/f'page-{page}'
 if not target.with_suffix('.jpg').exists():
  subprocess.run(['pdftoppm','-f',str(page),'-l',str(page),'-singlefile','-scale-to','1600','-jpeg','-jpegopt','quality=80',args.pdf,str(target)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
for e in entries:
 if e['continuationPage']:
  page=e['continuationPage'];target=out/f'page-{page}'
  if not target.with_suffix('.jpg').exists(): subprocess.run(['pdftoppm','-f',str(page),'-l',str(page),'-singlefile','-scale-to','1600','-jpeg','-jpegopt','quality=80',args.pdf,str(target)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
for e in entries:
 m=re.search(r'Concentration:\s*([^\n]+)',e['text'],re.I)
 if m:e['concentration']=m.group(1).strip()
 elif e['page']==255:e['concentration']='Pre-Med'
(out/'index.json').write_text(json.dumps(entries,indent=2,ensure_ascii=False)+'\n')
print('Indexed source program pages:',len(entries))
print([(e['page'],e['name']) for e in entries])
