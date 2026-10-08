use std::path::{Path, PathBuf};

use super::{mediapipe_face, scrfd, yunet_face};
use crate::pipeline::{FindingRegion, ScanFinding};

/// Minimum SCRFD confidence when no YuNet/BlazeFace corroboration exists.
const SCRFD_SOLO_THRESHOLD: f32 = 0.72;
/// IoU required for SCRFD to be kept when a conservative detector also fired.
const SCRFD_CORROBORATION_IOU: f32 = 0.25;

/// Runs face detection — SCRFD is cross-validated against YuNet + BlazeFace.
pub fn scan(file_path: &str, model_path: &str) -> Result<Vec<ScanFinding>, String> {
    let pack_dir = Path::new(model_path)
        .parent()
        .and_then(|p| p.parent())
        .map(Path::to_path_buf);

    let mut yunet_findings = Vec::new();
    let mut scrfd_findings = Vec::new();
    let mut blaze_findings = Vec::new();

    if let Some(ref dir) = pack_dir {
        let scrfd_path = dir.join("models").join("scrfd.onnx");
        if scrfd_path.exists() && scrfd_path.metadata().map(|m| m.len()).unwrap_or(0) > 1024 {
            match scrfd::scan_faces(file_path, scrfd_path.to_str().unwrap()) {
                Ok(hits) => scrfd_findings = hits,
                Err(e) => crate::log::error(&format!("scrfd failed: {e}")),
            }
        }

        let blazeface = dir.join("models").join("blazeface.onnx");
        if blazeface.exists() && blazeface.metadata().map(|m| m.len()).unwrap_or(0) > 1024 {
            match mediapipe_face::scan_faces(file_path, blazeface.to_str().unwrap()) {
                Ok(hits) => blaze_findings = hits,
                Err(e) => crate::log::error(&format!("blazeface failed: {e}")),
            }
        }
    }

    if is_blazeface_model(model_path) {
        match mediapipe_face::scan_faces(file_path, model_path) {
            Ok(hits) => blaze_findings.extend(hits),
            Err(e) => crate::log::error(&format!("blazeface(main) failed: {e}")),
        }
    } else {
        let yunet = resolve_yunet_path(model_path, pack_dir.as_ref());
        match yunet_face::scan_faces(file_path, yunet.to_str().unwrap()) {
            Ok(hits) => yunet_findings = hits,
            Err(e) => crate::log::error(&format!("yunet failed: {e}")),
        }
    }

    let corroborated_scrfd =
        filter_scrfd_ensemble(&scrfd_findings, &yunet_findings, &blaze_findings);
    crate::log::info(&format!(
        "face ensemble: yunet={} blaze={} scrfd_raw={} scrfd_kept={}",
        yunet_findings.len(),
        blaze_findings.len(),
        scrfd_findings.len(),
        corroborated_scrfd.len()
    ));

    let mut findings = Vec::new();
    findings.append(&mut yunet_findings);
    findings.append(&mut blaze_findings);
    findings.extend(corroborated_scrfd);

    Ok(dedupe_faces(findings))
}

/// SCRFD is sensitive on textured scenes (cars, watermarks). Keep hits only when
/// YuNet/BlazeFace agree, or when SCRFD confidence is very high on its own.
fn filter_scrfd_ensemble(
    scrfd: &[ScanFinding],
    yunet: &[ScanFinding],
    blaze: &[ScanFinding],
) -> Vec<ScanFinding> {
    let anchors: Vec<&FindingRegion> = yunet
        .iter()
        .chain(blaze.iter())
        .filter_map(|f| f.region.as_ref())
        .collect();

    scrfd
        .iter()
        .filter(|f| {
            if f.confidence >= SCRFD_SOLO_THRESHOLD {
                return true;
            }
            if anchors.is_empty() {
                return false;
            }
            f.region.as_ref().is_some_and(|r| {
                anchors
                    .iter()
                    .any(|a| iou_region(r, a) >= SCRFD_CORROBORATION_IOU)
            })
        })
        .cloned()
        .collect()
}

fn dedupe_faces(mut items: Vec<ScanFinding>) -> Vec<ScanFinding> {
    items.sort_by(|a, b| {
        b.confidence
            .partial_cmp(&a.confidence)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let mut kept = Vec::new();
    for candidate in items {
        let Some(ref region) = candidate.region else {
            kept.push(candidate);
            continue;
        };
        if kept.iter().any(|k| {
            let Some(kr) = &k.region else {
                return false;
            };
            iou_region(region, kr) >= 0.35
        }) {
            continue;
        }
        kept.push(candidate);
        if kept.len() >= 12 {
            break;
        }
    }
    kept
}

fn iou_region(a: &FindingRegion, b: &FindingRegion) -> f32 {
    let ax2 = a.x + a.width;
    let ay2 = a.y + a.height;
    let bx2 = b.x + b.width;
    let by2 = b.y + b.height;
    let ix1 = a.x.max(b.x);
    let iy1 = a.y.max(b.y);
    let ix2 = ax2.min(bx2);
    let iy2 = ay2.min(by2);
    let iw = (ix2 - ix1).max(0.0);
    let ih = (iy2 - iy1).max(0.0);
    let inter = iw * ih;
    let union = a.width * a.height + b.width * b.height - inter;
    if union <= 0.0 {
        0.0
    } else {
        inter / union
    }
}

fn is_blazeface_model(model_path: &str) -> bool {
    let lower = model_path.to_lowercase();
    lower.contains("blazeface") || lower.contains("blaze.onnx")
}

fn resolve_yunet_path(model_path: &str, pack_dir: Option<&PathBuf>) -> PathBuf {
    if let Some(dir) = pack_dir {
        let yunet = dir.join("models").join("yunet.onnx");
        if yunet.exists() {
            return yunet;
        }
    }
    PathBuf::from(model_path)
}
