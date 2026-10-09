"""Render recorded RGB frames and actual virtual ray returns; never invent geometry."""
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

root=Path(__file__).resolve().parents[1]/'artifacts'
stairs=root/'stairs'
indices=json.loads((stairs/'source.json').read_text())['indices']
fig,axes=plt.subplots(3,4,figsize=(16,10),layout='constrained')
for ax,index in zip(axes.ravel(),indices):
    ax.imshow(plt.imread(stairs/f'color_{index}.png'))
    ax.set_title(f'Recorded frame {index}');ax.axis('off')
fig.suptitle('RGB-D stair dataset: fixed subset before scoring — Wang et al., CC BY 4.0')
fig.savefig(stairs/'rgb-contact-sheet.png',dpi=130)
plt.close(fig)

room=root/'real-scene'
cases=json.loads((room/'room-replay-input.json').read_text())
results={r['id']:r for r in json.loads((room/'room-replay-results.json').read_text())}
fig,axes=plt.subplots(2,3,figsize=(15,10),layout='constrained')
for ax,case in zip(axes.ravel(),cases):
    points=np.array(case['points']);camera=case['camera'];forward=case['forward']
    relative=points-np.array([camera['x'],case['floor'],camera['z']])
    ahead=relative[:,0]*forward['x']+relative[:,2]*forward['z']
    side=-relative[:,0]*forward['z']+relative[:,2]*forward['x']
    plot=ax.scatter(side,ahead,c=relative[:,1],s=3,cmap='coolwarm',vmin=-.15,vmax=1.5)
    ax.plot([-.38,-.38,.38,.38],[.3,2.2,2.2,.3],color='black',linestyle='--',linewidth=1)
    ax.scatter([0],[0],marker='^',c='black',s=35)
    found=results[case['id']]['actual']
    ax.set(xlim=(-1.5,1.5),ylim=(0,3),aspect='equal',xlabel='Side (m)',ylabel='Ahead (m)',
           title=f"{case['id']}\nExpected {case['expected']} / observed {found}")
fig.colorbar(plot,ax=axes.ravel().tolist(),label='Returned surface height above estimated floor (m)',shrink=.65)
fig.suptitle('First-hit virtual rays through the REAL 3DLite apartment mesh\nFavorable synthetic camera; no physical sensor or localization trial. Derived data: CC BY-NC-SA 4.0.')
fig.savefig(room/'room-replay-preview.png',dpi=140)
plt.close(fig)
print('Rendered recorded staircase contact sheet and six room ray results.')
