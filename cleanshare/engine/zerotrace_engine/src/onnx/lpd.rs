use std::path::Path;

use ndarray::{Array, IxDyn};
use ort::value::TensorRef;

use crate::pipeline::{FindingRegion, ScanFinding};

/// Fixed YuNet LPD export (`yolov11n.onnx` in the vehicle pack) is 320×240 only.
/// Extra scales used to crash ORT and abort the whole plate scan via `?`.
const PRIMARY_W: u32 = 320;
const PRIMARY_H: u32 = 240;

const NMS_THRESHOLD: f32 = 0.35;
const TOP_K: usize = 5000;
const KEEP_TOP_K: usize = 750;

/// Lower gate for 320×240 resize; geometry filter removes weak boxes.
/// Slightly lower for angled / HSRP Indian plates in street photos.
const CONF_THRESHOLD: f32 = 0.18;

/// Max plates reported per image (production cap).
const MAX_PLATES: usize = 3;

pub fn scan_plates(file_path: &str, model_path: &str) -> Result<Vec<ScanFinding>, String> {
    let image = super::common::load_rgb_image(file_path)?;
    let (orig_w, orig_h) = image.dimensions();

    // Full-frame at native model size, then a center crop for small distant plates.
    let mut findings = infer_plates(
        &image,
        model_path,
        PRIMARY_W,
        PRIMARY_H,
        orig_w,
        orig_h,
        "primary",
    )
    .unwrap_or_default();

    if findings.is_empty() && orig_w >= 480 && orig_h >= 480 {
        let crop_w = (orig_w as f32 * 0.72) as u32;
        let crop_h = (orig_h as f32 * 0.55) as u32;
        let x0 = (orig_w - crop_w) / 2;
        // Plates sit low on the car — bias crop toward the lower half.
        let y0 = ((orig_h as f32 * 0.42) as u32).min(orig_h.saturating_sub(crop_h));
        let crop = image::imageops::crop_imm(&image, x0, y0, crop_w, crop_h).to_image();
        if let Ok(mut roi) = infer_plates(
            &crop,
            model_path,
            PRIMARY_W,
            PRIMARY_H,
            crop_w,
            crop_h,
            "lower-center",
        ) {
            for f in &mut roi {
                if let Some(ref mut region) = f.region {
                    region.x = (x0 as f32 / orig_w as f32)
                        + region.x * (crop_w as f32 / orig_w as f32);
                    region.y = (y0 as f32 / orig_h as f32)
                        + region.y * (crop_h as f32 / orig_h as f32);
                    region.width *= crop_w as f32 / orig_w as f32;
                    region.height *= crop_h as f32 / orig_h as f32;
                }
            }
            findings.append(&mut roi);
        }
    }

    let before = findings.len();
    findings = dedupe_plates(findings);
    findings = filter_plate_geometry(findings);
    if findings.len() > MAX_PLATES {
        findings.sort_by(|a, b| {
            b.confidence
                .partial_cmp(&a.confidence)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        findings.truncate(MAX_PLATES);
    }
    crate::log::info(&format!(
        "lpd kept plates={} (raw_merged={before})",
        findings.len()
    ));
    Ok(findings)
}

/// Runs LPD on a normalized ROI (vehicle-guided refinement).
pub fn scan_plates_in_roi(
    file_path: &str,
    model_path: &str,
    roi: FindingRegion,
) -> Result<Vec<ScanFinding>, String> {
    let image = super::common::load_rgb_image(file_path)?;
    let (orig_w, orig_h) = image.dimensions();

    let x1 = (roi.x * orig_w as f32).max(0.0) as u32;
    let y1 = (roi.y * orig_h as f32).max(0.0) as u32;
    let x2 = ((roi.x + roi.width) * orig_w as f32).min(orig_w as f32) as u32;
    let y2 = ((roi.y + roi.height) * orig_h as f32).min(orig_h as f32) as u32;
    if x2 <= x1 + 8 || y2 <= y1 + 8 {
        return Ok(Vec::new());
    }

    let crop = image::imageops::crop_imm(&image, x1, y1, x2 - x1, y2 - y1).to_image();
    let (crop_w, crop_h) = crop.dimensions();

    let mut findings = infer_plates(
        &crop,
        model_path,
        PRIMARY_W,
        PRIMARY_H,
        crop_w,
        crop_h,
        "roi",
    )?;

    // Map crop-normalized coords back to full image.
    for f in &mut findings {
        if let Some(ref mut region) = f.region {
            region.x = (x1 as f32 / orig_w as f32) + region.x * (crop_w as f32 / orig_w as f32);
            region.y = (y1 as f32 / orig_h as f32) + region.y * (crop_h as f32 / orig_h as f32);
            region.width *= crop_w as f32 / orig_w as f32;
            region.height *= crop_h as f32 / orig_h as f32;
        }
    }

    Ok(filter_plate_geometry(findings))
}

pub fn resolve_lpd_path(model_path: &str) -> std::path::PathBuf {
    let path = Path::new(model_path);
    if let Some(dir) = path.parent().and_then(|p| p.parent()) {
        for name in ["yolov11n.onnx", "lpd_yunet.onnx", "lpd.onnx"] {
            let candidate = dir.join("models").join(name);
            if candidate.exists() {
                return candidate;
            }
        }
    }
    path.to_path_buf()
}

fn infer_plates(
    image: &image::RgbImage,
    model_path: &str,
    input_w: u32,
    input_h: u32,
    orig_w: u32,
    orig_h: u32,
    tag: &str,
) -> Result<Vec<ScanFinding>, String> {
    let resized = image::imageops::resize(
        image,
        input_w,
        input_h,
        image::imageops::FilterType::Triangle,
    );
    let tensor = nchw_bgr_from_image(&resized);

    let array = Array::from_shape_vec(
        IxDyn(&[1, 3, input_h as usize, input_w as usize]),
        tensor,
    )
    .map_err(|e| e.to_string())?;

    super::session_cache::with_session(model_path, |session| {
        let input_name = super::common::primary_input_name(session);
        let outputs = session
            .run(ort::inputs![input_name.as_str() => TensorRef::from_array_view(array.view()).map_err(|e| e.to_string())?])
            .map_err(|e| e.to_string())?;

        let loc = tensor_f32(&outputs, "loc")?;
        let conf = tensor_f32(&outputs, "conf")?;
        let iou = tensor_f32(&outputs, "iou")?;

        let priors = generate_priors(input_w, input_h);
        if loc.len() < priors.len() * 14
            || conf.len() < priors.len() * 2
            || iou.len() < priors.len()
        {
            return Ok(Vec::new());
        }

        let dets = decode_lpd_yunet(&priors, &loc, &conf, &iou, input_w, input_h);
        let kept = nms_lpd_yunet(dets, CONF_THRESHOLD, NMS_THRESHOLD, TOP_K, KEEP_TOP_K);

        if !kept.is_empty() {
            let top = kept.iter().map(|d| d.score).fold(0.0_f32, f32::max);
            crate::log::info(&format!("lpd {tag} scale={input_w}x{input_h} hits={} top_score={top:.3}", kept.len()));
        }

        let plate_count = kept.len();
        let mut findings = Vec::new();
        for (idx, det) in kept.into_iter().enumerate() {
            let (x, y, w, h) = corners_to_aabb(&det.corners);
            let Some(region) = map_aabb_to_normalized(x, y, w, h, orig_w, orig_h, input_w, input_h)
            else {
                continue;
            };
            findings.push(ScanFinding {
                id: format!("vehicle-protection-plate-{tag}-{idx}"),
                category: "License Plates".to_string(),
                title: if plate_count == 1 {
                    "License plate detected".to_string()
                } else {
                    format!("License plate {} detected", idx + 1)
                },
                description:
                    "A license plate was detected. Enable blur before sharing this photo."
                        .to_string(),
                severity: "high".to_string(),
                confidence: det.score.clamp(0.0, 1.0),
                recommendation: Some("Enable blur to hide this license plate".to_string()),
                region: Some(region),
                supports_blur: true,
                ..Default::default()
            });
        }
        Ok(findings)
    })
}

fn filter_plate_geometry(mut findings: Vec<ScanFinding>) -> Vec<ScanFinding> {
    findings.retain(|f| {
        let Some(region) = &f.region else {
            return false;
        };
        if region.width <= 0.0 || region.height <= 0.0 {
            return false;
        }
        let aspect = region.width / region.height;
        // Indian HSRP plates are wider; allow slightly squarer angled crops.
        if aspect < 1.05 || aspect > 10.0 {
            return false;
        }
        let area = region.width * region.height;
        if area < 0.00025 || area > 0.22 {
            return false;
        }
        f.confidence >= 0.16
    });
    findings
}

fn dedupe_plates(mut items: Vec<ScanFinding>) -> Vec<ScanFinding> {
    items.sort_by(|a, b| {
        b.confidence
            .partial_cmp(&a.confidence)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let mut kept = Vec::new();
    for candidate in items {
        let Some(ref region) = candidate.region else {
            continue;
        };
        if kept.iter().any(|k: &ScanFinding| {
            k.region
                .as_ref()
                .is_some_and(|kr| iou_region(region, kr) >= 0.40)
        }) {
            continue;
        }
        kept.push(candidate);
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

fn nchw_bgr_from_image(image: &image::RgbImage) -> Vec<f32> {
    let (w, h) = image.dimensions();
    let plane = (w * h) as usize;
    let mut tensor = vec![0.0_f32; 3 * plane];
    for y in 0..h {
        for x in 0..w {
            let pixel = image.get_pixel(x, y);
            let idx = (y * w + x) as usize;
            tensor[idx] = pixel[2] as f32;
            tensor[plane + idx] = pixel[1] as f32;
            tensor[2 * plane + idx] = pixel[0] as f32;
        }
    }
    tensor
}

fn map_aabb_to_normalized(
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    orig_w: u32,
    orig_h: u32,
    input_w: u32,
    input_h: u32,
) -> Option<FindingRegion> {
    let scale_x = orig_w as f32 / input_w as f32;
    let scale_y = orig_h as f32 / input_h as f32;
    let x1 = (x * scale_x).max(0.0);
    let y1 = (y * scale_y).max(0.0);
    let x2 = ((x + w) * scale_x).min(orig_w as f32);
    let y2 = ((y + h) * scale_y).min(orig_h as f32);
    if x2 <= x1 || y2 <= y1 {
        return None;
    }
    let width = x2 - x1;
    let height = y2 - y1;
    if width < 2.0 || height < 2.0 {
        return None;
    }
    Some(FindingRegion {
        x: (x1 / orig_w as f32).clamp(0.0, 1.0),
        y: (y1 / orig_h as f32).clamp(0.0, 1.0),
        width: (width / orig_w as f32).clamp(0.0, 1.0),
        height: (height / orig_h as f32).clamp(0.0, 1.0),
    })
}

#[derive(Clone, Copy)]
struct Prior {
    cx: f32,
    cy: f32,
    sx: f32,
    sy: f32,
}

fn generate_priors(w: u32, h: u32) -> Vec<Prior> {
    let min_sizes: [&[f32]; 4] = [
        &[10.0, 16.0, 24.0],
        &[32.0, 48.0],
        &[64.0, 96.0],
        &[128.0, 192.0, 256.0],
    ];
    let steps = [8_u32, 16, 32, 64];
    let feature_map_2th = [(h + 1) / 2 / 2, (w + 1) / 2 / 2];
    let feature_map_3th = [feature_map_2th[0] / 2, feature_map_2th[1] / 2];
    let feature_map_4th = [feature_map_3th[0] / 2, feature_map_3th[1] / 2];
    let feature_map_5th = [feature_map_4th[0] / 2, feature_map_4th[1] / 2];
    let feature_map_6th = [feature_map_5th[0] / 2, feature_map_5th[1] / 2];
    let feature_maps = [
        feature_map_3th,
        feature_map_4th,
        feature_map_5th,
        feature_map_6th,
    ];

    let mut priors = Vec::new();
    for (k, f) in feature_maps.iter().enumerate() {
        for i in 0..f[0] {
            for j in 0..f[1] {
                for &min_size in min_sizes[k] {
                    priors.push(Prior {
                        cx: (j as f32 + 0.5) * steps[k] as f32 / w as f32,
                        cy: (i as f32 + 0.5) * steps[k] as f32 / h as f32,
                        sx: min_size / w as f32,
                        sy: min_size / h as f32,
                    });
                }
            }
        }
    }
    priors
}

#[derive(Clone, Copy)]
struct LpdDet {
    corners: [(f32, f32); 4],
    score: f32,
}

fn decode_lpd_yunet(
    priors: &[Prior],
    loc: &[f32],
    conf: &[f32],
    iou: &[f32],
    input_w: u32,
    input_h: u32,
) -> Vec<LpdDet> {
    let variance = 0.1_f32;
    let scale = [input_w as f32, input_h as f32];
    let mut dets = Vec::with_capacity(priors.len());

    for (idx, prior) in priors.iter().enumerate() {
        let mut iou_score = iou[idx];
        iou_score = iou_score.clamp(0.0, 1.0);
        let score = (conf[idx * 2 + 1] * iou_score).sqrt();

        let loc_base = idx * 14;
        let loc_slice = &loc[loc_base..loc_base + 14];
        let corners = [
            (
                (prior.cx + loc_slice[4] * variance * prior.sx) * scale[0],
                (prior.cy + loc_slice[5] * variance * prior.sy) * scale[1],
            ),
            (
                (prior.cx + loc_slice[6] * variance * prior.sx) * scale[0],
                (prior.cy + loc_slice[7] * variance * prior.sy) * scale[1],
            ),
            (
                (prior.cx + loc_slice[10] * variance * prior.sx) * scale[0],
                (prior.cy + loc_slice[11] * variance * prior.sy) * scale[1],
            ),
            (
                (prior.cx + loc_slice[12] * variance * prior.sx) * scale[0],
                (prior.cy + loc_slice[13] * variance * prior.sy) * scale[1],
            ),
        ];
        dets.push(LpdDet { corners, score });
    }
    dets
}

fn nms_lpd_yunet(
    mut dets: Vec<LpdDet>,
    score_threshold: f32,
    nms_threshold: f32,
    top_k: usize,
    keep_top_k: usize,
) -> Vec<LpdDet> {
    dets.retain(|d| d.score >= score_threshold);
    dets.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));
    if dets.len() > top_k {
        dets.truncate(top_k);
    }

    let mut kept = Vec::new();
    let mut suppressed = vec![false; dets.len()];

    for i in 0..dets.len() {
        if suppressed[i] {
            continue;
        }
        kept.push(dets[i]);
        if kept.len() >= keep_top_k {
            break;
        }
        for j in (i + 1)..dets.len() {
            if suppressed[j] {
                continue;
            }
            if iou_nms_corners(dets[i].corners, dets[j].corners) >= nms_threshold {
                suppressed[j] = true;
            }
        }
    }
    kept
}

fn iou_nms_corners(a: [(f32, f32); 4], b: [(f32, f32); 4]) -> f32 {
    let ax1 = a[0].0.min(a[1].0);
    let ay1 = a[0].1.min(a[1].1);
    let ax2 = a[0].0.max(a[1].0);
    let ay2 = a[0].1.max(a[1].1);
    let bx1 = b[0].0.min(b[1].0);
    let by1 = b[0].1.min(b[1].1);
    let bx2 = b[0].0.max(b[1].0);
    let by2 = b[0].1.max(b[1].1);

    let inter_x1 = ax1.max(bx1);
    let inter_y1 = ay1.max(by1);
    let inter_x2 = ax2.min(bx2);
    let inter_y2 = ay2.min(by2);
    let inter_w = (inter_x2 - inter_x1).max(0.0);
    let inter_h = (inter_y2 - inter_y1).max(0.0);
    let inter = inter_w * inter_h;
    let area_a = (ax2 - ax1).max(0.0) * (ay2 - ay1).max(0.0);
    let area_b = (bx2 - bx1).max(0.0) * (by2 - by1).max(0.0);
    let union = area_a + area_b - inter;
    if union <= 0.0 {
        0.0
    } else {
        inter / union
    }
}

fn corners_to_aabb(corners: &[(f32, f32); 4]) -> (f32, f32, f32, f32) {
    let min_x = corners.iter().map(|c| c.0).fold(f32::INFINITY, f32::min);
    let max_x = corners.iter().map(|c| c.0).fold(f32::NEG_INFINITY, f32::max);
    let min_y = corners.iter().map(|c| c.1).fold(f32::INFINITY, f32::min);
    let max_y = corners.iter().map(|c| c.1).fold(f32::NEG_INFINITY, f32::max);
    (min_x, min_y, (max_x - min_x).max(1.0), (max_y - min_y).max(1.0))
}

fn tensor_f32(
    outputs: &ort::session::SessionOutputs,
    name: &str,
) -> Result<Vec<f32>, String> {
    let value = outputs
        .get(name)
        .ok_or_else(|| format!("Missing ONNX output: {name}"))?;
    let (_shape, data) = value
        .try_extract_tensor::<f32>()
        .map_err(|e| e.to_string())?;
    Ok(data.to_vec())
}
