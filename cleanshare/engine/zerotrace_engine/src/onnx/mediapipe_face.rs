use ndarray::{Array, Array1, IxDyn};
use ort::value::TensorRef;

use super::common::{load_rgb_image, nms, Detection};
use crate::pipeline::{FindingRegion, ScanFinding};

const INPUT_SIZE: u32 = 128;
const CONF_THRESHOLD: f32 = 0.55;
const IOU_THRESHOLD: f32 = 0.35;
const MAX_DETECTIONS: i64 = 8;
const MAX_FACES: usize = 8;
const MIN_BOX_AREA: f32 = 0.01;

/// MediaPipe BlazeFace (short-range) — ONNX with built-in NMS.
pub fn scan_faces(file_path: &str, model_path: &str) -> Result<Vec<ScanFinding>, String> {
    let image = load_rgb_image(file_path)?;
    let (_orig_w, _orig_h) = image.dimensions();

    let resized = image::imageops::resize(
        &image,
        INPUT_SIZE,
        INPUT_SIZE,
        image::imageops::FilterType::Triangle,
    );

    let mut tensor = vec![0.0_f32; (3 * INPUT_SIZE * INPUT_SIZE) as usize];
    let plane = (INPUT_SIZE * INPUT_SIZE) as usize;
    for y in 0..INPUT_SIZE {
        for x in 0..INPUT_SIZE {
            let pixel = resized.get_pixel(x, y);
            let idx = y as usize * INPUT_SIZE as usize + x as usize;
            tensor[idx] = pixel[0] as f32 / 255.0;
            tensor[plane + idx] = pixel[1] as f32 / 255.0;
            tensor[2 * plane + idx] = pixel[2] as f32 / 255.0;
        }
    }

    let image_tensor = Array::from_shape_vec(
        IxDyn(&[1, 3, INPUT_SIZE as usize, INPUT_SIZE as usize]),
        tensor,
    )
    .map_err(|e| e.to_string())?;

    let conf = Array::from_shape_vec((1,), vec![CONF_THRESHOLD]).map_err(|e| e.to_string())?;
    let iou = Array::from_shape_vec((1,), vec![IOU_THRESHOLD]).map_err(|e| e.to_string())?;
    let max_det: Array1<i64> = ndarray::arr1(&[MAX_DETECTIONS]);

    super::session_cache::with_session(model_path, |session| {
        let outputs = session
            .run(ort::inputs![
                "image" => TensorRef::from_array_view(image_tensor.view()).map_err(|e| e.to_string())?,
                "conf_threshold" => TensorRef::from_array_view(conf.view()).map_err(|e| e.to_string())?,
                "max_detections" => TensorRef::from_array_view(max_det.view()).map_err(|e| e.to_string())?,
                "iou_threshold" => TensorRef::from_array_view(iou.view()).map_err(|e| e.to_string())?,
            ])
            .map_err(|e| e.to_string())?;

        let value = outputs
            .get("selectedBoxes")
            .ok_or_else(|| "BlazeFace missing selectedBoxes output".to_string())?;
        let (shape, data) = value
            .try_extract_tensor::<f32>()
            .map_err(|e| e.to_string())?;

        let boxes = parse_blazeface_boxes(shape, data);
        let face_count = boxes.len().min(MAX_FACES);
        let mut findings = Vec::new();
        for (idx, row) in boxes.into_iter().take(MAX_FACES).enumerate() {
            let region = map_blazeface_region(row[0], row[1], row[2], row[3]);
            findings.push(ScanFinding {
                id: format!("face-protection-{idx}"),
                category: "Faces".to_string(),
                title: if face_count == 1 {
                    "Face detected".to_string()
                } else {
                    format!("Face {} detected", idx + 1)
                },
                description: if face_count == 1 {
                    "One face was detected in this image. Enable blur in Review fixes to hide it before sharing.".to_string()
                } else {
                    format!(
                        "{face_count} distinct faces detected. Enable blur for each region you want hidden."
                    )
                },
                severity: "high".to_string(),
                confidence: row[4].clamp(0.0, 1.0),
                recommendation: Some("Enable blur to pixelate this face region".to_string()),
                region: Some(region),
                supports_blur: true,
                ..Default::default()
            });
        }
        Ok(findings)
    })
}

fn parse_blazeface_boxes(shape: &[i64], data: &[f32]) -> Vec<[f32; 5]> {
    let mut rows = Vec::new();
    if shape.len() == 3 && shape[0] == 1 && shape[2] == 16 {
        let count = shape[1] as usize;
        for i in 0..count {
            let base = i * 16;
            if base + 16 > data.len() {
                break;
            }
            if let Some(row) = row_from_blazeface(&data[base..base + 16]) {
                rows.push(row);
            }
        }
    } else if shape.len() == 2 && shape[0] == 1 && shape[1] == 16 && data.len() >= 16 {
        if let Some(row) = row_from_blazeface(data) {
            rows.push(row);
        }
    }

    if rows.is_empty() {
        return rows;
    }

    rows.sort_by(|a, b| {
        b[4]
            .partial_cmp(&a[4])
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let detections: Vec<Detection> = rows
        .iter()
        .map(|row| Detection {
            x: row[0] * INPUT_SIZE as f32,
            y: row[1] * INPUT_SIZE as f32,
            w: (row[2] - row[0]) * INPUT_SIZE as f32,
            h: (row[3] - row[1]) * INPUT_SIZE as f32,
            score: row[4],
        })
        .collect();

    let kept = nms(detections, IOU_THRESHOLD, MAX_FACES);
    kept.into_iter()
        .map(|det| {
            [
                det.x / INPUT_SIZE as f32,
                det.y / INPUT_SIZE as f32,
                (det.x + det.w) / INPUT_SIZE as f32,
                (det.y + det.h) / INPUT_SIZE as f32,
                det.score,
            ]
        })
        .collect()
}

fn row_from_blazeface(values: &[f32]) -> Option<[f32; 5]> {
    if values.len() < 16 {
        return None;
    }
    let ymin = values[0];
    let xmin = values[1];
    let ymax = values[2];
    let xmax = values[3];
    let score = values[15];
    if score < CONF_THRESHOLD {
        return None;
    }
    if xmax <= xmin || ymax <= ymin {
        return None;
    }
    let area = (xmax - xmin) * (ymax - ymin);
    if area < MIN_BOX_AREA {
        return None;
    }
    Some([xmin, ymin, xmax, ymax, score])
}

/// BlazeFace boxes are already normalized 0–1 on the 128×128 input.
pub fn map_blazeface_region(xmin: f32, ymin: f32, xmax: f32, ymax: f32) -> FindingRegion {
    FindingRegion {
        x: xmin.clamp(0.0, 1.0),
        y: ymin.clamp(0.0, 1.0),
        width: (xmax - xmin).clamp(0.0, 1.0),
        height: (ymax - ymin).clamp(0.0, 1.0),
    }
}
