#!/usr/bin/env python3
"""SOURCE ONLY: root review/admission required. Never invokes installs or retries.
Helper reuse from passed conference aggregate supervisor; output cap64MiB for this reviewed protocol.
Historical estimated registration is diagnostic only, not camera-mesh calibration.
"""
import hashlib, json, math, os, pathlib, re, resource, signal, stat, subprocess, sys, time
H = pathlib.Path(__file__).resolve().parent
ROOT = H.parents[1]
CPU, WALL, RSS, OUTPUT = 120, 180, 1024**3, 64*1024**2

def file_record(fd, hashed):
    before=os.fstat(fd)
    if not stat.S_ISREG(before.st_mode): raise RuntimeError('Nonregular file refused')
    row={'bytes':before.st_size,'device':before.st_dev,'inode':before.st_ino,
         'mtimeNs':before.st_mtime_ns,'ctimeNs':before.st_ctime_ns}
    if hashed:
        if before.st_size>OUTPUT: raise RuntimeError('File exceeds output bound')
        with os.fdopen(os.dup(fd),'rb') as f: row['sha256']=hashlib.file_digest(f,'sha256').hexdigest()
        after=os.fstat(fd)
        if (before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_size,after.st_mtime_ns,after.st_ctime_ns):
            raise RuntimeError('File changed during terminal hashing')
    return row

def sha(p):
    fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode): raise RuntimeError('Nonregular pinned input')
        before=os.fstat(fd)
        with os.fdopen(os.dup(fd),'rb') as f: digest=hashlib.file_digest(f,'sha256').hexdigest()
        after=os.fstat(fd)
        if (before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_size,after.st_mtime_ns,after.st_ctime_ns):
            raise RuntimeError('Pinned input changed during hash')
        return digest
    finally: os.close(fd)

def inventory(root, active):
    """Bounded descriptor traversal. Only active ENOENT races may be skipped."""
    result={}; visits=0; total=0
    def walk(fd,prefix,depth):
        nonlocal visits,total
        if depth>8: raise RuntimeError('Output nesting cap')
        with os.scandir(fd) as entries:
            for entry in entries:
                visits+=1
                if visits>4096: raise RuntimeError('Output entry cap')
                name=entry.name; key=prefix+name
                try:
                    seen=os.stat(name,dir_fd=fd,follow_symlinks=False);mode=seen.st_mode
                    if stat.S_ISLNK(mode): raise RuntimeError('Output symlink refused: '+key)
                    if stat.S_ISDIR(mode):
                        child=os.open(name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
                        try:
                            opened=os.fstat(child)
                            if (opened.st_dev,opened.st_ino)!=(seen.st_dev,seen.st_ino):
                                raise RuntimeError('Output directory replaced: '+key)
                            result[key+'/']={'bytes':0,'device':opened.st_dev,'inode':opened.st_ino,
                                             'mtimeNs':opened.st_mtime_ns,'ctimeNs':opened.st_ctime_ns}
                            walk(child,key+'/',depth+1)
                        finally: os.close(child)
                    elif stat.S_ISREG(mode):
                        child=os.open(name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=fd)
                        try:
                            opened=os.fstat(child)
                            if (opened.st_dev,opened.st_ino)!=(seen.st_dev,seen.st_ino):
                                raise RuntimeError('Output file replaced: '+key)
                            total+=opened.st_size
                            if total>OUTPUT: raise RuntimeError('Aggregate output inventory cap')
                            result[key]=file_record(child,not active and key!='GUARD_RUN/RESULT.json')
                        finally: os.close(child)
                    else: raise RuntimeError('Output special file refused: '+key)
                except FileNotFoundError:
                    if not active: raise
    fd=os.open(root,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try: walk(fd,'',0)
    finally: os.close(fd)
    return result

def stable_inventory(root):
    first=inventory(root,False)
    if first!=inventory(root,False): raise RuntimeError('Terminal output inventory changed')
    return {name:row for name,row in first.items() if name!='GUARD_RUN/RESULT.json'}

def usage():
    r=resource.getrusage(resource.RUSAGE_CHILDREN)
    s=resource.getrusage(resource.RUSAGE_SELF)
    return r.ru_utime+r.ru_stime+s.ru_utime+s.ru_stime

def group_sample(pgid):
    cpu=rss=members=0
    for entry in pathlib.Path('/proc').iterdir():
        if not entry.name.isdecimal(): continue
        try:
            # comm may contain whitespace or parentheses; split after final ')'.
            a=(entry/'stat').read_text().rsplit(')',1)[1].split()
            if int(a[2])!=pgid: continue  # Original field 5: pgrp.
            members+=1
            cpu+=sum(int(a[i]) for i in (11,12,13,14))/os.sysconf('SC_CLK_TCK')
            rss+=int(a[21])*os.sysconf('SC_PAGE_SIZE')
        except (FileNotFoundError, ProcessLookupError): pass
    return cpu,rss,members

def kill_group(pid):
    try: os.killpg(pid,signal.SIGKILL)
    except ProcessLookupError: pass

