"""Record genuine XCUITest interactions in an iOS simulator, without real child data."""
import json,os,subprocess,time,signal,shutil
from pathlib import Path

def run(*a): return subprocess.check_output(a,text=True).strip()
data=json.loads(run('xcrun','simctl','list','-j'))
r=max((r for r in data['runtimes'] if r.get('isAvailable') and 'iOS' in r['name'] and int(r['version'].split('.')[0])>=26),key=lambda r:tuple(map(int,r['version'].split('.'))))['identifier']
template=next(d for d in data['devices'][r] if d.get('isAvailable') and 'iPad' in d['name'] and '11-inch' in d['name'])
typeid=next(d['identifier'] for d in data['devicetypes'] if d['name']==template['name'])
device=run('xcrun','simctl','create','ABA iPad 11 Demo',typeid,r)
out=Path(os.environ['RUNNER_TEMP'])/'aba-demo';out.mkdir(exist_ok=True)
rec=None
try:
 run('xcrun','simctl','boot',device);run('xcrun','simctl','bootstatus',device,'-b')
 run('xcrun','simctl','status_bar',device,'override','--time','9:41','--batteryState','charged','--batteryLevel','100')
 common=['xcodebuild','-project','ABAProgress/XcodeProject/ABAProgress.xcodeproj','-scheme','Demo','-destination','id='+device,'-derivedDataPath',str(out/'build'),'CODE_SIGNING_ALLOWED=NO']
 with (out/'build.log').open('w') as log: subprocess.run(common+['build-for-testing'],stdout=log,stderr=subprocess.STDOUT,check=True)
 rec=subprocess.Popen(['xcrun','simctl','io',device,'recordVideo','--codec=h264',str(out/'ABAProgress-iPad-11-demo.mp4')])
 with (out/'test.log').open('w') as log:
  result=subprocess.run(common+['test-without-building','-only-testing:DemoUITests/DemoUITests/testReportWalkthrough','-parallel-testing-enabled','NO','-resultBundlePath',str(out/'demo.xcresult')],stdout=log,stderr=subprocess.STDOUT)
 rec.send_signal(signal.SIGINT);rec.wait(timeout=30);rec=None
 container=Path(run('xcrun','simctl','get_app_container',device,'com.abaprogress.universal','data'))
 for p in container.rglob('*.pdf'): shutil.copy2(p,out/p.name)
 run('xcrun','simctl','io',device,'screenshot',str(out/'final-screen.png'))
 if result.returncode: raise RuntimeError('Demo UI test failed; see test.log and recording')
 (out/'verified.txt').write_text('Real 11-inch iPad simulator UI recording. Synthetic records. Manual narrative; no AI provider call. Ends at system PDF share sheet; no external submission.\n')
finally:
 if rec: rec.send_signal(signal.SIGINT);rec.wait(timeout=30)
 subprocess.run(['xcrun','simctl','shutdown',device]);subprocess.run(['xcrun','simctl','delete',device])
 shutil.rmtree(out/'build',ignore_errors=True)
