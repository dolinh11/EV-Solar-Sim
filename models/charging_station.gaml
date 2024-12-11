/**
* Name: chargingstation
* Based on the internal empty template. 
* Author: linhdo
* Tags: 
*/


model chargingstation

global {
	// Chargingn station-related global variables
	int nb_activeCS_Cparking <- 20;
	int nb_activeCS_Jparking <- 15;
	int nb_activeCS_Cparking_fast <- 2;
	int nb_activeCS_Jparking_fast <- 4;
	int nb_activeCS_gasoline_used;
	int nb_activesCS_electric_used;
	int nb_activesCS_electric_charging;
	int nb_activeCS_used;

		
	// Road-related global variables
	graph the_graphA;
	graph the_graph_inside;
	graph the_graph_outside;
	
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