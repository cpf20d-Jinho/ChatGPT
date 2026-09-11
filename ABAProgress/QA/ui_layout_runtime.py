"""Run actual report/help/consent interactions across four installed simulator sizes."""
import json, os, subprocess, shutil
from pathlib import Path
def run(*a): return subprocess.check_output(a,text=True).strip()
data=json.loads(run('xcrun','simctl','list','-j'))
runtime=max((r for r in data['runtimes'] if r.get('isAvailable') and 'iOS' in r['name'] and int(r['version'].split('.')[0])>=26),key=lambda r:tuple(map(int,r['version'].split('.'))))['identifier']
names=[d['name'] for d in data['devices'][runtime] if d.get('isAvailable')]
phones=list(dict.fromkeys(n for n in names if 'iPhone' in n))
pads=list(dict.fromkeys(n for n in names if 'iPad' in n))
small=next((n for key in ['SE (3rd','16e','17e','iPhone 17','iPhone 16'] for n in phones if key in n and 'Max' not in n and 'Plus' not in n),phones[0])
standard=next((n for n in phones if n!=small and 'Pro' in n and 'Max' not in n),next(n for n in phones if n!=small))
pad11=next(n for n in pads if '11-inch' in n)
pad13=next(n for n in pads if '13-inch' in n or '12.9-inch' in n)
out=Path(os.environ['RUNNER_TEMP'])/'aba-layout';out.mkdir(exist_ok=True)
common=['xcodebuild','-project','ABAProgress/XcodeProject/ABAProgress.xcodeproj','-scheme','Demo','-derivedDataPath',str(out/'build'),'CODE_SIGNING_ALLOWED=NO']
with (out/'build.log').open('w') as log:
 subprocess.run(common+['-destination','generic/platform=iOS Simulator','build-for-testing'],stdout=log,stderr=subprocess.STDOUT,check=True)
results=[]
try:
 for index,name in enumerate([small,standard,pad11,pad13]):
  typeid=next(t['identifier'] for t in data['devicetypes'] if t['name']==name)
  device=run('xcrun','simctl','create','ABA Layout '+str(index),typeid,runtime)
  try:
   run('xcrun','simctl','boot',device);run('xcrun','simctl','bootstatus',device,'-b')
   if index==0: run('xcrun','simctl','ui',device,'content_size','accessibility-large')
   selected_tests=['-only-testing:DemoUITests/DemoUITests/testHelpAndWebConsent']
   if index==1:selected_tests+=['-only-testing:DemoUITests/DemoUITests/testConsolidatedProgramAndEditEntryPoints']
   with (out/f'{index}.log').open('w') as log:
    result=subprocess.run(common+['-destination','id='+device,'test-without-building']+selected_tests+['-parallel-testing-enabled','NO','-resultBundlePath',str(out/f'{index}.xcresult')],stdout=log,stderr=subprocess.STDOUT)
   results.append({'device':name,'success':result.returncode==0,'largeType':index==0})
   subprocess.run(['xcrun','xcresulttool','export','attachments','--path',str(out/f'{index}.xcresult'),'--output-path',str(out/f'{index}-screens')],check=True)
   manifest=json.loads((out/f'{index}-screens'/'manifest.json').read_text())
   orientation=next(a for test in manifest for a in test['attachments'] if 'Report alternate orientation' in a['suggestedHumanReadableName'])
   image=out/f'{index}-screens'/orientation['exportedFileName']
   properties=run('sips','-g','pixelWidth','-g','pixelHeight','-g','orientation',str(image))
   width=int(next(line.split(':',1)[1] for line in properties.splitlines() if 'pixelWidth' in line))
   height=int(next(line.split(':',1)[1] for line in properties.splitlines() if 'pixelHeight' in line))
   orientation_value=next((line.split(':',1)[1].strip().lower() for line in properties.splitlines() if 'orientation' in line),'up')
   # XCTest preserves the device rotation as EXIF orientation while the PNG pixel
   # matrix remains portrait. Validate the user-visible geometry, not raw storage.
   rotated=orientation_value in {'5','6','7','8'} or 'left' in orientation_value or 'right' in orientation_value
   visible_width,visible_height=(height,width) if rotated else (width,height)
   results[-1].update({'pixelSize':f'{width}x{height}','visibleSize':f'{visible_width}x{visible_height}','orientation':orientation_value})
   assert (visible_width>visible_height)==(index<2), f'Wrong visible orientation for {name}: {visible_width}x{visible_height} ({orientation_value}, stored {width}x{height})'
  finally:
   subprocess.run(['xcrun','simctl','shutdown',device]);subprocess.run(['xcrun','simctl','delete',device])
finally:
 shutil.rmtree(out/'build',ignore_errors=True)
 (out/'results.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results))
assert len(results)==4 and all(r['success'] for r in results)
