use ndarray::{Array, IxDyn};
use ort::value::TensorRef;

use super::common::{
    finding_from_detection, load_rgb_image, log_model_io, nms, prepare_nchw_bgr, primary_input_name,
    sigmoid, Detection,
};
use crate::pipeline::ScanFinding;

const INPUT_W: u32 = 640;
const INPUT_H: u32 = 640;
const CONF_THRESHOLD: f32 = 0.55;
const NMS_THRESHOLD: f32 = 0.38;
const MAX_FACES: usize = 12;

/// SCRFD face detector (OpenCV Zoo) — better angles and small faces than YuNet alone.
pub fn scan_faces(file_path: &str, model_path: &str) -> Result<Vec<ScanFinding>, String> {
    let image = load_rgb_image(file_path)?;
    let prepared = prepare_nchw_bgr(&image, INPUT_W, INPUT_H);

    let array = Array::from_shape_vec(
        IxDyn(&[1, 3, INPUT_H as usize, INPUT_W as usize]),
        prepared.tensor,
    )
    .map_err(|e| e.to_string())?;

    super::session_cache::with_session(model_path, |session| {
        log_model_io("scrfd", session);
        let input_name = primary_input_name(session);
        let outputs = session
            .run(ort::inputs![input_name.as_str() => TensorRef::from_array_view(array.view()).map_err(|e| e.to_string())?])
            .map_err(|e| e.to_string())?;

        let mut candidates = Vec::new();
        for stride in [8_u32, 16, 32] {
            let score_name = format!("score_{stride}");
            let bbox_name = format!("bbox_{stride}");
            let (Ok(scores), Ok(bboxes)) = (
                tensor_f32(&outputs, &score_name),
                tensor_f32(&outputs, &bbox_name),
            ) else {
                continue;
            };

            let fm = INPUT_W / stride;
            let anchors = (fm * fm) as usize;
            if scores.len() < anchors || bboxes.len() < anchors * 4 {
                continue;
            }

            for i in 0..anchors {
                let score = sigmoid(scores[i]);
                if score < CONF_THRESHOLD {
                    continue;
                }
                let row = i as u32 / fm;
                let col = i as u32 % fm;
                let bx = bboxes[i * 4];
                let by = bboxes[i * 4 + 1];
                let bw = bboxes[i * 4 + 2].exp() * stride as f32;
                let bh = bboxes[i * 4 + 3].exp() * stride as f32;
                let cx = (col as f32 + bx) * stride as f32;
                let cy = (row as f32 + by) * stride as f32;
                candidates.push(Detection {
                    x: cx - bw / 2.0,
                    y: cy - bh / 2.0,
                    w: bw,
                    h: bh,
                    score,
                });
            }
        }

        crate::log::info(&format!("scrfd raw candidates={}", candidates.len()));
        let kept = nms(candidates, NMS_THRESHOLD, MAX_FACES);
        crate::log::info(&format!("scrfd kept faces={}", kept.len()));
        let mut findings = Vec::new();
        for (idx, det) in kept.into_iter().enumerate() {
            if let Some(finding) = finding_from_detection(
                "face-protection",
                idx,
                "Faces",
                "Face detected (SCRFD)",
                "High-confidence face region from the pro SCRFD model. Enable blur before sharing.",
                "high",
                "Enable blur to hide this face",
                det,
                &prepared.letterbox,
            ) {
                findings.push(finding);
            }
        }
        Ok(findings)
    })
}

fn tensor_f32<'a>(
    outputs: &'a ort::session::SessionOutputs,
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
