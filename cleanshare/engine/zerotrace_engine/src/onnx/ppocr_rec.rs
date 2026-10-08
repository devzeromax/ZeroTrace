use std::path::{Path, PathBuf};

use ndarray::{Array, IxDyn};
use ort::value::TensorRef;

use super::common::load_rgb_image;
use crate::pipeline::{FindingRegion, ScanFinding};

/// OpenCV Zoo CRNN English recognition model input height.
const REC_HEIGHT: u32 = 32;
const MAX_REC_WIDTH: u32 = 320;

/// CRNN English charset (0 = CTC blank).
const CHARSET: &str =
    "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~ ";

pub fn enrich_with_recognition(
    file_path: &str,
    model_path: &str,
    findings: &mut [ScanFinding],
) {
    let rec_path = resolve_rec_path(model_path);
    if !rec_path.exists() {
        return;
    }
    let Ok(image) = load_rgb_image(file_path) else {
        return;
    };

    for finding in findings.iter_mut() {
        let Some(ref region) = finding.region else {
            continue;
        };
        let Some(text) = recognize_region(&image, *region, rec_path.to_str().unwrap()) else {
            continue;
        };
        if text.trim().is_empty() {
            continue;
        }
        finding.metadata.insert("ocr_text".to_string(), text.clone());
        finding.metadata
            .insert("doc_type".to_string(), classify_document_text(&text));
        finding.description = format!(
            "Recognized text may contain personal data: \"{}\"",
            mask_preview(&text)
        );
    }
}

fn resolve_rec_path(model_path: &str) -> PathBuf {
    let pack_dir = Path::new(model_path)
        .parent()
        .and_then(|p| p.parent());
    if let Some(dir) = pack_dir {
        let rec = dir.join("models").join("ppocr_rec.onnx");
        if rec.exists() {
            return rec;
        }
    }
    PathBuf::from(model_path)
}

fn recognize_region(
    image: &image::RgbImage,
    region: FindingRegion,
    rec_model_path: &str,
) -> Option<String> {
    let (iw, ih) = image.dimensions();
    let x1 = (region.x * iw as f32).max(0.0) as u32;
    let y1 = (region.y * ih as f32).max(0.0) as u32;
    let x2 = ((region.x + region.width) * iw as f32).min(iw as f32) as u32;
    let y2 = ((region.y + region.height) * ih as f32).min(ih as f32) as u32;
    if x2 <= x1 || y2 <= y1 {
        return None;
    }

    let crop = image::imageops::crop_imm(image, x1, y1, x2 - x1, y2 - y1).to_image();
    let aspect = crop.width() as f32 / crop.height().max(1) as f32;
    let mut target_w = ((REC_HEIGHT as f32 * aspect).round() as u32).clamp(8, MAX_REC_WIDTH);
    target_w = ((target_w + 7) / 8) * 8;

    let resized = image::imageops::resize(
        &crop,
        target_w,
        REC_HEIGHT,
        image::imageops::FilterType::Triangle,
    );

    let plane = (REC_HEIGHT * target_w) as usize;
    let mut tensor = vec![0.0_f32; plane];
    for y in 0..REC_HEIGHT {
        for x in 0..target_w {
            let pixel = resized.get_pixel(x, y);
            let gray = 0.299 * pixel[0] as f32 + 0.587 * pixel[1] as f32 + 0.114 * pixel[2] as f32;
            let idx = (y * target_w + x) as usize;
            tensor[idx] = (gray - 127.5) / 127.5;
        }
    }

    let array = Array::from_shape_vec(IxDyn(&[1, 1, REC_HEIGHT as usize, target_w as usize]), tensor)
        .ok()?;

    super::session_cache::with_session(rec_model_path, |session| {
        let tensor = TensorRef::from_array_view(array.view()).map_err(|e| e.to_string())?;
        let outputs = session
            .run(ort::inputs!["x" => tensor])
            .map_err(|e| e.to_string())?;

        let (shape, data) = first_output_tensor(&outputs).ok_or_else(|| "No tensor output".to_string())?;
        Ok(decode_ctc(&shape, &data))
    })
    .ok()
    .flatten()
}

fn first_output_tensor(
    outputs: &ort::session::SessionOutputs,
) -> Option<(Vec<i64>, Vec<f32>)> {
    for (name, _) in outputs.iter() {
        if let Ok((shape, data)) = outputs.get(name).unwrap().try_extract_tensor::<f32>() {
            return Some((shape.iter().copied().collect(), data.to_vec()));
        }
    }
    None
}

fn decode_ctc(shape: &[i64], data: &[f32]) -> Option<String> {
    let (steps, classes, transposed) = resolve_ctc_dims(shape)?;
    if classes < 2 || steps == 0 {
        return None;
    }

    let at = |step: usize, class_idx: usize| -> f32 {
        if transposed {
            data.get(class_idx * steps + step).copied().unwrap_or(f32::NEG_INFINITY)
        } else {
            data.get(step * classes + class_idx).copied().unwrap_or(f32::NEG_INFINITY)
        }
    };

    let mut out = String::new();
    let mut prev = usize::MAX;
    for step in 0..steps {
        let mut best_idx = 0usize;
        let mut best_val = f32::NEG_INFINITY;
        for class_idx in 0..classes {
            let val = at(step, class_idx);
            if val > best_val {
                best_val = val;
                best_idx = class_idx;
            }
        }
        if best_idx == 0 || best_idx == prev {
            prev = best_idx;
            continue;
        }
        prev = best_idx;
        let char_idx = best_idx.saturating_sub(1);
        if char_idx < CHARSET.len() {
            out.push(CHARSET.chars().nth(char_idx).unwrap_or('?'));
        }
    }
    Some(out.trim().to_string())
}

fn resolve_ctc_dims(shape: &[i64]) -> Option<(usize, usize, bool)> {
    let positive: Vec<i64> = shape.iter().copied().filter(|d| *d > 0).collect();
    let (a, b) = match positive.as_slice() {
        [t, c] => (*t, *c),
        [_, t, c] => (*t, *c),
        _ => return None,
    };
    // CRNN vocab is ~97 classes; time steps are typically much larger.
    if b >= 16 && a > b {
        Some((a as usize, b as usize, false))
    } else if a >= 16 && b > a {
        Some((b as usize, a as usize, true))
    } else if b > a {
        Some((a as usize, b as usize, false))
    } else {
        Some((b as usize, a as usize, true))
    }
}

fn mask_preview(text: &str) -> String {
    if text.len() <= 4 {
        return "*".repeat(text.len());
    }
    let visible = text.len().min(3);
    format!("{}…", &text[..visible])
}

fn classify_document_text(text: &str) -> String {
    let lower = text.to_lowercase();
    if lower.contains("aadhaar")
        || lower.contains("aadhar")
        || lower.contains("uidai")
        || lower.contains("unique identification")
        || lower.contains("government of india")
    {
        "aadhaar".to_string()
    } else if lower.contains("passport") || lower.contains("nationality") {
        "passport".to_string()
    } else if lower.contains("invoice") || lower.contains("total due") {
        "invoice".to_string()
    } else if lower.contains("payslip") || lower.contains("salary") {
        "payslip".to_string()
    } else if lower.contains("contract") || lower.contains("agreement") {
        "contract".to_string()
    } else if looks_like_aadhaar_digits(text) {
        "aadhaar".to_string()
    } else {
        "document".to_string()
    }
}

fn looks_like_aadhaar_digits(text: &str) -> bool {
    // 12-digit Aadhaar with optional spaces, e.g. 2345 6789 0123
    let bytes = text.as_bytes();
    let mut i = 0;
    while i + 14 <= bytes.len() {
        if is_four_digits(&bytes[i..])
            && (bytes[i + 4] == b' ' || bytes[i + 4] == b'-')
            && is_four_digits(&bytes[i + 5..])
            && (bytes[i + 9] == b' ' || bytes[i + 9] == b'-')
            && is_four_digits(&bytes[i + 10..])
        {
            return true;
        }
        i += 1;
    }
    let digits: String = text.chars().filter(|c| c.is_ascii_digit()).collect();
    digits.len() >= 12 && digits.len() <= 14
}

fn is_four_digits(bytes: &[u8]) -> bool {
    bytes.len() >= 4
        && bytes[0].is_ascii_digit()
        && bytes[1].is_ascii_digit()
        && bytes[2].is_ascii_digit()
        && bytes[3].is_ascii_digit()
}
