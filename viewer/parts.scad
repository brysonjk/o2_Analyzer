// Exports the parts in their assembled positions for the 3D viewer:
//   openscad -D 'P="tube"' -o m/tube.stl parts.scad   (bezel display ads body tube battery sensor cap diverter)
include <../o2_analyzer.scad>
P = "x";
PART = "none";
if (P == "bezel")    translate([0, 0, z_rim0]) bezel();
if (P == "display")  translate([0, 0, z_pcb]) dummy_display();
if (P == "ads")      translate(ads_pos) cube([ads_w, ads_l, 1.6]);
if (P == "body")     body();
if (P == "tube")     tube();
if (P == "battery")  translate([-batt_w/2, y_bk0 + batt_clear, z_pk0 + 0.05]) minkowski() { translate([0.5,0.5,0.5]) cube([batt_w-1, batt_l-1, batt_t-1]); sphere(0.5, $fn=8); }
if (P == "sensor")   at_cap() translate([0, 0, z_sh]) dummy_sensor();
if (P == "cap")      at_cap() cap();
if (P == "diverter") at_cap() translate([0, 0, -div_len]) diverter();
