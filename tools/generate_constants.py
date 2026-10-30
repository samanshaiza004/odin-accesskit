"""Mechanically check enum names/values and report raw C declaration coverage.
Run after bootstrap. --check compares generated output without modifying files.
"""
from pathlib import Path
import argparse, hashlib, json, re
root=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
parser.add_argument('--cache-root', type=Path, default=root/'.deps/accesskit')
args=parser.parse_args()
header=args.cache_root.expanduser().resolve()/'accesskit-c-0.23.1/include/accesskit.h'
source=header.read_text()
clean=re.sub(r'/\*.*?\*/|//[^\n]*', '', source, flags=re.S)
binding=(root/'accesskit/accesskit.odin').read_text()
existing=set(re.findall(r'^(\w+)\s*::',binding,re.M))
types={'action':'Action','aria_current':'Aria_Current','auto_complete':'Auto_Complete','has_popup':'Has_Popup','invalid':'Invalid','list_style':'List_Style','live':'Live','orientation':'Orientation','role':'Role','scroll_hint':'Scroll_Hint','scroll_unit':'Scroll_Unit','sort_direction':'Sort_Direction','text_align':'Text_Align','text_decoration_style':'Text_Decoration_Style','text_direction':'Text_Direction','toggled':'Toggled','vertical_offset':'Vertical_Offset'}
odin=['// Generated from AccessKit C 0.23.1 by tools/generate_constants.py.','package accesskit','']
asserts=['/* Generated from AccessKit C 0.23.1. */']
counts={}
for name,body in re.findall(r'enum accesskit_(\w+).*?\{(.*?)\};',clean,re.S):
 if name not in types: continue
 typ=types[name]
 if typ not in existing: odin += [f'{typ} :: distinct u8']
 value=-1;count=0
 for entry in body.split(','):
  entry=entry.strip()
  if not entry:continue
  m=re.fullmatch(r'(ACCESSKIT_\w+)(?:\s*=\s*(\d+))?',entry)
  if not m:raise ValueError(f'Unrecognized enum: {entry}')
  cname,number=m.groups(); value=int(number) if number is not None else value+1
  oname=cname.removeprefix('ACCESSKIT_')
  if oname not in existing: odin += [f'{oname} :: {typ}({value})']
  odin += [f'#assert(u8({oname}) == {value})']
  asserts += [f'_Static_assert({cname} == {value}, "{cname}");'];count+=1
 counts[name]=count;odin += ['']
upstream=set(re.findall(r'\b(accesskit_\w+)\s*\(',clean))
bound=set(re.findall(r'\b(accesskit_\w+)\s*::\s*proc "c"',binding))
manifest={'accesskit_c':'0.23.1','header_sha256':hashlib.sha256(header.read_bytes()).hexdigest(),'enums':counts,'raw_c_functions_bound':sorted(bound),'raw_c_functions_not_bound':sorted(upstream-bound)}
outputs={root/'accesskit/constants_generated.odin':'\n'.join(odin).rstrip()+'\n',root/'tests/abi_contract/enums_generated.h':'\n'.join(asserts)+'\n',root/'api-coverage.json':json.dumps(manifest,indent=2)+'\n'}
for path,text in outputs.items():
 if args.check:
  if not path.exists() or path.read_text()!=text:raise SystemExit(f'Stale generated file: {path}')
 else:path.write_text(text)
print(f'{sum(counts.values())} enum values checked; {len(bound)} of {len(upstream)} C functions declared')
