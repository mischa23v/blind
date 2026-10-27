"""Native full topology/locator admission only; zero floor/collision/movement queries."""
import sys,time,resource
from runtime import H,save,verify
import physics_primitives as motion
def main(expected):
 verify(expected);start=time.monotonic();runtime=motion.serial_vtk();surface,info,reader=motion.load_surface();u=resource.getrusage(resource.RUSAGE_SELF)
 save(H/'REFERENCE_PARSE_RESULT.json',{'status':'originalMeshAndLocatorLoaded','referenceMesh':info,'runtime':runtime,'wallSeconds':time.monotonic()-start,'CPUSeconds':u.ru_utime+u.ru_stime,'peakRSSKiB':u.ru_maxrss,'supportQueries':0,'collisionQueries':0,'movementEpisodes':0,'physicalAuthority':False});verify(expected)
if __name__=='__main__':main(sys.argv[1])
