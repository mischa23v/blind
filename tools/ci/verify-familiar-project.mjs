// Build-membership checks, not runtime recognition or consent-UI validation.
import {createHash} from 'node:crypto';
const id = name => createHash('sha256').update(name).digest('hex').slice(0,24).toUpperCase();
export function verifyFamiliarProject(project, sources) {
  const object = name => {
    const match = project.match(new RegExp(`${id(name)} = \\{ ([^\\n]+) \\};`));
    if (!match) throw Error(`Missing project object: ${name}`);
    return match[1];
  };
  const member = (phase, key) => {
    if (!object(phase).includes(id(key))) throw Error(`Missing ${phase} membership: ${key}`);
    object(key);
  };
  for (const file of ['FamiliarFaceExperiment.swift','FamiliarFaceStore.swift','FamiliarPeopleView.swift','FamiliarModelConfiguration.swift','FamiliarVisionComparison.swift']) {
    member('sources', `build:${file}`);
    if (!object(`build:${file}`).includes(id(file))) throw Error(`Wrong source reference: ${file}`);
  }
  const linkedFile = (build, reference, path) => {
    if (!object(build).includes(`fileRef = ${id(reference)};`) || !object(reference).includes(path)) throw Error(`Wrong file reference: ${build}`);
  };
  member('sources','build:face-native');
  linkedFile('build:face-native','face-native','BlindAssist/FamiliarNative/BAFaceEngine.mm');
  linkedFile('build:face-notice','face-notice','BlindAssist/FamiliarNative/MODEL_NOTICES.txt');
  linkedFile('build:face-opencv-notice','face-opencv-notice','BlindAssist/FamiliarNative/OPENCV_NOTICES.txt');
  for (const name of ['face_detection_yunet_2023mar.onnx','face_recognition_sface_2021dec.onnx']) linkedFile(`build:face-model:${name}`,`face-model:${name}`,`/${name}`);
  linkedFile('build:opencv','opencv-framework','/opencv2.framework');
  for (const key of ['build:face-notice','build:face-opencv-notice','build:face-model:face_detection_yunet_2023mar.onnx','build:face-model:face_recognition_sface_2021dec.onnx']) member('resources',key);
  member('frameworks','build:opencv');
  for (const name of ['Debug','Release']) {
    const settings=object(name);
    if (!/SWIFT_ACTIVE_COMPILATION_CONDITIONS = "[^"\n]*\bBLIND_FAMILIAR_PEOPLE\b/.test(settings) || !settings.includes('"BLIND_FAMILIAR_PEOPLE=1"')) throw Error(`Missing familiar Swift/native flags: ${name}`);
    if (!settings.includes('BlindAssist/FamiliarNative/BlindAssist-Bridging-Header.h')) throw Error(`Wrong familiar bridging header: ${name}`);
  }
  if (project.includes('BLIND_FAMILIAR_AURAFACE')) throw Error('Expected pinned SFace build');
  if (!object('package').includes('../BlindCore')) throw Error('Missing local consent Core package');
  const required = {
    'BlindCore/Sources/BlindCore/FamiliarEnrollmentConsent.swift':['guardianForChild','guardian-consenting-child-v1'],
    'ios/BlindAssist/FamiliarFaceExperiment.swift':['guardianToken == confirmationToken','guard requiresGuardianAttestation, guardianAttested, let guardianToken'],
    'ios/BlindAssist/FamiliarPeopleView.swift':['guardianToken: shownToken','familiar-guardian-enrollment'],
    'ios/BlindAssist/FamiliarNative/OPENCV_NOTICES.txt':['OpenCV'],
  };
  for (const [path,tokens] of Object.entries(required)) for (const token of tokens) {
    if (!sources[path]?.includes(token)) throw Error(`Required source/notices absent: ${path}`);
  }
  return true;
}
