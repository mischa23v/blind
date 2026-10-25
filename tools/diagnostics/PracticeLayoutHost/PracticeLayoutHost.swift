import SwiftUI
import UIKit

// Synthetic, dependency-free comparison host; never links the production app.
private enum Copy {
    static let button = "Try practice (2 minutes)"
    static let header = "Practice"
    static let footer = "Practice pauses live sensors and ends by itself after two minutes. Live monitoring resumes only if the camera control is on, and requires calibration. Keep using your cane or guide dog."
}

@main
struct PracticeLayoutHostApp: App {
    var body: some Scene {
        WindowGroup {
            ComparisonView()
                .preferredColorScheme(.dark)
                .tint(Color(red: 1, green: 0.8, blue: 0.33))
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}

private struct ComparisonView: View {
    private let variant = ProcessInfo.processInfo.environment["COMPARISON_VARIANT"] ?? "INVALID"
    var body: some View {
        NavigationStack {
            content.navigationTitle("Camera and safety")
        }
        .onAppear {
            precondition(["A", "B", "C"].contains(variant), "Explicit comparison variant required")
            let expected = ProcessInfo.processInfo.environment["COMPARISON_CATEGORY"]
            precondition(UIApplication.shared.preferredContentSizeCategory.rawValue == expected,
                         "Host content size category differs from requested category")
        }
    }

    @ViewBuilder private var content: some View {
        if variant == "A" {
            Form {
                Section {
                    Button(Copy.button) {}.accessibilityIdentifier("start-simulation")
                } header: {
                    Text(Copy.header).accessibilityIdentifier("practice-header")
                } footer: {
                    Text(Copy.footer).accessibilityIdentifier("practice-footer")
                }
            }
        } else if variant == "B" {
            Form {
                Section { styledButton } header: { styledHeader } footer: { styledFooter }
            }
        } else {
            // Intentional container change only: no minimum hit size or extra font overrides.
            ScrollView {
                VStack(alignment: .leading) {
                    styledHeader
                    styledButton
                    styledFooter
                }
                .padding()
            }
        }
    }

    // Exact English static Practice modifiers from DashboardView.swift blob
    // d3695f783f5c62b88ea78a746917b7f2d5d2c743. Action deliberately inert.
    private var styledButton: some View {
        Button {} label: {
            Text(Copy.button)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .accessibilityIdentifier("start-simulation")
    }
    private var styledHeader: some View {
        Text(Copy.header)
            .font(.body.weight(.semibold))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .accessibilityIdentifier("practice-header")
    }
    private var styledFooter: some View {
        Text(Copy.footer)
            .font(.body)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .accessibilityIdentifier("practice-footer")
    }
}
