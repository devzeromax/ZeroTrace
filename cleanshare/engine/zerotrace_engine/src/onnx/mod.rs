mod common;
mod db_postprocess;
mod face;
mod lpd;
mod mediapipe_face;
mod ppocr;
mod ppocr_rec;
mod scrfd;
mod session_cache;
mod vehicle_yolox;
mod yunet_face;

pub use session_cache::clear as clear_session_cache;

use crate::pipeline::ScanFinding;

/// True when the file extension is a raster image format the ONNX detectors can decode.
fn is_supported_image(path: &str) -> bool {
    let lower = path.to_ascii_lowercase();
    [
        ".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tif", ".tiff", ".gif", ".ico", ".tga", ".pnm",
        ".ppm", ".pgm", ".pbm", ".dds", ".hdr", ".exr", ".ff", ".heic", ".heif",
    ]
    .iter()
    .any(|ext| lower.ends_with(ext))
}

#[cfg(feature = "onnx")]
static ONNX_READY: std::sync::OnceLock<bool> = std::sync::OnceLock::new();

#[cfg(feature = "onnx")]
pub fn is_available() -> bool {
    *ONNX_READY.get_or_init(|| {
        // commit() returns false when another caller already configured ort — that
        // still means ONNX is available in this build.
        let _ = ort::init().with_name("zerotrace").commit();
        std::panic::catch_unwind(ort::api).is_ok()
    })
}

#[cfg(not(feature = "onnx"))]
pub fn is_available() -> bool {
    false
}

/// Runs ONNX inference for an installed pack model against a file path.
pub fn scan_with_model(
    file_path: &str,
    model_path: &str,
    pack_id: &str,
) -> Result<Vec<ScanFinding>, String> {
    if !is_available() {
        return Err("ONNX runtime not available in this engine build.".into());
    }

    // Image-based ONNX detectors (face/vehicle/document OCR) only handle raster
    // images. PDFs and other non-image files must not reach the image loader,
    // otherwise the decoder errors with "extension not recognized as an image".
    if !is_supported_image(file_path) {
        crate::log::info(&format!(
            "ONNX scan skipped pack={pack_id}: {file_path} is not a raster image"
        ));
        return Ok(Vec::new());
    }

    let model = std::fs::metadata(model_path).map_err(|e| e.to_string())?;
    if model.len() <= 1024 {
        return Err(format!(
            "Model for {pack_id} is a placeholder stub ({bytes} bytes). Ship real ONNX weights.",
            bytes = model.len()
        ));
    }

    #[cfg(feature = "onnx")]
    {
        crate::log::info(&format!("ONNX scan pack={pack_id} file={file_path}"));
        let result = match pack_id {
            "face-protection" => face::scan(file_path, model_path),
            "vehicle-protection" => vehicle_yolox::scan_vehicles_and_plates(file_path, model_path),
            "document-protection" => ppocr::scan_documents(file_path, model_path),
            other => Err(format!("Unsupported ONNX pack: {other}")),
        };
        if let Err(ref e) = result {
            crate::log::error(&format!("ONNX scan failed pack={pack_id}: {e}"));
        }
        result
    }

    #[cfg(not(feature = "onnx"))]
    {
        let _ = (file_path, model_path, pack_id);
        Err("ONNX feature not compiled. Rebuild with --features onnx.".into())
    }
}
