/**
* Name: vinuniCS
* Based on the internal empty template. 
* Author: linhdo
* Tags: 
*/


model vinuniCS

/* Insert your model definition here */

global {
	file shape_file_charging_areas <- file("../includes/vinuni_map/vinuni_gis_osm_chargingareas.shp");
	file shape_file_buildings <- file("../includes/vinuni_map/vinuni_gis_osm_buildings.shp");
	file shape_file_roads <- file("../includes/vinuni_map/vinuni_gis_osm_road.shp");
	file shape_file_traffic <- file("../includes/vinuni_map/vinuni_gis_osm_traffic.shp");
	file shape_file_bounds <- file("../includes/vinuni_map/vinuni_gis_osm_bound.shp");
	geometry shape <- envelope(shape_file_roads, shape_file_bounds);
    
	float step <- 5 #mn;
	int nb_car <- 40;
	
	date starting_date <- date("2019-09-01-00-00-00");
    int min_work_start <- 8;
    int max_work_start <- 10;
    int min_work_end <- 17; 
    int max_work_end <- 19; 
    float min_speed <- 10 #km / #h;
    float max_speed <- 40 #km / #h; 
    graph the_graph;
	
	init {
		create charging_area from: shape_file_charging_areas with: [type::string(read ("fclass"))] {
			if type="C_parking" {
				color <- #yellow ;
			}
		}
		create road from: shape_file_roads with: [type::string(read ("fclass"))] {
			if type="carway" {
				color <- #purple ;
			} else if type="outside" {
				color <- #blue ;
			}
		}
		the_graph <- as_edge_graph(road);
		
		create bound from: shape_file_bounds ;
		create building from: shape_file_buildings ;
		
		list<charging_area> parking_area <- charging_area where (each.type="C_parking");
		list<road> road_inside <- road where (each.type="carway") ;
        list<road> road_outside <- road where (each.type="outside") ;
		create car number: nb_car {
		    speed <- rnd(min_speed, max_speed);
		    start_work <- rnd (min_work_start, max_work_start);
		    end_work <- rnd(min_work_end, max_work_end);
//            vinuni <- one_of(road_inside + road_inside) ;
			target <- one_of(parking_area);
            home <- one_of(road_outside + road_inside) ;
            parking_obj <- "outside_vinuni";
            location <- any_location_in(home); 
       }
	}
}

species building {
	rgb building_color <- rgb(72, 175, 231);
	aspect base {
		draw shape color: building_color border: #black ;
	}
}

species bound {
	rgb bound_color <- rgb(103, 174, 115);
	aspect base {
		draw shape color: bound_color border: #black ;
	}
}

species charging_area {
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
//    road vinuni <- nil ;
	charging_area target <- nil;
    road home <- nil;
    int start_work ;
    int end_work  ;
    string parking_obj ; 
    point the_target <- nil ;

    reflex time_to_work when: current_date.hour = start_work and parking_obj = "outside_vinuni" {
    		parking_obj <- "inside_vinuni" ;
			the_target <- any_location_in (target);
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
			species bound aspect: base;
			species building aspect: base;
			species charging_area aspect: base ;
			species road aspect: base ;
			species car aspect: base ;
		}
	}
}