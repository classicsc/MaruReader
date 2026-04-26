use mdbook_markdown::pulldown_cmark::html;

#[uniffi::export]
pub fn render_markdown_to_html(markdown: String) -> String {
    let options = mdbook_markdown::MarkdownOptions::default();
    let parser = mdbook_markdown::new_cmark_parser(&markdown, &options);
    let mut html_output = String::new();
    html::push_html(&mut html_output, parser);
    html_output
}

uniffi::setup_scaffolding!();

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn renders_mdbook_markdown_extensions() {
        let html = render_markdown_to_html(
            "# Heading {#custom}\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n~~old~~\n".to_string(),
        );

        assert!(html.contains("<h1 id=\"custom\">Heading</h1>"));
        assert!(html.contains("<table>"));
        assert!(html.contains("<del>old</del>"));
    }
}
