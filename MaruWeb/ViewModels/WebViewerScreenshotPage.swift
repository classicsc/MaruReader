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
    <title>お花見日和 | 春の街歩きガイド</title>
    <style>
    :root {
        color-scheme: light only;
        --page-background: #f6f1e8;
        --surface: rgba(255, 252, 247, 0.96);
        --surface-strong: #fffdfa;
        --border: rgba(97, 74, 57, 0.16);
        --text-primary: #1f1b18;
        --text-secondary: #5f534a;
        --accent: #a94d4d;
        --accent-soft: rgba(169, 77, 77, 0.12);
        --accent-warm: #d9825b;
        --shadow: 0 20px 48px rgba(65, 43, 24, 0.08);
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
            radial-gradient(circle at top right, rgba(217, 130, 91, 0.18), transparent 28%),
            radial-gradient(circle at left 18%, rgba(169, 77, 77, 0.12), transparent 30%),
            linear-gradient(180deg, #fbf7f1 0%, var(--page-background) 100%);
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
            linear-gradient(135deg, rgba(255, 255, 255, 0.96), rgba(255, 248, 242, 0.96)),
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
        background: radial-gradient(circle, rgba(169, 77, 77, 0.16), rgba(169, 77, 77, 0));
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
        color: #7b3131;
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
        background: rgba(244, 221, 197, 0.95);
        color: #4a2f21;
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
        background: #f4ede3;
        color: #584a40;
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
        background: rgba(255, 253, 250, 0.88);
        padding: 20px;
        box-shadow: 0 10px 30px rgba(70, 48, 27, 0.05);
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
        background: rgba(255, 250, 244, 0.92);
        color: #54463c;
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
            <div class="eyebrow">春の街歩き</div>
            <h1>お花見日和を楽しむための、やさしい一日ガイド</h1>
            <p class="subtitle">見上げる桜も、足元に散る花びらも、落ち着いたペースで味わえるように。人の多い名所でも心地よく過ごせる工夫をまとめました。</p>

            <div class="hero-grid">
                <article class="panel">
                    <h2>今朝の読みもの</h2>
                    <p class="lead">川沿いの遊歩道では、淡い花びらが風に揺れ、桜がいっせいに <span class="highlight">咲き誇り</span> ます。少し早めの時間に歩き始めると、やわらかな光と静かな空気に包まれた景色をゆっくり楽しめます。</p>
                    <ul class="meta-list">
                        <li>午前の散策</li>
                        <li>高コントラスト表示</li>
                        <li>写真映えする構図</li>
                    </ul>
                </article>

                <aside class="panel">
                    <h2>持ちものメモ</h2>
                    <ul class="checklist">
                        <li><strong>敷物と温かい飲み物</strong><span>日陰のベンチでもゆったり休めます。</span></li>
                        <li><strong>薄手の上着</strong><span>夕方の川風は想像より冷たく感じます。</span></li>
                        <li><strong>小さなおやつ</strong><span>桜餅や団子があると休憩の時間が楽しくなります。</span></li>
                    </ul>
                </aside>
            </div>
        </section>

        <section class="sections">
            <article class="section-card">
                <div class="section-kicker">Walk</div>
                <h2>歩きやすい名所を選ぶ</h2>
                <p>川沿い、公園の外周、駅から近い並木道など、移動しやすい場所を選ぶと短い時間でも満足感があります。</p>
            </article>

            <article class="section-card">
                <div class="section-kicker">Rest</div>
                <h2>混雑の前に席を整える</h2>
                <p>座る場所を先に決めてから食べものを広げると、視線も動線も落ち着いて、景色に集中しやすくなります。</p>
            </article>

            <article class="section-card">
                <div class="section-kicker">Light</div>
                <h2>夕暮れの色も楽しむ</h2>
                <p>薄桃色の花が夕方には少し深く見えます。昼と夜のあいだの短い時間帯は、印象が大きく変わるおすすめの瞬間です。</p>
            </article>
        </section>

        <p class="footer-note">静かな景色を味わいたい日は、満開の翌日よりも少し手前がおすすめです。つぼみの残る枝と開いた花が混ざることで、風景に奥行きが生まれます。</p>
    </main>
    </body>
    </html>
    """
    // swiftlint:enable line_length
}
