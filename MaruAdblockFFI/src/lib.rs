use adblock::lists::{FilterFormat, FilterSet, ParseOptions, RuleTypes};

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

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum AdblockConversionError {
    #[error("failed to convert parsed filters into WebKit content blocking rules")]
    ContentBlockingConversion,
    #[error("failed to serialize WebKit content blocking rules: {0}")]
    Serialization(String),
}

#[uniffi::export]
pub fn convert_filter_lists_to_content_rule_list_json(
    filter_lists: Vec<AdblockFilterListInput>,
    options: AdblockConversionOptions,
) -> Result<AdblockConversionResult, AdblockConversionError> {
    let mut filter_set = FilterSet::new(true);

    for filter_list in filter_lists {
        let parse_options = ParseOptions {
            format: filter_list.format.into(),
            rule_types: options.rule_types.into(),
            ..ParseOptions::default()
        };
        filter_set.add_filter_list(&filter_list.contents, parse_options);
    }

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
}
