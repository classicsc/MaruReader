import CoreData
import MaruReaderCore
import SwiftUI

struct DictionaryDisplaySettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: DictionaryDisplayPreferences.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \DictionaryDisplayPreferences.id, ascending: true)],
        predicate: NSPredicate(format: "enabled == %@", NSNumber(value: true)),
        animation: .default
    ) private var activePreferences: FetchedResults<DictionaryDisplayPreferences>

    @State private var selectedFontIndex: Int = 0
    @State private var fontSize: Double = DictionaryDisplayDefaults.defaultFontSize
    @State private var popupFontSize: Double = DictionaryDisplayDefaults.defaultPopupFontSize
    @State private var showDeinflection: Bool = DictionaryDisplayDefaults.defaultShowDeinflection

    private let fontOptions: [(displayName: String, family: String)] = [
        ("System", "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif"),
        ("Serif", "TimesNewRomanPSMT, 'Times New Roman', Times, Georgia, serif"),
        ("Sans Serif", "HelveticaNeue, Helvetica, Arial, sans-serif"),
        ("Monospace", "Menlo, Monaco, 'Courier New', monospace"),
    ]

    private var fontFamily: String {
        fontOptions[selectedFontIndex].family
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Font Family") {
                    Picker("Font Family", selection: $selectedFontIndex) {
                        ForEach(0 ..< fontOptions.count, id: \.self) { index in
                            Text(fontOptions[index].displayName).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Font Size Scale") {
                    Stepper("Content: \(fontSize, specifier: "%.2f")x", value: $fontSize, in: 0.5 ... 3.0, step: 0.05)
                    Stepper("Popup: \(popupFontSize, specifier: "%.2f")x", value: $popupFontSize, in: 0.5 ... 3.0, step: 0.05)
                }

                Section("Display Options") {
                    Toggle("Show Deinflection Info", isOn: $showDeinflection)
                }
            }
            .navigationTitle("Display Settings")
            .onAppear(perform: loadPreferences)
            .onChange(of: activePreferences.count) { _, _ in loadPreferences() }
            .onChange(of: selectedFontIndex) { _, _ in savePreferences() }
            .onChange(of: fontSize) { _, _ in savePreferences() }
            .onChange(of: popupFontSize) { _, _ in savePreferences() }
            .onChange(of: showDeinflection) { _, _ in savePreferences() }
        }
    }

    private func loadPreferences() {
        if let pref = activePreferences.first {
            if let family = pref.fontFamily,
               let index = fontOptions.firstIndex(where: { $0.family == family })
            {
                selectedFontIndex = index
            } else {
                selectedFontIndex = 0
            }
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
