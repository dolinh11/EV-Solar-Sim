/**
* Name: directionalroad
* Based on the internal empty template. 
* Author: linhdo
* Tags: 
*/


model directionalroad

/* Insert your model definition here */


global {
	file road_file <- file("../includes/vinuni_map/vinuni_gis_osm_carway_clean_v1.shp");
	geometry shape <- envelope(road_file);
	graph the_graph; 
	
	init {
		create road from: road_file with:[direction::int(read("direction"))] {
			switch direction {
				match 0 {color <- #green;}
				match 1 {color <- #red;
					//inversion of the road geometry
					shape <- polyline(reverse(shape.points));
				}
				match 2 {color <- #blue;
					//bidirectional: creation of the inverse road
					create road {
						shape <- polyline(reverse(myself.shape.points));
						direction <- 2;
						color <- #blue;
					}
				} 
			}
		}
		//The operator directed modify the graph created by as_edge_graph(road) to a directed graph
		the_graph <- directed(as_edge_graph(road)) ;
		
		
		create people number: 300 {
			//The operator any_location_in returns a random point located in one of the road agents
			target <- any_location_in(one_of (road)) ;
			location <- any_location_in (one_of(road));
		} 
	}
}

species road {
	int direction;
	rgb color;
	aspect geom {
		draw shape color: color;
	}
}
//The people agents use the skill moving which have built-in variables such as speed, target, location, heading and built-in operators
species people skills: [moving] {
	point target;
	path my_path; 
	aspect circle {
		draw circle(3) color: #green;
	}
	
	reflex movement {
		
		//The operator goto is a built-in operator derivated from the moving skill, moving the agent from its location to its target, 
		//   restricted by the on variable, with the speed and returning the path followed
		my_path <- goto(on:the_graph, target:target, speed:10.0, return_path: true);
		
		//If the agent arrived to its target location, then it choose randomly an other target on the road
		if (target = location) {			
			target <- any_location_in(one_of (road)) ;
		}
	}
}

experiment simplemodel type: gui {
	output {
		display map {
			species road aspect: geom;
			species people aspect: circle;
		}
	}
}
