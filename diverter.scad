// =====================================================================
//  Cylinder flow diverter for the O2 analyzer (R-22D / PSR-11-39-MD)
//
//  Screws onto the sensor's M16x1 nose like a nut: its rear face tightens
//  against the cap's floor, clamping the sensor in the cap. (The sensor's
//  O-ring seals in the cap floor.) It is held against the cylinder valve:
//    * YOKE valve : flat front face presses on the valve's outlet O-ring
//    * DIN valve  : the cone seats in the mouth of the DIN socket
//  Gas -> Ø1.6 restrictor -> chamber over the sensor face -> 6 side vents.
//  Vent area is ~14x the inlet area, so the sensor sees ~ambient pressure.
//
//  Export:  openscad -o diverter.stl diverter.scad
//  Print nose-down (as exported), PETG or TPU 95A, 0.12–0.16 mm layers.
//  Thread it on until it's snug against the cap. Hand-tight is enough.
// =====================================================================

/* ---- sensor nose (keep in sync with o2_analyzer.scad) ---- */
s_thread_d   = 16.0;
s_thread_p   = 1.0;
s_nose_h     = 6.59;      // threaded section: shoulder -> tip (measured)
s_oring_d    = 18.0;      // O-ring OD as installed, at the base of the thread (measured)
s_oring_cs   = 1.7;       // O-ring thickness (measured)
cap_floor_t  = 1.8;       // cap floor under the sensor shoulder (o2_analyzer.scad)

/* ---- diverter ---- */
od           = 26.0;
th_clear     = 0.20;      // radial
th_depth     = 0.60;
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
z_top   = z_th0 + 0.6 + s_nose_h - cap_floor_t;  // rear face clamps the cap floor

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
        // female M16x1, full length to the rear face (all the exposed thread engages)
        translate([0, 0, z_th0])
            thread_solid(s_thread_d/2 - th_depth + th_clear, th_depth, z_top - z_th0 + eps, s_thread_p);
        translate([0, 0, z_top - 0.4]) cylinder(d1 = s_thread_d - 2*th_depth + 2*th_clear, d2 = s_thread_d + 0.8, h = 0.4 + eps);   // thread start
        // radial side vents from the chamber (exit just behind the cone, outside the valve)
        for (i = [0 : vent_n - 1]) rotate([0, 0, i * 360 / vent_n + 30])
            translate([0, 0, z_ch0 + chamber_h / 2]) 
                teardrop_x(vent_d, od);
        // grip flutes
        for (i = [0 : 11]) rotate([0, 0, i * 30 + 15])
            translate([od / 2 + 0.5, 0, z_th0 + 1.0]) cylinder(d = 2.2, h = z_top, $fn = 16);
    }
}

diverter();
