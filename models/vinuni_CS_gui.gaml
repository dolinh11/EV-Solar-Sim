/**
* Name: vinuniCS
* Based on the internal empty template. 
* Author: linhdo, truongnguyen
* Tags: 
*/
/**
* Name: vinuniCS
* Based on the internal empty template. 
* Author: linhdo
* Tags: 
*/
model vinuniCS

/* Insert your model definition here */
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
	date starting_date <- date("2024-01-01 00:00:00");
	
//	file energy_realtime <- csv_file("../includes/average_by_time_data.csv",",");
	file energy_realtime <- csv_file("../includes/energy_data.csv",",");

	
	init {
		//convert the file into a matrix
		matrix data <- matrix(energy_realtime);
		//loop on the matrix rows (skip the first header line)
		loop i from: 1 to: data.rows -1{
			//loop on the matrix columns
			loop j from: 0 to: data.columns -1{
				write "data rows:"+ i +" colums:" + j + " = " + data[j,i];
			}	
		}		
	}
	
	reflex update_values_from_csv {
    // Kiểm tra xem current_row có nằm trong phạm vi ma trận không
	    if (current_row < data.rows) {
	        // Lặp qua tất cả các cá thể của solar_energy và cập nhật giá trị
	        loop solar over: solar_energy {
				solar.air_temp <- data[0, current_row];	
				solar.solar_ghi <- data[1, current_row];	
			}
	        // Lặp qua tất cả các cá thể của wind_energy và cập nhật giá trị
	        loop wind over: wind_energy {
				wind.wind_speed <- data[2, current_row];	
			}
	        
	        // Cập nhật chỉ số dòng cho lần tiếp theo
	        current_row <- current_row + 1;
	    } else {
	        write "End of data reached";
	    }
	}

	// Energy Real-time data
	int current_row <- 0;
	matrix data <- matrix(energy_realtime);

	// Vehicle-related global variables
	int nb_electrical <- 12;
	int nb_gasoline <- 30; //28
	int min_work_start_1 <- 8;
	int max_work_start_1 <- 9;
	int min_work_start_2 <- 12;
	int max_work_start_2 <- 14;
	int min_work_end_2 <- 17;
	int max_work_end_2 <- 19;
	float min_speed <- 8 #km / #h;
	float max_speed <- 10 #km / #h;
	
	// Road-related global variables
	graph the_graphA;
	graph the_graph_inside;
	graph the_graph_outside;
	
	// Chargingn station-related global variables
	int nb_activeCS_Cparking <- 7;
	int nb_activeCS_Jparking <- 6;
	int nb_activeCS_Cparking_fast <- 0;
	int nb_activeCS_Jparking_fast <- 2;
	int nb_activeCS_gasoline_used;
	int nb_activesCS_electric_used;
	int nb_activesCS_electric_charging;
	int nb_activeCS_used;
	float occupancy_rate;
	float useful_occupancy_rate_1;
	float useful_occupancy_rate_2;
	
	//Polices
	bool policy_prohibit_parking <- false; //prohibit gasoline cars from parking in active_CS slot
	bool policy_force_moving <- false; //force EVs to move to inactive parking slot when fully charged
		
	//Charging demand varables
	int nbEV_charged_statisfied;
	int nbEV_uncharged_unsatisfied;
	float percentage_statisfied;
	float total_statisfied_day;
	float avg_statisfied_day;
	int total_statisfied_cycle;
	
	// Cost&Profit-related variables; computed daily & monthly
	float daily_revenue <- 0.0;
	float daily_profit <- 0.0;
	float daily_cost;
	float monthly_revenue <- 0.0;
	float monthly_profit <- 0.0;
	float monthly_cost;
	
	// Energy-related variables
	bool add_solar <- true; 
	int nb_solar <- 30;
	bool add_wind <- true;
	int nb_wind <- 4;
	int nb_bess <- 1;

    // Energy Consumption 
	float total_energy_EVs <- 0.0;
	float energy_consumption <- 0.0;
	float monthly_energy_consumption <- 0.0;
	float self_consumption;
	float self_sufficiency;
	float monthly_renew_energy;
	
	// total renewable energy generate
	float total_renew_energy <- 0.0;
	float total_solar_energy <- 0.0;
	float total_wind_energy <- 0.0;
	
	float renew_energy_generated;
	float solar_energy_generated;
	float wind_energy_generated;
	
	float charge_by_renew;
	float charge_by_bess;
	float charge_by_grid;
	
	float cumulative_energy_from_grid <- 0;
	float cumulative_energy_from_bess <- 0;
	float cumulative_energy_from_renew <- 0;
	float cycle_count <- 0;
	
	float energy_from_renew <- 0;
    float energy_from_bess <- 0;
    float energy_from_grid <- 0;
	
	
	// Renewable Energy Cost variable
	float solar_cost;
	float wind_cost;
	float renew_invest_cost;
	float payback_process;
	float payback_period;
	float monthly_renew_charge;
	float daily_renew_charge;
	
	float solar_capex_unit <- 18000000; // 18tr VND/ 1kWp
	float solar_opex <- 600000; // 600k
	float solar_capex;
	
	float wind_capex_unit <- 76000000; //  76tr VND/ 3kWh
	float wind_opex <- 1200000; // 1tr2
	float wind_capex;
	
	// BESS 
	float bess_capacity <- 80000;
	float bess_SoC <- 0;

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
		create solar_energy number: nb_solar;
		create wind_energy number: nb_wind;
		
		solar_capex <- solar_capex_unit * nb_solar * 0.61;
		solar_cost <- solar_capex + solar_opex;
		
		wind_capex <- wind_capex_unit * nb_wind;
		wind_cost <- wind_capex + wind_opex;
		
		payback_process <- solar_cost + wind_cost;
	}
	
	reflex cal_cumulative_energy {
		if cycle_count < 12 {
	    	cumulative_energy_from_grid <- cumulative_energy_from_grid + energy_from_grid;
	    	cumulative_energy_from_bess <- cumulative_energy_from_bess + energy_from_bess;
	    	cumulative_energy_from_renew <- cumulative_energy_from_renew + energy_from_renew;
	    	
	    	energy_from_renew <- 0;
    		energy_from_bess <- 0;
    		energy_from_grid <- 0;
	    	
	    	cycle_count <- cycle_count + 1;     
       } else if cycle_count = 12 {
	        // Reset cumulative values
	        cumulative_energy_from_grid <- 0;
	        cumulative_energy_from_bess <- 0;
	        cumulative_energy_from_renew <- 0;

	        // Reset cycle count
	        cycle_count <- 0;
        }
   }
	
	reflex update_bess_SoC {
        // Check if no car is charging and bess_SoC is below capacity
        if every(car_electrical where (each.is_charging = false)) and bess_SoC < bess_capacity {
            bess_SoC <- bess_SoC + renew_energy_generated;
            bess_SoC <- min(bess_SoC, bess_capacity);
        }
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

	// indicator 2: occupancy rate số trạm sạc active đang dùng/tổng số trạm (hoặc tổng số active)
	reflex calculate_occupancy {
		nb_activeCS_gasoline_used <- length(car_gasoline where (each.parking_slot = "active_CS"));
		nb_activesCS_electric_used <- length(car_electrical where (each.parking_slot = "active_CS"));
		nb_activeCS_used <- nb_activeCS_gasoline_used + nb_activesCS_electric_used;
		//		nb_activeCS_used_test <- (nb_activeCS_Cparking + nb_activeCS_Jparking) - (chargingAreas[0].active_CS + chargingAreas[1].active_CS);
		occupancy_rate <- nb_activeCS_used / (nb_activeCS_Cparking + nb_activeCS_Jparking);

		// If only the number of charging stations with electric vehicles parked is considered useful (even if the vehicle is fully charged but still parked)
		useful_occupancy_rate_1 <- nb_activesCS_electric_used / (nb_activeCS_Cparking + nb_activeCS_Jparking);

		// If considered more strictly, the charging station has electric vehicles parked and charging (fully charged vehicles are not counted)
		nb_activesCS_electric_charging <- length(car_electrical where (each.parking_slot = "active_CS" and each.is_charging = true));
		useful_occupancy_rate_2 <- nb_activesCS_electric_charging / (nb_activeCS_Cparking + nb_activeCS_Jparking);
	}

	//indicator 3: monthly revenue and profit
	reflex calculate_daily_profit when: (current_date.hour = 23 and current_date.minute = 45) {
		daily_revenue <- (total_energy_EVs * 3355) / 1000;
		daily_cost <- (charge_by_grid * 2049 + (nb_activeCS_Cparking + nb_activeCS_Jparking) * 500000 / 30) / 1000;
		daily_profit <- daily_revenue - daily_cost;
		daily_renew_charge <- charge_by_bess + charge_by_renew;
		monthly_energy_consumption <- 22 * total_energy_EVs;
		monthly_renew_charge <- 22 * daily_renew_charge;
	}
	
	reflex calculate_monthly_profit when: (current_date.hour = 23 and current_date.minute = 45) {
		monthly_revenue <- 22 * daily_revenue;
		monthly_cost <- 22 * daily_cost;
		monthly_profit <- 22 * daily_profit;
		payback_process <- payback_process - monthly_profit;
	}
	

	// Indicatior 4: Renewable Energy Efficiency	
	reflex calculate_daily_energy_ratio when: (current_date.hour = 23 and current_date.minute = 50){
		if  add_solar or add_wind {
			self_consumption <- daily_renew_charge / total_renew_energy;
			self_sufficiency <- daily_renew_charge / total_energy_EVs;
		}
		total_energy_EVs <- 0.0;
		total_renew_energy <- 0.0;
		charge_by_bess <- 0.0;
		charge_by_renew <- 0.0;
		charge_by_grid <- 0.0;
	}
	
	reflex total_renew_generation {
		renew_energy_generated <- solar_energy_generated + wind_energy_generated;
		total_solar_energy <- total_solar_energy + solar_energy_generated ;
		total_wind_energy <-  total_wind_energy + wind_energy_generated ;
		total_renew_energy <- total_renew_energy + renew_energy_generated;
	}
}

species solar_energy {
	int solar_ghi;
	float air_temp;
	float unit_panel_area <- 2.7 #m2;
	float total_panel_area;
	float current_panel_tmp;
	
	init {
//		solar_ghi <- rnd(400);
//		air_temp <- rnd(15.0, 34.0);
		total_panel_area <- nb_solar * unit_panel_area;
	}
	
	reflex generate_energy when: add_solar {
		current_panel_tmp <- (air_temp + 25 * solar_ghi/800 * 0.7664) / (1 + 25 * solar_ghi/800 * 0.0175);
		solar_energy_generated <-  total_panel_area / 12 * 1.15 * solar_ghi/800 * 610 * 0.226 * (1 - 0.0028 * (current_panel_tmp - 25));
	
	}
}

species wind_energy {
	float wind_speed;
	float v_cut_in <- 3.5 #m/#s;
	float v_cut_out <- 45 #m/#s;
	float v_r <- 12 #m/#s; 
	float P_rated <- 250;
	
	init {
	}
	
	reflex generate_energy when: add_wind {
		if wind_speed >= v_cut_in and wind_speed <= v_r {
			wind_energy_generated <- nb_wind * P_rated * (( wind_speed * wind_speed * wind_speed - 42.875) / (1728 - 42.875));
		} else if wind_speed >= v_r and wind_speed <= v_cut_out {
			wind_energy_generated <- nb_wind * P_rated;
		} else {
			wind_energy_generated <- 0;
		}
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
		do move_to_gate;
	}

	reflex parking when: moving_obj = "parking" and the_target = nil {
		the_graph <- the_graph_inside;
		do parking;
	}

	reflex time_to_go_home when: current_date.hour = end_work and moving_obj = "working" and the_target = nil {
		in_parkingArea <- false;
		do move_to_gate;
	}

	reflex leaving when: moving_obj = "leaving" and the_target = nil {
		the_graph <- the_graph_outside;
		do leaving;
	}

	reflex random_move when: (current_date.hour between (10, 15)) and (moving_obj = "working" or moving_obj = "resting") 
	and flip(0.01) and the_target = nil {
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
			} } }

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
	float SoC <- 20.0 + rnd(70); //battery level
	string EV_model; //type of EV
	float chargingRate_slow; // charging rate of EV at AC 11kW
	float chargingRate_fast; // charging rate of EV at AC 30kW
	float energy;
	string charging_mode <- "slow";
	list<string> EV_models_at_vinuni <- ["VFe34", "VF8", "VF9"];
	map<string, float> model_chargingRate_slow <- ["VFe34"::100 / 46, "VF8"::100 / 94, "VF9"::100 / 134];
	map<string, float> model_chargingRate_fast <- ["VFe34"::100 / 16, "VF8"::100 / 34, "VF9"::100 / 48];
	float time_to_charge <- 0 #nm;
	
	float energy_needed;

	init {
		if SoC <= 20 {
			parking_area <- one_of(vinuni_Jparking);
			priority_fast <- true;
		}
		EV_model <- one_of(EV_models_at_vinuni);
		chargingRate_slow <- model_chargingRate_slow[EV_model];
		chargingRate_fast <- model_chargingRate_fast[EV_model];
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
		} else if SoC < 70 and SoC > 35 {
			if flip(0.8) {
				do check_slot;
			} else {
				do assign_slot_randomly;
			}
		} else if SoC <= 35 {
			do check_slot;
		} }

	action check_slot {
		if parking_area = one_of(vinuni_Jparking) and priority_fast 
		and parking_area.activeCS_fast > 0 {
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
				} } } }

	action change_parkingArea {
		num_checkSlot <- num_checkSlot + 1;
		if parking_area = one_of(vinuni_Jparking) {
			parking_area <- one_of(vinuni_Cparking);
		} else if parking_area = one_of(vinuni_Cparking) {
			parking_area <- one_of(vinuni_Jparking);
		}
		do check_slot;
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

	reflex try_to_charge when: moving_obj = "working" and not done_charging {
		if (parking_slot = "active_CS" and in_parkingArea) {
		//Assume that when an EV decides to park in an active_CS slot, it always plugs the charge. 			
			is_charging <- true;
		}
	}
    
	reflex charge when: is_charging and moving_obj = "working" {
	    time_to_charge <- time_to_charge + 5;
	    
	    if charging_mode = "slow" {
	        energy_needed <- 11000 * (5 / 60);
	        SoC <- SoC + chargingRate_slow;
	    } else if charging_mode = "fast" {
	        energy_needed <- 30000 * (5 / 60);
	        SoC <- SoC + chargingRate_fast;
	    }
	
	    // Thứ tự ưu tiên sử dụng nguồn sạc: renew -> bess -> grid
	    if renew_energy_generated > 0 {
	        energy_from_renew <- min(renew_energy_generated, energy_needed);
	        charge_by_renew <- charge_by_renew + energy_from_renew;
	        total_energy_EVs <- total_energy_EVs + energy_from_renew; // Cập nhật tổng năng lượng sạc
	        renew_energy_generated <- renew_energy_generated - energy_from_renew;
	        energy_needed <- energy_needed - energy_from_renew;
	    } else {
	    	energy_from_renew <- 0;
	    }
	
	    if energy_needed > 0 and bess_SoC > 0 {
	        energy_from_bess <- min(bess_SoC, energy_needed);
	        charge_by_bess <- charge_by_bess + energy_from_bess;
	        total_energy_EVs <- total_energy_EVs + energy_from_bess; // Cập nhật tổng năng lượng sạc
	        bess_SoC <- bess_SoC - energy_from_bess;
	        energy_needed <- energy_needed - energy_from_bess;
	    } else {
	    	energy_from_bess <- 0;
	    }
	
	    if energy_needed > 0 {
	    	energy_from_grid <- energy_needed;
	        charge_by_grid <- charge_by_grid + energy_needed;
	        total_energy_EVs <- total_energy_EVs + energy_needed; // Cập nhật tổng năng lượng sạc
	        energy_needed <- 0;
	    } else {
	    	energy_from_grid <- 0;
	    }
	
	    // Sạc BESS với năng lượng dư từ nguồn tái tạo nếu không còn nhu cầu từ xe
	    if energy_needed = 0 and renew_energy_generated > 0 {
	        bess_SoC <- bess_SoC + renew_energy_generated;
	        bess_SoC <- min(bess_SoC, bess_capacity); // Đảm bảo không vượt quá dung lượng BESS
	        renew_energy_generated <- 0;
	    }
	
	    // Kiểm tra nếu sạc xong hoặc không còn trong khu vực đỗ xe
	    if (SoC > 99) or (not in_parkingArea) {
	        done_charging <- true;
	        is_charging <- false;
	    }
	}

	reflex move_to_inactive when: done_charging and in_parkingArea and not move_slot {
		do change_slot;
	}
}

experiment vinuni_traffic_dashboard type: gui {
	parameter "Number of gasoline car agents" var: nb_gasoline category: "No. Car";
	parameter "Number of electric car agents" var: nb_electrical category: "No. Car";
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "No. Active Charrging Stations";
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "No. Active Charrging Stations";
	parameter "Number of fast active CS at C_parking" var: nb_activeCS_Cparking_fast category: "No. Active Charrging Stations";
	parameter "Number of fast active CS at J_parking" var: nb_activeCS_Jparking_fast category: "No. Active Charrging Stations";
	parameter "Adding solar panel into CS Infrastructure" var: add_solar category: "Renewable Energy";
	parameter "Number of solar panel" var: nb_solar category: "Renewable Energy";
	parameter "Adding wind turbine into CS Infrastructure" var: add_wind category: "Renewable Energy";
	parameter "Number of wind turbine" var: nb_wind category: "Renewable Energy";

	reflex save_result_avg_satisfied_percent when: (current_date.hour = 23 and current_date.minute = 55) {
		save [nb_gasoline, nb_electrical, cycle, current_date, avg_statisfied_day] 
		   	to: "Results/avg_percentage_statisfied.csv"  format:"csv" rewrite: (cycle = 287) ? true : false;
	}

	output synchronized: true {
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
//			species bess;
//			species solar_energy;
//			species wind_energy;
		}
		
//		display time_to_charge refresh: every(12 #cycles) {
//		    chart "Energy Consumption" type: histogram style: stack x_serie_labels: current_date.hour {
//		        data "Energy from grid" accumulate_values: true value: cumulative_energy_from_grid color: #blue;
//		        data "Energy from renewable sources" accumulate_values: true value: cumulative_energy_from_renew + cumulative_energy_from_bess color: #yellow;
//			}
//		}
		
			
		display avg_daily_charged_EVs type: 2d refresh: (current_date.hour = 23 and current_date.minute = 55){ //plot at 23:55 each day
			chart "Daily EV Charging Rate (%)" type: series memorize: false x_label: "Day" {
				data "Average daily charged EVs percent" value: 100*avg_statisfied_day color: #blue marker: true;
			}
		}

		display Revenue_Profit type: 2d  refresh: (current_date.hour = 23 and current_date.minute = 55){ 
			chart "Monthly Revenue & Profit (in VND mn)" type: series memorize: false x_label: "Month"{
				data "Total monthly revenue" value: monthly_revenue / 1000000 color: #black marker: true;
				data "Total monthly cost" value: monthly_cost / 1000000 color: #red marker: true;
				data "Total monthly profit" value: monthly_profit / 1000000 color: #blue marker: true;
			}		
		}
		
		display Payback type: 2d  refresh: (current_date.hour = 23 and current_date.minute = 55){ 
			chart "Payback process (in VND mn)" type: series memorize: false x_label: "Month"{
				data "Payback for investment" value: payback_process / 1000000 color: #green marker: true;
			}	
		}
		
		display monthly_energy_consumption type: 2d refresh: (current_date.hour = 23 and current_date.minute = 55) {
			chart "Monthly Electric Energy Consumption (kWh)" type: series memorize: false x_label: "Month" {
				data "monthly_energy_consumption (kWh)" value: monthly_energy_consumption/1000 color: #red marker: true style: line;
				data "monthly_renewable_energy_consumption (kWh)" value: monthly_renew_charge/1000 color: #green marker: true style: line;
			}
		}
		
		display ratio_renewable_energy type: 2d refresh: (current_date.hour = 23 and current_date.minute = 55) {
			chart "Daily Renewable Energy Effectiveness" type: series memorize: false x_label: "Day" {
				data "self-consumpation ratio" value: self_consumption color: #red marker: true style: line;
				data "self-sufficiency ratio" value: self_sufficiency color: #green marker: true style: line;
			}
		} 
	}
}

experiment vinuni_traffic_test type: gui {
	parameter "Number of gasoline car agents" var: nb_gasoline category: "No. Car";
	parameter "Number of electric car agents" var: nb_electrical category: "No. Car";
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "No. Active Charrging Stations";
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "No. Active Charrging Stations";
	parameter "Number of fast active CS at C_parking" var: nb_activeCS_Cparking_fast category: "No. Active Charrging Stations";
	parameter "Number of fast active CS at J_parking" var: nb_activeCS_Jparking_fast category: "No. Active Charrging Stations";
	parameter "Implement a policy prohibiting gasoline cars from parking in active_CS" var: policy_prohibit_parking category: "Policies";
	parameter "Implement a policy forcing EVs to move to inactive parking slot when fully charged" var: policy_force_moving category: "Policies";

	reflex save_result_avg_satisfied_percent when: (current_date.hour = 23 and current_date.minute = 55) {
		save [nb_gasoline, nb_electrical, cycle, current_date, avg_statisfied_day] 
		   	to: "Results/avg_percentage_statisfied.csv"  format:"csv" rewrite: (cycle = 287) ? true : false;
	}

	output synchronized: true {
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
			chart "Number of charged vehicle" type: histogram style: stack  {
				data "Charged & Satisfied" accumulate_values: true value: nbEV_charged_statisfied color: #blue;
				data "Not Charged & Unsatisfied" accumulate_values: true value: nbEV_uncharged_unsatisfied color: #yellow;
			}
		}

		display percentage_statisfied type: 2d {
			chart "Indicator 1: EV Charging Rate (%)" type: series memorize: false x_serie_labels: current_date.hour {
				data "Percentage of EV satisfied" value: 100*percentage_statisfied color: #blue marker: false style: line;
			}
		}

		display occupancy_rate refresh: every(#cycle) type: 2d {
			chart "Occupancy Rate" type: pie style: exploded size: {0.5, 1} position: {0.5, 0} {
				data "Being used" value: occupancy_rate color: #magenta;
				data "Available" value: (1 - occupancy_rate) color: #blue;
			}

			chart "Useful Occupancy Rate" type: pie style: exploded size: {0.5, 1} position: {0, 0} {
				data "Being used" value: useful_occupancy_rate_1 color: #magenta;
				data "Available" value: (1 - useful_occupancy_rate_1) color: #blue;
			}

		}

//		display series type: 2d {
//			chart "Number of Active Charging Stations Available" type: series x_label: "#points to draw at each step" memorize: false x_serie_labels: current_date.hour {
//				data "Slots at C_parking" value: chargingAreas[0].active_CS color: #blue marker: false style: line;
//				data "Slots at J_parking" value: chargingAreas[1].active_CS color: #red marker: false style: line;
//			}
//		}
	}
	
}

//Experiment to show how to make multi simulations
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