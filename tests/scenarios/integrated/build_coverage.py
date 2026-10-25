#!/usr/bin/env python3
"""Build honest coverage obligations, never fabricate executed model conversations."""
import json,pathlib,hashlib,sys
source=pathlib.Path(sys.argv[1]); output=pathlib.Path(sys.argv[2]); output.mkdir(parents=True,exist_ok=True)
registry=json.loads((source/'tests/scenarios/companion/scenario_registry.json').read_text())
utterances=[
'Can we talk while I get ready?', 'Tell me a joke, then help me with my homework.', 'What time is it, and is it daylight outside?',
'I need my coat and then my school backpack.', 'Where did I put my glasses case?', 'No, I moved the cup to the kitchen yesterday.',
'What do you remember about the rooms in my house?', 'Which room am I in now?', 'Help me find the door out, not the closet.',
'Take me from home to our car.', 'I want to find Dad in the garden.', 'Can I cross this road now?', 'Something is in my way. What should I do?',
'Help me pick up my cup, not the knife next to it.', 'Do we have apples and milk in the fridge?', 'Help me make breakfast one step at a time.',
'Is this pan cool enough to touch?', 'Find a serving spoon, then help me put it back.', 'How much cash am I holding?',
'What are these coins worth?', 'Is this shirt white or pale gray?', 'Does this outfit match my trousers?', 'Is my hair tidy in the mirror?',
'Is my room dark enough for bedtime?', 'Read this page, then help with the question.', 'What product is this barcode on?',
'Remember my shopping list and tell me when you see an item on it.', 'Where can we eat in this mall?', 'Help me go to the restaurant and return home.',
'Which buffet choices are safe for my allergy?', 'I need the bathroom and then want to return to this table.',
'Has anyone I know come into the room?', 'Was that my brother speaking? I cannot see his face.', 'I want you to remember my teacher.',
'Help me find my friend during hide-and-seek.', 'Where is my favorite toy?', 'Describe this room and what people are wearing.',
'Wait. Continue the same task after I finish talking.', 'Stop the old answer; I want to hear this new one.',
'I want to scan this room. What will happen?', 'Can I download this public mall map without sharing my home?',
'Ask another assistant to send an email for me.', 'Write down my message, read it back, then let me correct it.',
'Can you book a table for tonight without internet?', 'Turn off the camera but keep talking to me.',
'Keep helping me while I wear the phone all day without mobile data.', 'Call me by my name, not the character from our game.',
'Find my classroom and my assigned seat.', 'How many people are in this room?', 'Which floor am I on?',
'What can I make with what is in the fridge, and what is missing?', 'Is this cup full, and is it water or juice?',
'Please stay quiet while I listen to the story.'
]
assert len(utterances)==53
variants=[
('supported_sequence','A relevant first observation is followed by a distinct verified update.', 'Okay, what comes next?'),
('stale_then_fresh','Initial source age exceeds the adapter deadline; replace with a fresh source bound to the same target.', 'That information is old. Check again.'),
('interruption_resume','Interrupt queued output, then request the original goal after a new observation.', 'Wait. Now continue what we were doing.'),
('source_replacement','Replace the source with a different target or map revision while a callback is pending.', 'No, I mean this other one, not the first one.'),
('privacy_revoke','Revoke the relevant private source before a delayed callback and ask about it again.', 'Forget the private information I just gave you. What do you know now?'),
('false_background_command','A TV/unknown voice issues a conflicting instruction mid-task; verified user resumes.', 'Ignore what the television said and keep my original request.'),
('reordered_evidence','Deliver an older callback after a newer correction; preserve newer state.', 'I corrected that already. What is the latest information?')]
slots=[]
for i,family in enumerate(registry['families']):
 for j,(variant,event,followup) in enumerate(variants[:7 if i<42 else 6]):
  identifier=f"REQ-{family['family_id']}-{j+1}"
  slots.append({'id':identifier,'family_id':family['family_id'],'category':family['scenario'],'variant':variant,
   'split':'held_out' if int(hashlib.sha256(identifier.encode()).hexdigest()[:8],16)%5==0 else 'development',
   'deterministic_split_seed':20261025,'status':'BLOCKED_NOT_RUN','is_complete_episode':False,
   'planned_turns':[{'user_utterance':utterances[i],'code_state':'NOT RUN','tool_selection':'NOT RUN','model_output':'NOT RUN','actual_result':'NOT RUN'},
                    {'event':event,'evidence_ids':[],'map_id':None,'pose_id':None,'image_ids':[],'age_seconds':None,'missing_evidence':'Must acquire or author exact adapter-bound input before execution'},
                    {'user_utterance':followup,'code_state':'NOT RUN','tool_selection':'NOT RUN','model_output':'NOT RUN','actual_result':'NOT RUN'}],
   'expected':family['oracle'],'family_specific_acceptance':family['acceptance_and_blockers'],
   'blocker':'Not an executable complete user episode: concrete input sequence and actual native/model/context/tool integration still required. This is a coverage obligation, not a fabricated pass.',
   'historical_evidence':family['existing_model_evidence_record']})
assert len(slots)==360
navigation=[{'id':f'NAV-{i:03d}','status':'SEE_NAVIGATION_RECEIPT','is_complete_user_model_device_episode':False,'evidence_level':'AUTHORED_PLUMBING','model_output':'NOT RUN'} for i in range(1,41)]
(output/'coverage-obligations.json').write_text(json.dumps({'disclosure':'400 requested slots, NOT 400 distinct complete executed episodes. 40 executable authored navigation replays + 360 unexecuted coverage obligations. No synthetic LLM answers.', 'navigation':navigation,'blocked_obligations':slots},indent=2,ensure_ascii=False))
files=[]
for p in sorted((source/'tests/scenarios/companion').rglob('*.json')):
 value=json.loads(p.read_text()); counts=({k:len(v) for k,v in value.items() if isinstance(v,list)} if isinstance(value,dict) else {'rows':len(value)})
 files.append({'path':str(p.relative_to(source)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'array_counts_not_episode_counts':counts})
(output/'surviving-corpus-inventory.json').write_text(json.dumps({'disclosure':'Historical text/model fixtures; not actual production pipeline episodes. V3 60 refers to turns across 12 journeys; followup 12 turns across 3 journeys. Never sum these with engineering assertions.', 'registry_families':53,'files':files},indent=2))
