include </home/claude/o2/o2_analyzer.scad>
P = "x";
if (P == "bezel")    translate([0, 0, body_h - rim_h]) bezel();
if (P == "display")  translate([0, 0, z_pcb]) dummy_display();
if (P == "ads")      translate([-ads_l/2, -ads_w/2 - 3, z_cav0]) cube([ads_l, ads_w, 1.6]);
if (P == "battery")  translate([-batt_l/2, -batt_w/2, z_batt0 + 0.3]) minkowski() { translate([0.5,0.5,0.5]) cube([batt_l-1, batt_w-1, batt_t-1]); sphere(0.5, $fn=8); }
if (P == "retainer") translate([0, 0, th_len - cap_h]) retainer();
if (P == "sensor")   translate([0, 0, th_len - cap_h + cap_floor]) dummy_sensor();
if (P == "button")   rotate([0, 0, btn_angle]) translate([cav_bore/2 - 1.0, 0, z_pcb - btn_z_off]) rotate([0, 90, 0]) button();
