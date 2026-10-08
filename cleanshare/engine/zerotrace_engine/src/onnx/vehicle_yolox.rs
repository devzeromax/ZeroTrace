use std::path::PathBuf;

use ndarray::{Array, IxDyn};
use ort::value::TensorRef;

use super::common::{
    finding_from_detection, load_rgb_image, nms, prepare_nchw_bgr, sigmoid, Detection,
};
use super::lpd;
use crate::pipeline::{FindingRegion, ScanFinding};

const INPUT_W: u32 = 640;
const INPUT_H: u32 = 640;
const CONF_THRESHOLD: f32 = 0.30;
const NMS_THRESHOLD: f32 = 0.45;
const MAX_VEHICLES: usize = 4;

/// COCO indices for vehicles.
const VEHICLE_CLASSES: [usize; 4] = [2, 3, 5, 7]; // car, motorcycle, bus, truck

pub fn scan_vehicles_and_plates(
    file_path: &str,
    model_path: &str,
) -> Result<Vec<ScanFinding>, String> {
    let lpd_model = lpd::resolve_lpd_path(model_path);
    let lpd_path = lpd_model.to_str().unwrap();

    let vehicles = scan_yolox_vehicles(file_path, model_path).unwrap_or_default();

    // Never abort the pack if LPD errors — vehicles alone still help ROI retry.
    let mut plate_findings = lpd::scan_plates(file_path, lpd_path).unwrap_or_else(|e| {
        crate::log::error(&format!("lpd full-frame failed: {e}"));
        Vec::new()
    });

    // Vehicle-guided refinement when full-frame LPD misses a plate (watermarks, small plates).
    if plate_findings.is_empty() {
        for vehicle in &vehicles {
            let Some(region) = vehicle.region else {
                continue;
            };
            // Prefer the lower bumper band where Indian plates sit.
            let bumper = FindingRegion {
                x: (region.x - 0.04).max(0.0),
                y: (region.y + region.height * 0.55).clamp(0.0, 0.95),
                width: (region.width + 0.08).min(1.0 - region.x),
                height: (region.height * 0.50).max(0.08).min(1.0 - region.y),
            };
            for roi in [bumper, expand_region(region, 0.16)] {
                if let Ok(mut roi_hits) = lpd::scan_plates_in_roi(file_path, lpd_path, roi) {
                    plate_findings.append(&mut roi_hits);
                }
                if !plate_findings.is_empty() {
                    break;
                }
            }
            if !plate_findings.is_empty() {
                break;
            }
        }
    }

    let mut findings = plate_findings;
    findings.extend(vehicles);
    Ok(findings)
}

fn expand_region(region: FindingRegion, margin: f32) -> FindingRegion {
    let x = (region.x - margin).max(0.0);
    let y = (region.y - margin).max(0.0);
    let x2 = (region.x + region.width + margin).min(1.0);
    let y2 = (region.y + region.height + margin).min(1.0);
    FindingRegion {
        x,
        y,
        width: (x2 - x).max(0.01),
        height: (y2 - y).max(0.01),
    }
}

fn scan_yolox_vehicles(file_path: &str, model_path: &str) -> Result<Vec<ScanFinding>, String> {
    let yolox = resolve_yolox_path(model_path);
    if !yolox.exists() {
        return Ok(Vec::new());
    }

    let image = load_rgb_image(file_path)?;
    let prepared = prepare_nchw_bgr(&image, INPUT_W, INPUT_H);

    let array = Array::from_shape_vec(
        IxDyn(&[1, 3, INPUT_H as usize, INPUT_W as usize]),
        prepared.tensor,
    )
    .map_err(|e| e.to_string())?;

    super::session_cache::with_session(yolox.to_str().unwrap(), |session| {
        super::common::log_model_io("yolox", session);
        let input_name = if session.inputs().iter().any(|i| i.name() == "images") {
            "images"
        } else {
            "input"
        };

        let outputs = session
            .run(ort::inputs![input_name => TensorRef::from_array_view(array.view()).map_err(|e| e.to_string())?])
            .map_err(|e| e.to_string())?;

        let (shape, data) = first_output_tensor(&outputs)?;
        crate::log::info(&format!("yolox output shape={shape:?}"));
        let candidates = decode_yolox(&shape, &data)?;
        crate::log::info(&format!("yolox raw vehicle candidates={}", candidates.len()));
        let kept = nms(candidates, NMS_THRESHOLD, MAX_VEHICLES);
        crate::log::info(&format!("yolox kept vehicles={}", kept.len()));

        let mut findings = Vec::new();
        for (idx, det) in kept.into_iter().enumerate() {
            if let Some(finding) = finding_from_detection(
                "vehicle-protection-vehicle",
                idx,
                "Vehicles",
                "Vehicle detected",
                "A vehicle was detected in this photo. Blur the vehicle or license plate before sharing.",
                "medium",
                "Enable blur to hide this vehicle region",
                det,
                &prepared.letterbox,
            ) {
                findings.push(finding);
            }
        }
        Ok(findings)
    })
}

fn resolve_yolox_path(model_path: &str) -> PathBuf {
    let model = PathBuf::from(model_path);
    let pack_dir = model.parent().and_then(|p| p.parent());
    if let Some(dir) = pack_dir {
        let yolox = dir.join("models").join("yolox.onnx");
        if yolox.exists() {
            return yolox;
        }
    }
    model
}

fn first_output_tensor(
    outputs: &ort::session::SessionOutputs,
) -> Result<(Vec<i64>, Vec<f32>), String> {
    for (name, _) in outputs.iter() {
        if let Ok((shape, data)) = outputs.get(name).unwrap().try_extract_tensor::<f32>() {
            return Ok((shape.iter().copied().collect(), data.to_vec()));
        }
    }
    Err("YOLOX produced no tensor output".into())
}

fn decode_yolox(shape: &[i64], data: &[f32]) -> Result<Vec<Detection>, String> {
    let (rows, cols, transposed) = resolve_yolox_dims(shape)?;

    if cols < 85 || rows == 0 {
        return Ok(Vec::new());
    }

    let mut out = Vec::new();
    for i in 0..rows {
        let base = if transposed {
            i
        } else {
            i * cols
        };
        if !transposed && base + 84 >= data.len() {
            break;
        }
        if transposed && base + (cols - 1) * rows >= data.len() {
            break;
        }

        let at = |row: usize, col: usize| -> f32 {
            if transposed {
                data[col * rows + row]
            } else {
                data[row * cols + col]
            }
        };

        let obj = sigmoid(at(i, 4));
        if obj < CONF_THRESHOLD {
            continue;
        }
        let mut best_class = 0usize;
        let mut best_score = 0.0_f32;
        for class_id in 0..80 {
            let score = sigmoid(at(i, 5 + class_id));
            if score > best_score {
                best_score = score;
                best_class = class_id;
            }
        }
        if !VEHICLE_CLASSES.contains(&best_class) {
            continue;
        }
        let confidence = (obj * best_score).sqrt();
        if confidence < CONF_THRESHOLD {
            continue;
        }
        let cx = at(i, 0);
        let cy = at(i, 1);
        let w = at(i, 2);
        let h = at(i, 3);
        out.push(Detection {
            x: cx - w / 2.0,
            y: cy - h / 2.0,
            w,
            h,
            score: confidence,
        });
    }
    Ok(out)
}

fn resolve_yolox_dims(shape: &[i64]) -> Result<(usize, usize, bool), String> {
    let positive: Vec<i64> = shape.iter().copied().filter(|d| *d > 0).collect();
    let (a, b) = match positive.as_slice() {
        [n, c] => (*n, *c),
        [_, n, c] => (*n, *c),
        _ => return Ok((0, 0, false)),
    };

    if b == 85 {
        Ok((a as usize, b as usize, false))
    } else if a == 85 {
        Ok((b as usize, a as usize, true))
    } else if b > a {
        Ok((a as usize, b as usize, false))
    } else {
        Ok((b as usize, a as usize, true))
    }
}
