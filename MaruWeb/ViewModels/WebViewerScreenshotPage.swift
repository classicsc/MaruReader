// WebViewerScreenshotPage.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

enum WebViewerScreenshotPage {
    // swiftlint:disable line_length
    static let html = """
    <!DOCTYPE html>
    <html lang="ja">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>雪山だより | 冬のスキー場ガイド</title>
    <style>
    :root {
        color-scheme: light only;
        --page-background: #eef3f8;
        --surface: rgba(250, 252, 255, 0.96);
        --surface-strong: #fbfdff;
        --border: rgba(52, 76, 102, 0.16);
        --text-primary: #17202a;
        --text-secondary: #4e5b69;
        --accent: #2f5f8f;
        --accent-soft: rgba(47, 95, 143, 0.12);
        --accent-warm: #6fa3c9;
        --shadow: 0 20px 48px rgba(24, 43, 65, 0.08);
    }

    * { box-sizing: border-box; }

    html {
        background: var(--page-background);
    }

    body {
        margin: 0;
        min-height: 100vh;
        font-family: "Hiragino Sans", "Yu Gothic", "Noto Sans JP", sans-serif;
        line-height: 1.75;
        color: var(--text-primary);
        background:
            radial-gradient(circle at top right, rgba(111, 163, 201, 0.22), transparent 28%),
            radial-gradient(circle at left 18%, rgba(47, 95, 143, 0.10), transparent 30%),
            linear-gradient(180deg, #f7fafd 0%, var(--page-background) 100%);
        -webkit-text-size-adjust: 100%;
    }

    .page {
        width: min(100%, 960px);
        margin: 0 auto;
        padding: clamp(20px, 4vw, 36px) clamp(16px, 4vw, 28px) 48px;
    }

    .hero {
        position: relative;
        overflow: hidden;
        padding: clamp(24px, 5vw, 38px);
        border: 1px solid var(--border);
        border-radius: 28px;
        background:
            linear-gradient(135deg, rgba(255, 255, 255, 0.96), rgba(242, 247, 252, 0.96)),
            var(--surface);
        box-shadow: var(--shadow);
    }

    .hero::after {
        content: "";
        position: absolute;
        inset: auto -40px -56px auto;
        width: 180px;
        height: 180px;
        border-radius: 50%;
        background: radial-gradient(circle, rgba(47, 95, 143, 0.16), rgba(47, 95, 143, 0));
        pointer-events: none;
    }

    .eyebrow {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        margin-bottom: 14px;
        padding: 7px 12px;
        border-radius: 999px;
        background: var(--accent-soft);
        color: #244a70;
        font-size: 13px;
        font-weight: 700;
        letter-spacing: 0.04em;
    }

    h1 {
        margin: 0;
        font-size: clamp(31px, 6vw, 47px);
        line-height: 1.12;
        letter-spacing: -0.03em;
    }

    .subtitle {
        max-width: 34rem;
        margin: 16px 0 0;
        font-size: clamp(17px, 2.3vw, 21px);
        color: var(--text-secondary);
    }

    .hero-grid {
        display: grid;
        grid-template-columns: minmax(0, 1.55fr) minmax(250px, 0.95fr);
        gap: 18px;
        margin-top: 26px;
    }

    .panel {
        position: relative;
        border: 1px solid var(--border);
        border-radius: 22px;
        background: var(--surface-strong);
        padding: 18px 18px 20px;
    }

    .panel h2,
    .section-card h2 {
        margin: 0 0 12px;
        font-size: 17px;
        line-height: 1.35;
    }

    .lead {
        margin: 0;
        font-size: 18px;
    }

    .highlight {
        padding: 0.08em 0.38em;
        border-radius: 0.45em;
        background: rgba(205, 226, 243, 0.95);
        color: #1d3a57;
        font-weight: 700;
    }

    .meta-list,
    .checklist {
        margin: 14px 0 0;
        padding: 0;
        list-style: none;
    }

    .meta-list {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
    }

    .meta-list li {
        padding: 9px 12px;
        border-radius: 999px;
        background: #e6eef6;
        color: #3f4f5f;
        font-size: 14px;
        font-weight: 600;
    }

    .checklist li + li {
        margin-top: 12px;
    }

    .checklist strong {
        display: block;
        margin-bottom: 2px;
        font-size: 15px;
    }

    .checklist span {
        color: var(--text-secondary);
        font-size: 15px;
    }

    .sections {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 16px;
        margin-top: 18px;
    }

    .section-card {
        border: 1px solid var(--border);
        border-radius: 22px;
        background: rgba(251, 253, 255, 0.88);
        padding: 20px;
        box-shadow: 0 10px 30px rgba(27, 48, 70, 0.05);
    }

    .section-card p {
        margin: 0;
        color: var(--text-secondary);
        font-size: 15px;
    }

    .section-kicker {
        margin-bottom: 8px;
        color: var(--accent);
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
    }

    .footer-note {
        margin-top: 18px;
        padding: 16px 18px;
        border-left: 4px solid var(--accent-warm);
        border-radius: 18px;
        background: rgba(244, 249, 253, 0.92);
        color: #3c4854;
        font-size: 15px;
    }

    @media (max-width: 760px) {
        .hero-grid,
        .sections {
            grid-template-columns: 1fr;
        }

        .panel,
        .section-card {
            padding: 18px;
        }

        .lead {
            font-size: 17px;
        }
    }
    </style>
    </head>
    <body>
    <main class="page">
        <section class="hero">
            <div class="eyebrow">冬の雪山ガイド</div>
            <h1>粉雪を追いかける、北国スキー旅のすすめ</h1>
            <p class="subtitle">日本海側の山々には、世界中のスキーヤーが憧れる軽い雪が降り積もります。初めての雪山旅でも迷わないように、行き先の選び方と過ごし方をまとめました。</p>

            <div class="hero-grid">
                <article class="panel">
                    <h2>今朝の読みもの</h2>
                    <p class="lead">夜のうちに降り積もった <span class="highlight">粉雪</span> が、朝いちばんのゲレンデをふわりと覆います。リフトが動き出す前に山頂へ向かうと、誰の跡もない斜面を滑り降りる贅沢を味わえます。</p>
                    <ul class="meta-list">
                        <li>ニセコ・白馬・蔵王</li>
                        <li>1月〜2月がベストシーズン</li>
                        <li>樹氷と温泉</li>
                    </ul>
                </article>

                <aside class="panel">
                    <h2>持ちものメモ</h2>
                    <ul class="checklist">
                        <li><strong>ゴーグルの替えレンズ</strong><span>吹雪と晴天では、見え方が大きく変わります。</span></li>
                        <li><strong>貼るカイロ</strong><span>リフト待ちの指先と足先を守ります。</span></li>
                        <li><strong>温泉セット</strong><span>滑り終わったあとの楽しみは、山麓の湯です。</span></li>
                    </ul>
                </aside>
            </div>
        </section>

        <section class="sections">
            <article class="section-card">
                <div class="section-kicker">Powder</div>
                <h2>行き先を雪質で選ぶ</h2>
                <p>北海道のニセコは軽い雪、長野の白馬は標高差のあるロングコース、山形の蔵王は樹氷の間を抜ける独特の景色が魅力です。</p>
            </article>

            <article class="section-card">
                <div class="section-kicker">Ride</div>
                <h2>朝いちばんのリフトを狙う</h2>
                <p>圧雪されたコースと降ったままの新雪が混ざる午前中は、同じ斜面でも滑り心地が刻々と変わります。</p>
            </article>

            <article class="section-card">
                <div class="section-kicker">Warm</div>
                <h2>滑ったあとの温泉と郷土料理</h2>
                <p>冷えた体を温泉で温め、芋煮やジンギスカンなど土地の味を楽しむのも雪山旅の醍醐味です。</p>
            </article>
        </section>

        <p class="footer-note">天気予報で「山沿いは大雪」と出た翌朝が、粉雪に出会える絶好のタイミングです。無理のない行程で、冬の山をたっぷり味わってください。</p>
    </main>
    </body>
    </html>
    """
    // swiftlint:enable line_length
}
