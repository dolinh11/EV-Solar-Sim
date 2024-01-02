/**
* Name: vinuniCS
* Based on the internal empty template. 
* Author: linhdo
* Tags: 
*/
model vinuniCS

/* Insert your model definition here */
global {
//	file shape_file_target <- file("../includes/vinuni_map/vinuni_gis_osm_target.shp");
//	file shape_file_traffic <- file("../includes/vinuni_map/vinuni_gis_osm_traffic.shp");
//	file shape_file_roads <- file("../includes/vinuni_map/vinuni_gis_osm_road_clean.shp");
	file shape_file_chargingareas <- shape_file("../includes/vinuni_map/vinuni_gis_osm_chargingareas.shp");
	file shape_file_residential <- shape_file("../includes/vinuni_map/vinuni_gis_osm_residential.shp");
	file shape_file_carway <- shape_file("../includes/vinuni_map/vinuni_gis_osm_carway_clean_v1.shp");
	file shape_file_footway <- shape_file("../includes/vinuni_map/vinuni_gis_osm_footway.shp");
	file shape_file_gate <- shape_file("../includes/vinuni_map/vinuni_gis_osm_gate.shp");
	file shape_file_buildings <- file("../includes/vinuni_map/vinuni_gis_osm_buildings.shp");
	file shape_file_vinuni_bounds <- file("../includes/vinuni_map/vinuni_gis_osm_bound.shp");
	file shape_file_boundary <- file("../includes/vinuni_map/vinuni_gis_osm_boundary.shp");
	geometry shape <- envelope(shape_file_boundary);
	float step <- 5 #mn;
	date starting_date <- date("2023-11-01 00:00:00");

	//	int nb_car <- 40;
	int nb_electrical <- 12;
	int nb_gasoline <- 28;
	int min_work_start_1 <- 8;
	int max_work_start_1 <- 10;
	int min_work_start_2 <- 12;
	int max_work_start_2 <- 14;
	int min_work_end_1 <- 11;
	int max_work_end_1 <- 15;
	int min_work_end_2 <- 17;
	int max_work_end_2 <- 19;
	float min_speed <- 3 #km / #h;
	float max_speed <- 5 #km / #h;
	graph the_graphA;
	graph the_graph_inside;
	graph the_graph_outside;
	int nb_activeCS_Cparking <- 7;
	int nb_activeCS_Jparking <- 6;
	int nb_activeCS_Cparking_fast <- 0;
	int nb_activeCS_Jparking_fast <- 2;
	float revenue <- 0.0;
	float total_energy_consumption <- 0.0;
	int nb_activeCS_slow_used;
	int nb_activeCS_fast_used;
	
	bool policy_prohibit_parking <- false; //prohibit gasoline cars from parking in active_CS slot

	init {
		create chargingAreas from: shape_file_chargingareas with: [type:: string(read("fclass")), active_CS::int(read("active_CS")), num_CS::int(read("num_CS"))] {
			if type = "C_parking" {
				chargingAreas_color <- #yellow;
			}
			chargingAreas[0].active_CS <- nb_activeCS_Cparking;
			chargingAreas[1].active_CS <- nb_activeCS_Jparking;
			chargingAreas[0].activeCS_fast <- nb_activeCS_Cparking_fast;
			chargingAreas[1].activeCS_fast <- nb_activeCS_Jparking_fast;
		}

		create residential from: shape_file_residential;
		create gate from: shape_file_gate with: [type:: string(read("fclass")), state_type::string(read("state"))] {
			if state_type = "close" {
				gate_color <- #navy;
			}
		}

		create vinuniBound from: shape_file_vinuni_bounds;
		create boundary from: shape_file_boundary;
		create building from: shape_file_buildings;
		create footway from: shape_file_footway;
		create road from: shape_file_carway with: [type:: string(read("fclass")), direction::int(read("direction"))] {
			switch direction {
				match 0 {
				}

				match 1 {
				//inversion of the road geometry
					shape <- polyline(reverse(shape.points));
				}

				match 2 {
				//bidirectional: creation of the inverse road
					create road {
						shape <- polyline(reverse(myself.shape.points));
						direction <- 2;
						type <- myself.type;
					}
				}
			}
		}

		the_graph_inside <- directed(as_edge_graph(road where (each.type = "inside")));
		the_graph_outside <- directed(as_edge_graph(road where (each.type = "outside")));
		the_graphA <- directed(as_edge_graph(road));
		create car_gasoline number: nb_gasoline;
		create car_electrical number: nb_electrical;
		//		create car;
	}
	
	reflex calculate_energy {
		nb_activeCS_fast_used <- (nb_activeCS_Cparking_fast - chargingAreas[0].activeCS_fast) + (nb_activeCS_Jparking_fast - chargingAreas[1].activeCS_fast);
		nb_activeCS_slow_used <- (nb_activeCS_Cparking - chargingAreas[0].active_CS) + (nb_activeCS_Jparking - chargingAreas[1].active_CS) - nb_activeCS_fast_used;
		total_energy_consumption <- (5/60) * ((nb_activeCS_slow_used * 11) + (nb_activeCS_fast_used * 30)); 
	}
}

species gate {
	string type;
	string state_type;
	rgb gate_color <- #yellow;

	aspect base {
		draw square(12) color: gate_color border: #black;
	}
}

species residential {
	rgb residential_color <- #gray;

	aspect base {
		draw shape color: residential_color border: #black;
	}
}

species building {
	rgb building_color <- rgb(72, 175, 231);

	aspect base {
		draw shape color: building_color border: #black;
	}
}

species vinuniBound {
	rgb bound_color <- rgb(103, 174, 115);

	aspect base {
		draw shape color: bound_color border: #black;
	}
}

species boundary {
	aspect base {
		draw shape color: #white border: #black;
	}
}

species chargingAreas {
	string type;
	int active_CS;
	int activeCS_fast;
	int num_CS;
	rgb chargingAreas_color <- #orange;

	aspect base {
		draw shape color: chargingAreas_color;
	}
}

species road {
	string type;
	int direction;
	rgb road_color <- #black;

	aspect base {
		draw shape color: road_color;
	}
}

species footway {
	rgb footway_color <- #gray;

	aspect base {
		draw shape color: footway_color;
	}
}

species car skills: [moving] {
	rgb color;
	chargingAreas parking_area <- nil;
	residential home <- nil;
	int start_work;
	int end_work;
	string moving_obj;
	point the_target <- nil;
	point the_gate <- nil;
	string parking_slot <- nil;
	graph the_graph;
	bool in_parkingArea <- false;
	string charging_mode <- nil;
		
	list<residential> residential_area <- residential where (true);
	list<chargingAreas> vinuni_Cparking <- chargingAreas where (each.type = "C_parking");
	list<chargingAreas> vinuni_Jparking <- chargingAreas where (each.type = "J_parking");
	list<gate> gate_open <- gate where (each.state_type = "open");

	init {
		speed <- rnd(min_speed, max_speed);

		//Define start_work hours with probability during interval 1 is P(arrive_early) = 0.7
		if flip(0.7) {
			start_work <- rnd(min_work_start_1, max_work_start_1);
		} else {
			start_work <- rnd(min_work_start_2, max_work_start_2);
		}

		end_work <- rnd(min_work_end_2, max_work_end_2);

		//Select parking area with P(C_parking) = 0.8
		if flip(0.8) {
			parking_area <- one_of(vinuni_Cparking);
		} else {
			parking_area <- one_of(vinuni_Jparking);
		}

		home <- one_of(residential_area);
		moving_obj <- "resting";
		location <- any_location_in(home);
		the_gate <- any_location_in(one_of(gate_open));
	}
			
	action assign_slot {
	}
	
	action reset {
	}

	action move_to_gate {
		if moving_obj = "resting" {
			the_graph <- the_graph_outside;
		} else if moving_obj = "working" {
			the_graph <- the_graph_inside;
		}
		the_target <- any_location_in(one_of(gate_open));
	}

	action parking {
		do assign_slot;
		the_target <- any_location_in(parking_area);
		if parking_slot = "active_CS" {
			parking_area.active_CS <- parking_area.active_CS - 1;
			if charging_mode = "fast" {
				parking_area.activeCS_fast <- parking_area.activeCS_fast - 1;
			}
		}
		parking_area.num_CS <- parking_area.num_CS - 1;
	}

	action leaving {
		the_target <- any_location_in(home);
		if parking_slot = "active_CS" {
			parking_area.active_CS <- parking_area.active_CS + 1;
			if charging_mode = "fast" {
				parking_area.activeCS_fast <- parking_area.activeCS_fast + 1;
			}
		}
		parking_area.num_CS <- parking_area.num_CS + 1;
		parking_slot <- nil;
	}

	reflex time_to_work when: current_date.hour = start_work and moving_obj = "resting" and the_target = nil {
	//		the_graph <- the_graph_outside;
		do move_to_gate;
	}

	reflex parking when: moving_obj = "parking" and the_target = nil {
		the_graph <- the_graph_inside;
		do parking;
	}

	reflex time_to_go_home when: current_date.hour = end_work and moving_obj = "working" and the_target = nil {
	//		the_graph <- the_graph_inside;
		in_parkingArea <- false;
		do move_to_gate;
	}

	reflex leaving when: moving_obj = "leaving" and the_target = nil {
		the_graph <- the_graph_outside;
		do leaving;
	}

	reflex random_move when: (current_date.hour between (10, 15)) and (moving_obj = "working" or moving_obj = "resting") and flip(0.01) and the_target = nil {
		if moving_obj = "working" {
			in_parkingArea <- false;
		}
		do move_to_gate;
	}

	reflex move when: the_target != nil {
		do goto target: the_target on: the_graph;
		if (location = the_target) {
			the_target <- nil;
			if moving_obj = "resting" {
				moving_obj <- "parking";
			} else if moving_obj = "parking" {
				moving_obj <- "working";
				in_parkingArea <- true;
			} else if moving_obj = "working" {
				moving_obj <- "leaving";
			} else if moving_obj = "leaving" {
				moving_obj <- "resting";
				do reset;
			} 
		} 
	}

	aspect base {
		draw circle(5) color: color border: #black;
		//		if (the_target != nil) {
		//			draw line([location, the_target]) color: #red;
		//		}
	} }

species car_gasoline parent: car {
	rgb color <- #red;
	float parking_active_prob; //probability of randomly parked in an active_CS slot
	
		action assign_slot {
			if not policy_prohibit_parking {
				if parking_area.active_CS > 0 and parking_area.num_CS > 0 {
					parking_active_prob <- parking_area.active_CS / parking_area.num_CS;
					parking_slot <- flip(parking_active_prob) ? "active_CS" : "inactive_CS";
				} else {
					parking_slot <- "inactive_CS";
				}
			} else if policy_prohibit_parking {
				parking_slot <- "inactive_CS";
			}
		}
		
		action reset {
		}
}

species car_electrical parent: car {
	rgb color <- #green;
	float parking_active_prob; //probability of randomly parked in an active_CS slot
	bool satisfied <- true;
	bool is_charging <- false;
	bool done_charging <- false;
	bool priority_destination <- flip(0.9) ? true : false; 
	
	//Check this probability again
	bool priority_fast <- flip(0.4) ? true : false; 
	
	int num_checkSlot <- 0;
	float SoC <- 10.0 +rnd(80);  //battery level
	string EV_model; //type of EV
	float chargingRate_slow; // charging rate of EV at AC 11kW
	float chargingRate_fast; // charging rate of EV at AC 30kW
	float charging_fee;
	string charging_mode <- "slow";
	
	list<string> EV_models_at_vinuni <- ["VFe34", "VF8", "VF9"];
	map<string, float> model_chargingRate_slow <- ["VFe34":: 100/46, "VF8":: 100/94, "VF9":: 100/134];
	map<string, float> model_chargingRate_fast <- ["VFe34":: 100/16, "VF8":: 100/34, "VF9":: 100/48];
	
	float time_to_charge <- 0 #nm;
	
	init {
		if SoC <= 20 {
			parking_area <- one_of(vinuni_Jparking);
			priority_fast <- true;
		}
		EV_model <- one_of(EV_models_at_vinuni);
		chargingRate_slow <- model_chargingRate_slow[EV_model];
		chargingRate_fast <- model_chargingRate_fast[EV_model];
		
	}
	
	action assign_slot_randomly {
		if parking_area.active_CS > 0 and parking_area.num_CS > 0 {
			parking_active_prob <- parking_area.active_CS / parking_area.num_CS;
			parking_slot <- flip(parking_active_prob) ? "active_CS" : "inactive_CS";
		} else {
			parking_slot <- "inactive_CS";
		}
	}
	
	action assign_slot {
		if SoC >= 70 {
			do assign_slot_randomly;
		}
		else if SoC < 70 and SoC > 35 {
			if flip(0.8) {
				do check_slot;
			} else {
				do assign_slot_randomly;
			}
		} else if SoC <= 35 {
			do check_slot;
		}
	}
	
	action check_slot {	
		if parking_area = one_of(vinuni_Jparking) and priority_fast and parking_area.activeCS_fast > 0 {
			charging_mode <- "fast";
			parking_slot <- "active_CS";
		} else {
			charging_mode <- "slow";
						
			if parking_area.active_CS > 0 {
				parking_slot <- "active_CS";
			} else if parking_area.active_CS = 0 and num_checkSlot = 1 {
				parking_slot <- "inactive_CS";
				satisfied <- false;
			} else if parking_area.active_CS = 0 and num_checkSlot = 0 {
				if SoC <= 35 {
					do change_parkingArea;
				} else if SoC < 70 and SoC > 35 {
					if priority_destination {
						parking_slot <- "inactive_CS";
						satisfied <- false;
					} else {
						do change_parkingArea;
					}
				}
			}
		}
	}
	
	action change_parkingArea {
		num_checkSlot <- num_checkSlot + 1;
		if parking_area = one_of(vinuni_Jparking) {
			parking_area <- one_of(vinuni_Cparking);
		} else if parking_area = one_of(vinuni_Cparking) {
			parking_area <- one_of(vinuni_Jparking);
		}
		do check_slot;
	}

	reflex try_to_charge when: moving_obj = "working" and not done_charging {
		if (parking_slot = "active_CS" and in_parkingArea) {
			//Assume that when an EV decides to park in an active_CS slot, it always plugs the charge. 			
			is_charging <- true;
		}
	}

	reflex charge when: is_charging and moving_obj = "working" {
		time_to_charge <- time_to_charge + 5;
		if charging_mode = "slow" {
			SoC <- SoC + chargingRate_slow;
		} else if charging_mode = "fast" {
			SoC <- SoC + chargingRate_fast;
		}
		
		if (SoC > 99) or (not in_parkingArea) {
			if charging_mode = "slow" {
				charging_fee <- 3355 * 11 * (time_to_charge / 60);
			} else if charging_mode = "fast" {
				charging_fee <- 3355 * 30 * (time_to_charge / 60);
			}
			revenue <- revenue + charging_fee;
			is_charging <- false;
			done_charging <- true;
		}
	}
	
	action reset {
		SoC <- 10.0 + rnd(80);
		time_to_charge <- 0 #mn;
		done_charging <- false;
		charging_fee <- 0.0;
	}
}

experiment vinuni_traffic type: gui {
//	parameter "Shapefile for the charging stations:" var: shape_file_charging_areas category: "GIS" ;
	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car";
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car";
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking";
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "J_parking";
	parameter "Implement a policy prohibiting gasoline cars from parking in active_CS" var: policy_prohibit_parking category: "Policy";

	//    parameter "minimal speed" var: min_speed category: "Speed" min: 0.1 #km/#h ;
	//    parameter "maximal speed" var: max_speed category: "Speed" max: 10 #km/#h;
	output synchronized:true{
		display vinuni_display type: 2d {
			species vinuniBound aspect: base;
			species building aspect: base;
			species residential aspect: base;
			species chargingAreas aspect: base;
			species road aspect: base;
			species footway aspect: base;
			species gate aspect: base;
			species car_gasoline aspect: base;
			species car_electrical aspect: base;
		}

		display time_to_charge refresh: every(12 #cycles) {
		//			chart "datalist_bar" type: histogram series_label_position: onchart {
		//				datalist legend: ["Average Time to charge","Number of Not charged" ] style: bar value:
		//				[mean(car_electrical collect each.time_to_charge),/*100] color: [#green,#red ];
		//			}
			chart "Number of charged vehicle" type: histogram style: stack  {
				data "Charged & Satisfied" accumulate_values: true value: length(car_electrical where (each.time_to_charge > 0 and each.parking_slot = "active_CS" and each.satisfied = true)) color: #blue;
				data "Not Charged & Unsatisfied" accumulate_values: true value: length(car_electrical where (each.parking_slot = "inactive_CS" and each.satisfied = false)) color: #yellow;
			}
		}

		display revenue type: 2d {
			chart "Revenue" type: series memorize: false {
				data "Total revenue" value: revenue color: #blue marker: false style: line;
			}
		}
		
		display energy_consumption type: 2d {
			chart "Energy" type: series memorize: false {
				data "Total Energy Consumption" value: total_energy_consumption color: #blue marker: false style: line;
			}
		}

		display chart_display refresh: every(12 #cycles) type: 2d {
			chart "Gasoline Car Position" type: pie style: exploded size: {0.5, 1} position: {0.5, 0} {
				data "Inside VinUni" value: car_gasoline count (each.moving_obj = "working") color: #magenta;
				data "Outside VinUni" value: car_gasoline count (each.moving_obj = "resting") color: #blue;
			}

			chart "Electrical Car Position" type: pie style: exploded size: {0.5, 1} position: {0, 0} {
				data "Inside VinUni" value: car_electrical count (each.moving_obj = "working") color: #magenta;
				data "Outside VinUni" value: car_electrical count (each.moving_obj = "resting") color: #blue;
			}
		}

		display series type: 2d {
			chart "Number of Active Charging Stations Available" type: series x_label: "#points to draw at each step" memorize: false {
				data "Slots at C_parking" value: chargingAreas[0].active_CS color: #blue marker: false style: line;
				data "Slots at J_parking" value: chargingAreas[1].active_CS color: #red marker: false style: line;
			}
		}
	}
}