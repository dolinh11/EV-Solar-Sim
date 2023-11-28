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

	
	file shape_file_chargingareas <- shape_file("../includes/vinuni_map/vinuni_gis_osm_chargingareas.shp");	
	file shape_file_residential <- shape_file("../includes/vinuni_map/vinuni_gis_osm_residential.shp");

	file shape_file_roads <- file("../includes/vinuni_map/vinuni_gis_osm_road_clean.shp");
	
	file shape_file_buildings <- file("../includes/vinuni_map/vinuni_gis_osm_buildings.shp");
	file shape_file_vinuni_bounds <- file("../includes/vinuni_map/vinuni_gis_osm_bound.shp");
	file shape_file_boundary <- file("../includes/vinuni_map/vinuni_gis_osm_boundary.shp");

	geometry shape <- envelope(shape_file_boundary);
    
	float step <- 5 #mn;
	
	date starting_date <- date("2023-11-01-00-00-00");
	
	int nb_car <- 40;
    int min_work_start <- 8;
    int max_work_start <- 10;
    int min_work_end <- 17; 
    int max_work_end <- 19; 
    float min_speed <- 1 #km / #h;
    float max_speed <- 5 #km / #h; 
    graph the_graph;
	
	init {
		create chargingAreas from: shape_file_chargingareas with: [type::string(read ("fclass"))] {
			if type="C_parking" {
				color <- #yellow ;
			}
		}
		
		create residential from: shape_file_residential ;
		
		create vinuniBound from: shape_file_vinuni_bounds ;
		create boundary from: shape_file_boundary ;
		create building from: shape_file_buildings ;

		create road from: shape_file_roads ;
		the_graph <- as_edge_graph(road);
		
		list<residential> residential_area <- residential where (true);
		list<chargingAreas> vinuni_parking <- chargingAreas where (true);
		create car number: nb_car {
		    speed <- rnd(min_speed, max_speed);
		    start_work <- rnd (min_work_start, max_work_start);
		    end_work <- rnd(min_work_end, max_work_end);
			parking <- one_of(vinuni_parking);
            home <- one_of(residential_area) ;
            parking_obj <- "outside_vinuni";
            location <- any_location_in(home); 
       }
	}
}

species residential {
	rgb residential_color <- rgb( 76, 60, 19 );
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

species car skills: [moving] {
	rgb color <- #red ;
	chargingAreas parking <- nil;
    residential home <- nil;
    int start_work ;
    int end_work  ;
    string parking_obj ; 
    point the_target <- nil ;

    reflex time_to_work when: current_date.hour = start_work and parking_obj = "outside_vinuni" {
    	parking_obj <- "inside_vinuni" ;
		the_target <- any_location_in (parking);
    }
    
    reflex time_to_go_home when: current_date.hour = end_work and parking_obj =  "inside_vinuni" {
        parking_obj <- "outside_vinuni" ;
		the_target <- any_location_in (home); 
    }
     
    reflex move when: the_target != nil {
		do goto target: the_target on: the_graph ; 
		if the_target = location {
	    	the_target <- nil ;
		}
    }
    
	aspect base {
		draw circle(5) color: color border: #black;
	}
}

experiment vinuni_traffic type: gui {
//	parameter "Shapefile for the charging stations:" var: shape_file_charging_areas category: "GIS" ;
	parameter "Number of car agents" var: nb_car category: "Car" ;
	parameter "Earliest hour to start work" var: min_work_start category: "People" min: 2 max: 8;
    parameter "Latest hour to start work" var: max_work_start category: "People" min: 8 max: 12;
    parameter "Earliest hour to end work" var: min_work_end category: "People" min: 12 max: 16;
    parameter "Latest hour to end work" var: max_work_end category: "People" min: 16 max: 23;
    parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
    parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
	
	output {
		display vinuni_display type:3d {
			species vinuniBound aspect: base;			
			species building aspect: base;
			species residential aspect: base ;
			species chargingAreas aspect: base ;
			species road aspect: base ;
			species car aspect: base ;
		}
	}
}