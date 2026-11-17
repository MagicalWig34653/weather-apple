import SwiftUI
import UIKit

// MOCK nur fuer Entwurfsbilder (Kartenwahl-Menue). Nicht Teil der App.
struct Row: View {
    let icon: String; let title: String; var sub: String? = nil
    var check = false; var chevron = false; var dim = false
    var body: some View {
        HStack(spacing: 12) {
            ZStack { if check { Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)) } }.frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 17))
                if let sub { Text(sub).font(.system(size: 13)).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(.secondary)
            if chevron { Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary) }
        }
        .foregroundStyle(dim ? .secondary : .primary)
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

struct Panel<C: View>: View {
    var width: CGFloat = 300
    @ViewBuilder var content: C
    var body: some View {
        VStack(spacing: 0) { content }
            .frame(width: width)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
    }
}

struct Div: View { var body: some View { Rectangle().fill(.primary.opacity(0.12)).frame(height: 0.5).padding(.horizontal, 12) } }

struct IconBar: View {
    let icons: [String]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(icons.enumerated()), id: \.offset) { i, s in
                Image(systemName: s).font(.system(size: 20))
                    .foregroundStyle(i == 0 ? Color.accentColor : .primary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(i == 0 ? Color.accentColor.opacity(0.15) : .clear)
                if i < icons.count - 1 { Rectangle().fill(.primary.opacity(0.12)).frame(width: 0.5, height: 30) }
            }
        }.padding(.horizontal, 6)
    }
}

struct MainMenu: View {
    let variant: Int
    var body: some View {
        Panel {
            if variant != 3 { IconBar(icons: ["cloud.rain", "cloud", "bolt.fill", "thermometer.medium"]); Div() }
            Row(icon: "cloud.rain", title: "Regenebenen", chevron: true)
            Row(icon: "square.3.layers.3d", title: "Zusatzebenen", chevron: true)
            Row(icon: "paintpalette", title: "Darstellung", chevron: true)
            Div()
            Row(icon: "arrow.clockwise", title: "Daten neu laden")
        }
    }
}

struct RainSub: View {
    let variant: Int
    var body: some View {
        Panel(width: 340) {
            Row(icon: "cloud.rain", title: "Deutschland (DWD)", sub: "Radar, 5-Minuten-Schritte", check: true)
            Row(icon: "globe.europe.africa", title: "Europa (OPERA)", sub: "Radarverbund, 5-Minuten-Schritte")
            if variant == 2 {
                Row(icon: "globe", title: "Welt (NOAA)", sub: "aus Satellitendaten geschätzt, ungenauer")
            }
        }
    }
}

struct Capsule1: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cloud.rain"); Text("Regen").font(.system(size: 16, weight: .medium))
            Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }
}

struct Placeholder: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.45, green: 0.58, blue: 0.5), Color(red: 0.35, green: 0.45, blue: 0.55)], startPoint: .top, endPoint: .bottom)
            Circle().fill(Color.blue.opacity(0.55)).frame(width: 260).offset(x: -60, y: 220).blur(radius: 30)
            Circle().fill(Color.green.opacity(0.6)).frame(width: 140).offset(x: 90, y: 330).blur(radius: 24)
            Circle().fill(Color.yellow.opacity(0.6)).frame(width: 90).offset(x: 40, y: 380).blur(radius: 16)
            Circle().fill(Color.purple.opacity(0.5)).frame(width: 220).offset(x: 100, y: 120).blur(radius: 30)
        }.ignoresSafeArea()
    }
}

struct Root: View {
    let variant: Int, sub: Bool, dark: Bool
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Placeholder()
            VStack(alignment: .trailing, spacing: 10) {
                Capsule1()
                MainMenu(variant: variant)
                if sub { RainSub(variant: variant) }
            }.padding(.trailing, 16).padding(.top, 70)
            VStack {
                Spacer()
                Text("MOCK, Entwurf Variante \(variant)\(sub ? ", Untermenü Regenebenen" : ""), kein echtes Menü")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8).background(Color.red.opacity(0.85), in: Capsule())
                    .padding(.bottom, 60)
            }.frame(maxWidth: .infinity)
        }
        .preferredColorScheme(dark ? .dark : .light)
    }
}

@main struct MockApp: App {
    var body: some Scene {
        let a = CommandLine.arguments
        let v = Int(a.drop(while: { $0 != "-variant" }).dropFirst().first ?? "1") ?? 1
        WindowGroup { Root(variant: v, sub: a.contains("-sub"), dark: a.contains("-dark")) }
    }
}
