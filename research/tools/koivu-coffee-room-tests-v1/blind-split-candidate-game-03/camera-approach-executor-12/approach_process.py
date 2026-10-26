"""Existing JSON subprocess transport, explicit frozen camera-approach artifact."""
from pathlib import Path
import selectors,subprocess,sys
HERE=Path(__file__).resolve().parent;GAME=HERE.parent
sys.path.insert(0,str(GAME/'source'))
from run_pilot import ControllerProcess
class ApproachControllerProcess(ControllerProcess):
    def __init__(self,out,plan_path,native_directory,native_sha256):
        from run_pilot import sha
        self.err=(Path(out)/'controller.stderr.log').open('x')
        self.p=subprocess.Popen([sys.executable,str(HERE/'approach_controller.py')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.err,text=True,bufsize=1)
        self.selector=selectors.DefaultSelector();self.selector.register(self.p.stdout,selectors.EVENT_READ)
        try:self.initial=self.ask({'command':'initialize','planPath':str(plan_path),'planSHA256':sha(plan_path),'nativeDirectory':str(native_directory),'nativeSHA256':native_sha256})
        except BaseException:self.close();raise
