#!/usr/bin/env python3
"""Export the exact production instruction assembly for portable replay."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
s=(root/'ios/BlindAssist/LocalImageAssistant.swift').read_text()
def declaration(marker):
    start=s.index(marker); first=s.index('{',start); depth=0
    for i in range(first,len(s)):
        if s[i]=='{': depth+=1
        elif s[i]=='}':
            depth-=1
            if depth==0: return s[start:i+1]
    raise ValueError(marker)
method=declaration('private static func conversationInstructions(').replace('private static','static',1)
sections=declaration('private struct CompanionSystemPrompts')
out='// Generated from production LocalImageAssistant.swift; do not hand edit.\nimport Foundation\nimport BlindCore\n'+sections+'\nenum ProductionConversationPrompt {\n'+method+'\n}\n'
p=root/'tools/semantic-input-replay/Sources/CompanionInputReplay/ProductionConversationPrompt.swift'
p.write_text(out)
print(hashlib.sha256(out.encode()).hexdigest())
