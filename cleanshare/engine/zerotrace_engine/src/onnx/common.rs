use crate::pipeline::{FindingRegion, ScanFinding};
use image::RgbImage;
use std::path::Path;

#[derive(Clone, Copy, Debug)]
pub struct Letterbox {
    pub scale: f32,
    pub pad_x: f32,
    pub pad_y: f32,
    pub input_w: u32,
    pub input_h: u32,
    pub orig_w: u32,
    pub orig_h: u32,
}

pub struct PreparedImage {
    pub tensor: Vec<f32>,
    pub letterbox: Letterbox,
}

pub fn load_rgb_image(path: &str) -> Result<RgbImage, String> {
    let path = Path::new(path);
    if !path.exists() {
        return Err(format!("Image not found: {path:?}"));
    }
    image::open(path)
        .map_err(|e| e.to_string())?
        .into_rgb8()
        .pipe(Ok)
}

trait Pipe<T> {
    fn pipe<F, U>(self, f: F) -> U
    where
        F: FnOnce(T) -> U;
}

impl<T> Pipe<T> for T {
    fn pipe<F, U>(self, f: F) -> U
    where
        F: FnOnce(T) -> U,
    {
        f(self)
    }
}

/// NCHW BGR tensor (OpenCV blob style) with letterboxing.
pub fn prepare_nchw_bgr(
    image: &image::RgbImage,
    input_w: u32,
    input_h: u32,
) -> PreparedImage {
    let orig_w = image.width();
    let orig_h = image.height();
    let scale = (input_w as f32 / orig_w as f32).min(input_h as f32 / orig_h as f32);
    let resized_w = (orig_w as f32 * scale).round().max(1.0) as u32;
    let resized_h = (orig_h as f32 * scale).round().max(1.0) as u32;
    let pad_x = ((input_w - resized_w) as f32) / 2.0;
    let pad_y = ((input_h - resized_h) as f32) / 2.0;

    let resized = image::imageops::resize(
        image,
        resized_w,
        resized_h,
        image::imageops::FilterType::Triangle,
    );

    let mut tensor = vec![114.0_f32; (3 * input_w * input_h) as usize];
    let plane = (input_w * input_h) as usize;

    for y in 0..resized_h {
        for x in 0..resized_w {
            let dst_x = x as i32 + pad_x.round() as i32;
            let dst_y = y as i32 + pad_y.round() as i32;
            if dst_x < 0
                || dst_y < 0
                || dst_x >= input_w as i32
                || dst_y >= input_h as i32
            {
                continue;
            }
            let pixel = resized.get_pixel(x, y);
            let idx = dst_y as usize * input_w as usize + dst_x as usize;
            tensor[idx] = pixel[2] as f32;
            tensor[plane + idx] = pixel[1] as f32;
            tensor[2 * plane + idx] = pixel[0] as f32;
        }
    }

    PreparedImage {
        tensor,
        letterbox: Letterbox {
            scale,
            pad_x,
            pad_y,
            input_w,
            input_h,
            orig_w,
            orig_h,
        },
    }
}

/// NCHW RGB tensor with ImageNet normalization — stretch resize (PPOCR-Det / OpenCV demo).
pub fn prepare_nchw_rgb_imagenet_stretch(
    image: &image::RgbImage,
    input_w: u32,
    input_h: u32,
) -> PreparedImage {
    const MEAN: [f32; 3] = [0.485, 0.456, 0.406];
    const STD: [f32; 3] = [0.229, 0.224, 0.225];

    let orig_w = image.width();
    let orig_h = image.height();
    let resized = image::imageops::resize(
        image,
        input_w,
        input_h,
        image::imageops::FilterType::Triangle,
    );

    let plane = (input_w * input_h) as usize;
    let mut tensor = vec![0.0_f32; 3 * plane];
    for y in 0..input_h {
        for x in 0..input_w {
            let pixel = resized.get_pixel(x, y);
            let idx = (y * input_w + x) as usize;
            let r = pixel[0] as f32 / 255.0;
            let g = pixel[1] as f32 / 255.0;
            let b = pixel[2] as f32 / 255.0;
            tensor[idx] = (r - MEAN[0]) / STD[0];
            tensor[plane + idx] = (g - MEAN[1]) / STD[1];
            tensor[2 * plane + idx] = (b - MEAN[2]) / STD[2];
        }
    }

    PreparedImage {
        tensor,
        letterbox: Letterbox {
            scale: 1.0,
            pad_x: 0.0,
            pad_y: 0.0,
            input_w,
            input_h,
            orig_w,
            orig_h,
        },
    }
}

/// Map a box in stretched model space back to normalized original coordinates.
pub fn map_stretch_box_to_normalized(
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    letterbox: &Letterbox,
) -> Option<FindingRegion> {
    let scale_x = letterbox.orig_w as f32 / letterbox.input_w as f32;
    let scale_y = letterbox.orig_h as f32 / letterbox.input_h as f32;
    let x1 = (x * scale_x).max(0.0);
    let y1 = (y * scale_y).max(0.0);
    let x2 = ((x + w) * scale_x).min(letterbox.orig_w as f32);
    let y2 = ((y + h) * scale_y).min(letterbox.orig_h as f32);
    if x2 <= x1 || y2 <= y1 {
        return None;
    }
    let width = x2 - x1;
    let height = y2 - y1;
    if width < 2.0 || height < 2.0 {
        return None;
    }
    Some(FindingRegion {
        x: (x1 / letterbox.orig_w as f32).clamp(0.0, 1.0),
        y: (y1 / letterbox.orig_h as f32).clamp(0.0, 1.0),
        width: (width / letterbox.orig_w as f32).clamp(0.0, 1.0),
        height: (height / letterbox.orig_h as f32).clamp(0.0, 1.0),
    })
}

pub fn map_box_to_normalized(
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    letterbox: &Letterbox,
) -> Option<FindingRegion> {
    let x1 = (x - letterbox.pad_x) / letterbox.scale;
    let y1 = (y - letterbox.pad_y) / letterbox.scale;
    let x2 = (x + w - letterbox.pad_x) / letterbox.scale;
    let y2 = (y + h - letterbox.pad_y) / letterbox.scale;

    let left = x1.min(x2).max(0.0);
    let top = y1.min(y2).max(0.0);
    let right = x1.max(x2).min(letterbox.orig_w as f32);
    let bottom = y1.max(y2).min(letterbox.orig_h as f32);

    if right <= left || bottom <= top {
        return None;
    }

    let width = right - left;
    let height = bottom - top;
    if width < 2.0 || height < 2.0 {
        return None;
    }

    Some(FindingRegion {
        x: (left / letterbox.orig_w as f32).clamp(0.0, 1.0),
        y: (top / letterbox.orig_h as f32).clamp(0.0, 1.0),
        width: (width / letterbox.orig_w as f32).clamp(0.0, 1.0),
        height: (height / letterbox.orig_h as f32).clamp(0.0, 1.0),
    })
}

pub fn sigmoid(x: f32) -> f32 {
    1.0 / (1.0 + (-x).exp())
}

/// First input tensor name for a session (models export different names).
pub fn primary_input_name(session: &ort::session::Session) -> String {
    session
        .inputs()
        .first()
        .map(|i| i.name().to_string())
        .unwrap_or_else(|| "input".to_string())
}

/// Logs the actual input/output tensor names so detector name maps can be verified.
pub fn log_model_io(tag: &str, session: &ort::session::Session) {
    let inputs: Vec<String> = session.inputs().iter().map(|i| i.name().to_string()).collect();
    let outputs: Vec<String> = session.outputs().iter().map(|o| o.name().to_string()).collect();
    crate::log::info(&format!("{tag} model io: inputs={inputs:?} outputs={outputs:?}"));
}

#[derive(Clone, Copy, Debug)]
pub struct Detection {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
    pub score: f32,
}

pub fn nms(mut dets: Vec<Detection>, threshold: f32, top_k: usize) -> Vec<Detection> {
    dets.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));
    dets.truncate(top_k.min(dets.len()));

    let mut keep = Vec::new();
    let mut suppressed = vec![false; dets.len()];

    for i in 0..dets.len() {
        if suppressed[i] {
            continue;
        }
        keep.push(dets[i]);
        for j in (i + 1)..dets.len() {
            if suppressed[j] {
                continue;
            }
            if iou(dets[i], dets[j]) >= threshold {
                suppressed[j] = true;
            }
        }
    }
    keep
}

fn iou(a: Detection, b: Detection) -> f32 {
    let ax2 = a.x + a.w;
    let ay2 = a.y + a.h;
    let bx2 = b.x + b.w;
    let by2 = b.y + b.h;
    let inter_x1 = a.x.max(b.x);
    let inter_y1 = a.y.max(b.y);
    let inter_x2 = ax2.min(bx2);
    let inter_y2 = ay2.min(by2);
    let inter_w = (inter_x2 - inter_x1).max(0.0);
    let inter_h = (inter_y2 - inter_y1).max(0.0);
    let inter = inter_w * inter_h;
    let union = a.w * a.h + b.w * b.h - inter;
    if union <= 0.0 {
        0.0
    } else {
        inter / union
    }
}

pub fn finding_from_detection(
    pack_id: &str,
    index: usize,
    category: &str,
    title: &str,
    description: &str,
    severity: &str,
    recommendation: &str,
    det: Detection,
    letterbox: &Letterbox,
) -> Option<ScanFinding> {
    let region = map_box_to_normalized(det.x, det.y, det.w, det.h, letterbox)?;
    Some(ScanFinding {
        id: format!("{pack_id}-{index}"),
        category: category.to_string(),
        title: title.to_string(),
        description: description.to_string(),
        severity: severity.to_string(),
        confidence: det.score.clamp(0.0, 1.0),
        recommendation: Some(recommendation.to_string()),
        region: Some(region),
        supports_blur: true,
        ..Default::default()
    })
}
