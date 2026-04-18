use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use sudachi::analysis::stateless_tokenizer::StatelessTokenizer;
use sudachi::analysis::{Mode, Tokenize};
use sudachi::config::Config;
use sudachi::dic::dictionary::JapaneseDictionary;

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct FuriganaSpan {
    pub base: String,
    pub reading: Option<String>,
    pub start_byte: u64,
    pub end_byte: u64,
}

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum SudachiAnalyzerError {
    #[error("resource directory does not exist: {0}")]
    MissingResourceDirectory(String),
    #[error("required resource file is missing: {0}")]
    MissingResourceFile(String),
    #[error("invalid Sudachi config: {0}")]
    InvalidConfig(String),
    #[error("failed to load Sudachi dictionary: {0}")]
    DictionaryLoad(String),
    #[error("failed to tokenize text: {0}")]
    Tokenization(String),
}

#[derive(uniffi::Object)]
pub struct SudachiAnalyzer {
    resource_dir: PathBuf,
    dictionary: Mutex<Option<Arc<JapaneseDictionary>>>,
}

impl std::fmt::Debug for SudachiAnalyzer {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("SudachiAnalyzer")
            .field("resource_dir", &self.resource_dir)
            .finish_non_exhaustive()
    }
}

#[uniffi::export]
impl SudachiAnalyzer {
    #[uniffi::constructor]
    pub fn new(resource_dir: String) -> Result<Self, SudachiAnalyzerError> {
        let resource_dir = PathBuf::from(resource_dir);
        validate_resource_dir(&resource_dir)?;

        // Parse the config eagerly so invalid JSON or plugin config fails at construction time.
        let _ = config_for_resource_dir(&resource_dir)?;

        Ok(Self {
            resource_dir,
            dictionary: Mutex::new(None),
        })
    }

    pub fn warm_up(&self) -> Result<(), SudachiAnalyzerError> {
        let _ = self.dictionary()?;
        Ok(())
    }

    pub fn generate_segments(
        &self,
        text: String,
    ) -> Result<Vec<FuriganaSpan>, SudachiAnalyzerError> {
        if text.is_empty() {
            return Ok(Vec::new());
        }

        let tokenizer = StatelessTokenizer::new(self.dictionary()?);
        let morphemes = tokenizer
            .tokenize(&text, Mode::C, false)
            .map_err(|error| SudachiAnalyzerError::Tokenization(error.to_string()))?;

        let mut spans = Vec::new();
        let mut previous_end = 0usize;

        for morpheme in morphemes.iter() {
            let start = morpheme.begin();
            let end = morpheme.end();

            if previous_end < start {
                spans.push(FuriganaSpan {
                    base: text[previous_end..start].to_string(),
                    reading: None,
                    start_byte: previous_end as u64,
                    end_byte: start as u64,
                });
            }

            if start < end {
                let surface = &text[start..end];
                let reading = katakana_to_hiragana(morpheme.reading_form());
                spans.extend(split_surface(surface, &reading, start, end));
            }

            previous_end = end;
        }

        if previous_end < text.len() {
            spans.push(FuriganaSpan {
                base: text[previous_end..].to_string(),
                reading: None,
                start_byte: previous_end as u64,
                end_byte: text.len() as u64,
            });
        }

        Ok(spans)
    }
}

impl SudachiAnalyzer {
    fn dictionary(&self) -> Result<Arc<JapaneseDictionary>, SudachiAnalyzerError> {
        let mut dictionary = self.dictionary.lock().map_err(|_| {
            SudachiAnalyzerError::DictionaryLoad("dictionary lock poisoned".to_string())
        })?;

        if let Some(existing) = dictionary.as_ref() {
            return Ok(existing.clone());
        }

        let config = config_for_resource_dir(&self.resource_dir)?;
        let loaded = JapaneseDictionary::from_cfg(&config)
            .map(Arc::new)
            .map_err(|error| SudachiAnalyzerError::DictionaryLoad(error.to_string()))?;

        *dictionary = Some(loaded.clone());
        Ok(loaded)
    }
}

const REQUIRED_RESOURCE_FILES: [&str; 5] = [
    "char.def",
    "rewrite.def",
    "sudachi.json",
    "system_full.dic",
    "unk.def",
];

fn validate_resource_dir(resource_dir: &Path) -> Result<(), SudachiAnalyzerError> {
    if !resource_dir.is_dir() {
        return Err(SudachiAnalyzerError::MissingResourceDirectory(
            resource_dir.display().to_string(),
        ));
    }

    for file_name in REQUIRED_RESOURCE_FILES {
        let file_path = resource_dir.join(file_name);
        if !file_path.is_file() {
            return Err(SudachiAnalyzerError::MissingResourceFile(
                file_path.display().to_string(),
            ));
        }
    }

    Ok(())
}

fn config_for_resource_dir(resource_dir: &Path) -> Result<Config, SudachiAnalyzerError> {
    Config::new(
        Some(resource_dir.join("sudachi.json")),
        Some(resource_dir.to_path_buf()),
        Some(resource_dir.join("system_full.dic")),
    )
    .map_err(|error| SudachiAnalyzerError::InvalidConfig(error.to_string()))
}

fn split_surface(
    surface: &str,
    reading_hiragana: &str,
    start_byte: usize,
    end_byte: usize,
) -> Vec<FuriganaSpan> {
    if !contains_kanji_like(surface) {
        return vec![FuriganaSpan {
            base: surface.to_string(),
            reading: None,
            start_byte: start_byte as u64,
            end_byte: end_byte as u64,
        }];
    }

    let Some((core_start, core_end)) = kanji_core_byte_range(surface) else {
        return vec![FuriganaSpan {
            base: surface.to_string(),
            reading: Some(reading_hiragana.to_string()),
            start_byte: start_byte as u64,
            end_byte: end_byte as u64,
        }];
    };

    let leading = &surface[..core_start];
    let core = &surface[core_start..core_end];
    let trailing = &surface[core_end..];

    let leading_hiragana = katakana_to_hiragana(leading);
    let trailing_hiragana = katakana_to_hiragana(trailing);

    if !reading_hiragana.starts_with(&leading_hiragana)
        || !reading_hiragana.ends_with(&trailing_hiragana)
    {
        return vec![FuriganaSpan {
            base: surface.to_string(),
            reading: Some(reading_hiragana.to_string()),
            start_byte: start_byte as u64,
            end_byte: end_byte as u64,
        }];
    }

    let reading_start = leading_hiragana.len();
    let reading_end = reading_hiragana
        .len()
        .saturating_sub(trailing_hiragana.len());
    if reading_start >= reading_end {
        return vec![FuriganaSpan {
            base: surface.to_string(),
            reading: Some(reading_hiragana.to_string()),
            start_byte: start_byte as u64,
            end_byte: end_byte as u64,
        }];
    }

    let core_reading = &reading_hiragana[reading_start..reading_end];
    let mut spans = Vec::with_capacity(3);

    if !leading.is_empty() {
        spans.push(FuriganaSpan {
            base: leading.to_string(),
            reading: None,
            start_byte: start_byte as u64,
            end_byte: (start_byte + core_start) as u64,
        });
    }

    spans.push(FuriganaSpan {
        base: core.to_string(),
        reading: Some(core_reading.to_string()),
        start_byte: (start_byte + core_start) as u64,
        end_byte: (start_byte + core_end) as u64,
    });

    if !trailing.is_empty() {
        spans.push(FuriganaSpan {
            base: trailing.to_string(),
            reading: None,
            start_byte: (start_byte + core_end) as u64,
            end_byte: end_byte as u64,
        });
    }

    spans
}

fn kanji_core_byte_range(surface: &str) -> Option<(usize, usize)> {
    let mut first = None;
    let mut last_end = None;

    for (offset, character) in surface.char_indices() {
        if is_kanji_like(character) {
            first.get_or_insert(offset);
            last_end = Some(offset + character.len_utf8());
        }
    }

    match (first, last_end) {
        (Some(start), Some(end)) if start < end => Some((start, end)),
        _ => None,
    }
}

fn contains_kanji_like(text: &str) -> bool {
    text.chars().any(is_kanji_like)
}

fn is_kanji_like(character: char) -> bool {
    matches!(
        character as u32,
        0x3005
            | 0x3007
            | 0x303B
            | 0x3400..=0x4DBF
            | 0x4E00..=0x9FFF
            | 0xF900..=0xFAFF
            | 0x20000..=0x2FA1F
    )
}

fn katakana_to_hiragana(text: &str) -> String {
    text.chars().map(katakana_char_to_hiragana).collect()
}

fn katakana_char_to_hiragana(character: char) -> char {
    match character as u32 {
        0x30A1..=0x30F6 => char::from_u32((character as u32) - 0x60).unwrap_or(character),
        _ => character,
    }
}

uniffi::setup_scaffolding!();

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;
    use std::fs;
    use std::process::Command;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::OnceLock;
    use std::time::{SystemTime, UNIX_EPOCH};

    static TEST_RESOURCE_DIR: OnceLock<PathBuf> = OnceLock::new();
    static TEMP_DIR_COUNTER: AtomicUsize = AtomicUsize::new(0);

    #[test]
    fn resource_directory_loading() -> Result<(), SudachiAnalyzerError> {
        let analyzer = SudachiAnalyzer::new(test_resource_dir().display().to_string())?;
        analyzer.warm_up()?;
        Ok(())
    }

    #[test]
    fn okurigana_shows_kanji_only_readings() -> Result<(), SudachiAnalyzerError> {
        let analyzer = test_analyzer()?;

        assert_eq!(
            analyzer.generate_segments("食べる".to_string())?,
            vec![
                span("食", Some("た"), 0, 3),
                span("べる", None, 3, "食べる".len()),
            ]
        );
        assert_eq!(
            analyzer.generate_segments("行く".to_string())?,
            vec![
                span("行", Some("い"), 0, 3),
                span("く", None, 3, "行く".len()),
            ]
        );
        assert_eq!(
            analyzer.generate_segments("高い".to_string())?,
            vec![
                span("高", Some("たか"), 0, 3),
                span("い", None, 3, "高い".len()),
            ]
        );
        assert_eq!(
            analyzer.generate_segments("飲む".to_string())?,
            vec![
                span("飲", Some("の"), 0, 3),
                span("む", None, 3, "飲む".len()),
            ]
        );

        Ok(())
    }

    #[test]
    fn all_kanji_words_keep_full_reading() -> Result<(), SudachiAnalyzerError> {
        let analyzer = test_analyzer()?;

        assert_eq!(
            analyzer.generate_segments("日本語".to_string())?,
            vec![span("日本語", Some("にほんご"), 0, "日本語".len())]
        );
        assert_eq!(
            analyzer.generate_segments("学校".to_string())?,
            vec![span("学校", Some("がっこう"), 0, "学校".len())]
        );
        assert_eq!(
            analyzer.generate_segments("東京".to_string())?,
            vec![span("東京", Some("とうきょう"), 0, "東京".len())]
        );

        Ok(())
    }

    #[test]
    fn representative_swift_contract_cases() -> Result<(), SudachiAnalyzerError> {
        let analyzer = test_analyzer()?;

        let sentence = analyzer.generate_segments("私は日本語を勉強する".to_string())?;
        assert!(
            sentence.contains(&span("私", Some("わたし"), 0, "私".len()))
                || sentence.contains(&span("私", Some("わたくし"), 0, "私".len()))
        );
        assert!(sentence
            .iter()
            .any(|segment| segment.base == "日本語"
                && segment.reading.as_deref() == Some("にほんご")));
        assert!(sentence
            .iter()
            .any(|segment| segment.base == "勉強"
                && segment.reading.as_deref() == Some("べんきょう")));
        let formatted = format_anki_style(&sentence);
        assert!(
            formatted == "私[わたし]は日本語[にほんご]を勉強[べんきょう]する"
                || formatted == "私[わたくし]は日本語[にほんご]を勉強[べんきょう]する"
        );

        let weather = analyzer.generate_segments("今日はいい天気ですね".to_string())?;
        assert!(weather
            .iter()
            .any(|segment| segment.base == "今日" && segment.reading.as_deref() == Some("きょう")));
        assert!(weather
            .iter()
            .any(|segment| segment.base == "天気" && segment.reading.as_deref() == Some("てんき")));

        Ok(())
    }

    #[test]
    fn byte_ranges_match_original_utf8_text() -> Result<(), SudachiAnalyzerError> {
        let text = "私は学生です";
        let analyzer = test_analyzer()?;
        let spans = analyzer.generate_segments(text.to_string())?;

        let mut expected_start = 0usize;
        for segment in &spans {
            let start = segment.start_byte as usize;
            let end = segment.end_byte as usize;
            assert_eq!(start, expected_start);
            assert_eq!(&text[start..end], segment.base);
            expected_start = end;
        }

        assert_eq!(expected_start, text.len());
        Ok(())
    }

    #[test]
    fn missing_resource_directory_fails() {
        let missing = env::temp_dir().join("maru-sudachi-missing-resource-dir");
        let error = SudachiAnalyzer::new(missing.display().to_string()).unwrap_err();
        assert!(matches!(
            error,
            SudachiAnalyzerError::MissingResourceDirectory(_)
        ));
    }

    #[test]
    fn missing_resource_file_fails() {
        let temp_dir = make_temp_dir("missing-file");
        fs::create_dir_all(&temp_dir).unwrap();
        fs::write(temp_dir.join("sudachi.json"), "{}").unwrap();

        let error = SudachiAnalyzer::new(temp_dir.display().to_string()).unwrap_err();
        assert!(matches!(
            error,
            SudachiAnalyzerError::MissingResourceFile(_)
        ));
    }

    #[test]
    fn invalid_config_fails() {
        let temp_dir = make_temp_dir("invalid-config");
        fs::create_dir_all(&temp_dir).unwrap();

        fs::write(temp_dir.join("char.def"), "").unwrap();
        fs::write(temp_dir.join("rewrite.def"), "").unwrap();
        fs::write(temp_dir.join("unk.def"), "").unwrap();
        fs::write(temp_dir.join("system_full.dic"), "").unwrap();
        fs::write(temp_dir.join("sudachi.json"), "{ invalid json").unwrap();

        let error = SudachiAnalyzer::new(temp_dir.display().to_string()).unwrap_err();
        assert!(matches!(error, SudachiAnalyzerError::InvalidConfig(_)));
    }

    fn test_analyzer() -> Result<SudachiAnalyzer, SudachiAnalyzerError> {
        SudachiAnalyzer::new(test_resource_dir().display().to_string())
    }

    fn test_resource_dir() -> &'static PathBuf {
        TEST_RESOURCE_DIR.get_or_init(|| {
            if let Ok(path) = env::var("MARU_SUDACHI_RESOURCE_DIR") {
                return PathBuf::from(path);
            }

            let repo_root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .parent()
                .expect("crate should live directly under the repo root")
                .to_path_buf();
            let resource_dir = repo_root.join("build/sudachi/v20260116-full");
            let dictionary_path = resource_dir.join("system_full.dic");

            if !dictionary_path.is_file() {
                let script_path = repo_root.join("scripts/fetch-sudachi-resources.sh");
                let output = Command::new(&script_path)
                    .arg(&resource_dir)
                    .output()
                    .expect("failed to run Sudachi resource fetch script");
                assert!(
                    output.status.success(),
                    "failed to fetch Sudachi test resources\nstdout:\n{}\nstderr:\n{}",
                    String::from_utf8_lossy(&output.stdout),
                    String::from_utf8_lossy(&output.stderr),
                );
            }

            resource_dir
        })
    }

    fn make_temp_dir(label: &str) -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("clock drift")
            .as_nanos();
        let counter = TEMP_DIR_COUNTER.fetch_add(1, Ordering::Relaxed);
        let path = env::temp_dir().join(format!("maru-sudachi-{label}-{nanos}-{counter}"));
        if path.exists() {
            fs::remove_dir_all(&path).unwrap();
        }
        path
    }

    fn format_anki_style(spans: &[FuriganaSpan]) -> String {
        let mut formatted = String::new();
        for span in spans {
            match &span.reading {
                Some(reading) => {
                    formatted.push_str(&span.base);
                    formatted.push('[');
                    formatted.push_str(reading);
                    formatted.push(']');
                }
                None => formatted.push_str(&span.base),
            }
        }
        formatted
    }

    fn span(base: &str, reading: Option<&str>, start_byte: usize, end_byte: usize) -> FuriganaSpan {
        FuriganaSpan {
            base: base.to_string(),
            reading: reading.map(str::to_string),
            start_byte: start_byte as u64,
            end_byte: end_byte as u64,
        }
    }
}
