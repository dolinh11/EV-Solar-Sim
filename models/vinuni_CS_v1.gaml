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
	
	date starting_date <- date("2023-11-01-00-00-00");
	
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
//    graph the_graph_inside;
//    graph the_graph_outside;
	graph the_graph;
    
    int nb_activeCS_Cparking <- 7;
    int nb_activeCS_Jparking <- 6;
	
	init {
		create chargingAreas from: shape_file_chargingareas with: [type::string(read ("fclass")), active_CS::int(read("active_CS"))] {
			if type="C_parking" {
				chargingAreas_color <- #yellow ;
			}
				chargingAreas[0].active_CS <- nb_activeCS_Cparking;
				chargingAreas[1].active_CS <- nb_activeCS_Jparking;
		}
		
		create residential from: shape_file_residential ;
		create gate from: shape_file_gate with: [type::string(read ("fclass")), state_type::string(read("state"))] {
			if state_type="close" {
				gate_color <- #navy;
			}
		}
		
		create vinuniBound from: shape_file_vinuni_bounds ;
		create boundary from: shape_file_boundary ;
		create building from: shape_file_buildings ;
		
		create footway from: shape_file_footway;
		create road from: shape_file_carway with:[type::string(read ("fclass")), direction::int(read("direction"))] {
			switch direction {
				match 0 {}
				match 1 {
					//inversion of the road geometry
					shape <- polyline(reverse(shape.points));
				}
				match 2 {
					//bidirectional: creation of the inverse road
					create road {
						shape <- polyline(reverse(myself.shape.points));
						direction <- 2;
					}
				} 
			}
		}
//		the_graph_inside <- directed(as_edge_graph(road where (each.type = "inside"))) ;
//		the_graph_outside <- directed(as_edge_graph(road where (each.type = "outside"))) ;
		the_graph <- directed(as_edge_graph(road));
		
		create car_gasoline number: nb_gasoline;
		create car_electrical number: nb_electrical;
		
//		create car;
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
		draw shape color: residential_color border: #black ;
	}
}

species building {
	rgb building_color <- rgb(72, 175, 231);
	aspect base {
		draw shape color: building_color border: #black ;
	}
}

species vinuniBound {
	rgb bound_color <- rgb(103, 174, 115);
	aspect base {
		draw shape color: bound_color border: #black ;
	}
}

species boundary {
	aspect base {
		draw shape color: #white border: #black ;
	}
}

species chargingAreas {
	string type; 
	int active_CS;
	rgb chargingAreas_color <- #orange  ;
	
	aspect base {
		draw shape color: chargingAreas_color ;
	}
}

species road  {
	string type; 
	int direction;
	rgb road_color <- #black ;
	
	aspect base {
		draw shape color: road_color ;
	}
}

species footway  {
	rgb footway_color <- #gray ;
	
	aspect base {
		draw shape color: footway_color ;
	}
}

species car skills: [moving] {
	rgb color;
	chargingAreas parking <- nil;
    residential home <- nil;
    int start_work ;
    int end_work  ;
    string car_obj ; 
    point the_target <- nil ;
    point the_gate <- nil;
    string parking_slot <- nil;
    bool at_gate <- false;
    
    list<residential> residential_area <- residential where (true);
	list<chargingAreas> vinuni_parking <- chargingAreas where (true);
	list<gate> gate_open <- gate where (each.state_type="open");
	
	init {
		speed <- rnd(min_speed, max_speed);
		    
		//Define start_work hours with probability during interval 1 is P(arrive_early) = 0.7
		if flip(0.7) {
		    start_work <- rnd (min_work_start_1, max_work_start_1);
		} else {
	    	start_work <- rnd (min_work_start_2, max_work_start_2);
	    }
		    
		end_work <- rnd(min_work_end_2, max_work_end_2);
		  
		//Select parking area with P(C_parking) = 0.8
		if flip(0.8) {
			parking <- one_of(vinuni_parking where (each.type="C_parking"));
		} else {
			parking <- one_of(vinuni_parking where (each.type="J_parking"));
		}
		home <- one_of(residential_area);
        car_obj <- "gate";
        location <- any_location_in(home);
        the_gate <- any_location_in(one_of(gate_open));
	}
	
	action assign_slot virtual: true;
	
//	action move_to_gate {
//		if car_obj = "outside_vinuni" {
//			do goto target: one_of(gate_open) on: the_graph_outside;
//		} else if car_obj = "inside_vinuni" {
//			do goto target: one_of(gate_open) on: the_graph_inside;
//		}
////		at_gate <- true;
//	}
	
//	reflex move_to_gate when: car_obj = "gate" {
//		if current_date.hour = start_work {
//			do goto target: the_gate on: the_graph_outside;
//			if the_gate = location {
//				car_obj <- "parking";
////				at_gate <- true;
//			}
//		} else if current_date.hour = end_work {
//			do goto target: the_gate on: the_graph_inside;
//		}
//	}

	action parking {
		the_target <- any_location_in (parking);
		do assign_slot;
		if parking_slot = "active_CS" {
			parking.active_CS <- parking.active_CS - 1 ;
	    }
//	    at_gate <- false;
	}
	
	action leaving {
		the_target <- any_location_in(home);
		car_obj <- "gate" ;
		if parking_slot = "active_CS" {
			parking.active_CS <- parking.active_CS + 1 ;
	    }
	    parking_slot <- nil;
	}
	
    reflex time_to_work when: car_obj = "parking" {
    	do parking;
    }
    
    reflex time_to_go_home when: current_date.hour = end_work and car_obj = "leaving" {
        do leaving;
    }
     
    reflex move when: the_target != nil {
//    	if car_obj = "leaving" {
//			do goto target: the_target on: the_graph_outside;
//		} else if car_obj = "parking" {
//			do goto target: the_target on: the_graph_inside;
//		}
		do goto target: the_target on: the_graph;
		if the_target = location {
	    	the_target <- nil ;
//	    	at_gate <- false;
		}
    }
    
//	reflex random_move when: (current_date.hour between(10,15)) and flip(0.01){
//		if (location = any_location_in(home)) {
//			do move_to_gate;
////			do parking;
//		} else {
//			do move_to_gate;
//// 			do leaving;
//		}
//	}
}

species car_gasoline parent: car {
	rgb color <- #red;
	
	action assign_slot {
		if parking.active_CS > 0 {
			parking_slot <- flip(0.25) ? "active_CS" : "inactive_CS";
	    } else {
	        parking_slot <- "inactive_CS";
	    }
    }
	
	aspect base {
		draw circle(5) color: color border: #black;
	}
}

species car_electrical parent: car {
	rgb color <- #green;
	
	aspect base {
		draw circle(5) color: color border: #black;
	}
	
	action assign_slot {
		if parking.active_CS > 0 {
			parking_slot <- flip(0.9) ? "active_CS" : "inactive_CS";
	    } else {
	        parking_slot <- "inactive_CS";
	    }
    }
}

experiment vinuni_traffic type: gui {
//	parameter "Shapefile for the charging stations:" var: shape_file_charging_areas category: "GIS" ;
	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car" ;
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" ;
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking" ;
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "J_parking" ;
	
//    parameter "minimal speed" var: min_speed category: "Speed" min: 0.1 #km/#h ;
//    parameter "maximal speed" var: max_speed category: "Speed" max: 10 #km/#h;
	
	output {
		display vinuni_display type:3d {
			species vinuniBound aspect: base;		
			species building aspect: base;
			species residential aspect: base ;
			species chargingAreas aspect: base;
			species road aspect: base;
			species footway aspect: base;
			species gate aspect: base;
			species car_gasoline aspect: base;
			species car_electrical aspect: base;
		}
		display chart_display refresh: every(10#cycles)  type: 2d { 
			chart "Gasoline Car Position" type: pie style: exploded size: {0.5, 1} position: {0.5, 0} {
				data "Inside VinUni" value: car_gasoline count (each.car_obj="parking") color: #magenta ;
				data "Outside VinUni" value: car_gasoline count (each.car_obj="leaving") color: #blue ;
			}
			chart "Electrical Car Position" type: pie style: exploded size: {0.5, 1} position: {0, 0} {
				data "Inside VinUni" value: car_electrical count (each.car_obj="parking") color: #magenta ;
				data "Outside VinUni" value: car_electrical count (each.car_obj="leaving") color: #blue ;
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