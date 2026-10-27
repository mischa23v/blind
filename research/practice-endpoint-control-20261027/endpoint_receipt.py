"""Small strict receipt for the two existing endpoint selectors; not an audit pass."""
from pathlib import Path
import re
SELECTORS={'large':'testPracticeLayoutAtDefaultSize','accessibility-extra-extra-extra-large':'testPracticeLayoutAtLargestAccessibilitySize'}
CATEGORIES={'large':'UICTContentSizeCategoryL','accessibility-extra-extra-extra-large':'UICTContentSizeCategoryAccessibilityXXXL'}
def verify_endpoint(path,size):
 if size not in SELECTORS:raise ValueError('Unknown endpoint')
 p=Path(path)
 if not p.is_file() or p.is_symlink() or p.stat().st_size>16*1024*1024:raise ValueError('Endpoint log missing/oversized')
 started=passed=failed=skipped=0;categories=[];end=[];roles=set();lines=0
 token=SELECTORS[size]
 with p.open(errors='replace') as stream:
  for line in stream:
   lines+=1
   if len(line)>65536:raise ValueError('Endpoint log line exceeds bound')
   if token in line and 'Test Case ' in line:
    started+=int(' started.' in line);passed+=int(' passed (' in line);failed+=int(' failed (' in line);skipped+=int(' skipped (' in line)
   if 'PRACTICE_LAYOUT category=' in line:
    m=re.search(r'category=(\S+) expected=(\S+)',line)
    if m:categories.append(m.groups())
   if 'PRACTICE_LAYOUT afterReveal ' in line:
    m=re.search(r'role=(button|header|footer)\b',line)
    if m:roles.add(m[1])
   if 'PRACTICE_LAYOUT footerEnd ' in line:
    m=re.search(r'footerEnd size=(\S+).*endVisible=(true|false)',line)
    if m:end.append(m.groups())
 if (started,passed,failed,skipped)!=(1,1,0,0):raise ValueError('Exact endpoint selector did not execute and pass once')
 if categories!=[(CATEGORIES[size],CATEGORIES[size])]:raise ValueError('Wrong/missing/duplicate endpoint category')
 if roles!={'button','header','footer'} or end!=[(size,'true')]:raise ValueError('Missing exact footer-end/readability evidence')
 return {'status':'passed','selector':token,'category':CATEGORIES[size],'footerEndVisible':True,'roleReceipts':sorted(roles),'scope':'full-app endpoint scroll reachability, not audit or VoiceOver acceptance'}
