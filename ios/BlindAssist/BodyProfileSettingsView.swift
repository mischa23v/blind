import SwiftUI
import BlindCore

/// Optional helper destination, never a first-screen task mode or onboarding gate.
@MainActor struct BodyProfileSettingsView: View {
    let onGeometryChange: () -> Void
    @State private var profile: LocalBodyProfile?
    @State private var age = ""
    @State private var gender = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var width = ""
    @State private var depth = ""
    @State private var right = ""
    @State private var up = ""
    @State private var forward = ""
    @State private var radial = ""
    @State private var overhead = ""
    @State private var status = ""
    @State private var confirmErase = false
    @State private var store = BodyProfileStore.shared
    @State private var busy = false
    @State private var operation = UUID()
    var body: some View {
        Form {
            Section("Optional body profile") {
                number("Age in years (optional)", text: $age)
                TextField("Gender (optional, your own words)", text: $gender)
                    .accessibilityIdentifier("body-profile-gender")
                number("Weight in kilograms (optional)", text: $weight)
                number("Height in centimetres (optional)", text: $height)
                Text("These fields stay on this phone. Gender does not determine body shape. Reported age does not verify age or guardian presence.").font(.footnote)
            }
            Section("Reported full-body bounds") {
                number("Maximum body width in centimetres", text: $width)
                number("Maximum body depth in centimetres", text: $depth)
                Text("Include the widest and deepest parts of the whole body, not only the chest. Leave unknown values blank. Helper-entered dimensions are reported, not a validated scan.").font(.footnote)
            }
            Section("Chest-mounted phone offset") {
                number("Camera right of body centre, centimetres", text: $right)
                number("Camera above floor, centimetres", text: $up)
                number("Camera forward of body centre, centimetres", text: $forward)
                Text("Left and behind are negative. A chest holder is intended; entering offsets does not calibrate the camera or confirm the mount is secure.").font(.footnote)
            }
            Section("Clothing and carried equipment") {
                number("Extra radial extent, centimetres", text: $radial)
                number("Extra overhead extent, centimetres", text: $overhead)
                Text("Include hands, clothing, backpack, carried objects and cane sweep. Blank means unknown, not zero. These simple bounds cannot describe every movement.").font(.footnote)
            }
            Section {
                Button("Save on this phone", action: save).disabled(profile == nil || busy)
                    .accessibilityIdentifier("body-profile-save")
                Button("Delete body profile", role: .destructive) { confirmErase = true }
                    .accessibilityIdentifier("body-profile-delete")
                if !status.isEmpty { Text(status).accessibilityIdentifier("body-profile-status") }
                Text("Approximate preview only. No entry here proves that a doorway or overhead space is clear. Validated scanning, chest calibration, floor support and current obstacle coverage remain unavailable. Geometry changes pause guidance for fresh evidence; name and conversation memory are unchanged.").font(.footnote)
            }
        }.navigationTitle("Body and chest holder")
            .task { load() }
            .confirmationDialog("Delete the local body profile?", isPresented: $confirmErase) {
                Button("Delete body profile", role: .destructive) {
                    onGeometryChange(); operation = UUID(); let requested = operation; busy = true
                    store.erase { result in
                        guard operation == requested else { return }
                        busy = false
                        switch result {
                        case .success: load(); status = "Body profile deleted. Conversation memory is unchanged."
                        case .failure: status = "Deletion could not be confirmed. Guidance remains paused. Retry after unlocking."
                        }
                    }
                }
            }
    }
    private func number(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text).keyboardType(.numbersAndPunctuation).accessibilityLabel(label)
    }
    private func value(_ text: String, centimetres: Bool = false) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let number = Double(trimmed), number.isFinite else { throw BodyProfileError.invalidInput }
        return centimetres ? BodyProfileInput.metres(centimetres: number) : number
    }
    private func text(_ number: Double?, centimetres: Bool = false) -> String {
        number.map { String($0 * (centimetres ? 100 : 1)) } ?? ""
    }
    private func load() {
        operation = UUID(); let requested = operation; busy = true
        store.load { result in
            guard operation == requested else { return }
            busy = false
            guard case .success(let loaded) = result, let p = loaded else {
                profile = nil; status = "Body profile could not be read. Unlock and reopen, or delete it to start again."; return
            }
            profile = p
            age = text(p.input.ageYears); gender = p.input.gender ?? ""; weight = text(p.input.weightKilograms)
            height = text(p.input.heightMetres, centimetres: true)
            let d = p.dimensions.first { $0.source == .reported }
            width = text(d?.width, centimetres: true); depth = text(d?.depth, centimetres: true)
            right = text(p.mount.right, centimetres: true); up = text(p.mount.up, centimetres: true); forward = text(p.mount.forward, centimetres: true)
            radial = text(p.equipment.radialExtension, centimetres: true); overhead = text(p.equipment.overheadExtension, centimetres: true)
        }
    }
    private func save() {
        guard let previous = profile, !busy else { return }
        var next = previous
        do {
            let input = try BodyProfileInput(ageYears: value(age), gender: gender.isEmpty ? nil : gender,
                weightKilograms: value(weight), heightMetres: value(height, centimetres: true))
            let mount = try ChestMountMetadata(right: value(right, centimetres: true), up: value(up, centimetres: true), forward: value(forward, centimetres: true))
            let equipment = try BodyEquipmentBounds(radialExtension: value(radial, centimetres: true), overheadExtension: value(overhead, centimetres: true))
            try next.update(input: input, mount: mount, equipment: equipment)
            let w = try value(width, centimetres: true), d = try value(depth, centimetres: true)
            if w != nil || d != nil {
                guard let w, let d, let h = input.heightMetres else { throw BodyProfileError.invalidDimension }
                let old = next.dimensions.first { $0.source == .reported }
                if old?.width != w || old?.depth != d || old?.height != h {
                    // Missing uncertainty stays unknown, never zero-error certification.
                    try next.record(.init(height: h, width: w, depth: d, uncertainty: nil, source: .reported,
                        provenance: "local helper entry; uncertainty unverified", recordedAt: Date().timeIntervalSince1970,
                        profileRevision: next.measurementBasisRevision), replacingGeometryRevision: next.geometryRevision)
                }
            } else if next.dimensions.contains(where: { $0.source == .reported }) {
                // Clearing the UI dimensions really removes the saved dimensions.
                next = try LocalBodyProfile(input: input, mount: mount, equipment: equipment)
            }
            if next.geometryRevision != profile?.geometryRevision { onGeometryChange() }
            operation = UUID(); let requested = operation; busy = true
            store.save(next, replacing: previous.revision) { result in
                guard operation == requested else { return }
                busy = false
                switch result {
                case .success(let saved):
                    profile = saved
                    status = "Saved locally. Preview only; measured collision clearance is unavailable."
                case .failure:
                    status = "Save could not be confirmed. Reopen the profile and retry. Guidance remains paused."
                }
            }
        } catch { status = "Not saved. Use finite numbers in the labelled units, or leave unknown fields blank. Width and depth also need height. Guidance may be paused until fresh evidence is available." }
    }
}
