// Native API probe only. No routing, no physical authority, no private input.
// Run on a standard public macOS runner: swift scnshape_probe.swift
import Foundation
import AppKit
import SceneKit
import SceneKit.ModelIO
import ModelIO

func inventory(_ geometry: SCNGeometry) -> [String: Any] {
    let sources = geometry.sources(for: .vertex)
    return [
        "sourceCount": sources.count,
        "sources": sources.prefix(8).map { source -> [String: Any] in
            ["vectorCount": source.vectorCount,
             "floatComponents": source.usesFloatComponents,
             "componentsPerVector": source.componentsPerVector,
             "bytesPerComponent": source.bytesPerComponent,
             "dataOffset": source.dataOffset,
             "dataStride": source.dataStride,
             "dataByteCount": source.data.count,
             "dataBase64": source.data.count <= 4096 ? source.data.base64EncodedString() : "omitted-over-bound"]
        },
        "elementCount": geometry.elements.count,
        "elements": geometry.elements.prefix(8).map { element -> [String: Any] in
            ["primitiveType": element.primitiveType.rawValue,
             "primitiveCount": element.primitiveCount,
             "bytesPerIndex": element.bytesPerIndex,
             "dataByteCount": element.data.count,
             "dataBase64": element.data.count <= 4096 ? element.data.base64EncodedString() : "omitted-over-bound"]
        }
    ]
}
let square: [[Double]] = [[-1,-1],[1,-1],[1,1],[-1,1]]
let cases: [(String, [[Double]])] = [
    ("square-counterclockwise", square),
    ("square-clockwise", Array(square.reversed())),
    ("concave", [[-1,-1],[1,-1],[1,0],[0,0],[0,1],[-1,1]])
]
var rows: [[String: Any]] = []
for (name, points) in cases {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: points[0][0], y: points[0][1]))
    for point in points.dropFirst() { path.line(to: NSPoint(x: point[0], y: point[1])) }
    path.close()
    let shape = SCNShape(path: path, extrusionDepth: 0)
    shape.chamferRadius = 0
    let direct = inventory(shape)
    let mesh = MDLMesh(scnGeometry: shape)
    let converted = SCNGeometry(mdlMesh: mesh)
    rows.append(["case": name, "sourcePolygon": points,
                 "direct": direct, "afterModelIOConversion": inventory(shape),
                 "modelIOVertexCount": mesh.vertexCount,
                 "modelIOSubmeshCount": mesh.submeshes?.count ?? 0,
                 "roundTrip": inventory(converted)])
}
let report: [String: Any] = [
    "schema": "blind.synthetic-scnshape-buffer-probe.v1",
    "scope": "macOS synthetic platform buffer probe; iOS native validation remains required",
    "physicalAuthority": false,
    "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
    "cases": rows
]
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
