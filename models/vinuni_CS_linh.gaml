model vinuniCS


global {
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
	
	int nb_electrical <- 12;
	int nb_gasoline <- 30; //28
	
	int min_work_start_1 <- 8;
	int max_work_start_1 <- 9;
	int min_work_start_2 <- 12;
	int max_work_start_2 <- 14;
	int min_work_end_1 <- 11;
	int max_work_end_1 <- 15;
	int min_work_end_2 <- 17;
	int max_work_end_2 <- 19;
	float min_speed <- 8 #km / #h;
	float max_speed <- 10 #km / #h;
	
	graph the_graphA;
	graph the_graph_inside;
	graph the_graph_outside;
	
	int nb_activeCS_Cparking <- 6;
	int nb_activeCS_Jparking <- 6;
	int nb_activeCS_Cparking_fast <- 0;
	int nb_activeCS_Jparking_fast <- 2;
//	int nb_activeCS_slow_used;
//	int nb_activeCS_fast_used;
	int nb_activeCS_gasoline_used;
	int nb_activesCS_electric_used;
	int nb_activesCS_electric_charging;
	int nb_activeCS_used;
//	int nb_activeCS_used_test;

	float  occupancy_rate;
	float useful_occupancy_rate_1;
	float useful_occupancy_rate_2;
	
	// Chia thành daily và monthly
	float daily_revenue <- 0.0;
	float daily_profit <- 0.0;
	float daily_cost;
	float total_energy_EVs <- 0.0;
	
	float monthly_revenue <- 0.0;
	float monthly_profit <- 0.0;
	float monthly_cost;
	
	float energy_consumption <- 0.0;
	float monthly_energy_consumption <- 0.0;
	
	int nbEV_charged_statisfied;
	int nbEV_uncharged_unsatisfied;
	float percentage_statisfied;
	float total_statisfied_day;
	float avg_statisfied_day;	
	int total_statisfied_cycle;
	
	bool policy_prohibit_parking <- false; //prohibit gasoline cars from parking in active_CS slot
	bool policy_force_moving <- false; //force EVs to move to inactive parking slot when fully charged
	
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
	}
	
	//indicator 1: average percent of daily charged EV
	reflex calculate_percentage_statisfied {
		nbEV_charged_statisfied <- length(car_electrical where (each.time_to_charge > 0 and each.parking_slot = "active_CS" and each.satisfied = true));
		nbEV_uncharged_unsatisfied <- length(car_electrical where (each.parking_slot = "inactive_CS" and each.satisfied = false));
		if (nbEV_charged_statisfied + nbEV_uncharged_unsatisfied) != 0 {
			percentage_statisfied <- nbEV_charged_statisfied / (nbEV_charged_statisfied + nbEV_uncharged_unsatisfied);
			total_statisfied_cycle <- total_statisfied_cycle + 1;
		} else {
			percentage_statisfied <- 0.0;
		}

		total_statisfied_day <- total_statisfied_day + percentage_statisfied;
	}
	
	reflex calculate_avg_statisfied when: (current_date.hour = 23 and current_date.minute = 50) {
		if total_statisfied_cycle != 0 {
			avg_statisfied_day <- total_statisfied_day / total_statisfied_cycle;
		} else {
			avg_statisfied_day <- 0.0;
		}
		total_statisfied_day <- 0.0;
		total_statisfied_cycle <- 0;
	}
	
//	// indicator 2: monthly energy consumption
//	reflex calculate_energy {
//		nb_activeCS_gasoline_used <- length(car_gasoline where (each.parking_slot = "active_CS"));
//		nb_activeCS_fast_used <- (nb_activeCS_Cparking_fast - chargingAreas[0].activeCS_fast) + (nb_activeCS_Jparking_fast - chargingAreas[1].activeCS_fast);
//		nb_activeCS_slow_used <- (nb_activeCS_Cparking - chargingAreas[0].active_CS) + (nb_activeCS_Jparking - chargingAreas[1].active_CS) - nb_activeCS_fast_used - nb_activeCS_gasoline_used;
//		energy_consumption <- (5/60) * ((nb_activeCS_slow_used * 11) + (nb_activeCS_fast_used * 30)); 
//	}

	// indicator 2: occupancy rate số trạm sạc active đang dùng/tổng số trạm (hoặc tổng số active)
	reflex calculate_energy {
		nb_activeCS_gasoline_used <- length(car_gasoline where (each.parking_slot = "active_CS"));
		nb_activesCS_electric_used <- length(car_electrical where (each.parking_slot = "active_CS"));
		nb_activeCS_used <- nb_activeCS_gasoline_used + nb_activesCS_electric_used;
//		nb_activeCS_used_test <- (nb_activeCS_Cparking + nb_activeCS_Jparking) - (chargingAreas[0].active_CS + chargingAreas[1].active_CS);
		
		occupancy_rate <- nb_activeCS_used / (nb_activeCS_Cparking + nb_activeCS_Jparking);
		
	// Nếu chỉ tính số trạm sạc có xe điện đỗ vào là useful (kể cả khi xe sạc đầy rồi nhưng vẫn đỗ)
		useful_occupancy_rate_1 <- nb_activesCS_electric_used / (nb_activeCS_Cparking + nb_activeCS_Jparking);
		
	// Nếu xét strict hơn là trạm sạc có xe điện đỗ và đang sạc (nghĩa là ko tính xe đã sạc đầy)
		nb_activesCS_electric_charging <- length(car_electrical where (each.parking_slot = "active_CS" and each.is_charging = true));
		useful_occupancy_rate_2 <- nb_activesCS_electric_charging / (nb_activeCS_Cparking + nb_activeCS_Jparking);
	}

	//indicator 3: monthly revenue and profit
	reflex calculate_daily_profit when: (current_date.hour = 23 and current_date.minute = 50){
		daily_revenue <- total_energy_EVs * 3355;
		daily_cost <- total_energy_EVs * 2049 + (nb_activeCS_Cparking + nb_activeCS_Jparking) * 500000 / 30;
		daily_profit <- daily_revenue - daily_cost;
		monthly_energy_consumption <- 22*total_energy_EVs;
		total_energy_EVs <- 0.0;
	}
	
	reflex calculate_monthly_profit when: (current_date.hour = 23 and current_date.minute = 50){
		monthly_revenue <- 22*daily_revenue;
		monthly_cost <- 22*daily_cost;
		monthly_profit <- 22*daily_profit;
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

		//Select parking area with P(C_parking) = 0.9
		if flip(0.9) {
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
	bool move_slot <- false;
	
	//Check this probability again
	bool priority_fast <- flip(0.4) ? true : false; 
	
	int num_checkSlot <- 0;
	float SoC <- 20.0 +rnd(70);  //battery level
	string EV_model; //type of EV
	float chargingRate_slow; // charging rate of EV at AC 11kW
	float chargingRate_fast; // charging rate of EV at AC 30kW
	float energy;
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
				energy <- 11 * (time_to_charge / 60);
			} else if charging_mode = "fast" {
				energy <- 30 * (time_to_charge / 60);
			}
			total_energy_EVs <- total_energy_EVs + energy;
			done_charging <- true;
			is_charging <- false;
		}
	}
	
	reflex move_to_inactive when: done_charging and in_parkingArea and not move_slot{
		do change_slot;
	}
	
	action change_slot {
		if policy_force_moving {
			parking_slot <- "inactive_CS";
			parking_area.active_CS <- parking_area.active_CS + 1;
			if charging_mode = "fast" {
				parking_area.activeCS_fast <- parking_area.activeCS_fast + 1;
			}
		}
		move_slot <- true;
	}
	
	action reset {
		SoC <- 20.0 + rnd(70);
		time_to_charge <- 0 #mn;
		done_charging <- false;
		energy <- 0.0;
		satisfied <- true;
		move_slot <- false;
		num_checkSlot <- 0;
	}
}
//Experiment to show how to make multi simulations
experiment alter2_effectiveness type: gui {
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" <- 30;
	init {
		create simulation with: [policy_prohibit_parking :: true, policy_force_moving :: false];
		create simulation with: [policy_prohibit_parking :: false, policy_force_moving :: true];
		create simulation with: [policy_prohibit_parking :: true, policy_force_moving :: true];
		//create vinuniCS_model with: [nb_electrical::30, nb_gasoline::28];
	}
	permanent {
		display Comparison refresh: every(288 #cycle) {
			chart "Avg Percent of charged EV" type: series {
				loop s over: simulations  {
					data "Case " + int(s) + ": policy 1: " + s.policy_prohibit_parking + ", policy 2: " + s.policy_force_moving value: 100*s.avg_statisfied_day marker: true style: line thickness: 3;
				}
			}
		}
//		display Comparison2 refresh: every(288 #cycle){
//			chart "Avg Percent of charged EV" type: series {
//				loop m over: [vinuniCS_model[2],vinuniCS_model[3]]  {
//					data "Case " + int(m) + ": policy 1: " + m.policy_prohibit_parking + ", policy 2: " + m.policy_force_moving value: 100*m.avg_statisfied_day marker: true style: line thickness: 3;
//				}
//			}
//		}
	}
	reflex column_name when: (cycle = 286){
		save ["Cycle", "Current date", "Case 0", "Case 1", "Case 2", "Case 3"] 
			to: "Results/multi_case_avg_percent.csv" format:"csv" rewrite: (cycle = 286) ? true : false header: false;	
	}
	reflex export_value when: (current_date.hour = 23 and current_date.minute = 55) {	
		list combinedResults <- [cycle, current_date];
		loop s over: simulations{
			ask s {
				combinedResults <- combinedResults + [100*s.avg_statisfied_day];
			}
		}
		save combinedResults 
			to: "Results/multi_case_avg_percent.csv" format:"csv" rewrite: false header: false;
		}		
}

experiment Sobol type: batch until:(current_date.hour = 23 and current_date.minute = 55) repeat: 20 parallel: 20 {
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" min:10 max:60 step:2;
	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car" min:35 max:80 step:2;
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking" min:6 max:30 step:2;
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "J_parking" min:6 max:30 step:2;
	parameter "Implement a policy prohibiting gasoline cars from parking in active_CS" var: policy_prohibit_parking category: "Policies" min:false max:true;
	parameter "Implement a policy forcing EVs to move to inactive parking slot when fully charged" var: policy_force_moving category: "Policies" min:false max:true;
	method sobol outputs:["avg_statisfied_day","monthly_energy_consumption","monthly_profit"] sample:1000 report:"Results/sobol.txt" results:"Results/sobol_raw.csv";
}

experiment replication_analysis type: batch until: (current_date.hour = 23 and current_date.minute = 55)  
	repeat:50 keep_simulations:false parallel: 10 {
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" min:10 max:10 step:1;
//	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car" min:30 max:60 step:2;
//	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking" min:6 max:29 step:1;
//	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "J_parking" min:6 max:27 step:1;
//	parameter "Implement a policy prohibiting gasoline cars from parking in active_CS" var: policy_prohibit_parking category: "Policies" min:false max:true;
//	parameter "Implement a policy forcing EVs to move to inactive parking slot when fully charged" var: policy_force_moving category: "Policies" min:false max:true;
	method stochanalyse outputs:["avg_statisfied_day","monthly_energy_consumption"] report:"Results/stochanalysis.txt" results:"Results/stochanalysis_raw.csv" sample:100;
} 
experiment indicator1_exploration type: batch until: (cycle=287) repeat: 10000 parallel: 10 {
	
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" min:10 max:10 step:1;
//	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car" min:30 max:80 step:2;
//	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking" min:6 max:30 step:2;
//	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "J_parking" min:6 max:30 step:2;
//	parameter "Implement a policy prohibiting gasoline cars from parking in active_CS" var: policy_prohibit_parking category: "Policies" <- true;
//	parameter "Implement a policy forcing EVs to move to inactive parking slot when fully charged" var: policy_force_moving category: "Policies" min:0 max:1;
	method exploration; 
	reflex save_results_explo {
		ask simulations {
			save [int(self),current_date, self.nb_electrical, self.nb_gasoline,self.nb_activeCS_Cparking, self. nb_activeCS_Jparking ,self. policy_prohibit_parking, self.policy_force_moving, self.avg_statisfied_day] 
		   		to: "Results/exploration_indicator1.csv" format:"csv" rewrite: (int(self) = 0) ? true : false header: true;
		}		
	}
	//the permanent section allows to define a output section that will be kept during all the batch experiment
//	permanent {
//		display charged_EV_percent  type: 2d {
//			chart "Percent of charged vehicle" type: series {
//				data "Mean Charged & Satisfied percent" value: mean(simulations collect each.avg_statisfied_day) marker: true style: line color: #blue;
//				data "Min Charged & Satisfied percent" value: min(simulations collect each.avg_statisfied_day) marker: true style: line color: #black;
//				data "Max Charged & Satisfied percent" value: max(simulations collect each.avg_statisfied_day) marker: true style: line color: #purple;
//			}	
//		}
//	}
//	permanent {
//		display charged_EV_percent  type: 2d {
//			chart "Percent of daily charged vehicle (%)" type: xy x_label: "Number of electric cars"{
//				data "Mean Charged & Satisfied percent" value: {nb_electrical, 100*mean(simulations collect each.avg_statisfied_day)} marker: true style: line color: #blue;
//				data "Min Charged & Satisfied percent" value: {nb_electrical, 100*min(simulations collect each.avg_statisfied_day)} marker: true style: line color: #black;
//				data "Max Charged & Satisfied percent" value: {nb_electrical, 100*max(simulations collect each.avg_statisfied_day)} marker: true style: line color: #purple;
//			}	
//		}	
//	}
}
experiment indicator2_exploration type: batch until: (current_date.day = 30 and current_date.hour = 23 and current_date.minute = 55) repeat: 10  {
	
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" min:10 max:60 step:2;
	method exploration; 
	permanent {
		display charged_EV_percent  type: 2d {
			chart "Mean Monthly Energy Consumption (in kWh)" type: xy x_label: "Number of electric cars"{
				data "Mean Monthly energy consumption" value: {nb_electrical, mean(simulations collect each.monthly_energy_consumption)} marker: true style: line color: #black thickness:4;
			}	
		}	
	}
}
experiment indicator3_exploration type: batch until: (current_date.day = 30 and current_date.hour = 23 and current_date.minute = 55) repeat: 5  {
	
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" min:10 max:60 step:2;
	method exploration; 
	permanent {
		display charged_EV_percent  type: 2d {
			chart "Mean Monthly Revenue and Profit (in VND)" type: xy x_label: "Number of electric cars"{
				data "Mean Monthly Revenue" value: {nb_electrical, mean(simulations collect each.monthly_revenue)} marker: true style: line color: #blue thickness:4;
				data "Mean Monthly Profit" value: {nb_electrical, mean(simulations collect each.monthly_profit)} marker: true style: line color: #red thickness:4;
			}	
		}	
	}
}
experiment alter_1_indi_1_effectiveness type: gui {
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" <- 30;
	init {
		create simulation with: [nb_activeCS_Cparking::10, nb_activeCS_Jparking::6];
		create simulation with: [nb_activeCS_Cparking::6, nb_activeCS_Jparking::10];
		create simulation with: [nb_activeCS_Cparking::10, nb_activeCS_Jparking::10];
		create simulation with: [nb_activeCS_Cparking::20, nb_activeCS_Jparking::20];
	}
	permanent {
		display Comparison refresh: every(288 #cycle) {
			chart "Avg Percent of charged EV" type: series {
				loop s over: simulations  {
					data "C: " + s.nb_activeCS_Cparking + ", J: " + s.nb_activeCS_Jparking value: 100*s.avg_statisfied_day marker: true style: line thickness: 3;
				}
			}
		}
	}		
}
experiment alter1_indi1_exploration type: batch until: (cycle=287) repeat: 30 parallel: 10 {
	
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" min:10 max:50 step:5;
//	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car" min:30 max:80 step:2;
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking" min:6 max:30 step:2;
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "J_parking" min:6 max:30 step:2;
//	parameter "Implement a policy prohibiting gasoline cars from parking in active_CS" var: policy_prohibit_parking category: "Policies" <- true;
//	parameter "Implement a policy forcing EVs to move to inactive parking slot when fully charged" var: policy_force_moving category: "Policies" min:0 max:1;
	method exploration; 
	reflex save_results_explo {
		ask simulations {
			save [int(self),current_date, self.nb_electrical, self.nb_gasoline,self.nb_activeCS_Cparking, self. nb_activeCS_Jparking ,self. policy_prohibit_parking, self.policy_force_moving, self.avg_statisfied_day] 
		   		to: "Results/exploration_alter1_indi1_CJ.csv" format:"csv" rewrite: (int(self) = 0) ? true : false header: true;
		}		
	}
}
experiment alter2_exploration type: batch until: (cycle=287) repeat: 10 parallel: 10 {
	
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" min:10 max:50 step:20;
	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car" <- 30;
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking" min:6 max:30 step:2;
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "J_parking" min:6 max:30 step:2;
	parameter "Implement a policy prohibiting gasoline cars from parking in active_CS" var: policy_prohibit_parking category: "Policies" <- false;
	parameter "Implement a policy forcing EVs to move to inactive parking slot when fully charged" var: policy_force_moving category: "Policies" <- false;
	method exploration; 
	reflex save_results_explo {
		ask simulations {
			save [int(self),current_date, self.nb_electrical, self.nb_gasoline,self.nb_activeCS_Cparking, self. nb_activeCS_Jparking ,self. policy_prohibit_parking, self.policy_force_moving, self.avg_statisfied_day,self.monthly_energy_consumption, self.monthly_profit] 
		   		to: "Results/exploration_alter2_False_False.csv" format:"csv" rewrite: (int(self) = 0) ? true : false header: true;
		}		
	}
}
experiment alter2_sobol type: batch until:(cycle=287) repeat: 30 parallel: 20 {
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" min:10 max:50 step:2;
	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car" <- 30;
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking" <- 6;
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "J_parking" <- 6;
	parameter "Implement a policy prohibiting gasoline cars from parking in active_CS" var: policy_prohibit_parking category: "Policies" min:false max:true;
	parameter "Implement a policy forcing EVs to move to inactive parking slot when fully charged" var: policy_force_moving category: "Policies" min:false max:true;
	method sobol outputs:["avg_statisfied_day","monthly_energy_consumption","monthly_profit"] sample:1000 report:"Results/sobol_alter2.txt" results:"Results/exploration_alter2.csv";
}

experiment vinuni_traffic type: gui {
	parameter "Number of gasoline car agents" var: nb_gasoline category: "No. Car";
	parameter "Number of electric car agents" var: nb_electrical category: "No. Car" <- 20;
	parameter "Number of active charging stations at Building C" var: nb_activeCS_Cparking category: "No. Active Charrging Stations";
	parameter "Number of active charging stations at Building J" var: nb_activeCS_Jparking category: "No. Active Charrging Stations";
	parameter "Number of fast charging stations at Building C" var: nb_activeCS_Cparking_fast category: "No. Active Charrging Stations";
	parameter "Number of fast charging stations at Building J" var: nb_activeCS_Jparking_fast category: "No. Active Charrging Stations";
	parameter "Policy Level 1: Banning gasoline cars from occupying active charging stations" var: policy_prohibit_parking category: "Policies";
	parameter "Policy Level 2: Requiring EVs to relocate to inactive charging stations once fully charged" var: policy_force_moving category: "Policies";

	reflex save_result_avg_satisfied_percent when: (current_date.hour = 23 and current_date.minute = 55) {
		save [nb_gasoline, nb_electrical, cycle, current_date, avg_statisfied_day] 
	   		to: "Results/avg_percentage_statisfied.csv"  format:"csv" rewrite: (cycle = 287) ? true : false;
	}
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

//		display time_to_charge refresh: every(12 #cycles) {
//////		//			chart "datalist_bar" type: histogram series_label_position: onchart {
//////		//				datalist legend: ["Average Time to charge","Number of Not charged" ] style: bar value:
//////		//				[mean(car_electrical collect each.time_to_charge),/*100] color: [#green,#red ];
//////		//			}
//			chart "Number of charged vehicle" type: histogram style: stack  {
//				data "Charged & Satisfied" accumulate_values: true value: nbEV_charged_statisfied color: #blue;
//				data "Not Charged & Unsatisfied" accumulate_values: true value: nbEV_uncharged_unsatisfied color: #yellow;
//			}
//		}
		
		display percentage_statisfied type: 2d {
			chart "Indicator 1: EV Charging Rate (%)" type: series memorize: false x_serie_labels: current_date.hour {
				data "Percentage of EV satisfied" value: 100*percentage_statisfied color: #blue marker: false style: line;
			}
		}
		
//		display avg_daily_charged_EVs type: 2d refresh: (current_date.hour = 23 and current_date.minute = 55){ //plot at 23:55 each day
//			chart "Daily EV Charging Rate (%)" type: series memorize: false x_label: "Day" {
//				data "Average daily charged EVs percent" value: 100*avg_statisfied_day color: #blue marker: true;
//			}
//		}
		
//		display occupancy_rate type: 2d refresh: every(12 #cycles){
//			chart "Occupancy Rate" type: pie style: exploded size: {0.5, 1} position: {0.5, 0} {
//				data "Being used" value: occupancy_rate color: #magenta;
//				data "Available" value: (1-occupancy_rate) color: #blue;
//			}
//
//			chart "Useful Occupancy Rate" type: pie style: exploded size: {0.5, 1} position: {0, 0} {
//				data "Being used" value: useful_occupancy_rate_1 color: #magenta;
//				data "Available" value: (1-useful_occupancy_rate_1) color: #blue;
//			}
//			chart "Useful Occupancy Rate over time" type: series {
//				data "Charging port occupancy rate" value: useful_occupancy_rate_1;
//			}
//		}

//		display Revenue_Profit type: 2d  refresh: (current_date.hour = 23 and current_date.minute = 55){ 
//			chart "Monthly Revenue & Profit (in VND)" type: series memorize: false x_label: "Month"{
//				data "Total monthly revenue" value: monthly_revenue color: #black marker: true;
//				data "Total monthly cost" value: monthly_cost color: #red marker: true;
//				data "Total monthly profit" value: monthly_profit color: #blue marker: true;
//			}
//		}
//		
//		display monthly_energy_consumption type: 2d refresh: (current_date.hour = 23 and current_date.minute = 55) {
//			chart "Monthly Electric Energy Consumption (kWh)" type: series memorize: false x_label: "Month" {
//				data "monthly_energy_consumption (kWh)" value: monthly_energy_consumption color: #black marker: true style: line;
//			}
//		} 

//		display chart_display refresh: every(12 #cycles) type: 2d {
//			chart "Gasoline Car Position" type: pie style: exploded size: {0.5, 1} position: {0.5, 0} {
//				data "Inside VinUni" value: car_gasoline count (each.moving_obj = "working") color: #magenta;
//				data "Outside VinUni" value: car_gasoline count (each.moving_obj = "resting") color: #blue;
//			}
//
//			chart "Electrical Car Position" type: pie style: exploded size: {0.5, 1} position: {0, 0} {
//				data "Inside VinUni" value: car_electrical count (each.moving_obj = "working") color: #magenta;
//				data "Outside VinUni" value: car_electrical count (each.moving_obj = "resting") color: #blue;
//			}
//		}

//		display series type: 2d {
//			chart "Number of Active Charging Stations Available" type: series x_label: "#points to draw at each step" memorize: false x_serie_labels: current_date.hour {
//				data "Slots at C_parking" value: chargingAreas[0].active_CS color: #blue marker: false style: line;
//				data "Slots at J_parking" value: chargingAreas[1].active_CS color: #red marker: false style: line;
//			}
//		}
	}
}

experiment explo type:batch until:cycle=287 repeat:32 parallel:16 keep_seed: true {
	
	parameter "nb_actveCS at C" var:nb_activeCS_Cparking min:7 max:13;
	parameter "nb_EVs" var:nb_electrical min:10 max:40  step: 5;

	method exploration;
	
	permanent {
		display Comparison background: #white {
			chart "Percentage of satisfied EV" type: xy {
				data "No. active charging stations at building C"  value:{nb_activeCS_Cparking, simulations mean_of (each.avg_statisfied_day)} ;
			}
		}
	}
}