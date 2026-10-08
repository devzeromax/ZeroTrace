use std::fs;
use std::path::Path;

use crate::pipeline::ScanFinding;

pub fn scan_file(file_path: &str) -> Result<Vec<ScanFinding>, String> {
    let path = Path::new(file_path);
    if !path.exists() {
        return Err(format!("File not found: {file_path}"));
    }

    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    if !matches!(ext.as_str(), "jpg" | "jpeg" | "png" | "heic" | "webp") {
        return Ok(Vec::new());
    }

    let bytes = fs::read(path).map_err(|e| e.to_string())?;
    let mut findings = Vec::new();

    if bytes.windows(2).any(|w| w == b"\xFF\xE1") {
        findings.push(ScanFinding {
            id: uuid_simple(),
            category: "Metadata".into(),
            title: "EXIF metadata block detected".into(),
            description: "JPEG APP1 (EXIF) segment found in image.".into(),
            severity: "high".into(),
            confidence: 0.9,
            recommendation: Some("Strip EXIF before sharing.".into()),
            region: None,
            supports_blur: false,
            ..Default::default()
        });
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
