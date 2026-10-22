// =====================================================================
//  Cylinder flow diverter for the O2 analyzer (R-22D / PSR-11-39-MD)
//
//  Slides (or screws) onto the sensor's M16x1 nose, seals on the sensor O-ring, and
//  is held against the cylinder valve outlet:
//    * YOKE valve : flat front face presses on the valve's outlet O-ring
//    * DIN valve  : the cone seats in the mouth of the DIN socket
//  Gas -> Ø1.6 restrictor -> chamber over the sensor face -> 6 side vents.
//  Vent area is ~14x the inlet area, so the sensor sees ~ambient pressure.
//
//  Export:  openscad -o diverter.stl diverter.scad
//  Print nose-down (as exported), PETG or TPU 95A, 0.12–0.16 mm layers.
//  (mount = "thread" only: chase the thread with an M16x1 tap.)
// =====================================================================

/* ---- sensor nose (keep in sync with o2_analyzer.scad) ---- */
s_thread_d   = 16.0;
s_thread_p   = 1.0;
s_thread_h   = 8.3;
s_oring_d    = 19.9;
exposed_neck = 3.6;       // neck length outside the cap floor (s_neck_h - cap_floor)

/* ---- diverter ---- */
// How it attaches to the sensor nose:
//   "push"   - slides on; the sensor's O-ring grips and seals it. No thread
//              to print. Stops against the cap. (default)
//   "thread" - M16x1 internal thread. Printed 1 mm threads are marginal:
//              run an M16x1 tap through it for a clean fit.
mount        = "push";
neck_margin  = 1.0;       // extra room behind the O-ring bore for neck length tolerance
od           = 26.0;
th_clear     = 0.30;      // radial (thread mount); set 0 and tap for the best fit
th_depth     = 0.55;
oring_bore   = s_oring_d - 0.5;   // radial squeeze ≈ 0.25 mm on the O-ring
chamber_d    = 15.0;
chamber_h    = 2.6;       // gas space in front of the sensor face
inlet_d      = 1.6;       // restrictor orifice
vent_d       = 2.4;
vent_n       = 6;
face_d       = 18.0;      // flat face for yoke valves (covers the outlet O-ring)
cone_d       = 25.0;      // cone base — seats in DIN sockets (G5/8, Ø≈20.6–22.9)
cone_h       = 4.0;
nose_h       = 1.6;       // flat part ahead of the cone

$fn = 96;
eps = 0.01;

// derived (z = 0 at the nose face, increasing toward the analyzer)
z_ch0   = nose_h + cone_h;                    // chamber floor
z_th0   = z_ch0 + chamber_h;                  // thread start (sensor face)
z_th1   = z_th0 + s_thread_h + 0.6;           // thread end
z_top   = z_th1 + exposed_neck + neck_margin - 0.3;   // rear face (0.3 short of the cap floor)

echo(str("Diverter length: ", z_top, " mm   inlet area ", PI*inlet_d*inlet_d/4,
         " mm²   vent area ", vent_n*PI*vent_d*vent_d/4, " mm²"));

function th_prof(t, rmin, d) =
    let(f = t - floor(t))
    f < 0.12 ? rmin :
    f < 0.42 ? rmin + d * (f - 0.12) / 0.30 :
    f < 0.58 ? rmin + d :
    f < 0.88 ? rmin + d * (0.88 - f) / 0.30 :
    rmin;
module thread_solid(rmin, d, len, pitch, n = 120) {
    linear_extrude(height = len, twist = -360 * len / pitch,
                   slices = ceil(len / pitch * 16), convexity = 6)
        polygon([for (i = [0 : n - 1])
            let(a = 360 * i / n, r = th_prof(a / 360, rmin, d)) [r * cos(a), r * sin(a)]]);
}

// horizontal hole with a 45° roof so it prints without support
module teardrop_x(d, len) {
    rotate([0, 90, 0]) linear_extrude(len) hull() {
        circle(d = d, $fn = 24);
        translate([-d * 0.707, 0]) square(0.01, center = true);
    }
}

module diverter() {
    difference() {
        union() {
            // body
            translate([0, 0, z_ch0]) cylinder(d = od, h = z_top - z_ch0);
            // DIN cone + yoke face
            translate([0, 0, nose_h]) cylinder(d1 = face_d, d2 = cone_d, h = cone_h + eps);
            cylinder(d = face_d, h = nose_h + eps);
        }
        // restrictor (with a small countersink so it centres on the valve orifice)
        translate([0, 0, -eps]) cylinder(d = inlet_d, h = z_ch0 + 2 * eps, $fn = 24);
        translate([0, 0, -eps]) cylinder(d1 = 4.0, d2 = inlet_d, h = 1.2, $fn = 32);
        // chamber
        translate([0, 0, z_ch0]) cylinder(d = chamber_d, h = chamber_h + eps);
        if (mount == "thread") {
            // female M16x1 (helical groove = thread_solid with the male major dia + clearance)
            translate([0, 0, z_th0])
                thread_solid(s_thread_d/2 - th_depth + th_clear, th_depth, z_th1 - z_th0, s_thread_p);
            // 45° lead-in so the sensor tip finds the thread
            translate([0, 0, z_th1 - 1.2])
                cylinder(d1 = s_thread_d - 2*th_depth + 2*th_clear, d2 = s_thread_d + 1.8, h = 1.2 + eps);
        } else {
            // smooth clearance bore around the sensor thread
            translate([0, 0, z_th0 - eps]) cylinder(d = s_thread_d + 0.8, h = z_th1 - z_th0 + 2*eps);
            translate([0, 0, z_th1 - 1.2]) cylinder(d1 = s_thread_d + 0.8, d2 = s_thread_d + 1.8, h = 1.2 + eps);
        }
        // neck clearance (absorbs neck-length tolerance), then the O-ring sealing bore + lead-in
        translate([0, 0, z_th1 - eps]) cylinder(d = s_thread_d + 1.8, h = neck_margin + 2 * eps);
        translate([0, 0, z_th1 + neck_margin - eps]) cylinder(d = oring_bore, h = z_top - z_th1 - neck_margin + 2 * eps);
        translate([0, 0, z_top - 1.0]) cylinder(d1 = oring_bore, d2 = oring_bore + 2.0, h = 1.0 + eps);
        // radial side vents from the chamber (exit just behind the cone, outside the valve)
        for (i = [0 : vent_n - 1]) rotate([0, 0, i * 360 / vent_n + 30])
            translate([0, 0, z_ch0 + chamber_h / 2]) 
                teardrop_x(vent_d, od);
        // grip flutes
        for (i = [0 : 11]) rotate([0, 0, i * 30 + 15])
            translate([od / 2 + 0.5, 0, z_th0 + 2.0]) cylinder(d = 2.2, h = z_top, $fn = 16);
    }
}

diverter();
