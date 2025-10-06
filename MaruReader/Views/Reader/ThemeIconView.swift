//
//  ThemeIconView.swift
//  MaruReader
//
//  Visual representation of a reader theme as a colored circle.
//

import ReadiumNavigator
import SwiftUI

struct ThemeIconView: View {
    let theme: ReaderTheme
    let size: CGFloat

    init(theme: ReaderTheme, size: CGFloat = 32) {
        self.theme = theme
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(iconColor)
            .frame(width: size, height: size)
    }

    private var iconColor: SwiftUI.Color {
        if let color = theme.value(forKey: "iconColor") as? ReadiumNavigator.Color {
            return color.swiftUIColor
        }
        // Fallback to background color
        if let bgColor = theme.value(forKey: "backgroundColor") as? ReadiumNavigator.Color {
            return bgColor.swiftUIColor
        }
        return .gray
    }
}

struct ProfileIconView: View {
    let profile: ReaderProfile
    let size: CGFloat

    init(profile: ReaderProfile, size: CGFloat = 32) {
        self.profile = profile
        self.size = size
    }

    var body: some View {
        if let theme = profile.theme, let darkTheme = profile.darkTheme {
            // Dual theme: show semicircles
            dualThemeIcon(light: theme, dark: darkTheme)
        } else if let theme = profile.theme {
            // Single theme: show character on color background
            singleThemeIcon(theme: theme)
        } else {
            // No theme: show placeholder
            placeholderIcon
        }
    }

    private func singleThemeIcon(theme: ReaderTheme) -> some View {
        ZStack {
            Circle()
                .fill(backgroundColor(for: theme))

            Text(profile.iconCharacter ?? "A")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(textColor(for: theme))
        }
        .frame(width: size, height: size)
    }

    private func dualThemeIcon(light: ReaderTheme, dark: ReaderTheme) -> some View {
        ZStack {
            // Left semicircle (light theme)
            Circle()
                .fill(backgroundColor(for: light))
                .mask(
                    Rectangle()
                        .frame(width: size / 2, height: size)
                        .offset(x: -size / 4)
                )

            // Right semicircle (dark theme)
            Circle()
                .fill(backgroundColor(for: dark))
                .mask(
                    Rectangle()
                        .frame(width: size / 2, height: size)
                        .offset(x: size / 4)
                )

            // Divider line
            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 1, height: size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholderIcon: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "questionmark")
                    .foregroundStyle(.secondary)
            )
    }

    private func backgroundColor(for theme: ReaderTheme) -> SwiftUI.Color {
        if let color = theme.value(forKey: "iconColor") as? ReadiumNavigator.Color {
            return color.swiftUIColor
        }
        if let bgColor = theme.value(forKey: "backgroundColor") as? ReadiumNavigator.Color {
            return bgColor.swiftUIColor
        }
        return .gray
    }

    private func textColor(for theme: ReaderTheme) -> SwiftUI.Color {
        if let color = theme.value(forKey: "iconTextColor") as? ReadiumNavigator.Color {
            return color.swiftUIColor
        }
        if let textColor = theme.value(forKey: "textColor") as? ReadiumNavigator.Color {
            return textColor.swiftUIColor
        }
        return .primary
    }
}
