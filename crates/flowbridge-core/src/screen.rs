//! DPI-independent coordinate conversion at an active screen edge.

use flowbridge_protocol::UnitInterval;
use std::error::Error;
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Edge {
    Left,
    Right,
    Top,
    Bottom,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ScreenGeometry {
    logical_width: f64,
    logical_height: f64,
}

impl ScreenGeometry {
    pub fn new(logical_width: f64, logical_height: f64) -> Result<Self, GeometryError> {
        if !logical_width.is_finite()
            || !logical_height.is_finite()
            || logical_width <= 0.0
            || logical_height <= 0.0
        {
            return Err(GeometryError::InvalidDimensions {
                logical_width,
                logical_height,
            });
        }
        Ok(Self {
            logical_width,
            logical_height,
        })
    }

    /// Maps a normalized edge position to a point just inside the target screen.
    #[must_use]
    pub fn entry_point(self, edge: Edge, position: UnitInterval) -> Point {
        let horizontal_max = (self.logical_width - 1.0).max(0.0);
        let vertical_max = (self.logical_height - 1.0).max(0.0);
        let ratio = f64::from(position.get());
        match edge {
            Edge::Left => Point {
                x: 0.0,
                y: ratio * vertical_max,
            },
            Edge::Right => Point {
                x: horizontal_max,
                y: ratio * vertical_max,
            },
            Edge::Top => Point {
                x: ratio * horizontal_max,
                y: 0.0,
            },
            Edge::Bottom => Point {
                x: ratio * horizontal_max,
                y: vertical_max,
            },
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum GeometryError {
    InvalidDimensions {
        logical_width: f64,
        logical_height: f64,
    },
}

impl fmt::Display for GeometryError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "invalid screen dimensions: {self:?}")
    }
}

impl Error for GeometryError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_five_k_source_position_inside_1080p_target() {
        let target = ScreenGeometry::new(1920.0, 1080.0).unwrap();
        let point = target.entry_point(Edge::Left, UnitInterval::new(0.75).unwrap());
        assert_eq!(point.x, 0.0);
        assert!((point.y - 809.25).abs() < f64::EPSILON);
        assert!(point.y < 1080.0);
    }

    #[test]
    fn endpoints_never_exceed_screen_bounds() {
        let target = ScreenGeometry::new(2560.0, 1440.0).unwrap();
        for position in [0.0, 1.0] {
            let normalized = UnitInterval::new(position).unwrap();
            for edge in [Edge::Left, Edge::Right, Edge::Top, Edge::Bottom] {
                let point = target.entry_point(edge, normalized);
                assert!((0.0..2560.0).contains(&point.x));
                assert!((0.0..1440.0).contains(&point.y));
            }
        }
    }

    #[test]
    fn rejects_invalid_dimensions() {
        assert!(ScreenGeometry::new(0.0, 1080.0).is_err());
        assert!(ScreenGeometry::new(1920.0, f64::NAN).is_err());
    }
}
