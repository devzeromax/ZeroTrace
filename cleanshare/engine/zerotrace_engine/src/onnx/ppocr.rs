use ndarray::{Array, IxDyn};
use ort::value::TensorRef;

use super::common::{
    load_rgb_image, map_stretch_box_to_normalized, nms, prepare_nchw_rgb_imagenet_stretch,
};
use super::db_postprocess::{boxes_from_bitmap, DbConfig};
use super::ppocr_rec;
use crate::pipeline::ScanFinding;

/// PPOCR-Det input — multiple of 32; 512 is faster than 736 on scene photos.
const INPUT_W: u32 = 512;
const INPUT_H: u32 = 512;
const NMS_THRESHOLD: f32 = 0.4;
const MAX_TEXT_REGIONS: usize = 6;
const MIN_REC_CONFIDENCE: f32 = 0.42;

pub fn scan_documents(file_path: &str, model_path: &str) -> Result<Vec<ScanFinding>, String> {
    let image = load_rgb_image(file_path)?;
    let prepared = prepare_nchw_rgb_imagenet_stretch(&image, INPUT_W, INPUT_H);

    let array = Array::from_shape_vec(
        IxDyn(&[1, 3, INPUT_H as usize, INPUT_W as usize]),
        prepared.tensor,
    )
    .map_err(|e| e.to_string())?;

    let (heatmap, heatmap_w, heatmap_h) = super::session_cache::with_session(model_path, |session| {
        let outputs = session
            .run(ort::inputs!["x" => TensorRef::from_array_view(array.view()).map_err(|e| e.to_string())?])
            .map_err(|e| e.to_string())?;
        first_output_tensor(&outputs)
    })?;

    let boxes = boxes_from_bitmap(&heatmap, heatmap_w, heatmap_h, &DbConfig::default());
    let kept = nms(boxes, NMS_THRESHOLD, MAX_TEXT_REGIONS);
    let region_count = kept.len();

    let mut findings = Vec::new();
    for (idx, det) in kept.into_iter().enumerate() {
        let Some(region) =
            map_stretch_box_to_normalized(det.x, det.y, det.w, det.h, &prepared.letterbox)
        else {
            continue;
        };
        findings.push(ScanFinding {
            id: format!("document-protection-{idx}"),
            category: "Documents".to_string(),
            title: if region_count == 1 {
                "Sensitive text detected".to_string()
            } else {
                format!("Text region {} detected", idx + 1)
            },
            description:
                "Document OCR found text that may contain personal or confidential data."
                    .to_string(),
            severity: "medium".to_string(),
            confidence: det.score.clamp(0.0, 1.0),
            recommendation: Some("Enable blur to redact this text before sharing".to_string()),
            region: Some(region),
            supports_blur: true,
            ..Default::default()
        });
    }

    if !findings.is_empty() {
        ppocr_rec::enrich_with_recognition(file_path, model_path, &mut findings);
        findings.retain(|f| f.confidence >= MIN_REC_CONFIDENCE || f.metadata.contains_key("ocr_text"));
    }

    Ok(findings)
}

fn first_output_tensor(outputs: &ort::session::SessionOutputs) -> Result<(Vec<f32>, u32, u32), String> {
    for (name, _) in outputs.iter() {
        if let Ok((shape, data)) = outputs
            .get(name)
            .unwrap()
            .try_extract_tensor::<f32>()
        {
            let dims: Vec<i64> = shape.iter().copied().collect();
            let (h, w) = heatmap_dims(&dims)?;
            return Ok((data.to_vec(), w, h));
        }
    }
    Err("PPOCR model produced no tensor output".into())
}

fn heatmap_dims(dims: &[i64]) -> Result<(u32, u32), String> {
    let positive: Vec<u32> = dims
        .iter()
        .filter_map(|d| (*d > 0).then_some(*d as u32))
        .collect();
    match positive.as_slice() {
        [h, w] => Ok((*h, *w)),
        [_, h, w] => Ok((*h, *w)),
        [_, _, h, w] => Ok((*h, *w)),
        _ => Err(format!("Unexpected PPOCR output shape: {dims:?}")),
    }
}
