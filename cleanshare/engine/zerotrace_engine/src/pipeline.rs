use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct FindingRegion {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ScanFinding {
    pub id: String,
    pub category: String,
    pub title: String,
    pub description: String,
    pub severity: String,
    pub confidence: f32,
    pub recommendation: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub region: Option<FindingRegion>,
    #[serde(default)]
    pub supports_blur: bool,
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanPipelineOutput {
    pub findings: Vec<ScanFinding>,
    pub risk_score: u8,
    pub duration_ms: u64,
}

/// Entry point for FFI — runs metadata + secrets scanners on a local file path.
pub fn run_scan(file_path: &str) -> Result<ScanPipelineOutput, String> {
    let started = std::time::Instant::now();
    let mut findings = Vec::new();

    findings.extend(crate::metadata::scan_file(file_path)?);
    findings.extend(crate::secrets::scan_file(file_path)?);

    let risk_score = score_findings(&findings);
    Ok(ScanPipelineOutput {
        findings,
        risk_score,
        duration_ms: started.elapsed().as_millis() as u64,
    })
}

fn score_findings(findings: &[ScanFinding]) -> u8 {
    let total: f32 = findings
        .iter()
        .map(|f| match f.severity.as_str() {
            "critical" => 28.0,
            "high" => 18.0,
            "medium" => 10.0,
            "low" => 4.0,
            _ => 0.0,
        } * f.confidence)
        .sum();
    total.clamp(0.0, 100.0) as u8
}
