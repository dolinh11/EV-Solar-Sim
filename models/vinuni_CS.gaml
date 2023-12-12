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
		
	file shape_file_carway <- shape_file("../includes/vinuni_map/vinuni_gis_osm_carway_clean.shp");
	file shape_file_footway <- shape_file("../includes/vinuni_map/vinuni_gis_osm_footway.shp");

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
    
    float min_speed <- 1 #km / #h;
    float max_speed <- 5 #km / #h; 
    graph the_graph;
	
	init {
		create chargingAreas from: shape_file_chargingareas with: [type::string(read ("fclass")), active_CS::int(read("active_CS"))] {
			if type="C_parking" {
				color <- #yellow ;
			}
		}
		
		create residential from: shape_file_residential ;
		
		create vinuniBound from: shape_file_vinuni_bounds ;
		create boundary from: shape_file_boundary ;
		create building from: shape_file_buildings ;
		
		create footway from: shape_file_footway;
		create road from: shape_file_carway ;
		the_graph <- as_edge_graph(road);
		
		create car_gasoline number: nb_gasoline;
		create car_electrical number: nb_electrical;
		
//		create car;
		
//		list<residential> residential_area <- residential where (true);
//		list<chargingAreas> vinuni_parking <- chargingAreas where (true);
//		create car {
//		    speed <- rnd(min_speed, max_speed);
//		    
//		    //Define start_work hours with probability during interval 1 is P(arrive_early) = 0.7
//		    if flip(0.7) {
//		    	start_work <- rnd (min_work_start_1, max_work_start_1);
//		    } else {
//		    	start_work <- rnd (min_work_start_2, max_work_start_2);
//		    }
//		    
//		    //Define end_work hours with probability during interval 1 is P(leave_early) = 0.2
////		    if flip(0.2) {
////		    	end_work <- rnd(min_work_end_1, max_work_end_1);
////		    } else {
////		    	end_work <- rnd(min_work_end_2, max_work_end_2);
////		    }
//		    
//		    end_work <- rnd(min_work_end_2, max_work_end_2);
//		  
//		    //Select parking area with P(C_parking) = 0.8
//		    if flip(0.8) {
//		    	parking <- one_of(vinuni_parking where (each.type="C_parking"));
//		    } else {
//		    	parking <- one_of(vinuni_parking where (each.type="J_parking"));
//		    }
//		    
//            home <- one_of(residential_area);
//            parking_obj <- "outside_vinuni";
//            location <- any_location_in(home); 
//       }
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
	rgb color <- #orange  ;
	
	aspect base {
		draw shape color: color ;
	}
}

species road  {
	string type; 
	rgb color <- #black ;
	
	aspect base {
		draw shape color: color ;
	}
}

species footway  {
	rgb color <- #black ;
	
	aspect base {
		draw shape color: color ;
	}
}

species car skills: [moving] {
	rgb color;
	chargingAreas parking <- nil;
    residential home <- nil;
    int start_work ;
    int end_work  ;
    string parking_obj ; 
    point the_target <- nil ;
    string parking_slot <- nil;
    
    list<residential> residential_area <- residential where (true);
	list<chargingAreas> vinuni_parking <- chargingAreas where (true);
	
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
        parking_obj <- "outside_vinuni";
        location <- any_location_in(home); 
	}
	
	action assign_slot virtual: true;
	
	action parking {
		parking_obj <- "inside_vinuni" ;
		the_target <- any_location_in (parking);
		do assign_slot;
		if parking_slot = "active_CS" {
			parking.active_CS <- parking.active_CS - 1 ;
	    }
	}
	
	action leaving {
		the_target <- any_location_in(home);
		parking_obj <- "outside_vinuni" ;
		if parking_slot = "active_CS" {
			parking.active_CS <- parking.active_CS + 1 ;
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
		do goto target: the_target on: the_graph ; 
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
			species car_gasoline aspect: base;
			species car_electrical aspect: base;
		}
		display chart_display refresh: every(10#cycles)  type: 2d { 
			chart "Gasoline Car Position" type: pie style: exploded size: {0.5, 1} position: {0.5, 0} {
				data "Inside VinUni" value: car_gasoline count (each.parking_obj="inside_vinuni") color: #magenta ;
				data "Outside VinUni" value: car_gasoline count (each.parking_obj="outside_vinuni") color: #blue ;
			}
			chart "Electrical Car Position" type: pie style: exploded size: {0.5, 1} position: {0, 0} {
				data "Inside VinUni" value: car_electrical count (each.parking_obj="inside_vinuni") color: #magenta ;
				data "Outside VinUni" value: car_electrical count (each.parking_obj="outside_vinuni") color: #blue ;
			}
		}
		
		display series type: 2d {
			chart "Number of Active Charging Stations Available" type: series x_label: "#points to draw at each step" memorize: false {
				data "Slots at C_parking" value: (one_of(chargingAreas where (each.type="C_parking"))).active_CS color: #blue marker: false style: line;
				data "Slots at J_parking" value: (one_of(chargingAreas where (each.type="J_parking"))).active_CS color: #red marker: false style: line;
			}

		}
	}
}