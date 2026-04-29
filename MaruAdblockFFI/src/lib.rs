use adblock::lists::{FilterFormat, FilterSet, ParseOptions, RuleTypes};
use adblock::resources::{InMemoryResourceStorage, PermissionMask, Resource};
use adblock::Engine;

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum AdblockFilterListFormat {
    Standard,
    Hosts,
}

impl From<AdblockFilterListFormat> for FilterFormat {
    fn from(value: AdblockFilterListFormat) -> Self {
        match value {
            AdblockFilterListFormat::Standard => FilterFormat::Standard,
            AdblockFilterListFormat::Hosts => FilterFormat::Hosts,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum AdblockFilterRuleTypes {
    All,
    NetworkOnly,
    CosmeticOnly,
}

impl From<AdblockFilterRuleTypes> for RuleTypes {
    fn from(value: AdblockFilterRuleTypes) -> Self {
        match value {
            AdblockFilterRuleTypes::All => RuleTypes::All,
            AdblockFilterRuleTypes::NetworkOnly => RuleTypes::NetworkOnly,
            AdblockFilterRuleTypes::CosmeticOnly => RuleTypes::CosmeticOnly,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct AdblockFilterListInput {
    pub identifier: String,
    pub contents: String,
    pub format: AdblockFilterListFormat,
    pub permission_mask: u8,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct AdblockConversionOptions {
    pub rule_types: AdblockFilterRuleTypes,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct AdblockConversionResult {
    pub content_rule_list_json: String,
    pub content_rule_count: u64,
    pub converted_filter_count: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct AdblockCosmeticResources {
    pub hide_selectors: Vec<String>,
    pub procedural_actions: Vec<String>,
    pub exceptions: Vec<String>,
    pub injected_script: String,
    pub generichide: bool,
}

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum AdblockConversionError {
    #[error("failed to convert parsed filters into WebKit content blocking rules")]
    ContentBlockingConversion,
    #[error("failed to serialize WebKit content blocking rules: {0}")]
    Serialization(String),
    #[error("failed to deserialize adblock resources: {0}")]
    ResourceDeserialization(String),
}

fn parse_filter_set(filter_lists: Vec<AdblockFilterListInput>, rule_types: RuleTypes) -> FilterSet {
    let mut filter_set = FilterSet::new(true);

    for filter_list in filter_lists {
        let parse_options = ParseOptions {
            format: filter_list.format.into(),
            rule_types,
            permissions: PermissionMask::from_bits(filter_list.permission_mask),
            ..ParseOptions::default()
        };
        filter_set.add_filter_list(&filter_list.contents, parse_options);
    }

    filter_set
}

#[uniffi::export]
pub fn convert_filter_lists_to_content_rule_list_json(
    filter_lists: Vec<AdblockFilterListInput>,
    options: AdblockConversionOptions,
) -> Result<AdblockConversionResult, AdblockConversionError> {
    let filter_set = parse_filter_set(filter_lists, options.rule_types.into());

    let (rules, filters_used) = filter_set
        .into_content_blocking()
        .map_err(|_| AdblockConversionError::ContentBlockingConversion)?;
    let content_rule_count = rules.len() as u64;
    let converted_filter_count = filters_used.len() as u64;
    let content_rule_list_json = serde_json::to_string(&rules)
        .map_err(|error| AdblockConversionError::Serialization(error.to_string()))?;

    Ok(AdblockConversionResult {
        content_rule_list_json,
        content_rule_count,
        converted_filter_count,
    })
}

#[derive(uniffi::Object)]
pub struct AdblockCosmeticFilterEngine {
    engine: Engine,
}

#[uniffi::export]
impl AdblockCosmeticFilterEngine {
    #[uniffi::constructor]
    pub fn new(
        filter_lists: Vec<AdblockFilterListInput>,
        resources_json: String,
    ) -> Result<Self, AdblockConversionError> {
        let filter_set = parse_filter_set(filter_lists, RuleTypes::All);
        let mut engine = Engine::from_filter_set(filter_set, true);
        let trimmed = resources_json.trim();

        if !trimmed.is_empty() {
            let resources: Vec<Resource> = serde_json::from_str(trimmed).map_err(|error| {
                AdblockConversionError::ResourceDeserialization(error.to_string())
            })?;
            engine.use_resource_storage(InMemoryResourceStorage::from_resources(resources));
        }

        Ok(Self { engine })
    }

    pub fn resources_for_url(&self, url: String) -> AdblockCosmeticResources {
        let resources = self.engine.url_cosmetic_resources(&url);
        AdblockCosmeticResources {
            hide_selectors: resources.hide_selectors.into_iter().collect(),
            procedural_actions: resources.procedural_actions.into_iter().collect(),
            exceptions: resources.exceptions.into_iter().collect(),
            injected_script: resources.injected_script,
            generichide: resources.generichide,
        }
    }

    pub fn hidden_class_id_selectors(
        &self,
        classes: Vec<String>,
        ids: Vec<String>,
        exceptions: Vec<String>,
    ) -> Vec<String> {
        self.engine
            .hidden_class_id_selectors(classes, ids, &exceptions.into_iter().collect())
    }
}

uniffi::setup_scaffolding!();

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn converts_standard_network_and_cosmetic_filters() {
        let result = convert_filter_lists_to_content_rule_list_json(
            vec![AdblockFilterListInput {
                identifier: "test".to_string(),
                contents: "||ads.example.com^\nexample.com##.ad-banner".to_string(),
                format: AdblockFilterListFormat::Standard,
                permission_mask: 0,
            }],
            AdblockConversionOptions {
                rule_types: AdblockFilterRuleTypes::All,
            },
        )
        .expect("filter list should convert");

        assert_eq!(result.converted_filter_count, 2);
        assert!(result.content_rule_count >= 2);
        assert!(result.content_rule_list_json.contains("\"type\":\"block\""));
        assert!(result
            .content_rule_list_json
            .contains("\"type\":\"css-display-none\""));
        assert!(result.content_rule_list_json.contains(".ad-banner"));
    }

    #[test]
    fn converts_hosts_format_to_network_rules() {
        let result = convert_filter_lists_to_content_rule_list_json(
            vec![AdblockFilterListInput {
                identifier: "hosts".to_string(),
                contents: "0.0.0.0 ads.example.com\ntracker.example.org".to_string(),
                format: AdblockFilterListFormat::Hosts,
                permission_mask: 0,
            }],
            AdblockConversionOptions {
                rule_types: AdblockFilterRuleTypes::NetworkOnly,
            },
        )
        .expect("hosts list should convert");

        assert_eq!(result.converted_filter_count, 2);
        assert!(result
            .content_rule_list_json
            .contains("ads\\\\.example\\\\.com"));
        assert!(result
            .content_rule_list_json
            .contains("tracker\\\\.example\\\\.org"));
    }

    #[test]
    fn cosmetic_engine_returns_url_specific_and_generic_selectors() {
        let engine = AdblockCosmeticFilterEngine::new(
            vec![AdblockFilterListInput {
                identifier: "test".to_string(),
                contents: "example.com##.ad-banner\n##.generic-ad".to_string(),
                format: AdblockFilterListFormat::Standard,
                permission_mask: 0,
            }],
            String::new(),
        )
        .expect("cosmetic engine should compile");

        let resources = engine.resources_for_url("https://example.com/article".to_string());
        assert!(resources.hide_selectors.contains(&".ad-banner".to_string()));
        assert!(!resources
            .hide_selectors
            .contains(&".generic-ad".to_string()));

        let selectors =
            engine.hidden_class_id_selectors(vec!["generic-ad".to_string()], vec![], vec![]);
        assert!(selectors.contains(&".generic-ad".to_string()));
    }

    #[test]
    fn cosmetic_engine_uses_scriptlet_resources() {
        let resources_json = r#"[{
            "name":"maru-test.js",
            "aliases":["maru-test"],
            "kind":{"mime":"application/javascript"},
            "content":"ZnVuY3Rpb24gbWFydVRlc3QoYXJnKSB7IHdpbmRvdy5fX21hcnVUZXN0ID0gYXJnOyB9"
        }]"#;
        let engine = AdblockCosmeticFilterEngine::new(
            vec![AdblockFilterListInput {
                identifier: "test".to_string(),
                contents: "example.com##+js(maru-test, hello)".to_string(),
                format: AdblockFilterListFormat::Standard,
                permission_mask: 0,
            }],
            resources_json.to_string(),
        )
        .expect("cosmetic engine should compile with resources");

        let resources = engine.resources_for_url("https://example.com/".to_string());
        assert!(resources.injected_script.contains("function maruTest"));
        assert!(resources.injected_script.contains("maruTest(\"hello\")"));
    }
}
