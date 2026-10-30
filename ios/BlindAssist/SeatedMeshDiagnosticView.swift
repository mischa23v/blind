#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import SwiftUI
import SceneKit
import LiveMeshClassifiedBench

struct SeatedMeshDiagnosticView: View {
    @ObservedObject var model: NavigationModel
    @State private var entryError: String?
    @State private var confirming = false
    @State private var viewID: UUID?
    @State private var confirmationID: UUID?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(LiveMeshBenchSession.requiredWarning).font(.headline)
                    .accessibilityIdentifier("seated-mesh-warning")
                Text("Helper-only test. Actual live source mesh, not a saved-room replacement. No photos, geometry or logs are uploaded or saved. Stop or leave this page to erase the display. Normal camera stays stopped afterward.")
                if let controller = model.seatedMeshDiagnostic {
                    SeatedMeshDiagnosticDisplay(controller: controller)
                } else {
                    Button("I am seated with a helper — review camera handoff") {
                        guard let viewID, let confirmation = model.confirmSeatedMeshDiagnostic(viewID: viewID) else { return }
                        confirmationID = confirmation; confirming = true
                    }
                        .frame(minHeight: 44).accessibilityIdentifier("seated-mesh-start")
                    Button("Explicitly resume normal camera") { if let viewID { model.resumeNormalCameraAfterMeshDiagnostic(viewID: viewID) } }
                        .frame(minHeight: 44).accessibilityIdentifier("seated-mesh-resume-normal")
                }
                if let entryError { Text(entryError).accessibilityIdentifier("seated-mesh-entry-reason") }
            }.padding()
        }
        .navigationTitle("Seated mesh diagnostic")
        .confirmationDialog("Phone hazard monitoring will stop. Stay seated; this is not walking guidance.", isPresented: $confirming, titleVisibility: .visible) {
            Button("Start seated mesh diagnostic") {
                guard let viewID, let confirmationID else { return }
                entryError = model.beginSeatedMeshDiagnostic(viewID: viewID, confirmationID: confirmationID)
                self.confirmationID = nil
            }
            Button("Cancel", role: .cancel) { model.cancelSeatedMeshDiagnosticConfirmation(); confirmationID = nil }
        }
        .onAppear { viewID = model.openSeatedMeshDiagnosticView() }
        .onDisappear {
            if let viewID { model.closeSeatedMeshDiagnosticView(viewID) }
            viewID = nil; confirmationID = nil; confirming = false
        }
    }
}
private struct SeatedMeshDiagnosticDisplay: View {
    @ObservedObject var controller: SeatedMeshDiagnosticController
    @State private var start = ""
    @State private var goal = ""
    @State private var radius = "0.3"
    @State private var height = "1.7"
    @State private var useDeclaredFoot = false
    @State private var mount = ""
    @State private var yaw = ""
    @State private var confirmed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Stop diagnostic and erase geometry", role: .destructive) { controller.stop() }
                .frame(minHeight: 44).accessibilityIdentifier("seated-mesh-stop")
            Text(controller.renderReceipt).textSelection(.enabled).accessibilityIdentifier("seated-mesh-render-receipt")
            Text(controller.sourceReceipt).textSelection(.enabled).accessibilityIdentifier("seated-mesh-source-receipt")
            Text("Scale reference: 1 coordinate unit = 1 metre. The viewport fits the source bounds; orbit and zoom only change the view, never geometry scale. Numeric bounds are source extents, not measured passage clearance.")
                .accessibilityIdentifier("seated-mesh-metre-scale")
            Text(controller.meshBoundsReceipt).textSelection(.enabled).accessibilityIdentifier("seated-mesh-source-bounds")
            Text(controller.producerReceipt).accessibilityIdentifier("seated-mesh-producer-receipt")
            Button("Refresh current tracked-frame anchors — bounded 8 seconds") { controller.reacquire() }
                .frame(minHeight: 44).disabled(controller.stopped).accessibilityIdentifier("seated-mesh-refresh")
            if let scene = controller.scene {
                SceneView(scene: scene, options: [.allowsCameraControl])
                    .frame(height: 280).accessibilityHidden(true)
                Text("Actual source wireframe. Purple: normalized floor role, not verified support. Orange: obstacle role. Gray: unavailable role. Cyan: source-only preview, never a safe walking route. Raw ARKit class labels are unavailable. Drag to inspect the model, not to select a location.")
            }
            Text("Supplied test coordinates only — session-local X Y Z, metres. No camera-to-body assumption. Radius and height are declared query parameters, not measured clearance.").font(.headline)
            Toggle("Use UNVALIDATED camera + declared mount candidate", isOn: $useDeclaredFoot)
            if useDeclaredFoot {
                Text("Seated diagnostic only. Declare camera offset from floor below body centre: right, up, forward in metres. Body yaw is session-world: 0 faces -Z, +90 faces -X. Camera yaw is NOT body yaw. Yellow dot is the requested candidate, not verified feet.")
                TextField("Camera right up forward offsets (metres)", text: $mount).textFieldStyle(.roundedBorder)
                TextField("Declared body yaw (-180 to 180 degrees)", text: $yaw).textFieldStyle(.roundedBorder)
                Toggle("Helper reviewed these unvalidated declarations", isOn: $confirmed)
            }
            TextField("Start X Y Z (metres)", text: $start).textFieldStyle(.roundedBorder).accessibilityIdentifier("seated-mesh-start-point")
            TextField("Goal X Y Z (metres)", text: $goal).textFieldStyle(.roundedBorder).accessibilityIdentifier("seated-mesh-goal-point")
            TextField("Declared radius (metres)", text: $radius).textFieldStyle(.roundedBorder)
            TextField("Declared height (metres)", text: $height).textFieldStyle(.roundedBorder)
            Button("Request source-only strict preview") { controller.requestPreview(startText: start, goalText: goal, radiusText: radius, heightText: height, declaredMountText: useDeclaredFoot ? mount : nil, declaredYawText: useDeclaredFoot ? yaw : nil, confirmed: confirmed) }
                .frame(minHeight: 44).disabled(controller.stopped).accessibilityIdentifier("seated-mesh-preview")
            Text(controller.footReceipt).textSelection(.enabled).accessibilityIdentifier("seated-mesh-foot-candidate")
            Text(controller.routeReceipt).textSelection(.enabled).accessibilityIdentifier("seated-mesh-route-receipt")
            DisclosureGroup("Diagnostic path coordinates — up to first 256 points, not walking instructions") {
                ForEach(Array(controller.routePointReceipts.enumerated()), id: \.offset) { _, receipt in Text(receipt).textSelection(.enabled) }
            }
            DisclosureGroup("Anchor delivery receipts (not capture freshness)") {
                ForEach(Array(controller.anchorReceipts.enumerated()), id: \.offset) { _, receipt in Text(receipt).textSelection(.enabled) }
            }
        }
        .onChange(of: useDeclaredFoot) { _ in confirmed = false; controller.retirePreview() }
        .onChange(of: mount) { _ in confirmed = false; controller.retirePreview() }
        .onChange(of: yaw) { _ in confirmed = false; controller.retirePreview() }
        .onChange(of: confirmed) { _ in controller.retirePreview() }
        .onChange(of: start) { _ in controller.retirePreview() }
        .onChange(of: goal) { _ in controller.retirePreview() }
        .onChange(of: radius) { _ in controller.retirePreview() }
        .onChange(of: height) { _ in controller.retirePreview() }
    }
}
#endif
