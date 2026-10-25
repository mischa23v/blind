import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {generateProject} from '../generate-xcode-project.mjs';
import {verifyFamiliarProject} from '../ci/verify-familiar-project.mjs';
const id = name => createHash('sha256').update(name).digest('hex').slice(0,24).toUpperCase();
const files=['FamiliarFaceExperiment.swift','FamiliarFaceStore.swift','FamiliarPeopleView.swift','FamiliarModelConfiguration.swift','FamiliarVisionComparison.swift'];
const options={familiarPeople:true,familiarBackend:'sface',opencvFramework:'/private/assets/opencv2.framework',familiarModels:'/private/assets/models'};
// Minimal source-contract fixtures exercise build admission only, never consent behavior or accuracy.
const sources={
  'BlindCore/Sources/BlindCore/FamiliarEnrollmentConsent.swift':'guardianForChild guardian-consenting-child-v1',
  'ios/BlindAssist/FamiliarFaceExperiment.swift':'guardianToken == confirmationToken guard requiresGuardianAttestation, guardianAttested, let guardianToken',
  'ios/BlindAssist/FamiliarPeopleView.swift':'guardianToken: shownToken familiar-guardian-enrollment',
  'ios/BlindAssist/FamiliarNative/OPENCV_NOTICES.txt':'OpenCV test notice fixture',
};
const project=generateProject(files,options);
test('face build has both configurations, native bridge, resources and consent source contract',()=>assert.equal(verifyFamiliarProject(project,sources),true));
for(const key of ['build:FamiliarFaceExperiment.swift','build:face-native','build:face-opencv-notice','build:face-model:face_recognition_sface_2021dec.onnx','build:opencv']) {
 test(`removed ${key} rejects`,()=>assert.throws(()=>verifyFamiliarProject(project.replaceAll(id(key),'000000000000000000000000'),sources)));
}
test('missing Swift flag rejects',()=>assert.throws(()=>verifyFamiliarProject(project.replaceAll('BLIND_FAMILIAR_PEOPLE','MISSING_FACE_FLAG'),sources)));
test('missing native flag rejects',()=>assert.throws(()=>verifyFamiliarProject(project.replaceAll('BLIND_FAMILIAR_PEOPLE=1','MISSING_NATIVE_FLAG'),sources)));
test('missing guardian Core rejects',()=>assert.throws(()=>verifyFamiliarProject(project,{...sources,'BlindCore/Sources/BlindCore/FamiliarEnrollmentConsent.swift':''})));
test('missing shown-token binding rejects',()=>assert.throws(()=>verifyFamiliarProject(project,{...sources,'ios/BlindAssist/FamiliarPeopleView.swift':'familiar-guardian-enrollment'})));
test('default project still lacks face flag/resources',()=>{const ordinary=generateProject(files);assert.ok(!ordinary.includes('BLIND_FAMILIAR_PEOPLE'));assert.ok(!ordinary.includes('OPENCV_NOTICES'));});

test('wrong native source path rejects',()=>assert.throws(()=>verifyFamiliarProject(project.replace('FamiliarNative/BAFaceEngine.mm','FamiliarNative/Other.mm'),sources)));
test('wrong copied notice path rejects',()=>assert.throws(()=>verifyFamiliarProject(project.replace('FamiliarNative/OPENCV_NOTICES.txt','FamiliarNative/Missing.txt'),sources)));
