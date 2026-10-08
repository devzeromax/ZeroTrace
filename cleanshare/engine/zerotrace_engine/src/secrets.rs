use std::fs;
use std::path::Path;

use regex::Regex;

use crate::pipeline::ScanFinding;

struct SecretRule {
    name: &'static str,
    pattern: &'static str,
    severity: &'static str,
}

const RULES: &[SecretRule] = &[
    SecretRule {
        name: "AWS Access Key",
        pattern: r"AKIA[0-9A-Z]{16}",
        severity: "critical",
    },
    SecretRule {
        name: "GitHub Token",
        pattern: r"ghp_[A-Za-z0-9]{36,}",
        severity: "critical",
    },
    SecretRule {
        name: "GitHub OAuth",
        pattern: r"gho_[A-Za-z0-9]{36,}",
        severity: "critical",
    },
    SecretRule {
        name: "JWT Token",
        pattern: r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}",
        severity: "high",
    },
    SecretRule {
        name: "Generic API Key",
        pattern: r#"(?i)(api[_-]?key|secret[_-]?key)\s*[:=]\s*["']?[A-Za-z0-9\-]{16,}"#,
        severity: "high",
    },
];

pub fn scan_file(file_path: &str) -> Result<Vec<ScanFinding>, String> {
    let path = Path::new(file_path);
    if !path.exists() {
        return Err(format!("File not found: {file_path}"));
    }

    let content = match fs::read_to_string(path) {
        Ok(c) => c,
        Err(_) => return Ok(Vec::new()),
    };

    let mut findings = Vec::new();
    for rule in RULES {
        let re = Regex::new(rule.pattern).map_err(|e| e.to_string())?;
        if re.is_match(&content) {
            findings.push(ScanFinding {
                id: uuid_simple(),
                category: "Developer Tools".into(),
                title: format!("{} detected", rule.name),
                description: format!("A {} pattern was found in this file.", rule.name),
                severity: rule.severity.into(),
                confidence: 0.9,
                recommendation: Some("Rotate the credential and remove it before sharing.".into()),
                region: None,
                supports_blur: false,
                ..Default::default()
            });
        }
    }

    Ok(findings)
}

fn uuid_simple() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    format!("zt-{nanos:x}")
}
