use super::common::Detection;

/// OpenCV Zoo `PPOCRDet` / PaddleOCR DB defaults.
#[derive(Clone, Copy)]
pub struct DbConfig {
    pub binary_threshold: f32,
    pub polygon_threshold: f32,
    pub max_candidates: usize,
    pub unclip_ratio: f32,
    pub min_size: f32,
    /// Skip flood-fill blobs larger than this (avoids freezing on photo heatmaps).
    pub max_component_pixels: usize,
}

impl Default for DbConfig {
    fn default() -> Self {
        Self {
            binary_threshold: 0.3,
            polygon_threshold: 0.5,
            max_candidates: 200,
            unclip_ratio: 2.0,
            min_size: 3.0,
            max_component_pixels: 12_000,
        }
    }
}

/// PaddleOCR `boxes_from_bitmap` — connected components, mean score, unclip, size filter.
pub fn boxes_from_bitmap(
    pred: &[f32],
    width: u32,
    height: u32,
    config: &DbConfig,
) -> Vec<Detection> {
    let w = width as usize;
    let h = height as usize;
    if w == 0 || h == 0 || pred.len() < w * h {
        return Vec::new();
    }

    // Downsample large heatmaps before flood-fill (736² → 368²) for ~4× faster postprocess.
    let (pred_ds, w, h, scale) = if w * h > 160_000 {
        downsample_heatmap(pred, w, h, 2)
    } else {
        (pred.to_vec(), w, h, 1.0_f32)
    };

    let mut visited = vec![false; w * h];
    let mut components = Vec::new();

    for y in 0..h {
        for x in 0..w {
            let idx = y * w + x;
            if visited[idx] || pred_ds[idx] <= config.binary_threshold {
                continue;
            }
            let component = flood_component(
                &pred_ds,
                w,
                h,
                x,
                y,
                config.binary_threshold,
                &mut visited,
                config.max_component_pixels,
            );
            if component.pixels.len() < config.min_size as usize {
                continue;
            }
            if component.short_side() < config.min_size {
                continue;
            }
            let score = component.mean_score(&pred_ds, w);
            if score < config.polygon_threshold {
                continue;
            }
            components.push((component, score));
        }
    }

    components.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
    components.truncate(config.max_candidates);

    let mut boxes = Vec::new();
    for (component, score) in components {
        let (mut x1, mut y1, mut x2, mut y2) = component.bounds();
        x1 *= scale;
        y1 *= scale;
        x2 *= scale;
        y2 *= scale;
        (x1, y1, x2, y2) = unclip_aabb(x1, y1, x2, y2, config.unclip_ratio);
        let bw = x2 - x1;
        let bh = y2 - y1;
        if bw.min(bh) < config.min_size + 2.0 {
            continue;
        }
        boxes.push(Detection {
            x: x1,
            y: y1,
            w: bw.max(1.0),
            h: bh.max(1.0),
            score,
        });
    }
    boxes
}

fn downsample_heatmap(pred: &[f32], w: usize, h: usize, factor: usize) -> (Vec<f32>, usize, usize, f32) {
    let nw = (w / factor).max(1);
    let nh = (h / factor).max(1);
    let mut out = vec![0.0_f32; nw * nh];
    for y in 0..nh {
        for x in 0..nw {
            let mut sum = 0.0_f32;
            let mut count = 0usize;
            for dy in 0..factor {
                for dx in 0..factor {
                    let sx = x * factor + dx;
                    let sy = y * factor + dy;
                    if sx < w && sy < h {
                        sum += pred[sy * w + sx];
                        count += 1;
                    }
                }
            }
            out[y * nw + x] = if count > 0 { sum / count as f32 } else { 0.0 };
        }
    }
    (out, nw, nh, factor as f32)
}

struct Component {
    pixels: Vec<(usize, usize)>,
    min_x: usize,
    min_y: usize,
    max_x: usize,
    max_y: usize,
}

impl Component {
    fn short_side(&self) -> f32 {
        let w = (self.max_x - self.min_x + 1) as f32;
        let h = (self.max_y - self.min_y + 1) as f32;
        w.min(h)
    }

    fn bounds(&self) -> (f32, f32, f32, f32) {
        (
            self.min_x as f32,
            self.min_y as f32,
            (self.max_x + 1) as f32,
            (self.max_y + 1) as f32,
        )
    }

    fn mean_score(&self, pred: &[f32], width: usize) -> f32 {
        if self.pixels.is_empty() {
            return 0.0;
        }
        let sum: f32 = self
            .pixels
            .iter()
            .map(|&(x, y)| pred[y * width + x])
            .sum();
        sum / self.pixels.len() as f32
    }
}

fn flood_component(
    pred: &[f32],
    w: usize,
    h: usize,
    sx: usize,
    sy: usize,
    threshold: f32,
    visited: &mut [bool],
    max_pixels: usize,
) -> Component {
    let mut stack = vec![(sx, sy)];
    let mut pixels = Vec::new();
    let mut min_x = sx;
    let mut min_y = sy;
    let mut max_x = sx;
    let mut max_y = sy;

    while let Some((x, y)) = stack.pop() {
        if pixels.len() > max_pixels {
            break;
        }
        let idx = y * w + x;
        if visited[idx] || pred[idx] <= threshold {
            continue;
        }
        visited[idx] = true;
        pixels.push((x, y));
        min_x = min_x.min(x);
        min_y = min_y.min(y);
        max_x = max_x.max(x);
        max_y = max_y.max(y);

        for (nx, ny) in [
            (x.wrapping_sub(1), y),
            (x + 1, y),
            (x, y.wrapping_sub(1)),
            (x, y + 1),
        ] {
            if nx < w && ny < h {
                stack.push((nx, ny));
            }
        }
    }

    Component {
        pixels,
        min_x,
        min_y,
        max_x,
        max_y,
    }
}

fn unclip_aabb(x1: f32, y1: f32, x2: f32, y2: f32, unclip_ratio: f32) -> (f32, f32, f32, f32) {
    let w = (x2 - x1).max(1.0);
    let h = (y2 - y1).max(1.0);
    let area = w * h;
    let length = 2.0 * (w + h);
    let distance = if length > 0.0 {
        area * unclip_ratio / length
    } else {
        0.0
    };
    (x1 - distance, y1 - distance, x2 + distance, y2 + distance)
}
