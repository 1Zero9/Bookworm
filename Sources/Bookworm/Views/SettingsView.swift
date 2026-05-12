import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    private let models: [(id: String, name: String, description: String)] = [
        ("gemini-2.0-flash",          "Gemini 2.0 Flash",        "Fast & capable — recommended"),
        ("gemini-1.5-pro",            "Gemini 1.5 Pro",           "High quality, larger context"),
        ("gemini-2.5-pro-preview",    "Gemini 2.5 Pro Preview",   "Most capable, slower"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(AppTheme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    apiKeySection
                    Divider().background(AppTheme.border)
                    modelSection
                }
                .padding(24)
            }
        }
        .frame(width: 440, height: 480)
        .background(AppTheme.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.accentWorld)
                Text("Settings")
                    .font(AppTheme.editorialFont(18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - API key

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Gemini API Key", systemImage: "key.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            SecureField("Paste your API key here…", text: $settings.geminiApiKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

            HStack(spacing: 6) {
                Image(systemName: settings.hasApiKey ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(settings.hasApiKey ? Color.green : AppTheme.textSecondary.opacity(0.5))
                Text(settings.hasApiKey ? "API key set — AI Audit is active" : "No key — AI Audit will be disabled")
                    .font(.system(size: 11))
                    .foregroundStyle(settings.hasApiKey ? Color.green : AppTheme.textSecondary)
            }

            Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                    Text("Get a free key at aistudio.google.com")
                        .font(.system(size: 11))
                }
                .foregroundStyle(AppTheme.accentWrite)
            }
        }
    }

    // MARK: - Model picker

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Gemini Model", systemImage: "cpu")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 6) {
                ForEach(models, id: \.id) { model in
                    modelRow(model)
                }
            }
        }
    }

    private func modelRow(_ model: (id: String, name: String, description: String)) -> some View {
        let isSelected = settings.geminiModel == model.id
        return Button { settings.geminiModel = model.id } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? AppTheme.accentWorld : AppTheme.textSecondary.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(model.description)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding(10)
            .background(
                isSelected ? AppTheme.accentWorld.opacity(0.08) : AppTheme.border.opacity(0.2),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}
