#!/usr/bin/env python3
"""Bounded synthetic exporter/CLI fixtures; NOT Apple path/collision execution."""
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj
m = module('routes', 'native-route-diagnostic-evidence.py')
u = module('statuses', 'export-native-unit-statuses.py')
DOCS, UUIDS, HASHES = m.sources(ROOT)


def report(label, executed=False):
    journey = label == 'journey'
    result = {'schema':1,'protocolSHA256':m.JOURNEY if journey else m.BASE,
              'physicalAuthority':False,'fullFootprintSupportVerified':False,'outcomes':[],'errors':[]}
    if journey:
        result.update(baseline18Unchanged=True, suppliedPoseCandidateReplayOnly=True,
                      cameraLocalizationTested=False, getUpKinematicsTested=False,
                      productionGuidanceCode=['SpatialFacts.relation','SpatialFacts.phrase','GuidanceCadence.label'],
                      sustainedControllerTested=False, VoiceOverTested=False)
        for j in DOCS['RoomRouteDiagnostic/JOURNEY_ADDENDUM.json']['journeys']:
            for s in j['stages']:
                result['outcomes'].append({'journey':j['id'],'stage':s['id'],'outcome':'not-run-after-aborted-stage'})
    else:
        result.update(profileAddendumSHA256=m.WIDTH if label == 'width28-addendum' else 'none',schedule=label,
                      currentCoverageKnown=False,scope='candidate waypoint replay; not controller/device arrival')
        profiles = DOCS['RoomRouteDiagnostic/'+ ('PROFILE_28CM_ADDENDUM.json' if label == 'width28-addendum' else 'PROTOCOL.json')]['profiles']
        for pair in DOCS['RoomRouteDiagnostic/PROTOCOL.json']['pairs']:
            for profile in profiles:
                result['outcomes'].append({'pair':pair['id'],'profile':profile['id'],'outcome':'not-run-after-aborted-stage'})
    if executed:
        row = result['outcomes'][0]
        row.update(outcome='modeled-segment-candidate-no-contact' if journey else 'candidate-model-route-no-contact',
                   sourceSHA256=m.FIXTURES['Bedroom3' if journey else 'Hallway2'],physicalAuthority=False,
                   requestedStart=[0,0,0],requestedGoal=[1,0,0],routePoints=[[0,0,0],[1,0,0]],
                   projectedStart=[0,0,0],projectedGoal=[1,0,0],nativeComplete=True,nativeStatus=1073741824,
                   startProjectionMetres=0,goalProjectionMetres=0,initialBodyContact=False,initialMarginContact=False,
                   fullFootprintSupportVerified=False,bodyContact=False,marginContact=False,floorContactIDs=[],
                   obstacleSurfaceIDs=[],furnitureBoundIDs=[],segments=[
                       {'kind':'requested-start-to-projection','from':[0,0,0],'to':[0,0,0],'bodyContact':False,'marginContact':False},
                       {'kind':'detour-segment-1','from':[0,0,0],'to':[1,0,0],'bodyContact':False,'marginContact':False},
                       {'kind':'projection-to-requested-goal','from':[1,0,0],'to':[1,0,0],'bodyContact':False,'marginContact':False}])
        if journey:
            row.update(seatedFeatureID='45597D99-3218-4419-A2E4-2ADFA824D033',seatedObservationIsAuthored=True,
                       expectedWithhold=False,cameraLocalizationTested=False,getUpKinematicsTested=False,
                       originalSuppliedStandingPoint=[0,0,0],declaredHeading=[1,0,0],replayPositionAfterStage=[1,0,0],
                       guidanceDelivered=True,productionGuidanceReceipts=[{
                           'segmentIndex':1,'segmentKind':'detour-segment-1','from':[0,0,0],'to':[1,0,0],
                           'sector':'ahead','angleDegrees':0,'horizontalMetres':1,'syntheticSeconds':2,
                           'physicalAuthority':False,'source':'production SpatialFacts + GuidanceCadence; supplied heading',
                           'text':'TEST '+row['stage']+' detour-segment-1: ahead, 1.0 metres.'}])
        else:
            row.update(rawRadius=.27,rawHeight=1.6,effectiveRadius=.42,effectiveHeight=1.75,initialFurnitureBoundIDs=[],waypointSinkDelivered=True)
    return result


def chain_report(complete=True, metadata=True):
    result=report('original-baseline',True);row=result['outcomes'][0]
    row.update(requestedStart=[0,0,0],projectedStart=[1,0,0],routePoints=[[1,.1,0],[2,.1,0]],
               projectedGoal=[2,0,0],requestedGoal=[3,0,0],nativeComplete=complete,
               outcome='candidate-model-route-no-contact' if complete else 'partial-route',waypointSinkDelivered=complete)
    edges=[('requested-start-to-projection',[0,0,0],[1,0,0]),
           ('projection-to-detour-start',[1,0,0],[1,.1,0]),
           ('detour-segment-1',[1,.1,0],[2,.1,0])]
    if complete:
        edges.extend([('detour-end-to-projection',[2,.1,0],[2,0,0]),
                      ('projection-to-requested-goal',[2,0,0],[3,0,0])])
    row['segments']=[{'kind':k,'from':a,'to':b,'bodyContact':False,'marginContact':False} for k,a,b in edges]
    if metadata:
        row.update(scoredChainContinuous=True,scoredChainIncludesRequestedGoal=complete,
                   sourceFloorSupportAlongScoredChain='unverified-full-footprint')
        for segment in row['segments']:
            segment.update(floorContactIDs=[],fullFootprintSupportVerified=False,sourceFloorSupport='unverified-full-footprint')
    return result


def export_fixture(directory, name, payload, suggested=None, filename='report.json'):
    directory.mkdir(parents=True, exist_ok=True)
    (directory/'manifest.json').write_text(json.dumps([{'testName':'synthetic fixture','attachments':[
        {'suggestedHumanReadableName':suggested or name,'exportedFileName':filename}]}]))
    if filename == 'report.json': (directory/filename).write_text(json.dumps(payload))


def metadata_inventory():
    result = {'schema':'blind.saved-room-route-mesh-metadata-inventory.v1','physicalAuthority':False,'fixtures':[]}
    for room, digest in m.FIXTURES.items():
        uuid = sorted(UUIDS[room])[0]
        name_hash = hashlib.sha256(b'Wall0').hexdigest()
        root = {'index':0,'depth':0,'name':'Wall0','nameSHA256':name_hash,'isMesh':False,
                'directMappingPresent':True,'inheritedMappingPresent':False,'knownFeature':True,
                'directUUID':uuid,'resolvedUUID':uuid}
        mesh = {'index':1,'parentIndex':0,'depth':1,'name':'Wall0','nameSHA256':name_hash,'isMesh':True,
                'vertexCount':4,'submeshCount':1,'directMappingPresent':False,
                'inheritedMappingPresent':True,'knownFeature':True,'inheritedUUID':uuid,'resolvedUUID':uuid}
        result['fixtures'].append({'fixtureID':room,'sourceSHA256':digest,'metadataByteCount':128,'metadataFormat':'json','metadataRootKind':'object',
            'metadataEntryCount':1,'metadataEntriesTruncated':False,'metadataEntries':[
                {'key':'Wall0','keySHA256':name_hash,'valueKind':'string','uuidValue':True,'knownFeature':True,'uuid':uuid}],
            'nodeCount':2,'nodesTruncated':False,'nodes':[root,mesh],
            'meshCount':1,'unmatchedMeshCount':0,'unknownFeatureMeshCount':0})
    return result


def collision_matrix():
    result = {'schemaVersion':1,'evidenceKind':'synthetic-collision-backend-matrix','physicalAuthority':False,
              'fullFootprintSupportVerified':False,'cells':[]}
    for configuration in ('restricted-no-renderer','default-no-renderer','restricted-offscreen-renderer','default-offscreen-renderer'):
        queries = []
        for name in m.CONTROL_NAMES:
            empty = {'obstacleSurfaceIDs':[],'floorSurfaceIDs':[],'furnitureBoundIDs':[]}
            query = {'name':name,'errorCode':'none','initial':copy.deepcopy(empty),'swept':copy.deepcopy(empty),
                     'terminal':copy.deepcopy(empty),'passed':False}
            wall, solid, overhead, floor = ['00000000-0000-0000-0000-00000000000'+str(i) for i in range(1,5)]
            if name.startswith('thinWall'): query['swept']['obstacleSurfaceIDs'] = [wall]
            elif name == 'wallInitialOverlap': query['initial']['obstacleSurfaceIDs'] = [wall]
            elif name == 'wallTerminalOverlap': query['terminal']['obstacleSurfaceIDs'] = [wall]
            elif name == 'containedSolid':
                for phase in ('initial','terminal'): query[phase]['furnitureBoundIDs'] = [solid]
            elif name.startswith('overheadTall'): query['swept']['obstacleSurfaceIDs'] = [overhead]
            elif name == 'floor':
                for phase in ('initial','terminal'): query[phase]['floorSurfaceIDs'] = [floor]
            query['passed'] = True
            queries.append(query)
        result['cells'].append({'configurationID':configuration,
            'sourceCollisionMask':'probe-only' if configuration.startswith('restricted') else 'platform-default-all',
            'rendererMode':'none' if configuration.endswith('no-renderer') else 'retained-offscreen-update',
            'physicsSpeed':1,'timeStepSeconds':1/60,'gravity':[0,0,0],
            'sourceCategoryMask':1,'probeCategoryMask':2,'queryCollisionMask':1,
            'backendReady':True,'failedControls':[],'queries':queries})
    return result


def diagnostic_report(label):
    if label == 'metadata-inventory': return metadata_inventory()
    if label == 'collision-backend': return collision_matrix()
    return mixed_collision_matrix()


def mixed_collision_matrix():
    result = {'schemaVersion':1,'evidenceKind':'synthetic-collision-mixed-scene','physicalAuthority':False,
              'fullFootprintSupportVerified':False,'cells':[]}
    for configuration in ('wall-only-combined','wall-and-floor-combined','wall-only-separated','wall-and-floor-separated'):
        mode='separated' if configuration.endswith('separated') else 'combined'
        layout='wall-and-floor' if configuration.startswith('wall-and-floor') else 'wall-only'
        queries=[copy.deepcopy(query) for query in collision_matrix()['cells'][0]['queries'] if query['name'] in m.MIXED_CONTROL_NAMES]
        for query in queries:
            for phase in ('initial','swept','terminal'):
                contacts=query[phase]
                contacts['obstacleSurfaceIDs']=['10000000-0000-0000-0000-000000000001'] if contacts['obstacleSurfaceIDs'] else []
                contacts['floorSurfaceIDs']=['10000000-0000-0000-0000-000000000002'] if layout=='wall-and-floor' else []
        result['cells'].append({'configurationID':configuration,'layout':layout,'queryMode':mode,
            'rendererMode':'retained-offscreen-update','physicsSpeed':1,'timeStepSeconds':1/60,'gravity':[0,0,0],
            'obstacleCategoryMask':1,'floorCategoryMask':4 if mode=='separated' else 1,'probeCategoryMask':2,
            'queryCollisionMasks':[1,4] if mode=='separated' else [1],
            'backendReady':True,'failedControls':[],'queries':queries})
    return result


def geometry_inventory(group='walls'):
    data=metadata_inventory()
    for fixture in data['fixtures']:
        features=DOCS['RoomPlanApple/'+fixture['fixtureID']+'.capturedRoom.json'][group]
        if not features:continue
        feature=features[0];uuid=feature['identifier']
        fixture['adapterFailure']='sourceGeometryMismatch'
        fixture['metadataEntries'][0]['uuid']=uuid
        fixture['nodes'][0].update(directUUID=uuid,resolvedUUID=uuid)
        fixture['nodes'][1].update(inheritedUUID=uuid,resolvedUUID=uuid)
        dimensions=[m.float32(value) for value in feature['dimensions']]
        transform=[m.float32(value) for value in feature['transform']]
        corners=[] if group=='objects' else [[m.float32(value) for value in point] for point in feature.get('polygonCorners',[])]
        low=[min(point[i] for point in corners) if corners else -dimensions[i]/2 for i in range(3)]
        high=[max(point[i] for point in corners) if corners else dimensions[i]/2 for i in range(3)]
        points=corners or [[high[i] if mask & (1<<i) else low[i] for i in range(3)] for mask in range(8)]
        def world(point):
            return [transform[i]*point[0]+transform[4+i]*point[1]+transform[8+i]*point[2]+transform[12+i] for i in range(3)]
        original=[world(point) for point in points]
        mesh_local=[(lo+hi)/2 for lo,hi in zip(low,high)];mesh_local[2]=high[2]+0.05
        exported_world=[m.float32(value) for value in world(mesh_local)]
        local=[transform[4*i]*exported_world[0]+transform[4*i+1]*exported_world[1]+transform[4*i+2]*exported_world[2]
               -(transform[4*i]*transform[12]+transform[4*i+1]*transform[13]+transform[4*i+2]*transform[14]) for i in range(3)]
        epsilon=64*2**-23*max([1]+[abs(value) for value in exported_world+transform+dimensions])
        identity=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
        fixture['geometryProbe']={'sourceEncoding':'capturedRoomFloat32','nodeIndex':1,'featureID':uuid,
            'featureKind':{'walls':'wall','floors':'floor','objects':'furniture'}[group],
            'vertexIndex':0,'vertexCount':4,'axis':2,'side':'aboveMaximum','lower':low[2],'upper':high[2],
            'epsilon':epsilon,'residual':local[2]-high[2],
            'meshLocalPoint':mesh_local,'worldPoint':exported_world,'sourceLocalPoint':local,
            'sourceDimensions':dimensions,'sourceLocalMinimum':low,'sourceLocalMaximum':high,
            'sourceWorldMinimum':[min(point[i] for point in original) for i in range(3)],
            'sourceWorldMaximum':[max(point[i] for point in original) for i in range(3)],
            'exportedWorldMinimum':[value-.01 for value in exported_world],'exportedWorldMaximum':[value+.01 for value in exported_world],
            'exportedSourceLocalMinimum':[value-.01 for value in local],'exportedSourceLocalMaximum':[value+.01 for value in local],
            'assetUpAxis':[0,1,0],'sourceTransform':transform,'meshLocalTransform':identity,
            'meshGlobalTransform':transform[:],'parentGlobalTransform':transform[:],'rootGlobalTransform':transform[:]}
    return data


class GeometryProbeValidationTests(unittest.TestCase):
    def validate(self,data):return m.validate_metadata_inventory(data,UUIDS,DOCS)
    def test_public_wall_floor_and_furniture_source_values_bound_exactly(self):
        for group in ('walls','floors','objects'):
            data=geometry_inventory(group)
            self.assertEqual(self.validate(data),data)
    def test_probe_requires_original_docs_known_sampled_mesh_and_matching_context(self):
        with self.assertRaisesRegex(m.EvidenceError,'geometry_source_unavailable'):
            m.validate_metadata_inventory(geometry_inventory(),UUIDS)
        for key,value in [('nodeIndex',128),('nodeIndex',True),('nodeIndex',0),('vertexCount',200001),
                          ('vertexCount',5),('vertexIndex',4),('vertexIndex',-1),('featureKind','floor'),
                          ('sourceEncoding','rawJSON'),('featureID','00000000-0000-0000-0000-000000000000')]:
            data=geometry_inventory();data['fixtures'][0]['geometryProbe'][key]=value
            with self.subTest(key=key,value=value),self.assertRaises(m.EvidenceError):self.validate(data)
        data=geometry_inventory();del data['fixtures'][0]['adapterFailure']
        with self.assertRaisesRegex(m.EvidenceError,'geometry_probe_context_mismatch'):self.validate(data)
    def test_source_dimensions_transform_bounds_never_approximate_or_replace_pinned_values(self):
        for key in ('sourceDimensions','sourceTransform','sourceLocalMinimum','sourceLocalMaximum','sourceWorldMinimum','sourceWorldMaximum'):
            data=geometry_inventory();data['fixtures'][0]['geometryProbe'][key][0]+=1e-12
            with self.subTest(key=key),self.assertRaisesRegex(m.EvidenceError,'geometry_probe_source_mismatch'):self.validate(data)
        data=geometry_inventory();fixture=data['fixtures'][0];probe=fixture['geometryProbe']
        raw=DOCS['RoomPlanApple/'+fixture['fixtureID']+'.capturedRoom.json']['walls'][0]
        self.assertNotEqual(raw['dimensions'],probe['sourceDimensions'])
        probe['sourceDimensions']=raw['dimensions']
        with self.assertRaisesRegex(m.EvidenceError,'geometry_probe_source_mismatch'):self.validate(data)
    def test_unknown_fields_paths_raw_geometry_and_nonfinite_numbers_rejected(self):
        for key,value in [('vertices',[0,0,0]),('triangles',[0,1,2]),('path','/Users/private/home'),
                          ('featureID','private-room'),('meshLocalPoint',[True,0,0]),('worldPoint',[float('nan'),0,0]),
                          ('assetUpAxis',[float('inf'),0,0]),('rootGlobalTransform',[0]*15),
                          ('meshGlobalTransform',[10001]+[0]*15),('epsilon',True),('residual',20001)]:
            data=geometry_inventory();data['fixtures'][0]['geometryProbe'][key]=value
            with self.subTest(key=key),self.assertRaises(m.EvidenceError):self.validate(data)
    def test_production_epsilon_and_first_axis_not_relaxed_by_probe(self):
        for key,value in [('epsilon',1),('epsilon',0),('residual',0),('axis',0),('axis',True),
                          ('side','belowMinimum'),('side','approximatelyOutside'),('lower',-.1),('upper',.1)]:
            data=geometry_inventory();data['fixtures'][0]['geometryProbe'][key]=value
            with self.subTest(key=key,value=value),self.assertRaises(m.EvidenceError):self.validate(data)
        data=geometry_inventory();probe=data['fixtures'][0]['geometryProbe']
        probe['sourceLocalPoint'][0]=probe['sourceLocalMaximum'][0]+1
        probe['exportedSourceLocalMaximum'][0]=probe['sourceLocalPoint'][0]
        with self.assertRaises(m.EvidenceError):self.validate(data)
    def test_below_bound_observation_keeps_positive_residual_and_full_mesh_bbox(self):
        data=geometry_inventory();probe=data['fixtures'][0]['geometryProbe']
        t=probe['sourceTransform'];p=probe['meshLocalPoint'];p[2]=probe['lower']-.05
        w=[m.float32(t[i]*p[0]+t[4+i]*p[1]+t[8+i]*p[2]+t[12+i]) for i in range(3)]
        probe['worldPoint']=w
        probe['sourceLocalPoint']=[t[4*i]*w[0]+t[4*i+1]*w[1]+t[4*i+2]*w[2]-(t[4*i]*t[12]+t[4*i+1]*t[13]+t[4*i+2]*t[14]) for i in range(3)]
        probe['side']='belowMinimum'
        probe['epsilon']=64*2**-23*max([1]+[abs(value) for value in w+t+probe['sourceDimensions']])
        probe['residual']=probe['lower']-probe['sourceLocalPoint'][2]
        for point,prefix in (('worldPoint','exportedWorld'),('sourceLocalPoint','exportedSourceLocal')):
            probe[prefix+'Minimum']=probe[point][:];probe[prefix+'Maximum']=probe[point][:]
        self.assertEqual(self.validate(data),data)
        probe['exportedSourceLocalMinimum'][2]+=.001
        with self.assertRaises(m.EvidenceError):self.validate(data)
    def test_world_local_residual_cannot_be_fabricated_independently(self):
        for field in ('worldPoint','sourceLocalPoint'):
            data=geometry_inventory();probe=data['fixtures'][0]['geometryProbe'];probe[field][2]+=.001
            probe['residual']=probe['sourceLocalPoint'][2]-probe['upper']
            with self.subTest(field=field),self.assertRaisesRegex(m.EvidenceError,'geometry_probe_world_local_mismatch'):self.validate(data)
    def test_bounded_probe_failure_retained_without_partial_probe_or_unknown_error(self):
        data=geometry_inventory();fixture=data['fixtures'][0];del fixture['geometryProbe']
        fixture['geometryProbeFailure']='budgetExceeded';self.assertEqual(self.validate(data),data)
        fixture['geometryProbeFailure']='/Users/private/geometry'
        with self.assertRaisesRegex(m.EvidenceError,'unapproved_error_text'):self.validate(data)
        data=geometry_inventory();data['fixtures'][0]['geometryProbeFailure']='budgetExceeded'
        with self.assertRaisesRegex(m.EvidenceError,'geometry_probe_context_mismatch'):self.validate(data)
    def test_probe_collects_in_same_allowlisted_attachment_and_preserves_failed_test(self):
        cases=[{'identifier':key,'result':'Failed'} for key,_,_ in m.SPECS+m.DIAGNOSTIC_SPECS]
        def exporter(bundle,identifier,destination):
            key,name,label=next(spec for spec in m.SPECS+m.DIAGNOSTIC_SPECS if spec[0]==m.canonical(identifier))
            value=report(label) if (key,name,label) in m.SPECS else (geometry_inventory() if label=='metadata-inventory' else diagnostic_report(label))
            export_fixture(destination,name,value)
        with patch.object(m,'export_test',side_effect=exporter):result=m.collect(ROOT,Path('unused'),cases,u.query)
        self.assertEqual(result['status'],'complete');self.assertEqual(len(result['reports']),6)
        record=result['reports'][3];self.assertEqual(record['testResult'],'Failed')
        self.assertEqual(record['report'],geometry_inventory());self.assertLess(record['bytes'],m.DIAGNOSTIC_LIMIT)


class DiagnosticValidationTests(unittest.TestCase):
    def test_fixed_public_inventory_and_synthetic_matrix(self):
        self.assertEqual(m.validate_metadata_inventory(metadata_inventory(),UUIDS),metadata_inventory())
        self.assertEqual(m.validate_collision_matrix(collision_matrix()),collision_matrix())
    def test_metadata_failures_preserved_not_promoted(self):
        for error in m.METADATA_FAILURES:
            data=metadata_inventory();data['fixtures'][0].update(adapterFailure=error,inventoryFailure=error)
            self.assertEqual(m.validate_metadata_inventory(data,UUIDS),data)
        for error in m.METADATA_FAILURES-{'unclassifiedError'}:
            data=report('original-baseline');data['outcomes'][0].update(outcome='unsupported-geometry',error=error)
            data['errors']=['Hallway2: '+error]
            self.assertEqual(m.validate_report(data,'original-baseline',DOCS,UUIDS),data)
    def test_content_free_metadata_format_enums_and_json_coherence(self):
        for format in ('binaryPlist','xmlPlist','unknown','unread'):
            data=metadata_inventory();fixture=data['fixtures'][0]
            fixture.update(metadataFormat=format,metadataRootKind='unread' if format=='unread' else 'invalidJSON',
                           metadataByteCount=0 if format=='unread' else 128,metadataEntryCount=0,
                           metadataEntries=[],inventoryFailure='metadataDecodeFailed')
            self.assertEqual(m.validate_metadata_inventory(data,UUIDS),data)
        for format in ('json','xmlPlist','unknown','/Users/private',True):
            data=metadata_inventory();data['fixtures'][0]['metadataFormat']=format
            if format=='json':data['fixtures'][0]['metadataRootKind']='invalidJSON'
            with self.subTest(format=format),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
    def test_binary_plist_decoded_shapes_and_historical_decode_failure(self):
        for kind in ('object','array','string','number','boolean','null','invalidPropertyList','invalidJSON'):
            data=metadata_inventory();fixture=data['fixtures'][0]
            fixture.update(metadataFormat='binaryPlist',metadataRootKind=kind)
            if kind!='object':fixture.update(metadataEntryCount=0,metadataEntries=[])
            if kind.startswith('invalid'):fixture['inventoryFailure']='metadataDecodeFailed'
            self.assertEqual(m.validate_metadata_inventory(data,UUIDS),data)
    def test_property_list_parse_error_is_exclusive_to_binary_plist(self):
        for format in ('unread','json','xmlPlist','unknown'):
            data=metadata_inventory();fixture=data['fixtures'][0]
            fixture.update(metadataFormat=format,metadataRootKind='invalidPropertyList',
                           metadataEntryCount=0,metadataEntries=[],inventoryFailure='metadataDecodeFailed')
            with self.subTest(format=format),self.assertRaisesRegex(m.EvidenceError,'metadata_format_disagreement'):
                m.validate_metadata_inventory(data,UUIDS)
        data=metadata_inventory();data['fixtures'][0].update(metadataFormat='binaryPlist',metadataRootKind='unread')
        with self.assertRaisesRegex(m.EvidenceError,'metadata_format_disagreement'):m.validate_metadata_inventory(data,UUIDS)
    def test_decoded_binary_plist_cannot_bypass_fixture_or_private_data_guards(self):
        for change in ('source','raw','path','unknown_uuid','bytes','authority'):
            data=metadata_inventory();fixture=data['fixtures'][0];fixture['metadataFormat']='binaryPlist'
            if change=='source':fixture['sourceSHA256']='0'*64
            elif change=='raw':fixture['rawMetadata']='PRIVATE_BINARY_PAYLOAD'
            elif change=='path':fixture['metadataEntries'][0]['key']='/Users/private/family'
            elif change=='unknown_uuid':fixture['metadataEntries'][0]['uuid']='00000000-0000-0000-0000-000000000000'
            elif change=='bytes':fixture['metadataByteCount']=m.LIMIT+1
            else:data['physicalAuthority']=True
            with self.subTest(change=change),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
    def test_metadata_schema_source_and_private_payload_fail_closed(self):
        for key,value in [('fixtureID','PrivateBedroom'),('sourceSHA256','0'*64),('adapterFailure','/Users/private/photo.jpg'),
                          ('rawMetadata',{'family':'secret'}),('metadataRootKind','private'),('metadataByteCount',m.LIMIT+1),
                          ('nodeCount',4097),('metadataEntryCount',4097),('metadataEntriesTruncated',1),
                          ('nodesTruncated',True),('meshCount',2),('unknownFeatureMeshCount',2)]:
            data=metadata_inventory();data['fixtures'][0][key]=value
            with self.subTest(key=key),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
        data=metadata_inventory();data['physicalAuthority']=True
        with self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
        data=metadata_inventory();data['fixtures'][1]=copy.deepcopy(data['fixtures'][0])
        with self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
    def test_metadata_names_are_bounded_paths_redacted_hashes_checked(self):
        for name in ('/Users/private/family','file://private','x\\private','private\ntext','x'*129,''):
            data=metadata_inventory();node=data['fixtures'][0]['nodes'][0];node['name']=name
            node['nameSHA256']=hashlib.sha256(name.encode()).hexdigest()
            with self.subTest(name=name),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
        data=metadata_inventory();node=data['fixtures'][0]['nodes'][0];node['name']='<redacted>'
        self.assertEqual(m.validate_metadata_inventory(data,UUIDS),data)
        node['nameSHA256']='bad'
        with self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
        data=metadata_inventory();data['fixtures'][0]['metadataEntries'][0]['keySHA256']='a'*64
        with self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
    def test_metadata_uuid_parent_and_geometry_count_consistency(self):
        for key,value in [('resolvedUUID','00000000-0000-0000-0000-000000000000'),('parentIndex',1),('depth',64),
                          ('index',True),('knownFeature',False),('inheritedMappingPresent',False),('vertexCount',200001),
                          ('submeshCount',True),('coordinates',[0,0,0])]:
            data=metadata_inventory();data['fixtures'][0]['nodes'][1][key]=value
            with self.subTest(key=key),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
        for key,value in [('uuid','00000000-0000-0000-0000-000000000000'),('uuidValue',False),
                          ('knownFeature',False),('valueKind','number')]:
            data=metadata_inventory();data['fixtures'][0]['metadataEntries'][0][key]=value
            with self.subTest(key=key),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
        data=metadata_inventory();node=data['fixtures'][0]['nodes'][1]
        node.update(directMappingPresent=True,knownFeature=False);del node['resolvedUUID']
        data['fixtures'][0]['unknownFeatureMeshCount']=1
        self.assertEqual(m.validate_metadata_inventory(data,UUIDS),data) # unknown direct wins; no guessed feature
    def test_metadata_exact_sample_limits_and_mesh_required_fields(self):
        data=metadata_inventory();fixture=data['fixtures'][0]
        fixture.update(nodeCount=4096,nodesTruncated=True,meshCount=127,
                       metadataEntryCount=4096,metadataEntriesTruncated=True)
        entry=fixture['metadataEntries'][0]
        fixture['metadataEntries']=[dict(entry,key='Wall'+str(i),keySHA256=hashlib.sha256(('Wall'+str(i)).encode()).hexdigest()) for i in range(64)]
        mesh=copy.deepcopy(fixture['nodes'][1])
        fixture['nodes']=[fixture['nodes'][0]]+[dict(mesh,index=i) for i in range(1,128)]
        self.assertEqual(m.validate_metadata_inventory(data,UUIDS),data)
        fixture['nodes'].append(dict(mesh,index=128))
        with self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
        for key in ('vertexCount','submeshCount'):
            data=metadata_inventory();del data['fixtures'][0]['nodes'][1][key]
            with self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
    def test_synthetic_schema_order_configuration_and_identifiers(self):
        for change in ('schema','cell_count','cell_order','query_order','speed','mask','renderer','gravity','time','private','unknown_id','wrong_category','duplicate'):
            data=collision_matrix();cell=data['cells'][0];query=cell['queries'][0]
            if change=='schema':data['schemaVersion']=True
            elif change=='cell_count':data['cells'].pop()
            elif change=='cell_order':data['cells'].reverse()
            elif change=='query_order':cell['queries'].reverse()
            elif change=='speed':cell['physicsSpeed']=False
            elif change=='mask':cell['sourceCollisionMask']='all'
            elif change=='renderer':cell['rendererMode']='none-but-ready'
            elif change=='gravity':cell['gravity']=[False,0,0]
            elif change=='time':cell['timeStepSeconds']=float('nan')
            elif change=='private':query['privateHistory']='family'
            elif change=='unknown_id':query['swept']['obstacleSurfaceIDs']=[sorted(UUIDS['Hallway2'])[0]]
            elif change=='wrong_category':query['swept']['floorSurfaceIDs']=query['swept']['obstacleSurfaceIDs']
            else:query['swept']['obstacleSurfaceIDs']*=2
            with self.subTest(change=change),self.assertRaises(m.EvidenceError):m.validate_collision_matrix(data)
    def test_collision_predicates_ready_and_error_coherence(self):
        for index in range(10):
            data=collision_matrix();query=data['cells'][0]['queries'][index]
            query['passed']=False
            with self.subTest(index=index),self.assertRaisesRegex(m.EvidenceError,'collision_pass_disagreement'):m.validate_collision_matrix(data)
        data=collision_matrix();cell=data['cells'][0];query=cell['queries'][0]
        query['swept']['obstacleSurfaceIDs']=[];query['passed']=False
        cell.update(backendReady=False,failedControls=['thinWallForward'])
        self.assertEqual(m.validate_collision_matrix(data),data)
        query['errorCode']='invalidGeometry'
        self.assertEqual(m.validate_collision_matrix(data),data)
        query['initial']['obstacleSurfaceIDs']=['00000000-0000-0000-0000-000000000001']
        with self.assertRaisesRegex(m.EvidenceError,'collision_error_disagreement'):m.validate_collision_matrix(data)
        data=collision_matrix();data['cells'][0]['backendReady']=False
        with self.assertRaisesRegex(m.EvidenceError,'collision_readiness_disagreement'):m.validate_collision_matrix(data)
    def test_control_failure_text_accepts_only_ordered_fixed_names(self):
        failure='backendUnavailable("backend controls failed: thinWallForward,containedSolid,floor")'
        self.assertTrue(m.approved_failure(failure))
        data=report('original-baseline');data['outcomes'][0].update(outcome='collision-backend-unavailable',error=failure)
        data['errors']=['Hallway2 collision backend unavailable: '+failure]
        self.assertEqual(m.validate_report(data,'original-baseline',DOCS,UUIDS),data)
        for names in ('','floor,thinWallForward','floor,floor','private','floor,/Users/private','floor, floor'):
            self.assertFalse(m.approved_failure('backendUnavailable("backend controls failed: '+names+'")'))


class ValidationTests(unittest.TestCase):
    def validate(self, data, label='original-baseline'):
        return m.validate_report(data,label,DOCS,UUIDS)
    def test_all_three_full_schedules_and_executed_rows(self):
        for _,_,label in m.SPECS:
            for executed in (False,True): self.assertEqual(self.validate(report(label,executed),label),report(label,executed))
    def test_protocol_source_authority_and_schema_fail_closed(self):
        for key,value in [('protocolSHA256','0'*64),('physicalAuthority',True),('privateHistory','secret'),('schema',True)]:
            r=report('original-baseline');r[key]=value
            with self.assertRaises(m.EvidenceError):self.validate(r)
        r=report('original-baseline',True);r['outcomes'][0]['sourceSHA256']='a'*64
        with self.assertRaises(m.EvidenceError):self.validate(r)
    def test_nonfinite_numbers_and_nonvectors(self):
        for bad in ([float('nan'),0,0],[float('inf'),0,0],[True,0,0],[0,0],['private',0,0],[1e100,0,0],[10**400,0,0]):
            r=report('original-baseline',True);r['outcomes'][0]['routePoints']=[bad]
            with self.assertRaises(m.EvidenceError):self.validate(r)
    def test_duplicate_key_and_nonfinite_json(self):
        for raw in ('{"a":1,"a":2}','{"a":NaN}','{"a":Infinity}'):
            with self.assertRaises(m.EvidenceError):m.decode(raw)
    def test_missing_duplicate_and_unknown_schedules(self):
        for change in ('missing','duplicate','unknown'):
            r=report('original-baseline')
            if change=='missing':r['outcomes'].pop()
            elif change=='duplicate':r['outcomes'][-1]=r['outcomes'][0]
            else:r['outcomes'][0]['pair']='my-private-bedroom'
            with self.assertRaises(m.EvidenceError):self.validate(r)
    def test_private_and_model_strings_are_rejected(self):
        for change in ('error','unknown_field','text','source','uuid'):
            r=report('journey',True);row=r['outcomes'][0]
            if change=='error':r['errors']=['/Users/private/family-camera.jpg']
            elif change=='unknown_field':row['cameraFrame']='encoded-private-frame'
            elif change=='text':row['productionGuidanceReceipts'][0]['text']='My model says go to Sarah in bedroom'
            elif change=='source':row['productionGuidanceReceipts'][0]['source']='model output'
            else:row['furnitureBoundIDs']=['00000000-0000-0000-0000-000000000000']
            with self.assertRaises(m.EvidenceError):self.validate(r,'journey')
    def test_guidance_segments_cannot_be_substituted(self):
        r=report('journey',True);r['outcomes'][0]['productionGuidanceReceipts'][0]['to']=[8,8,8]
        with self.assertRaises(m.EvidenceError):self.validate(r,'journey')
    def test_incomplete_and_conflicting_candidate_claims_rejected(self):
        for label in ('original-baseline','journey'):
            for key in ('segments','routePoints','nativeComplete','bodyContact','physicalAuthority'):
                r=report(label,True);del r['outcomes'][0][key]
                with self.assertRaises(m.EvidenceError):self.validate(r,label)
            r=report(label,True);r['outcomes'][0]['bodyContact']=True
            with self.assertRaises(m.EvidenceError):self.validate(r,label)
            r=report(label,True);r['outcomes'][0]['segments']=[]
            with self.assertRaises(m.EvidenceError):self.validate(r,label)
    def test_exact_discrepancy_chains_complete_partial_and_legacy(self):
        for complete in (False,True):
            for metadata in (False,True):
                r=chain_report(complete,metadata);self.assertEqual(self.validate(r),r)
    def test_omitted_reordered_extra_or_edited_edges_rejected(self):
        for change in ('omit_start_connector','omit_end_connector','reorder','extra','wrong_from','wrong_kind'):
            r=chain_report();edges=r['outcomes'][0]['segments']
            if change=='omit_start_connector':del edges[1]
            elif change=='omit_end_connector':del edges[-2]
            elif change=='reorder':edges[1],edges[2]=edges[2],edges[1]
            elif change=='extra':edges.append(copy.deepcopy(edges[-1]))
            elif change=='wrong_from':edges[2]['from']=[1,0,0]
            else:edges[1]['kind']='detour-segment-2'
            with self.assertRaisesRegex(m.EvidenceError,'scored_chain_mismatch'):self.validate(r)
    def test_partial_chain_must_not_bridge_to_projected_or_requested_goal(self):
        r=chain_report(False);r['outcomes'][0]['segments']+=chain_report()['outcomes'][0]['segments'][-2:]
        with self.assertRaisesRegex(m.EvidenceError,'scored_chain_mismatch'):self.validate(r)
    def test_continuity_metadata_exact_types_and_goal_semantics(self):
        for key,value in [('scoredChainContinuous',False),('scoredChainContinuous',1),
                          ('scoredChainIncludesRequestedGoal',False),('scoredChainIncludesRequestedGoal',1)]:
            r=chain_report();r['outcomes'][0][key]=value
            with self.assertRaisesRegex(m.EvidenceError,'chain_metadata_disagreement'):self.validate(r)
    def test_no_positive_or_mixed_floor_support_metadata(self):
        for change in ('row_positive','segment_positive','verified','missing_row','missing_segment','legacy_segment'):
            r=chain_report(metadata=change!='legacy_segment');row=r['outcomes'][0];segment=row['segments'][0]
            if change=='row_positive':row['sourceFloorSupportAlongScoredChain']='verified'
            elif change=='segment_positive':segment['sourceFloorSupport']='supported'
            elif change=='verified':segment['fullFootprintSupportVerified']=True
            elif change=='missing_row':del row['scoredChainContinuous']
            elif change=='missing_segment':del segment['fullFootprintSupportVerified']
            else:segment['sourceFloorSupport']='unverified-full-footprint'
            with self.assertRaises(m.EvidenceError):self.validate(r)
    def test_contact_aggregates_cannot_hide_scored_connector_collision(self):
        for field in ('bodyContact','marginContact'):
            r=chain_report();r['outcomes'][0]['segments'][1][field]=True
            with self.assertRaisesRegex(m.EvidenceError,'contact_aggregate_mismatch'):self.validate(r)
            row=r['outcomes'][0];row[field]=True;row['outcome']='candidate-contact'
            self.assertEqual(self.validate(r),r)
    def test_floor_contact_is_recorded_but_never_support_proof(self):
        r=chain_report();row=r['outcomes'][0]
        floor=DOCS['RoomPlanApple/Hallway2.capturedRoom.json']['floors'][0]['identifier']
        row['segments'][1]['floorContactIDs']=[floor]
        with self.assertRaisesRegex(m.EvidenceError,'floor_contact_aggregate_mismatch'):self.validate(r)
        row['floorContactIDs']=[floor];self.assertEqual(self.validate(r),r)
        self.assertFalse(row['fullFootprintSupportVerified']);self.assertFalse(row['segments'][1]['fullFootprintSupportVerified'])
    def test_authored_failure_is_retained_not_relabelled_pass(self):
        r=report('original-baseline');r['outcomes'][0].update(outcome='unsupported-geometry',error='invalidMesh')
        r['errors']=['Hallway2: invalidMesh']
        self.assertEqual(self.validate(r),r)
    def test_source_digest_changed_before_collection(self):
        with patch.object(Path,'read_bytes',return_value=b'{}'):
            with self.assertRaises(m.EvidenceError):m.sources(ROOT)


class FileBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.d=Path(self.tmp.name)/'export';self.addCleanup(self.tmp.cleanup)
        self.name=m.SPECS[0][1];self.payload=report('original-baseline')
    def test_exact_and_known_exporter_suffix(self):
        for name in (self.name,self.name.removesuffix('.json')+'_1_ABCD.json',self.name+'_1_ABCD.json'):
            export_fixture(self.d,self.name,self.payload,suggested=name)
            self.assertEqual(m.decode(m.exported_report(self.d,self.name)),self.payload)
    def test_paths_never_opened(self):
        for filename in ('../private.json','/tmp/private.json','x\\private.json','report.png','..','bad\x00.json'):
            export_fixture(self.d,self.name,self.payload,filename=filename)
            with self.assertRaises(m.EvidenceError):m.exported_report(self.d,self.name)
    def test_symlink_rejected(self):
        export_fixture(self.d,self.name,self.payload)
        p=self.d/'report.json';p.unlink();p.symlink_to('/etc/passwd')
        with self.assertRaises(m.EvidenceError):m.exported_report(self.d,self.name)
    def test_unknown_attachment_never_read(self):
        for name in ('screenshot.png','camera-frame.json','audio.wav','model-output.json',self.name+'Private.json'):
            export_fixture(self.d,self.name,self.payload,suggested=name)
            (self.d/'report.json').write_bytes(b'not-readable-json')
            with self.assertRaisesRegex(m.EvidenceError,'unexpected_test_attachment'):m.exported_report(self.d,self.name)
    def test_declared_type_and_size_when_present(self):
        for key,value in [('uniformTypeIdentifier','public.png'),('payloadSize',m.LIMIT+1),('payloadSize',True)]:
            export_fixture(self.d,self.name,self.payload)
            path=self.d/'manifest.json';data=json.loads(path.read_text());data[0]['attachments'][0][key]=value;path.write_text(json.dumps(data))
            with self.assertRaises(m.EvidenceError):m.exported_report(self.d,self.name)
    def test_export_directory_symlink_rejected_without_traversal(self):
        self.d.symlink_to(self.d.parent, target_is_directory=True)
        with self.assertRaises(m.EvidenceError):m.export_size(self.d)
    def test_duplicate_empty_unsupported_and_large_manifest(self):
        export_fixture(self.d,self.name,self.payload)
        manifest=self.d/'manifest.json'; original=json.loads(manifest.read_text())
        for data in ({},[],[{'attachments':[]}],[{'attachments':original[0]['attachments']*2}]):
            manifest.write_text(json.dumps(data))
            with self.assertRaises(m.EvidenceError):m.exported_report(self.d,self.name)
        manifest.write_text(' '*65537)
        with self.assertRaises(m.EvidenceError):m.exported_report(self.d,self.name)
    def test_file_count_subdirectory_and_byte_bounds(self):
        self.d.mkdir()
        for i in range(9):(self.d/str(i)).touch()
        with self.assertRaises(m.EvidenceError):m.export_size(self.d)
        for p in self.d.iterdir():p.unlink()
        (self.d/'dir').mkdir()
        with self.assertRaises(m.EvidenceError):m.export_size(self.d)
        (self.d/'dir').rmdir();(self.d/'large').write_bytes(b'x'*(m.LIMIT+65537))
        with self.assertRaises(m.EvidenceError):m.export_size(self.d)


class CollectionTests(unittest.TestCase):
    def cases(self,status='Passed'):
        return [{'identifier':'BlindAssistTests/'+key+'()','result':status} for key,_,_ in m.SPECS]
    def exporter(self,bundle,identifier,destination):
        spec=next(s for s in m.SPECS if s[0]==m.canonical(identifier))
        export_fixture(destination,spec[1],report(spec[2],True))
    def collect(self,cases=None):
        with patch.object(m,'export_test',side_effect=self.exporter):return m.collect(ROOT,Path('unused'),self.cases() if cases is None else cases,u.query)
    def test_failed_tests_keep_full_reports_and_status(self):
        result=self.collect(self.cases('Failed'))
        self.assertEqual(result['status'],'complete');self.assertEqual(len(result['reports']),3)
        self.assertTrue(all(r['testResult']=='Failed' and r['report']['physicalAuthority'] is False for r in result['reports']))
        self.assertTrue(all(r['sha256'] and r['bytes']>0 for r in result['reports']))
    def test_unknown_prefix_and_lookalikes_do_not_export(self):
        with patch.object(m,'export_test') as tool:
            for identifier in ('Unknown/'+m.SPECS[0][0],m.SPECS[0][0]+'Extra()',m.SPECS[0][0]+'/subcase'):
                result=m.collect(ROOT,Path('unused'),[{'identifier':identifier,'result':'Passed'}],u.query)
                self.assertEqual(result['status'],'not_observed')
            tool.assert_not_called()
    def test_duplicate_and_missing_cases_explicit(self):
        cases=self.cases();result=self.collect(cases+[cases[0]])
        self.assertEqual(result['status'],'incomplete');self.assertEqual(result['reports'][0]['status'],'duplicate_test_case')
        self.assertEqual(self.collect([])['status'],'not_observed')
    def test_export_errors_are_sanitized_and_temp_cleaned(self):
        paths=[]
        def bad(*args):paths.append(args[-1].parent);raise OSError('/Users/private/family')
        with patch.object(m,'export_test',side_effect=bad):r=m.collect(ROOT,Path('unused'),self.cases(),u.query)
        self.assertNotIn('private',json.dumps(r));self.assertTrue(all(not p.exists() for p in paths))
        self.assertEqual(r['reports'][0]['status'],'attachment_export_or_schema_error')
    def test_budget_omits_reports_before_case_statuses(self):
        result={'schema':1,'complete':True,'cases':[{'identifier':'x','result':'Failed'}],
                'routeDiagnosticEvidence':{'status':'complete','reports':[{'report':{'oversized':'x'*m.LIMIT},'status':'collected'}]}}
        encoded=u.encode_evidence(result);r=json.loads(encoded)
        self.assertLessEqual(len(encoded.encode()),m.LIMIT);self.assertEqual(r['cases'],result['cases'])
        self.assertTrue(r['complete']);self.assertEqual(r['routeDiagnosticEvidence']['status'],'artifact_over_budget')
    def test_huge_integer_is_only_additive_error_not_crash(self):
        def bad(bundle,identifier,destination):
            key,name,label=next(s for s in m.SPECS if s[0]==m.canonical(identifier))
            data=report(label,True);data['outcomes'][0]['routePoints'][0][0]=10**400
            export_fixture(destination,name,data)
        with patch.object(m,'export_test',side_effect=bad):r=m.collect(ROOT,Path('unused'),self.cases(),u.query)
        self.assertEqual(r['status'],'incomplete')
        self.assertTrue(all(x['status']=='invalid_route_points' for x in r['reports']))
    def test_main_integration_keeps_exit_and_target_verdict(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);out=root/'unit-case-statuses.json';log=root/'unit.log';log.write_text('')
            cases=self.cases('Failed')
            (root/'unit-summary.json').write_text(json.dumps({'totalTestCount':3,'passedTests':0,'failedTests':3,'skippedTests':0,'expectedFailures':0}))
            raw=json.dumps({'testNodes':[{'nodeType':'Test Case','nodeIdentifier':c['identifier'],'result':c['result']} for c in cases]}).encode()
            source={'actual_head':'a'*40,'tracked_source_clean':True}
            with patch.object(sys,'argv',['exporter','unit.xcresult',str(log),str(out)]),patch.dict(os.environ,{'GITHUB_SHA':'a'*40}),\
                 patch.object(u,'provenance',return_value=source),patch.object(u,'query',return_value=raw),\
                 patch.object(u,'route_evidence',return_value=self.collect(cases)),contextlib.redirect_stdout(io.StringIO()):
                code=u.main()
            final=json.loads(out.read_text());self.assertEqual(code,0);self.assertTrue(final['complete'])
            self.assertFalse(final['target_pass_verified']);self.assertEqual(final['cases'],cases)
            self.assertEqual(final['routeDiagnosticEvidence']['reports'][0]['testResult'],'Failed')


class StubCLITests(unittest.TestCase):
    def test_owned_export_timeout_is_explicit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);stub=root/'xcrun'
            stub.write_text('#!'+sys.executable+'\nimport time;time.sleep(10)\n');stub.chmod(0o755)
            with patch.dict(os.environ,{'PATH':str(root)+os.pathsep+os.environ.get('PATH','')}),\
                 patch.object(m.time,'monotonic',side_effect=[0,31]):
                with self.assertRaisesRegex(m.EvidenceError,'attachment_export_timeout'):
                    m.export_test(Path('fixture.xcresult'),m.SPECS[0][0],root/'output')
    def test_owned_export_file_size_limit_is_enforced(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);stub=root/'xcrun'
            stub.write_text('#!'+sys.executable+'\n'+"import pathlib,sys; a=sys.argv;p=pathlib.Path(a[a.index('--output-path')+1]);p.mkdir();(p/'too-big.json').write_bytes(b'x'*2097152)\n")
            stub.chmod(0o755)
            with patch.dict(os.environ,{'PATH':str(root)+os.pathsep+os.environ.get('PATH','')}):
                with self.assertRaisesRegex(m.EvidenceError,'attachment_export_failed'):
                    m.export_test(Path('fixture.xcresult'),m.SPECS[0][0],root/'output')
            self.assertLessEqual((root/'output/too-big.json').stat().st_size,m.LIMIT)
    def test_real_subprocess_exact_test_flag_and_auto_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);stub=p/'xcrun';capture=p/'commands.jsonl';fixtures=p/'fixtures.json'
            fixtures.write_text(json.dumps({key+'()':{'name':name,'report':report(label,True)} for key,name,label in m.SPECS}))
            stub.write_text('#!'+sys.executable+'\n'+'''import json,os,pathlib,sys
args=sys.argv[1:]
assert args[:3]==['xcresulttool','export','attachments']
assert '--test-id' in args and '--only-failures' not in args
with open(os.environ['COMMANDS'],'a') as f:f.write(json.dumps(args)+'\\n')
fixture=json.load(open(os.environ['FIXTURES']))[args[args.index('--test-id')+1]]
p=pathlib.Path(args[args.index('--output-path')+1]);p.mkdir()
(p/'report.json').write_text(json.dumps(fixture['report']))
(p/'manifest.json').write_text(json.dumps([{'attachments':[{'suggestedHumanReadableName':fixture['name'],'exportedFileName':'report.json'}]}]))
''');stub.chmod(0o755)
            env={'PATH':str(p)+os.pathsep+os.environ.get('PATH',''),'COMMANDS':str(capture),'FIXTURES':str(fixtures)}
            cases=[{'identifier':key+'()','result':'Passed'} for key,_,_ in m.SPECS]
            with patch.dict(os.environ,env):result=m.collect(ROOT,Path('fixture.xcresult'),cases,u.query)
            self.assertEqual(result['status'],'complete')
            commands=[json.loads(line) for line in capture.read_text().splitlines()]
            self.assertEqual(len(commands),3)
            self.assertEqual({c[c.index('--test-id')+1] for c in commands},{c['identifier'] for c in cases})
            self.assertTrue(all(not Path(c[c.index('--output-path')+1]).exists() for c in commands))


class DiagnosticCollectionTests(unittest.TestCase):
    specs=m.SPECS+m.DIAGNOSTIC_SPECS[:2] # Preserve the original five-report compatibility fixture.
    def cases(self):
        return [{'identifier':'BlindAssistTests/'+key+'()','result':'Failed'} for key,_,_ in self.specs]
    def exporter(self,bundle,identifier,destination):
        key,name,label=next(spec for spec in self.specs if spec[0]==m.canonical(identifier))
        export_fixture(destination,name,diagnostic_report(label) if (key,name,label) in m.DIAGNOSTIC_SPECS else report(label))
    def collect(self,cases=None):
        with patch.object(m,'export_test',side_effect=self.exporter):
            return m.collect(ROOT,Path('unused'),self.cases() if cases is None else cases,u.query)
    def test_both_diagnostics_additive_failed_verdicts_and_source_hashes_preserved(self):
        result=self.collect()
        self.assertEqual(result['status'],'complete');self.assertEqual(len(result['reports']),5)
        self.assertTrue(all(row['testResult']=='Failed' and row['status']=='collected' for row in result['reports']))
        self.assertIn('ios/BlindAssistTests/SavedRoomRouteMeshAppleFixtureTests.swift',result['sourceSHA256'])
        self.assertIn('ios/BlindAssistTests/SavedRoomRouteCollisionOracleTests.swift',result['sourceSHA256'])
        self.assertLessEqual(result['rawAttachmentBytes'],m.LIMIT)
        legacy=self.collect(self.cases()[:3]);self.assertEqual(len(legacy['reports']),3)
        self.assertEqual(legacy['status'],'complete')
    def test_exact_diagnostic_identifiers_only_duplicate_never_exported(self):
        for key,_,_ in m.DIAGNOSTIC_SPECS:
            for invalid in ('Unknown/'+key,key+'Extra()',key+'/subcase'):
                with patch.object(m,'export_test') as tool:
                    result=m.collect(ROOT,Path('unused'),[{'identifier':invalid,'result':'Failed'}],u.query)
                    self.assertEqual(result['status'],'not_observed');tool.assert_not_called()
        cases=self.cases();result=self.collect(cases+[cases[-1]])
        self.assertEqual(result['status'],'incomplete')
        self.assertEqual(result['reports'][-1]['status'],'duplicate_test_case')
    def test_diagnostic_per_report_budget_and_private_errors_are_sanitized(self):
        original=m.exported_report
        def oversized(directory,name):
            raw=original(directory,name)
            return raw+b' '*m.DIAGNOSTIC_LIMIT if name==m.DIAGNOSTIC_SPECS[0][1] else raw
        with patch.object(m,'exported_report',side_effect=oversized):result=self.collect()
        self.assertEqual(result['reports'][3]['status'],'diagnostic_over_budget')
        self.assertTrue(all(row['status']=='collected' for row in result['reports'][:3]))
        def private(directory,name):
            raw=original(directory,name)
            if name!=m.DIAGNOSTIC_SPECS[0][1]: return raw
            data=json.loads(raw);data['fixtures'][0]['adapterFailure']='/Users/private/family-camera.jpg'
            return json.dumps(data).encode()
        with patch.object(m,'exported_report',side_effect=private):result=self.collect()
        self.assertEqual(result['reports'][3]['status'],'unapproved_error_text')
        self.assertNotIn('family-camera',json.dumps(result))
    def test_shared_aggregate_cap_not_increased_by_diagnostics(self):
        original=m.exported_report
        def padded(directory,name):
            raw=original(directory,name)
            size=330000 if name in {spec[1] for spec in m.SPECS} else (90000 if name==m.DIAGNOSTIC_SPECS[0][1] else len(raw))
            return raw+b' '*max(0,size-len(raw))
        with patch.object(m,'exported_report',side_effect=padded):result=self.collect()
        self.assertEqual(result['reports'][3]['status'],'aggregate_over_budget')
        self.assertLessEqual(result['rawAttachmentBytes'],m.LIMIT)
        self.assertEqual(result['aggregateByteLimit'],m.LIMIT)
    def test_final_artifact_budget_preserves_every_case_and_test_verdict(self):
        result={'schema':1,'complete':True,'target_pass_verified':False,'cases':self.cases(),'routeDiagnosticEvidence':self.collect()}
        for row in result['routeDiagnosticEvidence']['reports']:row['report']['oversized']='x'*300000
        encoded=u.encode_evidence(result);decoded=json.loads(encoded)
        self.assertLessEqual(len(encoded.encode()),m.LIMIT)
        self.assertEqual(decoded['cases'],self.cases());self.assertTrue(decoded['complete'])
        self.assertFalse(decoded['target_pass_verified'])
        self.assertTrue(all(row['testResult']=='Failed' and row['status']=='omitted_artifact_over_budget'
                            for row in decoded['routeDiagnosticEvidence']['reports']))
    def test_actual_status_main_keeps_five_failed_cases_and_zero_native_pass_claim(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);out=root/'unit-case-statuses.json';log=root/'unit.log';log.write_text('')
            cases=self.cases()
            (root/'unit-summary.json').write_text(json.dumps({'totalTestCount':5,'passedTests':0,'failedTests':5,'skippedTests':0,'expectedFailures':0}))
            raw=json.dumps({'testNodes':[{'nodeType':'Test Case','nodeIdentifier':case['identifier'],'result':case['result']} for case in cases]}).encode()
            source={'actual_head':'a'*40,'tracked_source_clean':True}
            with patch.object(sys,'argv',['exporter','unit.xcresult',str(log),str(out)]),patch.dict(os.environ,{'GITHUB_SHA':'a'*40}),\
                 patch.object(u,'provenance',return_value=source),patch.object(u,'query',return_value=raw),\
                 patch.object(u,'route_evidence',return_value=self.collect(cases)),contextlib.redirect_stdout(io.StringIO()):
                code=u.main()
            final=json.loads(out.read_text());self.assertEqual(code,0);self.assertTrue(final['complete'])
            self.assertFalse(final['target_pass_verified']);self.assertEqual(final['cases'],cases)
            self.assertEqual(final['counts']['Failed'],5)
            self.assertEqual(len(final['routeDiagnosticEvidence']['reports']),5)


class MeshParityEvidenceTests(unittest.TestCase):
    def capture(self):
        data = metadata_inventory()
        for fixture in data['fixtures']:
            bits = lambda values: [m.struct.unpack('<I', m.struct.pack('<f', value))[0] for value in values]
            identity = bits([1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1])
            points = bits([0,0,0, 1,0,0, 1,1,0, 0,1,0])
            fixture['meshParity'] = {'schema':'blind.public-apple-native-mesh-parity.v1',
                'representation':'raw-diagnostic-export','coordinateEncoding':'float32-bit-patterns-column-major',
                'winding':'ordered-native-triangle-indices','complete':True,'meshes':[{
                    'nodeIndex':1,'featureID':fixture['nodes'][1]['resolvedUUID'],
                    'localTransformBits':identity[:],'worldTransformBits':identity[:],
                    'localPositionBits':points[:],'worldPositionBits':points[:],'triangleIndices':[0,1,2,0,2,3]}]}
        return data
    def test_complete_numeric_capture_and_legacy_inventory_are_both_valid(self):
        for data in (self.capture(), metadata_inventory()):
            self.assertEqual(m.validate_metadata_inventory(data, UUIDS), data)
    def test_rejects_unknown_schema_authority_and_coordinate_semantics(self):
        changes = [('schema','other'),('representation','corrected-route-mesh'),('coordinateEncoding','float64'),
                   ('winding','silently-repaired'),('complete',False),('complete',1)]
        for field,value in changes:
            data=self.capture();data['fixtures'][0]['meshParity'][field]=value
            with self.subTest(field=field), self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
    def test_rejects_missing_duplicate_and_unknown_meshes(self):
        for mode in ('missing','duplicate','unknown','wrong-feature'):
            data=self.capture();rows=data['fixtures'][0]['meshParity']['meshes']
            if mode=='missing':rows.clear()
            elif mode=='duplicate':rows.append(copy.deepcopy(rows[0]))
            elif mode=='unknown':rows[0]['nodeIndex']=0
            else:rows[0]['featureID']='00000000-0000-0000-0000-000000000000'
            with self.subTest(mode=mode),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
    def test_rejects_invalid_float_words_and_lengths(self):
        for value in (-1,0x100000000,True,1.0,0x7f800000,0x7fc00000):
            data=self.capture();data['fixtures'][0]['meshParity']['meshes'][0]['localPositionBits'][0]=value
            with self.subTest(value=value),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
        for field in ('localTransformBits','worldTransformBits','localPositionBits','worldPositionBits'):
            data=self.capture();data['fixtures'][0]['meshParity']['meshes'][0][field].pop()
            with self.subTest(field=field),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
    def test_rejects_indices_and_world_local_disagreement(self):
        for indices in ([],[0,1],[0,1,4],[0,1,-1],[0,1,True],[0,1,1.0],[0,1,2]*1025):
            data=self.capture();data['fixtures'][0]['meshParity']['meshes'][0]['triangleIndices']=indices
            with self.subTest(indices=indices[:6]),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)
        data=self.capture();row=data['fixtures'][0]['meshParity']['meshes'][0]
        row['worldPositionBits'][0]=0x3f800000
        with self.assertRaisesRegex(m.EvidenceError,'world_local'):m.validate_metadata_inventory(data,UUIDS)
        data=self.capture();row=data['fixtures'][0]['meshParity']['meshes'][0];row['worldTransformBits'][15]=0
        with self.assertRaisesRegex(m.EvidenceError,'affine'):m.validate_metadata_inventory(data,UUIDS)
    def test_records_winding_instead_of_claiming_geometric_correctness(self):
        data=self.capture();row=data['fixtures'][0]['meshParity']['meshes'][0]
        row['triangleIndices']=[0,2,1,0,3,2]
        self.assertEqual(m.validate_metadata_inventory(data,UUIDS),data)
        # A source-frame scale mistake is retained for independent comparison;
        # an internally coherent numeric capture does not prove correct units.
        row['worldTransformBits'][0]=0x40000000
        row['worldPositionBits'][3]=row['worldPositionBits'][6]=0x40000000
        self.assertEqual(m.validate_metadata_inventory(data,UUIDS),data)
    def test_rejects_partial_capture_and_unapproved_extra_fields(self):
        for change in ('failure','extra','vertex-budget'):
            data=self.capture();fixture=data['fixtures'][0];row=fixture['meshParity']['meshes'][0]
            if change=='failure':fixture['inventoryFailure']='invalidMesh'
            elif change=='extra':row['privatePath']='not-allowed'
            else:fixture['nodes'][1]['vertexCount']=1025
            with self.subTest(change=change),self.assertRaises(m.EvidenceError):m.validate_metadata_inventory(data,UUIDS)


class MixedCollisionEvidenceTests(unittest.TestCase):
    def collect(self):
        specs=m.SPECS+m.DIAGNOSTIC_SPECS
        cases=[{'identifier':key+'()','result':'Failed'} for key,_,_ in specs]
        def exporter(bundle,identifier,destination):
            key,name,label=next(spec for spec in specs if spec[0]==m.canonical(identifier))
            export_fixture(destination,name,report(label) if (key,name,label) in m.SPECS else diagnostic_report(label))
        with patch.object(m,'export_test',side_effect=exporter):return m.collect(ROOT,Path('unused'),cases,u.query)
    def test_separate_schema_and_all_four_paired_cells(self):
        data=mixed_collision_matrix();self.assertEqual(m.validate_mixed_collision_matrix(data),data)
        with self.assertRaises(m.EvidenceError):m.validate_collision_matrix(data)
        with self.assertRaises(m.EvidenceError):m.validate_mixed_collision_matrix(collision_matrix())
        self.assertEqual(m.validate_collision_matrix(collision_matrix()),collision_matrix())
    def test_configuration_layout_masks_and_denominators_fixed(self):
        for key,value in [('layout','wall-and-floor'),('queryMode','separated'),('rendererMode','none'),
                          ('floorCategoryMask',4),('probeCategoryMask',True),('queryCollisionMasks',[True]),
                          ('queryCollisionMasks',[1,4]),('gravity',[0,1,0]),('physicsSpeed',0),
                          ('timeStepSeconds',1/30),('configurationID','private-room')]:
            data=mixed_collision_matrix();data['cells'][0][key]=value
            with self.subTest(key=key,value=value),self.assertRaises(m.EvidenceError):m.validate_mixed_collision_matrix(data)
        data=mixed_collision_matrix();data['cells'].reverse()
        with self.assertRaises(m.EvidenceError):m.validate_mixed_collision_matrix(data)
        data=mixed_collision_matrix();data['cells'][0]['queries'].pop()
        with self.assertRaises(m.EvidenceError):m.validate_mixed_collision_matrix(data)
    def test_fixed_identifiers_error_privacy_and_false_authority(self):
        for change in ('old_wall','public_uuid','bounds','path','private','authority','error_contacts'):
            data=mixed_collision_matrix();query=data['cells'][0]['queries'][0]
            if change=='old_wall':query['swept']['obstacleSurfaceIDs']=['00000000-0000-0000-0000-000000000001']
            elif change=='public_uuid':query['swept']['obstacleSurfaceIDs']=[sorted(UUIDS['Hallway2'])[0]]
            elif change=='bounds':query['initial']['furnitureBoundIDs']=['10000000-0000-0000-0000-000000000001']
            elif change=='path':query['errorCode']='/Users/private/family'
            elif change=='private':query['rawScene']='private'
            elif change=='authority':data['physicalAuthority']=True
            else:query.update(errorCode='invalidQuery',passed=False)
            with self.subTest(change=change),self.assertRaises(m.EvidenceError):m.validate_mixed_collision_matrix(data)
    def test_mixed_floor_observations_never_hide_failed_wall_or_endpoint(self):
        for index in range(6):
            data=mixed_collision_matrix();data['cells'][1]['queries'][index]['passed']=False
            with self.subTest(index=index),self.assertRaisesRegex(m.EvidenceError,'collision_pass_disagreement'):
                m.validate_mixed_collision_matrix(data)
        data=mixed_collision_matrix();cell=data['cells'][1];query=cell['queries'][0]
        query['swept']['obstacleSurfaceIDs']=[];query['passed']=False
        cell.update(backendReady=False,failedControls=['thinWallForward'])
        self.assertEqual(m.validate_mixed_collision_matrix(data),data) # floor remains; failed wall is not cleared
        cell['backendReady']=True
        with self.assertRaisesRegex(m.EvidenceError,'collision_readiness_disagreement'):m.validate_mixed_collision_matrix(data)
    def test_unexpected_wall_only_floor_is_retained_as_failure_not_success(self):
        data=mixed_collision_matrix();cell=data['cells'][0];query=cell['queries'][0]
        query['initial']['floorSurfaceIDs']=['10000000-0000-0000-0000-000000000002']
        with self.assertRaisesRegex(m.EvidenceError,'collision_pass_disagreement'):m.validate_mixed_collision_matrix(data)
        query['passed']=False;cell.update(backendReady=False,failedControls=['thinWallForward'])
        self.assertEqual(m.validate_mixed_collision_matrix(data),data)
    def test_optional_sixth_report_keeps_failed_status_and_existing_reports(self):
        result=self.collect()
        self.assertEqual(result['status'],'complete');self.assertEqual(len(result['reports']),6)
        self.assertTrue(all(row['testResult']=='Failed' and row['status']=='collected' for row in result['reports']))
        self.assertEqual(result['reports'][-1]['report'],mixed_collision_matrix())
        self.assertEqual(result['aggregateByteLimit'],m.LIMIT)
        self.assertLessEqual(result['rawAttachmentBytes'],m.LIMIT)
    def test_mixed_report_keeps_existing_per_report_and_shared_byte_caps(self):
        original=m.exported_report
        def oversized(directory,name):
            raw=original(directory,name)
            return raw+b' '*m.DIAGNOSTIC_LIMIT if name==m.DIAGNOSTIC_SPECS[-1][1] else raw
        with patch.object(m,'exported_report',side_effect=oversized):result=self.collect()
        self.assertEqual(result['reports'][-1]['status'],'diagnostic_over_budget')
        self.assertTrue(all(row['status']=='collected' for row in result['reports'][:-1]))
        def aggregate(directory,name):
            raw=original(directory,name)
            size=330000 if name in {spec[1] for spec in m.SPECS} else (65000 if name==m.DIAGNOSTIC_SPECS[-1][1] else len(raw))
            return raw+b' '*max(0,size-len(raw))
        with patch.object(m,'exported_report',side_effect=aggregate):result=self.collect()
        self.assertEqual(result['reports'][-1]['status'],'aggregate_over_budget')
        self.assertLessEqual(result['rawAttachmentBytes'],m.LIMIT)


if __name__=='__main__':unittest.main()

