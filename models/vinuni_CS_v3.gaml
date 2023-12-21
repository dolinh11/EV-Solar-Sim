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
	
	date starting_date <- date("2023-12-10-00-00-00");
	
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
    
    float min_speed <- 2 #km / #h;
    float max_speed <- 2.5 #km / #h; 
    graph the_graph;
//    graph the_graph_inside;
//    graph the_graph_outside;
    
    int nb_parking_slot_C <- 29;
    int nb_parking_slot_J <- 27;
    int nb_activeCS_Cparking_fast <- 0;
    int nb_activeCS_Cparking_normal <- 7;
    int nb_activeCS_Jparking_fast <- 2;
    int nb_activeCS_Jparking_normal <- 4;
    
    int nb_no_charging_car <- 0;
    int nb_no_parking_car <- 0;
    
	
	init {
		create chargingAreas from: shape_file_chargingareas with: [type::string(read ("fclass")), active_CS::int(read("active_CS")), nb_parking_slots::int(read("num_CS"))] {
			if type="C_parking" {
				chargingAreas_color <- #yellow ;
			}
			chargingAreas[0].active_CS <- nb_activeCS_Cparking_fast + nb_activeCS_Cparking_normal;
			chargingAreas[1].active_CS <- nb_activeCS_Jparking_fast + nb_activeCS_Jparking_normal;
			
			chargingAreas[0].nb_parking_slots <- nb_parking_slot_C;
			chargingAreas[1].nb_parking_slots <- nb_parking_slot_J;
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
	int nb_parking_slots;
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
    float start_work ;
    float end_work  ;
    string parking_obj ; 
    point the_target <- nil ;
    point the_gate <- nil;
    string parking_slot <- nil;
    int count_trial <- 0;
    string current_action <- nil;
    
    list<residential> residential_area <- residential where (true);
	list<chargingAreas> vinuni_parking <- chargingAreas where (true);
	
	init {
		speed <- rnd(min_speed, max_speed);
		//Define start_work hours with probability during interval 1 is P(arrive_early) = 0.7
		if flip(0.7) {
		    start_work <- rnd (min_work_start_1, max_work_start_1); //8am to 10am
		} else {
	    	start_work <- rnd (min_work_start_2, max_work_start_2); //12 to 14
	    }
		end_work <- rnd(min_work_end_2, max_work_end_2); //between 17 and 19
		//Select parking area with P(C_parking) = 0.8
		if flip(0.8) {
			parking <- one_of(vinuni_parking where (each.type="C_parking"));
		} else {
			parking <- one_of(vinuni_parking where (each.type="J_parking"));
		}
		home <- one_of(residential_area);
        parking_obj <- "outside_vinuni";
        location <- any_location_in(home);
	}
	
	action assign_slot virtual: true; //a virtual action is to be overridden in the species that inherit from this "car" species
	action charging virtual: true;
	action parking {
		parking_obj <- "inside_vinuni" ;
		the_target <- any_location_in (parking);
		do assign_slot;
		if parking_slot = "active_CS" {
			parking.active_CS <- parking.active_CS - 1 ;
	    }
	    if parking_slot != "no_parking_slots"{
	    	parking.nb_parking_slots <- parking.nb_parking_slots - 1;
	    }
	    else if parking_slot = "no_parking_slots"{
	    	nb_no_parking_car <- nb_no_parking_car + 1;
	    }
	}
	action moving_between_C_and_J {
		if (parking.type ="C_parking"){
			parking.type <- "J_parking";
		}
		else {
			parking.type <- "J_parking";
		}
		the_target <- any_location_in (parking);
		if (current_action = "looking_for_parking_slot") {do assign_slot;}
		else if (current_action = "looking_for_charging_slot") {do charging;}
	}
	
	action leaving {
		parking_obj <- "outside_vinuni" ;
		the_target <- any_location_in(home);
		if parking_slot != "no_parking_slots" {
			parking.nb_parking_slots <- parking.nb_parking_slots + 1 ;
	    }
	    parking_slot <- nil;
	}

    reflex time_to_work when: current_date.hour = start_work and parking_obj = "outside_vinuni" {
    	do parking;	
    }
    
    
    reflex time_to_go_home when: current_date.hour = end_work and parking_obj = "inside_vinuni" {
        do leaving;
    }
     
    reflex move when: the_target != nil {
		do goto target: the_target on: the_graph;
		if the_target = location {
	    	the_target <- nil ;
		}
    }
    
	reflex random_move when: (current_date.hour between(10,15)) and flip(0.01){
		if (location = any_location_in(home)) {
			do parking;
		} else {
 			do leaving;
		}
	}
}

species car_gasoline parent: car {
	rgb color <- #red;
	//aspect defines how an agent should be represented or drawn in graphical display
	aspect base {
		draw circle(5) color: color border: #black;
	}
	action charging{}
	action assign_slot {
		if (parking.nb_parking_slots > 0 and parking.active_CS > 0) {
			parking_slot <- flip(0.25) ? "parked_active_CS" : "parked_inactive_CS";
	    } 
	    else if (parking.nb_parking_slots > 0 and parking.active_CS <= 0){
	        parking_slot <- "parked_inactive_CS";
	    }
	    else if (parking.nb_parking_slots <= 0 and parking.active_CS <= 0){
	    	if (count_trial <= 2){
	    		count_trial <- count_trial + 1;
	    		current_action <- "looking_for_parking_slot";
				do moving_between_C_and_J;	    		
	    	}
	    	else {count_trial <- 0; parking_slot <- "no_parking_slots";}
	    }
    }
}

species car_electrical parent: car {
	rgb color <- #green;
	float initial_SoC; //battery level
	string EV_model; //type of EV
	list<string> EV_models_at_vinuni <- ["VFe34", "VF8", "VF9"];
	//attributes for charging time and charging mode
	float fully_charging_time;
	string charging_mode <-nil;
	// Map containing charging times for each model and each charging mode
    map<string, map<string, float>> model_charging_times <- ["VFe34"::["fast"::80/60, "normal"::230/60], 
                                                              "VF8"::["fast"::170/60, "normal"::470/60], 
                                                              "VF9"::["fast"::240/60, "normal"::670/60]];
	
	init {
		initial_SoC <- rnd(10,70); 		//assign a random SoC between 10% and 70%
		EV_model <- one_of(EV_models_at_vinuni); //assign a random EV model
	}
//	reflex assign_SoC_when_arriving_at_vinuni when: parking_obj = "inside_vinuni" {
//        initial_SoC <- rnd(10,70); //assign a random SoC between 10% and 70%
//    }
    
    reflex determine_charging_mode when: current_date.hour > start_work and parking_obj = "inside_vinuni" and initial_SoC < 20 {
		do charging;
	}
	action charging{
		//calculate charging time from initial_SoC to 100% in "normal" 11kW and "fast" 30kW charging mode
		float charging_time_normal <- model_charging_times[EV_model]["normal"] * (1 - initial_SoC/100);
		float charging_time_fast <- model_charging_times[EV_model]["fast"] * (1 - initial_SoC/100);
		//logic to choose a charging mode
		if (charging_time_normal >= 0.8*(end_work - start_work)){
			if (parking.type = "C_parking"){
				if (nb_activeCS_Cparking_fast > 0){
					charging_mode <- "fast";
					nb_activeCS_Cparking_fast <- nb_activeCS_Cparking_fast - 1;
					parking.active_CS <- parking.active_CS - 1;					
				}
				else if (nb_activeCS_Cparking_normal > 0){
					charging_mode <- "normal";
					nb_activeCS_Cparking_normal <- nb_activeCS_Cparking_normal - 1;	
					parking.active_CS <- parking.active_CS - 1;						
				}
				else{
					if (count_trial <= 2){
	    				count_trial <- count_trial + 1;
	    				current_action <- "looking_for_charging_slot";
						do moving_between_C_and_J;	    		
	    			}
	    			else {count_trial <- 0; charging_mode <- "no_charging_point_available"; nb_no_charging_car <- nb_no_charging_car + 1;}
				}
			}
			else{
				if (nb_activeCS_Jparking_fast > 0){
					charging_mode <- "fast";
					nb_activeCS_Jparking_fast <- nb_activeCS_Jparking_fast - 1;	
					parking.active_CS <- parking.active_CS - 1;			
				}
				else if (nb_activeCS_Jparking_normal > 0){
					charging_mode <- "normal";
					nb_activeCS_Jparking_normal <- nb_activeCS_Jparking_normal - 1;
					parking.active_CS <- parking.active_CS - 1;							
				}
				else{
					if (count_trial <= 2){
	    				count_trial <- count_trial + 1;
	    				current_action <- "looking_for_charging_slot";
						do moving_between_C_and_J;	    		
	    			}
	    			else {count_trial <- 0; charging_mode <- "no_charging_point_available"; nb_no_charging_car <- nb_no_charging_car + 1;}
				}				
			}
		}
		else {
			if (parking.type = "C_parking" and nb_activeCS_Cparking_normal > 0){ 
				charging_mode <- "normal";
				nb_activeCS_Cparking_normal <- nb_activeCS_Cparking_normal - 1;
				chargingAreas[0].active_CS <- chargingAreas[0].active_CS - 1;		
			}
			else if (parking.type = "C_parking" and nb_activeCS_Cparking_normal <= 0){
				charging_mode <- "no_charging_point_available";
				chargingAreas[0].active_CS <- chargingAreas[0].active_CS - 1;
			}
			else if (parking.type = "J_parking" and nb_activeCS_Jparking_normal > 0){ 
				charging_mode <- "normal";
				nb_activeCS_Jparking_normal <- nb_activeCS_Jparking_normal - 1;
				chargingAreas[1].active_CS <- chargingAreas[1].active_CS - 1;	
			}
			else if (parking.type = "J_parking" and nb_activeCS_Jparking_normal <= 0){ 
				if (count_trial <= 2){
	    			count_trial <- count_trial + 1;
	    			current_action <- "looking_for_charging_slot";
					do moving_between_C_and_J;	    		
	    		}
	    		else {count_trial <- 0; charging_mode <- "no_charging_point_available"; nb_no_charging_car <- nb_no_charging_car + 1;}
			}
		}
	}

	aspect base {
		draw circle(5) color: color border: #black;
	}
	
	action assign_slot {
		if (parking.nb_parking_slots > 0 and parking.active_CS > 0) {
			parking_slot <- flip(0.9) ? "parked_active_CS" : "parked_inactive_CS";
	    } 
	    else if (parking.nb_parking_slots > 0 and parking.active_CS <= 0){
	        parking_slot <- "parked_inactive_CS";
	    }
	    else if (parking.nb_parking_slots <= 0 and parking.active_CS <= 0){
	    	if (count_trial <= 2){
	    		count_trial <- count_trial + 1;
	    		current_action <- "looking_for_parking_slot";
				do moving_between_C_and_J;	    		
	    	}
	    	else {count_trial <- 0; parking_slot <- "no_parking_slots";}
	    }
    }
}

experiment vinuni_traffic type: gui {
//	parameter "Shapefile for the charging stations:" var: shape_file_charging_areas category: "GIS" ;
	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car" ;
	parameter "Number of electrical car agents" var: nb_electrical category: "Electric Car" ;
	
	parameter "Number of parking slots at C_parking" var: nb_parking_slot_C category: "Building C parking area" ;
	parameter "Number of active FAST (30kW) charging ports at C_parking" var: nb_activeCS_Cparking_fast category: "Building C parking area" ;
	parameter "Number of active NORMAL (11kW) charging ports at C_parking" var: nb_activeCS_Cparking_normal category: "Building C parking area" ;
	
	parameter "Number of parking slots at J_parking" var: nb_parking_slot_J category: "Building J parking area" ;
	parameter "Number of active FAST (30kW) charging ports at J_parking" var: nb_activeCS_Jparking_fast category: "Building J parking area" ;
	parameter "Number of active NORMAL (11kW) charging ports at J_parking" var: nb_activeCS_Jparking_normal category: "Building J parking area" ;
	
//    parameter "minimal speed" var: min_speed category: "Speed" min: 0.1 #km/#h ;
//    parameter "maximal speed" var: max_speed category: "Speed" max: 10 #km/#h;
	
	output {
		layout #split;
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
//			chart "Gasoline Car Position" type: pie style: exploded size: {0.5, 1} position: {0.5, 0} {
//				data "Inside VinUni" value: car_gasoline count (each.parking_obj="inside_vinuni") color: #magenta ;
//				data "Outside VinUni" value: car_gasoline count (each.parking_obj="outside_vinuni") color: #blue ;
//			}
//			chart "Electrical Car Position" type: pie style: exploded size: {0.5, 1} position: {0, 0} {
//				data "Inside VinUni" value: car_electrical count (each.parking_obj="inside_vinuni") color: #magenta ;
//				data "Outside VinUni" value: car_electrical count (each.parking_obj="outside_vinuni") color: #blue ;
//			}
//		}
			chart "Number of Active Charging Stations Available" type: series x_label: "#points to draw at each time step"{
				data "Slots at C_parking" value: nb_activeCS_Cparking_fast + nb_activeCS_Cparking_normal color: #blue marker: false style: line;
				data "Slots at J_parking" value: nb_activeCS_Jparking_fast + nb_activeCS_Jparking_normal color: #red marker: false style: line;
			}
//			chart "Number of Cars with no parking or charging slot" type: series x_label: "#points to draw at each time step"{
//				data "NO parking slot car" value: nb_no_parking_car color: #blue marker: false style: line;
//				data "NO charging slot car" value: nb_no_charging_car color: #red marker: false style: line;
//			}
		}
		
//		display chart_display refresh: every(10#cycles) type: 2d {
//			chart "EV Types Inside VinUni" type: pie style: exploded{
//				data "VFe34" value: car_electrical count (each.EV_model = "VFe34" and each.parking_obj = "inside_vinuni") color: #blue;
//				data "VF8" value: car_electrical count (each.EV_model = "VF8" and each.parking_obj = "inside_vinuni") color: #red;
//				data "VF9" value: car_electrical count (each.EV_model = "VF9" and each.parking_obj = "inside_vinuni") color: #green;
//
//			}
//		}
	}
}