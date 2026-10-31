// Observer-only addition; released erosion decisions do not read this state.
#pragma once
#include "Recast.h"
struct ProvenanceEvent { int span, parent, distance; };
struct ProvenanceTrace {
    int *seed, *event; unsigned char *distance;
    ProvenanceEvent* events; int count, capacity; bool overflow;
    void boundary(int i) {
        seed[i]=i; append(i,-1,0);
    }
    void improve(int i,int from,int d) {
        seed[i]=seed[from]; append(i,event[from],d);
    }
    void append(int i,int parent,int d) {
        if(count>=capacity){overflow=true;return;}
        events[count]={i,parent,d}; event[i]=count++;
    }
};
bool provenanceErode(rcContext*,int,rcCompactHeightfield&,ProvenanceTrace&);
