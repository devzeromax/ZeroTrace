//! Lazy ONNX session cache — models load once per path and stay resident for reuse.

use std::collections::HashMap;
use std::sync::Mutex;

use ort::session::Session;

static CACHE: Mutex<Option<HashMap<String, Session>>> = Mutex::new(None);

fn cache() -> std::sync::MutexGuard<'static, Option<HashMap<String, Session>>> {
    CACHE.lock().unwrap_or_else(|e| e.into_inner())
}

/// Runs inference with a cached [Session], loading from disk on first use.
pub fn with_session<F, T>(model_path: &str, f: F) -> Result<T, String>
where
    F: FnOnce(&mut Session) -> Result<T, String>,
{
    let mut guard = cache();
    let map = guard.get_or_insert_with(HashMap::new);

    if !map.contains_key(model_path) {
        crate::log::info(&format!("Loading ONNX model: {model_path}"));
        let session = Session::builder()
            .map_err(|e| e.to_string())?
            .commit_from_file(model_path)
            .map_err(|e| format!("Failed to load ONNX model {model_path}: {e}"))?;
        map.insert(model_path.to_string(), session);
    }

    let session = map
        .get_mut(model_path)
        .ok_or_else(|| format!("Session cache miss for {model_path}"))?;
    f(session)
}

/// Drops all cached sessions (e.g. after pack uninstall).
#[allow(dead_code)]
pub fn clear() {
    let mut guard = cache();
    if let Some(map) = guard.as_mut() {
        let count = map.len();
        map.clear();
        if count > 0 {
            crate::log::info(&format!("Cleared {count} cached ONNX session(s)"));
        }
    }
}
