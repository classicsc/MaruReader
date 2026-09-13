// Runs in WKContentWorld.defaultClient against the loaded page only. No network requests.
const url = new URL(location.href);
const videoID = url.pathname === '/watch' ? url.searchParams.get('v') : null;
if (!['www.youtube.com', 'youtube.com', 'm.youtube.com'].includes(url.hostname) || videoID !== expectedVideoID) {
    return null;
}
const watch = document.querySelector('ytd-watch-flexy');
if (watch?.getAttribute('video-id') && watch.getAttribute('video-id') !== videoID) return null;
const video = document.querySelector('#movie_player video') || document.querySelector('video');
const adPlaying = !!document.querySelector('#movie_player.ad-showing, #movie_player.ad-interrupting');
const state = globalThis.maruYouTubeTranscriptState ||= { videoID, rows: [], staleRows: [], didRequestTranscript: false };
if (state.videoID !== videoID) {
    state.staleRows = state.rows;
    state.rows = [];
    state.videoID = videoID;
    state.didRequestTranscript = false;
}
if (action === 'seek') {
    if (video && !adPlaying && Number.isFinite(seconds) && seconds >= 0) {
        video.currentTime = Math.min(seconds, Number.isFinite(video.duration) ? video.duration : seconds);
    }
    return null;
}
if (action === 'frame') {
    if (!video || adPlaying || video.readyState < 2 || !video.videoWidth) return null;
    try {
        const canvas = document.createElement('canvas');
        const scale = Math.min(1, 1280 / video.videoWidth);
        canvas.width = Math.round(video.videoWidth * scale);
        canvas.height = Math.round(video.videoHeight * scale);
        canvas.getContext('2d').drawImage(video, 0, 0, canvas.width, canvas.height);
        return canvas.toDataURL('image/jpeg', 0.85);
    } catch (_) {
        // Protected or cross-origin video cannot be exported from a canvas.
        return null;
    }
}
let cues = null;
if (action === 'open') state.didRequestTranscript = false;
if (action === 'read' || action === 'open') {
    const rows = Array.from(document.querySelectorAll('transcript-segment-view-model, ytd-transcript-segment-renderer'));
    const unchanged = rows.length > 0 && rows.every(row => state.staleRows.some(old => old.node === row && old.text === row.textContent));
    const freshRows = unchanged ? [] : rows;
    if (freshRows.length) state.staleRows = [];
    cues = freshRows.map((row, id) => {
        const timestamp = row.querySelector('.ytwTranscriptSegmentViewModelTimestamp, .segment-timestamp')?.textContent?.trim();
        const text = row.querySelector('span.ytAttributedStringHost, .segment-text')?.textContent?.trim();
        if (!timestamp || !text || !/^\d+(?::\d{2}){1,2}$/.test(timestamp)) return null;
        const start = timestamp.split(':').reduce((total, part) => total * 60 + Number(part), 0);
        return { id, start, text };
    }).filter(Boolean).sort((a, b) => a.start - b.start);
    state.rows = rows.map(node => ({ node, text: node.textContent }));
    if (!cues.length) {
        // Opening the description materializes the language-independent transcript button.
        const expand = document.querySelector('ytd-watch-metadata #description-inline-expander #expand');
        expand?.click();
        const button = document.querySelector('ytd-video-description-transcript-section-renderer button');
        if (!state.didRequestTranscript && button && !button.disabled && button.getAttribute('aria-disabled') !== 'true') {
            state.didRequestTranscript = true;
            button.click();
        }
    }
}
return JSON.stringify({
    videoID,
    title: document.querySelector('ytd-watch-metadata h1')?.textContent?.trim() || document.title.replace(/ - YouTube$/, ''),
    currentTime: video && Number.isFinite(video.currentTime) ? video.currentTime : 0,
    adPlaying,
    cues
});
