//! ZeroTrace core scanner engine (Rust).
//!
//! Responsibilities:
//! - Metadata extraction and stripping
//! - Developer secret pattern detection
//! - ONNX model inference (via `ort` when enabled)
//!
//! Flutter binds through `flutter_rust_bridge` — see `ARCHITECTURE.md`.

pub mod ffi;
pub mod log;
pub mod metadata;
pub mod onnx;
pub mod pipeline;
pub mod secrets;

pub use pipeline::{ScanFinding, ScanPipelineOutput, run_scan};
