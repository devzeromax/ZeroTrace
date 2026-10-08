//! C ABI exports for Flutter FFI.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use crate::pipeline::ScanPipelineOutput;

#[no_mangle]
pub extern "C" fn zerotrace_engine_version() -> *mut c_char {
    CString::new("0.1.0").unwrap().into_raw()
}

/// Returns 1 when ONNX Runtime is linked in this build.
#[no_mangle]
pub extern "C" fn zerotrace_onnx_available() -> i32 {
    if crate::onnx::is_available() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn zerotrace_run_onnx_scan_json(
    file_path: *const c_char,
    model_path: *const c_char,
    pack_id: *const c_char,
) -> *mut c_char {
    let file = match ptr_to_str(file_path) {
        Some(s) => s,
        None => return error_json("Invalid file path pointer"),
    };
    let model = match ptr_to_str(model_path) {
        Some(s) => s,
        None => return error_json("Invalid model path pointer"),
    };
    let pack = match ptr_to_str(pack_id) {
        Some(s) => s,
        None => return error_json("Invalid pack id pointer"),
    };

    match crate::onnx::scan_with_model(&file, &model, &pack) {
        Ok(findings) => {
            let output = ScanPipelineOutput {
                findings,
                risk_score: 0,
                duration_ms: 0,
            };
            ok_json(&output)
        }
        Err(e) => error_json(&e),
    }
}

fn ptr_to_str(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }
    let c_str = unsafe { CStr::from_ptr(ptr) };
    c_str.to_str().ok().map(str::to_string)
}

#[no_mangle]
pub extern "C" fn zerotrace_run_scan_json(path: *const c_char) -> *mut c_char {
    if path.is_null() {
        return error_json("Null file path");
    }

    let c_str = unsafe { CStr::from_ptr(path) };
    let path_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return error_json("Invalid UTF-8 file path"),
    };

    match crate::pipeline::run_scan(path_str) {
        Ok(output) => ok_json(&output),
        Err(e) => error_json(&e),
    }
}

fn ok_json(output: &ScanPipelineOutput) -> *mut c_char {
    match serde_json::to_string(output) {
        Ok(json) => CString::new(json).unwrap().into_raw(),
        Err(e) => error_json(&e.to_string()),
    }
}

fn error_json(message: &str) -> *mut c_char {
    crate::log::error(message);
    let payload = ScanPipelineOutput {
        findings: Vec::new(),
        risk_score: 0,
        duration_ms: 0,
    };
    let mut value = serde_json::to_value(&payload).unwrap_or_default();
    if let Some(obj) = value.as_object_mut() {
        obj.insert("error".into(), serde_json::Value::String(message.to_string()));
    }
    match serde_json::to_string(&value) {
        Ok(json) => CString::new(json).unwrap().into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn zerotrace_free_string(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(s);
    }
}

/// Clears cached ONNX sessions (call after pack uninstall).
#[no_mangle]
pub extern "C" fn zerotrace_clear_onnx_cache() {
    crate::onnx::clear_session_cache();
}
