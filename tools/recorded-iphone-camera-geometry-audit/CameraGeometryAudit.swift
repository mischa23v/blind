import Foundation
import BlindCore
import NativeDepthPolicySupport

// Recorded camera-frame arithmetic only. No Observation, detector, pose, tracking,
// gravity, body, mount, map, goal, route or controller is supplied or constructed.
private struct Manifest: Decodable { let frames: [FrameInput] }
private struct FrameInput: Decodable {
    let id, width, height, imageWidth, imageHeight: Int
    let depthPath, confidencePath: String
    let fx, fy, cx, cy: Float
    let originalRelativeTimestamp: Double
}
private struct Intrinsics: Encodable {
    let fx, fy, cx, cy: Double
    init(_ p: DepthProjection) { fx=p.fx; fy=p.fy; cx=p.cx; cy=p.cy }
}
private struct RaySpan: Encodable {
    let leftEdgeDegrees, rightEdgeDegrees, topEdgeDegrees, bottomEdgeDegrees: Double
    let horizontalDegrees, verticalDegrees: Double
}
private struct FrameResult: Encodable {
    let frameID: Int
    let originalRelativeTimestamp: Double
    let fullRasterPixels, attemptedStridePixels, scalarAdmitted, projectedPoints: Int
    let rejectedConfidence0, rejectedConfidence1, rejectedOtherConfidence, rejectedDepth: Int
    let originalRGBIntrinsics, actualSharedDepthIntrinsics: Intrinsics
    let rgbPixelCentreSpan, depthPixelCentreSpan, admittedRayEnvelope: RaySpan
    let maxRoundTripPixelResidual, maxRoundTripDepthResidual: Double
    let pointFile: String
    let cameraRelativeOnly = true, physicalAuthority = false, worldProjectionExecuted = false
}
private struct Probe: Encodable { let name: String; let maxCoordinateError, maxIntrinsicError: Double }
private struct Summary: Encodable {
    let scope = "camera-relative numerical geometry and recorded-ray diagnostics only; not physical accuracy, obstacle detection, clearance or navigation"
    let tracking = "unknown and unused"
    let posesUsed = false, gravityUsed = false, bodyUsed = false, physicalAuthority = false
    let goldenProbes: [Probe]
    let frames: [FrameResult]
}
private enum AuditError: Error { case invalidArguments, invalidInput, invalidCalibration, goldenMismatch, unexpectedAdmission, invalidPoint, roundTripMismatch }

private func validate(_ p: DepthProjection) throws {
    guard [p.fx,p.fy,p.cx,p.cy].allSatisfy(\.isFinite), p.fx>0, p.fy>0 else { throw AuditError.invalidCalibration }
}
private func span(_ p: DepthProjection, width: Int, height: Int) -> RaySpan {
    let k = 180.0 / Double.pi
    let left = atan((0-p.cx)/p.fx)*k, right = atan((Double(width-1)-p.cx)/p.fx)*k
    let top = atan(p.cy/p.fy)*k, bottom = -atan((Double(height-1)-p.cy)/p.fy)*k
    return RaySpan(leftEdgeDegrees:left,rightEdgeDegrees:right,topEdgeDegrees:top,bottomEdgeDegrees:bottom,
                   horizontalDegrees:right-left,verticalDegrees:top-bottom)
}
private func golden(_ name: String, raw: [Float], image: [Int], depth: [Int], uv: [Double], expectedK: [Double], expectedP: [Double]) throws -> Probe {
    let p=NativeDepthObservationPolicy.projection(fx:raw[0],fy:raw[1],cx:raw[2],cy:raw[3],
        depthWidth:depth[0],depthHeight:depth[1],imageWidth:Double(image[0]),imageHeight:Double(image[1]))
    try validate(p)
    let k=[p.fx,p.fy,p.cx,p.cy], ke=zip(k,expectedK).map{abs($0-$1)}.max()!
    guard uv.allSatisfy(\.isFinite), uv[0]>=0, uv[0]<Double(depth[0]), uv[1]>=0, uv[1]<Double(depth[1]),
          let q=p.cameraPoint(column:uv[0],row:uv[1],depth:2),q.isFinite else { throw AuditError.invalidPoint }
    let pe=zip([q.x,q.y,q.z],expectedP).map{abs($0-$1)}.max()!
    guard ke<=1e-10,pe<=1e-10 else { throw AuditError.goldenMismatch }
    return Probe(name:name,maxCoordinateError:pe,maxIntrinsicError:ke)
}

@main private enum Audit {
    static func main() throws {
        guard CommandLine.arguments.count==3 else { throw AuditError.invalidArguments }
        let input=try JSONDecoder().decode(Manifest.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
        let destination=URL(fileURLWithPath:CommandLine.arguments[2],isDirectory:true)
        guard input.frames.map(\.id)==Array(0..<8),NativeDepthObservationPolicy.pixelStride==2 else { throw AuditError.invalidInput }
        let probes = try [
            golden("reference",raw:[100,100,50,40],image:[100,80],depth:[100,80],uv:[60,45],expectedK:[100,100,50,40],expectedP:[0.2,-0.1,-2]),
            golden("asymmetric_offcentre",raw:[120,80,17,23],image:[100,80],depth:[100,80],uv:[29,31],expectedK:[120,80,17,23],expectedP:[0.2,-0.2,-2]),
            golden("unequal_resolution_scales",raw:[300,200,90,68],image:[300,200],depth:[150,50],uv:[60,22],expectedK:[150,50,45,17],expectedP:[0.2,-0.2,-2]),
            golden("principal_ray",raw:[120,80,17,23],image:[100,80],depth:[100,80],uv:[17,23],expectedK:[120,80,17,23],expectedP:[0,0,-2]),
            golden("left_and_up",raw:[120,80,17,23],image:[100,80],depth:[100,80],uv:[5,15],expectedK:[120,80,17,23],expectedP:[-0.2,0.2,-2])]
        let expectedAdmissions=[4278,4296,4037,3692,3568,3878,3828,4071]
        var results:[FrameResult]=[]
        for f in input.frames {
            guard f.width==256,f.height==192,f.imageWidth==1920,f.imageHeight==1440,
                  f.originalRelativeTimestamp.isFinite,[f.fx,f.fy,f.cx,f.cy].allSatisfy(\.isFinite),f.fx>0,f.fy>0 else { throw AuditError.invalidInput }
            let depths=try Data(contentsOf:URL(fileURLWithPath:f.depthPath)),confidence=try Data(contentsOf:URL(fileURLWithPath:f.confidencePath))
            guard depths.count==f.width*f.height*4,confidence.count==f.width*f.height else { throw AuditError.invalidInput }
            let p=NativeDepthObservationPolicy.projection(fx:f.fx,fy:f.fy,cx:f.cx,cy:f.cy,depthWidth:f.width,depthHeight:f.height,
                imageWidth:Double(f.imageWidth),imageHeight:Double(f.imageHeight));try validate(p)
            let rgb=DepthProjection(fx:Double(f.fx),fy:Double(f.fy),cx:Double(f.cx),cy:Double(f.cy))
            var attempted=0,admitted=0,projected=0,c0=0,c1=0,co=0,dr=0
            var maxPixel=0.0,maxDepth=0.0,minH=Double.infinity,maxH = -Double.infinity,minV=Double.infinity,maxV = -Double.infinity
            var csv="frame,row,column,original_depth_m,original_confidence,x_camera_m,y_camera_m,z_camera_m\n"
            for row in stride(from:0,to:f.height,by:NativeDepthObservationPolicy.pixelStride) {
                for col in stride(from:0,to:f.width,by:NativeDepthObservationPolicy.pixelStride) {
                    let index=row*f.width+col,o=index*4
                    let bits=UInt32(depths[o]) | UInt32(depths[o+1])<<8 | UInt32(depths[o+2])<<16 | UInt32(depths[o+3])<<24
                    let d=Float(bitPattern:bits),c=confidence[index];attempted+=1
                    guard let accepted=NativeDepthObservationPolicy.acceptedDepth(d,confidence:c) else {
                        if c==0 { c0+=1 } else if c==1 { c1+=1 } else if c != 2 { co+=1 } else { dr+=1 };continue
                    }
                    admitted+=1
                    let u=Double(col),v=Double(row)
                    guard u.isFinite,v.isFinite,u>=0,u<Double(f.width),v>=0,v<Double(f.height),accepted==Double(d),
                          let q=p.cameraPoint(column:u,row:v,depth:accepted),q.isFinite,q.z<0 else { throw AuditError.invalidPoint }
                    let backDepth = -q.z,backU=p.fx*q.x/backDepth+p.cx,backV=p.cy-p.fy*q.y/backDepth
                    let pixelError=max(abs(backU-u),abs(backV-v)),depthError=abs(backDepth-accepted)
                    guard backU.isFinite,backV.isFinite,pixelError<=1e-8,depthError<=1e-12 else { throw AuditError.roundTripMismatch }
                    maxPixel=max(maxPixel,pixelError);maxDepth=max(maxDepth,depthError);projected+=1
                    let h=atan(q.x/backDepth)*180/Double.pi,vangle=atan(q.y/backDepth)*180/Double.pi
                    minH=min(minH,h);maxH=max(maxH,h);minV=min(minV,vangle);maxV=max(maxV,vangle)
                    csv += "\(f.id),\(row),\(col),\(accepted),\(c),\(q.x),\(q.y),\(q.z)\n"
                }
            }
            guard attempted==12288,admitted==expectedAdmissions[f.id],projected==admitted,
                  admitted+c0+c1+co+dr==attempted else { throw AuditError.unexpectedAdmission }
            let name="frame-\(f.id)-camera-points.csv"
            try Data(csv.utf8).write(to:destination.appendingPathComponent(name),options:.withoutOverwriting)
            let envelope=RaySpan(leftEdgeDegrees:minH,rightEdgeDegrees:maxH,topEdgeDegrees:maxV,bottomEdgeDegrees:minV,
                horizontalDegrees:maxH-minH,verticalDegrees:maxV-minV)
            results.append(FrameResult(frameID:f.id,originalRelativeTimestamp:f.originalRelativeTimestamp,fullRasterPixels:f.width*f.height,
                attemptedStridePixels:attempted,scalarAdmitted:admitted,projectedPoints:projected,rejectedConfidence0:c0,rejectedConfidence1:c1,
                rejectedOtherConfidence:co,rejectedDepth:dr,originalRGBIntrinsics:Intrinsics(rgb),actualSharedDepthIntrinsics:Intrinsics(p),
                rgbPixelCentreSpan:span(rgb,width:f.imageWidth,height:f.imageHeight),depthPixelCentreSpan:span(p,width:f.width,height:f.height),
                admittedRayEnvelope:envelope,maxRoundTripPixelResidual:maxPixel,maxRoundTripDepthResidual:maxDepth,pointFile:name))
        }
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(Summary(goldenProbes:probes,frames:results)));FileHandle.standardOutput.write(Data([10]))
    }
}
