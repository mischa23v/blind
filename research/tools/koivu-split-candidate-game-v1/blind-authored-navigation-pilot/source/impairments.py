"""Deterministic simulator impairments; never a navigation or pose authority.

15 Hz fixture increments are queued, not absolute target poses. The world alone
integrates applied yaw then translation. An ordinary stop is a queued zero command
and MUST NOT erase commands already in flight. Instantiate fresh queues per episode.
"""
from __future__ import annotations
from collections import deque
from copy import deepcopy
from dataclasses import dataclass
import json
import math
import random

MAX_TRANSLATION = .025
MAX_YAW = math.radians(1)

def _tick(value):
    if isinstance(value,bool) or not isinstance(value,int) or value<0:
        raise ValueError('tick must be a nonnegative integer')
    return value

def _finite(value,name):
    if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(value):
        raise ValueError(name+' must be finite')
    return float(value)

@dataclass(frozen=True)
class SensorProfile:
    seed: int = 271828
    delay_ticks: int = 0
    jitter_ticks: int = 0
    drop_probability: float = 0.
    maximum_pending_packets: int = 64
    maximum_packet_bytes: int = 1024*1024
    def __post_init__(self):
        if isinstance(self.seed,bool) or not isinstance(self.seed,int):raise ValueError('seed')
        if not 0<=_tick(self.delay_ticks)<=30 or not 0<=_tick(self.jitter_ticks)<=30:raise ValueError('delay limit')
        if not 0<=_finite(self.drop_probability,'drop_probability')<=1:raise ValueError('drop probability')
        if not 1<=_tick(self.maximum_pending_packets)<=128:raise ValueError('queue limit')
        if not 1<=_tick(self.maximum_packet_bytes)<=2*1024*1024:raise ValueError('packet limit')

@dataclass(frozen=True)
class SensorDisposition:
    source_tick: int
    scheduled_tick: int|None
    dropped: bool
    protected_command: bool

@dataclass(frozen=True)
class DeliveredSensor:
    packet: dict
    source_tick: int
    scheduled_tick: int
    delivered_tick: int

class SensorFIFO:
    """Retain native timestamps, source pose, original tick and pixel bytes.

    Only packet.receivedAt changes on delivery. Initialization/profile/explicit
    command packets are protected from random drop, NOT from configured delay.
    Jittered due ticks are monotonic, preserving FIFO rather than time travel.
    Metadata is returned outside the packet. Never replace a missing sensor frame
    with a fabricated fresh capture; a runner must handle no-delivery ticks.
    """
    def __init__(self,profile=SensorProfile()):
        self.profile=profile;self.random=random.Random(profile.seed);self.pending=deque()
        self.last_submit=-1;self.last_release=-1;self.last_due=-1
    def submit(self,tick,packet,*,protected=False):
        _tick(tick)
        if tick<=self.last_submit:raise ValueError('source ticks must strictly increase')
        if not isinstance(packet,dict) or packet.get('tick')!=tick:raise ValueError('source tick mismatch')
        _finite(packet.get('receivedAt'),'receivedAt')
        raw=json.dumps(packet,allow_nan=False,separators=(',',':')).encode()
        if len(raw)>self.profile.maximum_packet_bytes:raise ValueError('packet byte limit')
        reliable=bool(protected or tick==0 or 'reportedProfile' in packet or
                      packet.get('command') not in (None,'continue'))
        dropped=self.random.random()<self.profile.drop_probability and not reliable
        jitter=self.random.randint(-self.profile.jitter_ticks,self.profile.jitter_ticks)
        if not dropped and len(self.pending)>=self.profile.maximum_pending_packets:
            raise BufferError('sensor queue overflow; do not silently discard reliable commands')
        self.last_submit=tick
        if dropped:return SensorDisposition(tick,None,True,reliable)
        due=max(tick,tick+self.profile.delay_ticks+jitter,self.last_due)
        self.last_due=due;self.pending.append((tick,due,deepcopy(packet)))
        return SensorDisposition(tick,due,False,reliable)
    def release(self,tick,received_at):
        _tick(tick);now=_finite(received_at,'received_at')
        if tick<self.last_release:raise ValueError('delivery ticks cannot go backwards')
        ready=[]
        # Validate clocks before removing anything, avoiding partial release on error.
        for _,due,p in self.pending:
            if due>tick:break
            if now<p['receivedAt']:raise ValueError('delivery cannot precede original capture transport time')
        self.last_release=tick
        while self.pending and self.pending[0][1]<=tick:
            source,due,p=self.pending.popleft();p['receivedAt']=now
            ready.append(DeliveredSensor(p,source,due,tick))
        return tuple(ready)

@dataclass(frozen=True)
class ActorCommand:
    forward_metres: float
    yaw_radians: float
    issued_tick: int
    source_captured_at: float|None = None
    stop_reason: str = ''
    def __post_init__(self):
        _tick(self.issued_tick)
        if abs(_finite(self.forward_metres,'forward_metres'))>MAX_TRANSLATION+1e-12:raise ValueError('input translation limit')
        if abs(_finite(self.yaw_radians,'yaw_radians'))>MAX_YAW+1e-12:raise ValueError('input yaw limit')
        if self.source_captured_at is not None:_finite(self.source_captured_at,'source_captured_at')
        if not isinstance(self.stop_reason,str) or len(self.stop_reason)>200:raise ValueError('stop_reason')

@dataclass(frozen=True)
class ActorProfile:
    reaction_delay_ticks: int = 0
    translation_scale: float = 1.
    wrong_turn_start_tick: int|None = None
    wrong_turn_end_tick_exclusive: int|None = None
    wrong_turn_yaw_radians: float = MAX_YAW
    def __post_init__(self):
        if not 0<=_tick(self.reaction_delay_ticks)<=30:raise ValueError('reaction delay limit')
        if not 0<=_finite(self.translation_scale,'translation_scale')<=1.25:raise ValueError('scale limit')
        if abs(_finite(self.wrong_turn_yaw_radians,'wrong_turn_yaw_radians'))>MAX_YAW+1e-12:raise ValueError('wrong-turn yaw limit')
        a,b=self.wrong_turn_start_tick,self.wrong_turn_end_tick_exclusive
        if (a is None)!=(b is None):raise ValueError('complete wrong-turn interval required')
        if a is not None and not _tick(a)<_tick(b):raise ValueError('wrong-turn interval')

@dataclass(frozen=True)
class AppliedCommand:
    forward_metres: float
    yaw_radians: float
    applied_tick: int
    issued_tick: int|None
    source_captured_at: float|None
    stop_reason: str
    forced_wrong_turn: bool
    translation_clipped: bool
    reaction_delay_ticks: int

class ActorFIFO:
    """Queue increments, including stops; no pose/map/LLM input or output."""
    def __init__(self,profile=ActorProfile()):
        self.profile=profile;self.pending=deque();self.last_tick=-1
    def step(self,tick,command):
        _tick(tick)
        if self.last_tick>=0 and tick!=self.last_tick+1:raise ValueError('actor ticks must be consecutive')
        if not isinstance(command,ActorCommand) or command.issued_tick!=tick:raise ValueError('actor issue tick mismatch')
        self.last_tick=tick;self.pending.append((tick+self.profile.reaction_delay_ticks,command))
        applied=None
        if self.pending and self.pending[0][0]<=tick:_,applied=self.pending.popleft()
        raw=(applied.forward_metres*self.profile.translation_scale) if applied else 0.
        forward=max(-MAX_TRANSLATION,min(MAX_TRANSLATION,raw))
        yaw=applied.yaw_radians if applied else 0.
        a,b=self.profile.wrong_turn_start_tick,self.profile.wrong_turn_end_tick_exclusive
        wrong=a is not None and a<=tick<b
        # A forced physical wrong-turn pulse is nonzero even when nominal yaw=0.
        if wrong:yaw=self.profile.wrong_turn_yaw_radians
        yaw=max(-MAX_YAW,min(MAX_YAW,yaw))
        return AppliedCommand(forward,yaw,tick,applied.issued_tick if applied else None,
            applied.source_captured_at if applied else None,
            applied.stop_reason if applied else 'reactionQueueWarming',wrong,abs(raw)>MAX_TRANSLATION,
            self.profile.reaction_delay_ticks)
