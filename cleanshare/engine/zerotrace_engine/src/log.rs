//! Lightweight stderr logging for the native engine (visible in debug / DevTools).

pub fn info(message: &str) {
    eprintln!("[zerotrace] {message}");
}

pub fn warn(message: &str) {
    eprintln!("[zerotrace:warn] {message}");
}

pub fn error(message: &str) {
    eprintln!("[zerotrace:error] {message}");
}
