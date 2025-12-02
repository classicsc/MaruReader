import SwiftUI
import CoreData
import MaruReaderCore

struct DictionaryDisplaySettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: DictionaryDisplayPreferences.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \DictionaryDisplayPreferences.id, ascending: true)],
        predicate: NSPredicate(format: "enabled == %@", NSNumber(value: true)),
        animation: .default
    ) private var activePreferences: FetchedResults<DictionaryDisplayPreferences>

    @State private var fontFamily: String = DictionaryDisplayDefaults.defaultFontFamily
    @State private var fontSize: Double = DictionaryDisplayDefaults.defaultFontSize
    @State private var popupFontSize: Double = DictionaryDisplayDefaults.defaultPopupFontSize
    @State private var showDeinflection: Bool = DictionaryDisplayDefaults.defaultShowDeinflection

    private let fontOptions: [(displayName: String, family: String)] = [
        ("System", "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif"),
        ("Serif", "TimesNewRomanPSMT, 'Times New Roman', Times, Georgia, serif"),
        ("Sans Serif", "HelveticaNeue, Helvetica, Arial, sans-serif"),
        ("Monospace", "Menlo, Monaco, 'Courier New', monospace")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Font Family") {
                    Picker("Font Family", selection: $fontFamily) {
                        ForEach(fontOptions, id: \.family) { option in
                            Text(option.displayName).tag(option.family)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Font Size Scale") {
                    Stepper("Content: \(fontSize, specifier: "%.2f")x", value: $fontSize, in: 0.5...3.0, step: 0.05)
                    Stepper("Popup: \(popupFontSize, specifier: "%.2f")x", value: $popupFontSize, in: 0.5...3.0, step: 0.05)
                }

                Section("Display Options") {
                    Toggle("Show Deinflection Info", isOn: $showDeinflection)
                }
            }
            .navigationTitle("Display Settings")
            .onAppear(perform: loadPreferences)
            .onChange(of: activePreferences.count) { _, _ in loadPreferences() }
            .onChange(of: fontFamily) { _, _ in savePreferences() }
            .onChange(of: fontSize) { _, _ in savePreferences() }
            .onChange(of: popupFontSize) { _, _ in savePreferences() }
            .onChange(of: showDeinflection) { _, _ in savePreferences() }
        }
    }

    private func loadPreferences() {
        if let pref = activePreferences.first {
            fontFamily = pref.fontFamily ?? DictionaryDisplayDefaults.defaultFontFamily
            fontSize = pref.fontSize
            popupFontSize = pref.popupFontSize
            showDeinflection = pref.showDeinflection
        } else {
            createDefaultPreferences()
        }
    }

    private func createDefaultPreferences() {
        // Disable existing enabled preferences
        let request: NSFetchRequest<DictionaryDisplayPreferences> = DictionaryDisplayPreferences.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == %@", NSNumber(value: true))
        do {
            let enabledPrefs = try viewContext.fetch(request)
            for pref in enabledPrefs {
                pref.enabled = false
            }
        } catch {
            print("Error disabling existing preferences: \(error)")
        }

        // Create new default
        let newPref = DictionaryDisplayPreferences(context: viewContext)
        newPref.id = UUID()
        newPref.enabled = true
        newPref.fontFamily = DictionaryDisplayDefaults.defaultFontFamily
        newPref.fontSize = DictionaryDisplayDefaults.defaultFontSize
        newPref.popupFontSize = DictionaryDisplayDefaults.defaultPopupFontSize
        newPref.showDeinflection = DictionaryDisplayDefaults.defaultShowDeinflection

        do {
            try viewContext.save()
        } catch {
            print("Error saving default preferences: \(error)")
        }
    }

    private func savePreferences() {
        guard let pref = activePreferences.first else { return }
        pref.fontFamily = fontFamily
        pref.fontSize = fontSize
        pref.popupFontSize = popupFontSize
        pref.showDeinflection = showDeinflection
        do {
            try viewContext.save()
        } catch {
            print("Error saving preferences: \(error)")
        }
    }
}

#Preview {
    DictionaryDisplaySettingsView()
        .environment(\.managedObjectContext, DictionaryPersistenceController.shared.container.viewContext)
}
