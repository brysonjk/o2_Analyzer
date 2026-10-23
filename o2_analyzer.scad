// =====================================================================
//  Compact O2 Analyzer  —  ESP32-2424S012 + ADS1115 + R-22D sensor
//  Parametric OpenSCAD enclosure, no screws.  Units: mm.
//
//    BEZEL    : screws onto the threaded body rim, holds the display glass
//    BODY     : display seat, flexure power button, ADS1115 bay, battery
//               pocket with spring latches, 4-start threaded spigot
//    CAP      : sensor seat; "open" (nose out, separate diverter) or with
//               the flow diverter built in
//    RETAINER : collar on the sensor flange, clamped by the body when the
//               cap is screwed on, so the sensor can't push up
//
//  Unscrew the CAP (< 1 turn)  ->  pull the battery down out of its
//  pocket; lift the retainer collar off and pull the sensor out.
//
//  Render one part:  set PART below, or from the CLI:
//     openscad -D 'PART="body"' -o body.stl o2_analyzer.scad
// =====================================================================

PART = "assembly";   // assembly | exploded | section | body | cap | bezel | retainer | fit_test

// Cap style:
//   "open"     - the sensor's M16x1 nose and O-ring stick out of the cap.
//                Use the screw-on diverter.scad, or any standard M16 T-piece /
//                inflator adapter.
//   "diverter" - restrictor, chamber, vents, yoke face and DIN cone built
//                into the cap (shortest, one less part).
// CLI:  openscad -D 'cap_style="diverter"' -D 'PART="cap"' -o cap_diverter.stl o2_analyzer.scad
cap_style = "open";
show_diverter = true;     // assembly views: show the screw-on diverter on the open cap

use <diverter.scad>
div_len = 15.39;          // diverter.scad length (its z_top); its rear face seats on the sensor shoulder

/* ---------- MEASURE THESE WITH CALIPERS BEFORE PRINTING ---------- */
// ESP32-2424S012 (bare board, out of its stock case)
pcb_d          = 37.0;   // round part of the PCB (spec drawing)
pcb_tab_w      = 14.23;  // tab at the USB-C end (spec drawing)
pcb_tab_r      = 20.0;   // centre -> end of the tab (38.5 overall - 18.5)
glass_d        = 36.6;   // round display glass / backlight frame dia
glass_stack    = 3.6;    // glass top -> PCB top surface (display side)
pcb_t          = 1.0;
comp_h         = 3.8;    // tallest part under the PCB (USB-C, module)
view_d         = 33.0;   // visible window (active area ≈ Ø32.4)

// USB-C and on/off button positions (angle measured CCW looking from top,
// 0° = +X).  Rotate these to match YOUR board.
usb_angle      = 270;
usb_w          = 9.6;
usb_h          = 3.8;
btn_angle      = 0;      // IP5306 on/off button (side-actuated)
btn_z_off      = 1.6;    // button centre below PCB bottom face
btn_reach      = 19.4;   // radius the flexure nub reaches in to (switch sits at the 37 mm board edge)

// R-22D type sensor (PSR-11-39-MD) — measured with calipers on a real sensor
s_total_h      = 40.5;   // thread tip -> rear face
s_nose_h       = 6.59;   // threaded section: shoulder -> tip (O-ring sits at its base)
s_body_d       = 26.0;   // body between the shoulder and the flange
s_body_h       = 15.75;  // shoulder -> underside of the flange
s_flange_d     = 28.5;   // widest flange (measured 3x; the AII drawing says 29.3)
s_flange_h     = 8.5;
s_taper_h      = 3.1;    // * (not measured) chamfer from the flange to the rear boss
s_boss_d       = 14.7;   // * (not measured) rear boss, Molex recessed inside it
s_oring_d      = 18.0;   // O-ring outside diameter as installed on the sensor (17.7 loose)
s_oring_cs     = 1.7;    // O-ring thickness
s_thread_d     = 16.0;   // M16 x 1
plug_clear     = 11.0;   // space behind the boss face for the mating Molex plug + wire bend
body_clear     = 0.5;    // radial room around the body (paper label, print tolerance)
flange_clear   = 0.4;    // radial room around the flange (printed holes shrink ~0.1-0.2)

s_boss_h       = s_total_h - s_nose_h - s_body_h - s_flange_h - s_taper_h;   // rest of the length
sensor_h       = s_body_h + s_flange_h + s_taper_h + s_boss_h;   // shoulder -> rear face (33.9)
nose_len       = s_nose_h;                                       // shoulder -> sensor face
oring_zone     = s_oring_cs + 0.3;                               // O-ring band below the shoulder
s_bore_body    = s_body_d + 2*body_clear;
s_bore_flange  = s_flange_d + 2*flange_clear;

// LiPo (default 602030: 6 x 20 x 30 mm, ~300 mAh)
batt_t         = 6.0;
batt_w         = 20.0;
batt_l         = 30.0;

// ADS1115 breakout (Adafruit / clone ≈ 28 x 17.8), no headers, wires flat
ads_l          = 28.6;
ads_w          = 18.4;
ads_zone       = 3.8;    // free height for ADS board + soldered wires

/* ---------- Enclosure ---------- */
od             = 46.0;
fit            = 0.30;   // general radial clearance
bezel_plate    = 1.2;
rim_h          = 3.8;    // threaded body rim the bezel screws onto
rim_wall       = 1.2;    // bezel skirt wall (behind the thread grooves)
// screw-on bezel: 3-start thread on the rim, ~3/4 turn on, seats on the rim top
bz_pitch       = 1.5;    // axial spacing between ridges (lead = 4.5 mm per turn)
bz_starts      = 3;
bz_depth       = 0.7;
bz_clear       = 0.30;   // radial clearance

// body <-> cap thread: 4-start, so the cap closes in < 1 turn and the
// sensor wires barely twist
th_pitch       = 2.0;    // axial spacing between thread ridges
th_starts      = 4;      // lead = pitch * starts = 8 mm per turn
th_depth       = 0.9;
th_len         = 7.0;
th_major       = 42.4;   // male (body spigot) major diameter
th_clear       = 0.40;   // radial clearance male/female
th_relief      = 1.5;    // undercut below the cap thread so the shoulder seats before the spigot bottoms
spigot_id      = 37.0;   // must pass the battery diagonal (36.1 for 602030)

// built-in diverter (bottom of the cap)
inlet_d        = 1.6;    // restrictor orifice
vent_d         = 2.2;
vent_n         = 6;
face_d         = 18.0;   // flat face for yoke valves (covers the outlet O-ring)
cone_d         = 25.0;   // seats in DIN sockets (G5/8, Ø≈20.6–22.9)
cone_h         = 4.0;
nose_face_h    = 1.6;
chamber_d      = 15.0;
chamber_h      = 2.0;    // gas space in front of the sensor face
nose_od        = 26.0;
oring_squeeze  = 0.2;    // radial squeeze on the O-ring (~12% of its 1.7 mm section)
oring_bore     = s_oring_d - 2*oring_squeeze;

// sensor retainer collar: sits on the flange edge; its spring petals are
// pressed by the end of the body's spigot when the cap is screwed on
ret_preload    = 0.5;    // petal deflection with the cap fully tightened
ret_petal_t    = 0.8;
ret_id         = 25.8;   // passes the Molex plug and the rear boss

$fn = 96;
eps = 0.01;

/* ---------- Derived heights: BODY (z = 0 at spigot end) ---------- */
z_batt0   = th_len;                        // battery pocket bottom opening
batt_zone = batt_t + 0.6;
z_floor   = z_batt0 + batt_zone;           // floor between battery & ADS
floor_t   = 1.0;
z_cav0    = z_floor + floor_t;             // ADS cavity floor
z_pcb     = z_cav0 + ads_zone + comp_h;    // PCB bottom face rests here
z_glass   = z_pcb + pcb_t + glass_stack;   // glass top
body_h    = z_glass;
z_rim0    = body_h - rim_h;

disp_bore = pcb_d + 2*fit;
cav_bore  = od - 2*2.4;                    // ADS / component cavity
rim_od    = od - 2*rim_wall - 2*fit;

/* ---------- Derived heights: CAP (z = 0 at the nose face) ---------- */
z_ch0     = nose_face_h + cone_h;          // chamber floor
z_sface   = z_ch0 + chamber_h;             // sensor face (nominal)
// open style: the sensor sits on its flange, with the shoulder flush with the
// cap's bottom face, so the whole threaded nose and the O-ring are exposed
z_sh      = cap_style == "diverter" ? z_sface + nose_len : 0;   // sensor shoulder plane
z_flange0 = z_sh + s_body_h;
z_flange1 = z_flange0 + s_flange_h;        // flange top edge (the retainer sits here)
cav_above = max(1.0, plug_clear - th_len); // the spigot bore is free space too
cap_h     = z_sh + sensor_h + cav_above + th_len;
z_cap_in_body = th_len - cap_h;            // cap origin in body coordinates

echo(str("Body height: ", body_h, "   Cap height: ", cap_h));
echo(str("Cap style: ", cap_style, "   overall length: ", body_h + bezel_plate + cap_h - th_len,
         cap_style == "diverter" ? " (diverter built in)" : str(" + ", nose_len, " sensor nose")));
echo(str("Inlet area ", PI*inlet_d*inlet_d/4, " mm²   vent area ", vent_n*PI*vent_d*vent_d/4, " mm²"));

/* =====================================================================
   Helical thread: horizontal cross-section r(θ) extruded with twist.
   Multi-start: the profile repeats `starts` times around, and the
   extrusion twists once per lead (pitch × starts).
   ===================================================================== */
function th_prof(t, rmin, d) =             // t in [0,1): trapezoid profile
    let(f = t - floor(t))
    f < 0.12 ? rmin :
    f < 0.42 ? rmin + d * (f - 0.12) / 0.30 :
    f < 0.58 ? rmin + d :
    f < 0.88 ? rmin + d * (0.88 - f) / 0.30 :
    rmin;

module thread_section(rmin, d, starts, n = 192) {
    polygon([for (i = [0 : n - 1])
        let(a = 360 * i / n, r = th_prof(starts * a / 360, rmin, d))
        [r * cos(a), r * sin(a)]]);
}

module thread_solid(rmin, d, len, pitch, starts = 1) {
    lead = pitch * starts;
    linear_extrude(height = len, twist = -360 * len / lead,
                   slices = ceil(len / lead * 72), convexity = 8)
        thread_section(rmin, d, starts);
}

/* ============================== BODY ================================= */
module body() {
    difference() {
        union() {
            // main tube (above spigot), stepped rim at the top for the bezel
            translate([0, 0, th_len]) cylinder(d = od, h = z_rim0 - th_len);
            // threaded rim for the bezel (lead-in chamfer at the top)
            translate([0, 0, z_rim0 - eps]) intersection() {
                thread_solid(rim_od/2 - bz_depth, bz_depth, rim_h + eps, bz_pitch, bz_starts);
                union() {
                    cylinder(d = rim_od + 1, h = rim_h - 0.8);
                    translate([0, 0, rim_h - 0.8 - eps]) cylinder(d1 = rim_od + 1, d2 = rim_od - 2*bz_depth - 0.6, h = 0.8 + 2*eps);
                }
            }
            // threaded spigot (male, 4-start) with a lead-in chamfer
            intersection() {
                thread_solid(th_major/2 - th_depth, th_depth, th_len + eps, th_pitch, th_starts);
                union() {
                    translate([0, 0, -0.05]) cylinder(d1 = th_major - 2*th_depth - 0.6, d2 = th_major + 0.6, h = 1.25);
                    translate([0, 0, 1.2 - eps]) cylinder(d = th_major + 1, h = th_len);
                }
            }
        }

        // spigot bore (sensor Molex + wiring space, battery passes through)
        translate([0, 0, -eps]) cylinder(d = spigot_id, h = th_len + 2*eps);

        // battery pocket (opens downward) + side channel for its plug/leads
        translate([0, 0, z_batt0 - eps]) {
            translate([-batt_l/2 - 0.4, -batt_w/2 - 0.4, 0])
                cube([batt_l + 0.8, batt_w + 0.8, batt_zone + eps]);
            translate([-9, batt_w/2, 0]) cube([18, 6.0, batt_zone + eps]);
            translate([0, -batt_w/2 - 0.4, 0]) scale([1, 0.45, 1])
                cylinder(r = 7, h = batt_zone * 0.6);
        }

        // wire pass-throughs in the floor: battery leads + sensor leads
        translate([ 6, batt_w/2 + 3, z_floor - 1]) cylinder(d = 4.2, h = floor_t + 2, $fn = 32);
        translate([-6, batt_w/2 + 3, z_floor - 1]) cylinder(d = 4.2, h = floor_t + 2, $fn = 32);

        // ADS1115 + under-PCB component cavity
        translate([0, 0, z_cav0]) cylinder(d = cav_bore, h = z_pcb - z_cav0 + eps);
        translate([-ads_l/2, -ads_w/2 - 3, z_cav0 - 0.6]) cube([ads_l, ads_w, 1]);

        // display seat: the round board plus a pocket for its USB-C tab, with a
        // channel through the rim so the tab and connector can be lowered in
        translate([0, 0, z_pcb]) cylinder(d = disp_bore, h = body_h);
        translate([0, 0, z_pcb - eps]) linear_extrude(body_h - z_pcb + 1) pcb_tab_2d(fit);
        translate([0, 0, z_rim0 - eps]) linear_extrude(rim_h + 1) rotate([0, 0, usb_angle - 270])
            translate([-pcb_tab_w/2 - fit, -od/2 - 1]) square([pcb_tab_w + 2*fit, od/2 + 1]);

        // USB-C slot (opening flares outward for the plug overmould)
        rotate([0, 0, usb_angle]) translate([od/2 - 3.5, 0, z_pcb - usb_h/2 - 0.2]) {
            rotate([0, 90, 0]) linear_extrude(4) offset(r = 1.2) offset(delta = -1.2)
                square([usb_h + 0.6, usb_w + 0.6], center = true);
            translate([2.2, 0, 0]) rotate([0, 90, 0]) linear_extrude(3) offset(r = 2)
                square([usb_h + 3, usb_w + 3.4], center = true);
        }

        // flexure power button: U-slot through the wall + thinned tab
        rotate([0, 0, btn_angle]) button_cut();

        // thread relief at the shoulder: the cap's top turn can run fully home
        translate([0, 0, th_len - 0.8]) difference() {
            cylinder(d = th_major + 2, h = 0.8 + eps);
            translate([0, 0, -eps]) cylinder(d = th_major - 2*th_depth, h = 1);
        }

        // top chamfer on rim inner edge (eases display insertion)
        translate([0, 0, body_h - 0.8]) cylinder(d1 = disp_bore, d2 = disp_bore + 1.6, h = 0.8 + eps);
    }

    // flexure button nub
    rotate([0, 0, btn_angle]) button_nub();

    // PCB support pads in the cavity (3 pads, skip USB + button sectors)
    for (a = [usb_angle + 120, usb_angle + 240, usb_angle + 60])
        if (abs(((a - btn_angle + 540) % 360) - 180) > 20)
        rotate([0, 0, a]) translate([pcb_d/2 - 1.2, -2, z_cav0])
            cube([cav_bore/2 - pcb_d/2 + 1.4, 4, z_pcb - z_cav0]);     // 1.2 mm under the board edge

    // battery latches: two spring beams inside the spigot
    for (m = [0, 1]) mirror([m, 0, 0]) battery_latch();
}

// annular sector between radii r0..r1, angles a0..a1 (deg), heights z0..z1
module sector(r0, r1, a0, a1, z0, z1) {
    translate([0, 0, z0]) rotate([0, 0, a0])
        rotate_extrude(angle = a1 - a0, $fn = 192) translate([r0, 0]) square([r1 - r0, z1 - z0]);
}

// the PCB's tab, as a 2D outline grown by `off`
module pcb_tab_2d(off = 0) {
    rotate([0, 0, usb_angle - 270]) offset(delta = off)
        translate([-pcb_tab_w/2, -pcb_tab_r]) square([pcb_tab_w, pcb_tab_r]);
}

/* ---- flexure button ---- */
btn_tab_w   = 6.0;
btn_tab_z0  = z_pcb - btn_z_off - 5.5;   // hinge (bottom)
btn_tab_z1  = z_pcb - 0.2;               // free end, kept below the bezel rim
btn_slot    = 0.6;
btn_thin    = 0.8;                       // outer recess -> tab is 1.6 thick

module button_cut() {
    r_in = cav_bore/2;
    // U-shaped slot: two sides + top, hinge left at the bottom
    for (s = [-1, 1])
        translate([r_in - 1, s * (btn_tab_w/2 + btn_slot/2) - btn_slot/2, btn_tab_z0])
            cube([od/2 - r_in + 2, btn_slot, btn_tab_z1 - btn_tab_z0 + btn_slot]);
    translate([r_in - 1, -btn_tab_w/2 - btn_slot, btn_tab_z1])
        cube([od/2 - r_in + 2, btn_tab_w + 2*btn_slot, btn_slot]);
    // outer recess thins the tab and gives the thumb a locator
    translate([od/2 - btn_thin, -btn_tab_w/2 - btn_slot, btn_tab_z0 - 1.5])
        cube([2, btn_tab_w + 2*btn_slot, btn_tab_z1 - btn_tab_z0 + btn_slot + 1.5]);
}

module button_nub() {
    r_in = cav_bore/2;
    zc = z_pcb - btn_z_off;
    // tapered pin from the tab's inner face to btn_reach, 45° underside
    hull() {
        translate([r_in + 0.1, 0, zc]) rotate([0, -90, 0]) cylinder(d = 3.0, h = eps, $fn = 24);
        translate([btn_reach, 0, zc]) rotate([0, -90, 0]) cylinder(d = 2.0, h = eps, $fn = 24);
        translate([r_in + 0.1, 0, zc - 1.6]) rotate([0, -90, 0]) cylinder(d = 0.6, h = eps, $fn = 12);
    }
}

/* ---- battery latches ---- */
latch_x    = batt_l/2 + 0.5;   // beam inner face (just behind the pocket wall)
latch_t    = 1.0;              // beam thickness (flex direction)
latch_w    = 6.0;
latch_hook = 1.0;              // how far the hook reaches under the battery edge (0.5 overlap)
latch_z0   = 0.8;

module battery_latch() {
    r_wall = spigot_id/2;
    translate([latch_x, -latch_w/2, latch_z0])
        cube([sqrt(r_wall*r_wall - (latch_w/2)*(latch_w/2)) - latch_x + 0.6, latch_w, 1.5]);
    translate([latch_x, -latch_w/2, latch_z0]) cube([latch_t, latch_w, z_batt0 + 0.6 - latch_z0]);
    translate([0, latch_w/2, 0]) rotate([90, 0, 0]) linear_extrude(latch_w)
        polygon([[latch_x, z_batt0 - 1.8], [latch_x - latch_hook, z_batt0 - 0.8],
                 [latch_x - latch_hook, z_batt0 + 0.0], [latch_x, z_batt0 + 0.6]]);
}

/* ============================== BEZEL ================================ */
// Screws onto the threaded rim (3-start, about 3/4 turn) and seats on the
// rim's top face. The skirt is 0.4 mm short of the body shoulder, so it's the
// rim top that it tightens against.
module bezel() {
    skirt_h = rim_h - 0.4;
    difference() {
        cylinder(d = od, h = skirt_h + bezel_plate);
        // female thread (the helix solid is filled to the centre, so it also clears the inside)
        translate([0, 0, -eps]) thread_solid(rim_od/2 - bz_depth + bz_clear, bz_depth, skirt_h + eps, bz_pitch, bz_starts);
        translate([0, 0, -eps]) cylinder(d1 = rim_od + 2*bz_clear + 0.8, d2 = rim_od - 2*bz_depth, h = 0.8);   // lead-in
        // display window with outward chamfer
        translate([0, 0, skirt_h - eps]) cylinder(d = view_d, h = bezel_plate + 2*eps);
        translate([0, 0, skirt_h + bezel_plate - 0.8]) cylinder(d1 = view_d, d2 = view_d + 1.6, h = 0.8 + eps);
        // glass recess (glass sits 0.4 into the plate, so it can't shift)
        translate([0, 0, skirt_h - eps]) cylinder(d = glass_d + 0.5, h = 0.4 + eps);
        // grip flutes
        for (i = [0 : 23]) rotate([0, 0, i * 15])
            translate([od/2 + 0.5, 0, -eps]) cylinder(d = 1.6, h = skirt_h + bezel_plate - 0.8, $fn = 12);
        // top outer edge chamfer
        translate([0, 0, skirt_h + bezel_plate - 0.6])
            difference() { cylinder(d = od + 1, h = 1); cylinder(d1 = od, d2 = od - 1.2, h = 0.6 + eps); }
    }
}

/* =============================== CAP ================================= */
module cap() {
    tot = cap_h;
    r_fb = s_bore_flange/2;                 // flange bore radius
    difference() {
        if (cap_style == "diverter") cap_shell_diverter(tot); else cap_shell_open(tot);
        // ---- sensor seat (both styles) ----
        // upper body bore (locates the sensor), then flange bore
        // body bore; the flat step up to the flange bore is the seat for the flange
        translate([0, 0, z_sh - eps]) cylinder(d = s_bore_body, h = s_body_h + 2*eps);
        translate([0, 0, z_flange0]) cylinder(d = 2*r_fb, h = sensor_h - s_body_h + eps);
        // Molex plug headroom
        translate([0, 0, z_sh + sensor_h - eps]) cylinder(d = th_major - 2*th_depth + 2*th_clear - 0.2, h = cav_above + 2*eps);

        // room for the retainer collar above the flange
        translate([0, 0, z_flange1 - eps]) cylinder(d = 2*ret_r1 + 0.8, h = sensor_h - s_body_h - s_flange_h + 2*eps);

        // ---- body thread (female, 4-start) ----
        translate([0, 0, tot - th_len])
            thread_solid(th_major/2 - th_depth + th_clear, th_depth, th_len + eps, th_pitch, th_starts);
        translate([0, 0, tot - 1.0]) cylinder(d1 = th_major - 2*th_depth + 2*th_clear - 0.6, d2 = th_major + 2*th_clear + 0.8, h = 1 + eps);
        // relief below the thread: room for the spigot so the cap seats on the shoulder
        translate([0, 0, tot - th_len - th_relief]) cylinder(d = th_major + 2*th_clear + 0.4, h = th_relief + eps);

        // grip flutes
        z_fl = cap_style == "diverter" ? z_sh + 6 : 2;
        for (i = [0 : 17]) rotate([0, 0, i * 20])
            translate([od/2 + 0.6, 0, z_fl]) cylinder(d = 2.4, h = tot - th_len - z_fl - 1, $fn = 16);
    }
}

// open style: plain cylinder, open at the bottom; the flange sits on the
// step between the body bore and the flange bore
module cap_shell_open(tot) {
    difference() {
        cylinder(d = od, h = tot);
        translate([0, 0, -eps]) difference() {
            cylinder(d = od + 1, h = 0.8);
            cylinder(d1 = od - 1.6, d2 = od, h = 0.8 + eps);
        }
    }
}

// diverter style: nose barrel with the gas path, O-ring sealing bore
module cap_shell_diverter(tot) {
    difference() {
        union() {
            cylinder(d = nose_od, h = z_sh - 4 + eps);                         // nose barrel
            translate([0, 0, z_sh - 4]) cylinder(d1 = nose_od, d2 = od, h = (od - nose_od)/2);  // 45° shoulder
            translate([0, 0, z_sh - 4 + (od - nose_od)/2 - eps]) cylinder(d = od, h = tot - (z_sh - 4 + (od - nose_od)/2) + eps);
            // DIN cone + yoke face
            translate([0, 0, nose_face_h]) cylinder(d1 = face_d, d2 = cone_d, h = cone_h + eps);
            cylinder(d = face_d, h = nose_face_h + eps);
        }
        // trim the barrel under the cone back to the cone
        translate([0, 0, -eps]) difference() {
            cylinder(d = nose_od + 2, h = z_ch0);
            translate([0, 0, nose_face_h]) cylinder(d1 = face_d, d2 = cone_d, h = cone_h + 2*eps);
            cylinder(d = face_d, h = nose_face_h + 2*eps);
        }

        // ---- gas path ----
        translate([0, 0, -eps]) cylinder(d = inlet_d, h = z_ch0 + 2*eps, $fn = 24);
        translate([0, 0, -eps]) cylinder(d1 = 4.0, d2 = inlet_d, h = 1.2, $fn = 32);   // centring countersink
        translate([0, 0, z_ch0]) cylinder(d = chamber_d, h = chamber_h + eps);
        for (i = [0 : vent_n - 1]) rotate([0, 0, i * 360 / vent_n + 30])
            translate([chamber_d/2 - 1.5, 0, z_ch0 + chamber_h/2]) teardrop_x(vent_d, nose_od);

        // clearance for the M16 nose (sensor face sits 1.2 above the chamber ledge)
        translate([0, 0, z_ch0 + 0.8]) cylinder(d = s_thread_d + 0.8, h = z_sh - z_ch0 - 0.8 + eps);
        // O-ring sealing bore (seals the chamber off from the electronics)
        translate([0, 0, z_sh - oring_zone]) cylinder(d = oring_bore, h = oring_zone + eps);
        translate([0, 0, z_sh - 0.3]) cylinder(d1 = oring_bore, d2 = oring_bore + 0.6, h = 0.3 + eps);
    }
}

// horizontal hole with a 45° roof (prints without support when z is up)
module teardrop_x(d, len) {
    rotate([0, 90, 0]) linear_extrude(len) hull() {
        circle(d = d, $fn = 24);
        translate([-d * 0.707, 0]) square(0.01, center = true);
    }
}

/* ========================= SENSOR RETAINER ============================ */
// A collar that sits on the outer edge of the sensor flange. Its 8 spring
// petals are pressed down by the end of the body's spigot when the cap is
// screwed on, clamping the flange onto its seat in the cap. Exported
// petals-down; print as-is in PETG (or TPU), no supports.
ret_r0   = ret_id/2;
ret_r1   = s_bore_flange/2 + 0.2;            // tube OD
ret_lip0 = s_flange_d/2 - 0.65;              // contact lip: touches the flange's edge
ret_lip1 = s_flange_d/2 + 0.15;
ret_z0   = z_flange1 + s_taper_h * (s_flange_d/2 - ret_lip0) / (s_flange_d/2 - s_boss_d/2) + 0.05;   // lip rests on the flange's taper (cap coords)
ret_z1   = cap_h - th_len + ret_preload;     // petal top = spigot end + preload
ret_petal_od = th_major - 2*th_depth + 2*th_clear - 0.8;

module retainer() {
    difference() {
        union() {
            translate([0, 0, ret_z0]) cylinder(r = ret_lip1, h = 1.0 + eps);                       // lip
            translate([0, 0, ret_z0 + 1.0]) cylinder(r = ret_r1, h = ret_z1 - ret_z0 - 1.0);      // tube
            translate([0, 0, ret_z1 - ret_petal_t]) cylinder(d = ret_petal_od, h = ret_petal_t);   // petal disc
        }
        translate([0, 0, ret_z0 - 1]) cylinder(r = ret_lip0, h = 2.0 + eps);
        translate([0, 0, ret_z0 + 1.0 - eps]) cylinder(r = ret_r0, h = ret_z1 - ret_z0);
        // 8 slots split the disc into spring petals
        for (i = [0 : 7]) rotate([0, 0, i * 45 + 22.5])
            translate([ret_r1 - 0.3, -0.7, ret_z1 - ret_petal_t - 1]) cube([12, 1.4, ret_petal_t + 2]);
        // wire notch so the sensor leads can lie flat
        translate([-2.5, ret_r0 - 1, ret_z1 - 3]) cube([5, 4, 4]);
    }
}

/* ===================== FIT TEST (print first) ======================== */
// Display seat ring, sensor seat (O-ring bore + upper-body bore),
// flange ring, and 4 mm of the mating thread.  ~20 min of printing.
module fit_test() {
    difference() {          // display seat: drop the board in, tab into its pocket
        cylinder(d = 2*pcb_tab_r + 4, h = 2);
        translate([0, 0, -eps]) cylinder(d = disp_bore, h = 3);
        translate([0, 0, -eps]) linear_extrude(3) pcb_tab_2d(fit);
    }
    // sensor seat: body bore with the flange step on top (open cap seats here)
    translate([52, 0, 0]) difference() {
        cylinder(d = s_bore_flange + 4, h = 6);
        translate([0, 0, -eps]) cylinder(d = s_bore_body, h = 3 + 2*eps);
        translate([0, 0, 3]) cylinder(d = s_bore_flange, h = 4);
    }
    // O-ring sealing bore (built-in-diverter cap)
    translate([90, 0, 0]) difference() {
        cylinder(d = oring_bore + 5, h = oring_zone + 1);
        translate([0, 0, -eps]) cylinder(d = s_thread_d + 0.8, h = 2);
        translate([0, 0, 1]) cylinder(d = oring_bore, h = oring_zone + eps);
        translate([0, 0, oring_zone + 0.7]) cylinder(d1 = oring_bore, d2 = oring_bore + 0.6, h = 0.3 + eps);
    }
    translate([0, 54, 0]) intersection() { body(); cylinder(d = od + 1, h = 4); }
    translate([54, 54, 0]) difference() {
        cylinder(d = od, h = 4);
        translate([0, 0, -eps]) thread_solid(th_major/2 - th_depth + th_clear, th_depth, 4 + 2*eps, th_pitch, th_starts);
    }
}

/* ======================== Reference dummies ========================== */
module dummy_sensor() {   // z = 0 at the shoulder
    color("#333") {
        cylinder(d = s_body_d, h = s_body_h);
        translate([0, 0, s_body_h]) cylinder(d = s_flange_d, h = s_flange_h);
        translate([0, 0, s_body_h + s_flange_h]) cylinder(d1 = s_flange_d, d2 = s_boss_d, h = s_taper_h);
        translate([0, 0, sensor_h - s_boss_h - eps]) cylinder(d = s_boss_d, h = s_boss_h);
        translate([0, 0, -s_nose_h]) cylinder(d = s_thread_d, h = s_nose_h + eps);
    }
    color("black") translate([0, 0, -s_oring_cs/2 - 0.05]) rotate_extrude() translate([(s_oring_d - s_oring_cs)/2, 0]) circle(d = s_oring_cs, $fn = 16);
    color("white") translate([-4, -2.5, sensor_h]) cube([8, 5, 6]);       // mating plug
    color("red") for (x = [-2.5, 0, 2.5]) translate([x, 0, sensor_h + 6]) cylinder(d = 1.2, h = 3, $fn = 8);
}
module dummy_display() {
    color("darkgreen") linear_extrude(pcb_t) union() { circle(d = pcb_d); pcb_tab_2d(); }
    color("black") translate([0, 0, pcb_t]) cylinder(d = glass_d, h = glass_stack);
    color("royalblue") translate([0, 0, pcb_t + glass_stack - 0.05]) cylinder(d = 32.4, h = 0.1);
    color("gray") rotate([0, 0, usb_angle]) translate([pcb_tab_r - 7.3, -4.5, -3.2]) cube([7.3, 9, 3.2]);
}

/* ============================ Output ================================= */
module assembly(explode = 0) {
    color("#3a6ea5") body();
    translate([0, 0, z_rim0 + explode * 1.2]) color("#2c2c2c") bezel();
    translate([0, 0, z_pcb + explode * 0.8]) dummy_display();
    color("purple") translate([-ads_l/2, -ads_w/2 - 3, z_cav0]) cube([ads_l, ads_w, 1.6]);
    color("orange") translate([-batt_l/2, -batt_w/2, z_batt0 + 0.3 - explode * 0.5]) cube([batt_l, batt_w, batt_t]);
    translate([0, 0, z_cap_in_body - explode * 2]) {
        color("#e0e0e0") cap();
        translate([0, 0, z_sh + explode * 1.2]) dummy_sensor();
        color("#d08030") translate([0, 0, explode * 1.6]) retainer();
        if (cap_style == "open" && show_diverter)
            color("#1f9e8f") translate([0, 0, -div_len - explode * 1.4]) diverter();
    }
}

if (PART == "assembly")        assembly(0);
else if (PART == "exploded")   assembly(18);
else if (PART == "section")    difference() { assembly(0); translate([-60, 0, -80]) cube([120, 60, 160]); }
else if (PART == "body")       body();
else if (PART == "bezel")      translate([0, 0, rim_h + bezel_plate]) rotate([180, 0, 0]) bezel();
else if (PART == "cap")        cap();
else if (PART == "retainer")   translate([0, 0, ret_z1]) rotate([180, 0, 0]) retainer();
else if (PART == "fit_test")   fit_test();
