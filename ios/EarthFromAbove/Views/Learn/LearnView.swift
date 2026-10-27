import SwiftUI
import EarthFromAboveCore

/// Reference content bundled with the app as Markdown files under Resources/Content.
struct LearnView: View {
    @Environment(AppState.self) private var app

    struct Article: Identifiable {
        var id: String { file }
        var title: String
        var file: String
        var symbol: String
    }

    static let articles: [Article] = [
        Article(title: "How to spot things from the air", file: "spotting_guide", symbol: "eye"),
        Article(title: "Clouds from above", file: "clouds", symbol: "cloud"),
        Article(title: "Lightning and storms", file: "lightning", symbol: "cloud.bolt"),
        Article(title: "Lines on the land: borders, rivers, divides", file: "lines_on_the_land", symbol: "map"),
        Article(title: "Reading the human landscape", file: "human_landscape", symbol: "building.2"),
        Article(title: "Reading the geology", file: "geology", symbol: "mountain.2"),
        Article(title: "Why is it bumpy?", file: "turbulence", symbol: "wind"),
        Article(title: "Sky tricks: glories, halos, contrails", file: "sky_optics", symbol: "sparkles")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Guides") {
                    ForEach(Self.articles) { a in
                        NavigationLink { ArticleView(article: a) } label: { Label(a.title, systemImage: a.symbol) }
                    }
                }
                Section("This flight") {
                    NavigationLink { WeatherView() } label: { Label("Weather and ride", systemImage: "cloud.sun") }
                    if let a = app.bundle?.aircraft {
                        NavigationLink { AircraftView(aircraft: a) } label: { Label(a.typeName, systemImage: "airplane") }
                    }
                }
            }
            .navigationTitle("Learn")
        }
    }
}

struct ArticleView: View {
    var article: LearnView.Article
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            MarkdownBlocks(text: loadText())
                .padding()
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadText() -> String {
        let kid = app.settings.kidModeEnabled
        let name = kid ? article.file + "_kids" : article.file
        let url = Bundle.main.url(forResource: name, withExtension: "md") ?? Bundle.main.url(forResource: article.file, withExtension: "md")
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "This article is missing from the app bundle."
        }
        return text
    }
}

/// Minimal Markdown renderer: headings, bullet lists and paragraphs with inline
/// styling. Enough for the reference articles without a dependency.
struct MarkdownBlocks: View {
    var text: String

    private enum Block: Identifiable {
        case heading(Int, String), bullet(String), paragraph(String)
        var id: String {
            switch self {
            case .heading(let l, let t): return "h\(l)-" + t
            case .bullet(let t): return "b-" + t
            case .paragraph(let t): return "p-" + t
            }
        }
    }

    private var blocks: [Block] {
        var out: [Block] = []
        var para: [String] = []
        func flush() {
            if !para.isEmpty { out.append(.paragraph(para.joined(separator: " "))); para.removeAll() }
        }
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("#") {
                flush()
                let level = line.prefix { $0 == "#" }.count
                out.append(.heading(level, line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flush()
                out.append(.bullet(String(line.dropFirst(2))))
            } else {
                para.append(line)
            }
        }
        flush()
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let t):
                    Text(inline(t)).font(level <= 1 ? .title.bold() : level == 2 ? .title2.bold() : .headline).padding(.top, 6)
                case .bullet(let t):
                    HStack(alignment: .top, spacing: 8) { Text("•"); Text(inline(t)) }
                case .paragraph(let t):
                    Text(inline(t))
                }
            }
        }
        .textSelection(.enabled)
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }
}
