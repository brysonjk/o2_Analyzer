// Exports the reference parts in their assembled positions for the 3D viewer.
include <../o2_analyzer.scad>
P = "x";
if (P == "bezel")    translate([0, 0, z_rim0]) bezel();
if (P == "display")  translate([0, 0, z_pcb]) dummy_display();
if (P == "ads")      translate([-ads_l/2, -ads_w/2 - 3, z_cav0]) cube([ads_l, ads_w, 1.6]);
if (P == "battery")  translate([-batt_l/2, -batt_w/2, z_batt0 + 0.3]) minkowski() { translate([0.5,0.5,0.5]) cube([batt_l-1, batt_w-1, batt_t-1]); sphere(0.5, $fn=8); }
if (P == "sensor")   translate([0, 0, z_cap_in_body + z_sh]) dummy_sensor();
