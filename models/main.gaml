
/**
* Name: main
* Based on the internal empty template. 
* Author: linhdo
* Tags: 
*/


model main

import "traffic.gaml"

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
	
	init {
//		seed <- 32.0;
		create chargingAreas from: shape_file_chargingareas with: [type:: string(read("fclass")), active_CS::int(read("active_CS")), num_CS::int(read("num_CS"))] {
			if type = "C_parking" {
				chargingAreas_color <- #gray;
			}

			chargingAreas[0].active_CS <- nb_activeCS_Cparking;
			chargingAreas[1].active_CS <- nb_activeCS_Jparking;
			chargingAreas[0].activeCS_fast <- nb_activeCS_Cparking_fast;
			chargingAreas[1].activeCS_fast <- nb_activeCS_Jparking_fast;
			chargingAreas[0].num_CS <- max(chargingAreas[0].num_CS, nb_activeCS_Cparking + nb_activeCS_Cparking_fast);
			chargingAreas[1].num_CS <- max(chargingAreas[1].num_CS, nb_activeCS_Jparking + nb_activeCS_Jparking_fast);
		}

		create residential from: shape_file_residential;
		create gate from: shape_file_gate with: [type:: string(read("fclass")), state_type::string(read("state"))] {
			if state_type = "close" {
				gate_color <- #black;
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
		
		renew_invest_cost <- solar_cost + wind_cost;
		payback_process <- solar_cost + wind_cost;
	}
	
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

	// Energy Consumption 
	float monthly_renew_charge;
	float daily_renew_charge;
	float monthly_energy_consumption <- 0.0;
	float self_consumption;
	float self_sufficiency;
//	float energy_consumption <- 0.0;
//	float monthly_renew_energy;
	
	// Renewable Energy Cost variable
	float payback_period;
	int payback_threshold <- 60;
	float payback_period_norm;
 

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
		slot_noti <- false;
	}

	//indicator 2: monthly revenue and profit
	reflex calculate_daily_profit when: (current_date.hour = 23 and current_date.minute = 45) {
		daily_revenue <- ((total_energy_EVs * 3355) + (total_idle_time * 1000)) / 1000;
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
		payback_period <- renew_invest_cost / monthly_profit;
		
		if payback_period <= payback_threshold {
			payback_period_norm <- payback_period / payback_threshold;
		} else {
	        payback_period_norm <- exp((payback_threshold - payback_period) / payback_threshold);
		}
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
	
	float metric <-0.0;
	reflex metric when: (current_date.hour = 23 and current_date.minute = 50) {
		metric <- avg_statisfied_day + 0.8 * self_sufficiency + payback_period_norm;
	}
	
	reflex total_renew_generation {
		renew_energy_generated <- solar_energy_generated + wind_energy_generated;
		total_solar_energy <- total_solar_energy + solar_energy_generated ;
		total_wind_energy <-  total_wind_energy + wind_energy_generated ;
		total_renew_energy <- total_renew_energy + renew_energy_generated;
	}
}

experiment traffic_dashboard type: gui {
	parameter "Number of gasoline car agents" var: nb_gasoline category: "No. Car" <- 30;
	parameter "Number of electric car agents" var: nb_electrical category: "No. Car" <- 50;
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "No. Active Charrging Stations" ;
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "No. Active Charrging Stations";
	parameter "Number of fast active CS at C_parking" var: nb_activeCS_Cparking_fast category: "No. Active Charrging Stations";
	parameter "Number of fast active CS at J_parking" var: nb_activeCS_Jparking_fast category: "No. Active Charrging Stations";
	parameter "Adding solar panel into CS Infrastructure" var: add_solar category: "Renewable Energy";
	parameter "Number of solar panel" var: nb_solar category: "Renewable Energy" <- 500;
	parameter "Adding wind turbine into CS Infrastructure" var: add_wind category: "Renewable Energy" <- false;
	parameter "Number of wind turbine" var: nb_wind category: "Renewable Energy" <- 0;
	parameter "Expected payback period" var: payback_threshold category: "Renewable Energy";
	parameter "Policy 1: Ban gasoline vehicles from active charging stations" var: policy_ban_gasoline category: "Policies";
	parameter "Policy 2: Charge idle fees of 1,000 VND/min after 30 minutes of full charge" var: policy_idle_fee category: "Policies";
	parameter "Policy 3: Relocate fully charged EVs to inactive charging stations" var: policy_relocation category: "Policies";
	parameter "Policy 4: Notify users when nearby charging spots are available" var: policy_notification category: "Policies";
	
//	parameter "Disconnecting with Grid at Building C" var: off_grid_C category: "Grid Connection";
//	parameter "Disconnecting with Grid at Building J" var: off_grid_J category: "Grid Connection";	
	
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
			
		display avg_daily_charged_EVs type: 2d refresh: (current_date.hour = 23 and current_date.minute = 55){ //plot at 23:55 each day
			chart "Daily EV Charging Rate (%)" type: series memorize: false x_label: "Day" {
				data "Average daily charged EVs percent" value: 100*avg_statisfied_day color: #blue marker: true;
			}
		}

		display Revenue_Profit type: 2d  refresh: (current_date.hour = 23 and current_date.minute = 55){ 
			chart "Monthly Revenue & Profit (in VND)" type: series memorize: false x_label: "Month"{
				data "Total monthly revenue" value: monthly_revenue color: #black marker: true;
				data "Total monthly cost" value: monthly_cost color: #orange marker: true;
				data "Total monthly profit" value: monthly_profit color: #blue marker: true;
			}		
		}
		display Payback type: 2d  refresh: (current_date.hour = 23 and current_date.minute = 55){ 
			chart "Payback process" type: series memorize: false x_label: "Month"{
				data "Payback for investment" value: payback_process color: #blue marker: true;
			}	
		}
		
		display monthly_energy_consumption type: 2d refresh: (current_date.hour = 23 and current_date.minute = 55) {
			chart "Monthly Electric Energy Consumption (kWh)" type: series memorize: false x_label: "Month" {
				data "monthly_renewable_energy_consumption (kWh)" value: monthly_renew_charge/1000 color: #orange marker: true style: line;
				data "monthly_energy_consumption (kWh)" value: monthly_energy_consumption/1000 color: #blue marker: true style: line;
			}
		}
		
		display ratio_renewable_energy type: 2d refresh: (current_date.hour = 23 and current_date.minute = 55) {
			chart "Daily Renewable Energy Effectiveness" type: series memorize: false x_label: "Day" {
				data "self-consumpation ratio" value: self_consumption color: #orange marker: true style: line;
				data "self-sufficiency ratio" value: self_sufficiency color: #blue marker: true style: line;
			}
		}		
	}

//	reflex column_name when: (cycle = 286){
//		save ["Cycle", "Current date", "Case 0", "Case 1", "Case 2", "Case 3"] 
//			to: "Results/gui_Q1_wo_wind_v1.csv" format:"csv" rewrite: (cycle = 286) ? true : false header: false;	
//	}
//	reflex export_value when: (current_date.hour = 23 and current_date.minute = 55) {	
//		list combinedResults <- [cycle, current_date];
//		loop s over: simulations{
//			ask s {
//				combinedResults <- combinedResults + [s.self_sufficiency];
//			}
//		}
//		save combinedResults 
//			to: "res_data/weather/test_Q1_wo_wind.csv" format:"csv" rewrite: false header: false;
//		}
}


experiment batch_config type: batch  repeat: 10 parallel: 10 keep_seed: true until: (cycle=287) {
	init {
	//Make grids schedule their agents in parallel
	gama.pref_parallel_grids <- false;
	//Make experiments run simulations in parallel
	gama.pref_parallel_simulations <- true;
	//Make species schedule their agents in parallel
	gama.pref_parallel_species <- false;
  }
		
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" <- 100;
	
	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car" <- 30;
	
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking" min:20 max:50 step:5;
	parameter "Number of fast active CS at C_parking" var: nb_activeCS_Cparking_fast category: "C_parking" min:2 max:10 step:2;
	
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "J_parking" min:15 max:30 step:3;
	parameter "Number of fast active CS at J_parking" var: nb_activeCS_Jparking_fast category: "J_parking" min:2 max:8 step:2;
	
	parameter "Add solar panel" var: add_solar category: "Renewable Energy" <- true;
	parameter "Number of solar panel" var: nb_solar category: "Renewable Energy" min: 200 max: 900 step: 100;
	
	parameter "Add wind turbine" var: add_wind category: "Renewable Energy" <- false;
//	parameter "Number of wind turbine" var: nb_wind category: "Renewable Energy" min: 2 max: 10 step: 2;

	parameter "Expected payback period" var: payback_threshold category: "Renewable Energy" <- 60;
//	parameter "Disconnecting with Grid at Building C" var: off_grid_C category: "Grid Connection" <- false;
//	parameter "Disconnecting with Grid at Building J" var: off_grid_J category: "Grid Connection" <- false;
	
	parameter "Policy 1: Ban gasoline vehicles from active charging stations" var: policy_ban_gasoline category: "Policies" <- true;
	parameter "Policy 2: Charge idle fees of 1,000 VND/min after 30 minutes of full charge" var: policy_idle_fee category: "Policies" <- false;
	parameter "Policy 3: Relocate fully charged EVs to inactive charging stations" var: policy_relocation category: "Policies" <- false;
	parameter "Policy 4: Notify users when nearby charging spots are available" var: policy_notification category: "Policies" <- false;
	

//	method exploration;	

//	method hill_climbing maximize: metric; 
    
//    method annealing 
//        temp_init: 0.5  temp_end: 0.02
//        temp_decrease: 0.95 nb_iter_cst_temp: 5
//        maximize: metric;
    
//    method tabu 
//        iter_max: 280 tabu_list_size: 3 
//        maximize: metric;
        
//    method reactive_tabu 
//        iter_max: 140 tabu_list_size_init: 10 tabu_list_size_min: 5 tabu_list_size_max: 20
//        nb_tests_wthout_col_max: 20 cycle_size_min: 3 cycle_size_max: 10 
//        maximize: metric;
	
//	  method genetic maximize: metric 
//         pop_dim: 20 crossover_prob: 0.8 mutation_prob: 0.1 
//         nb_prelim_gen: 3 max_gen: 40;

	  method pso num_particles: 5 weight_inertia: 0.7 weight_cognitive: 1.4 weight_social: 1.6  iter_max: 10  maximize: metric; 
        
	reflex save_results_explore {
		ask simulations {
			save [int(self), self.nb_electrical, self.nb_activeCS_Cparking, self.nb_activeCS_Cparking_fast,
				    self.nb_activeCS_Jparking, self.nb_activeCS_Jparking_fast,
					self. nb_solar, self.nb_wind,
					self.avg_statisfied_day, self.monthly_profit,
					self.monthly_energy_consumption, self.monthly_renew_charge, 
					self.self_consumption, self.self_sufficiency, 
					self.payback_period, self.payback_period_norm,
					self.metric
			]
		   		to: "res_data/config/test_pso_EV100.csv" format:"csv" rewrite: (int(self) = 0) ? true : false header: true;
		}		
	}
}


experiment batch_policy type: batch  repeat: 10 parallel: 10 keep_seed: true until: (cycle=287) {
		
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" <- 100;
	parameter "Number of gasoline car agents" var: nb_gasoline category: "No. Car" <- 30;

	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking" <- 20;
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "No. Active Charrging Stations" <- 15;
	parameter "Number of fast active CS at C_parking" var: nb_activeCS_Cparking_fast category: "No. Active Charrging Stations" <- 4;
	parameter "Number of fast active CS at J_parking" var: nb_activeCS_Jparking_fast category: "No. Active Charrging Stations" <- 4;
	
	parameter "Adding solar panel into CS Infrastructure" var: add_solar category: "Renewable Energy" <- false;
	parameter "Adding wind turbine into CS Infrastructure" var: add_wind category: "Renewable Energy" <- false;

    parameter "Policy 1: Ban gasoline vehicles from active charging stations" var: policy_ban_gasoline category: "Policies" among: [true, false];
    parameter "Policy 2: Charge idle fees of 1,000 VND/min after 30 minutes of full charge" var: policy_idle_fee category: "Policies" among: [true, false];
    parameter "Policy 3: Relocate fully charged EVs to inactive charging stations" var: policy_relocation category: "Policies" among: [true, false];
    parameter "Policy 4: Notify users when nearby charging spots are available" var: policy_notification category: "Policies" among: [true, false];

	method exploration;	 
        
	reflex save_results_explore {
		ask simulations {
			save [int(self), self.nb_electrical, self.nb_activeCS_Cparking, self.nb_activeCS_Cparking_fast,
					self. nb_solar, self.nb_wind,
					self.policy_ban_gasoline, self.policy_idle_fee,
					self.policy_relocation, self.policy_notification,
					self.avg_statisfied_day, self.monthly_profit,
					self.monthly_energy_consumption, self.monthly_renew_charge, 
					self.self_consumption, self.self_sufficiency, 
					self.payback_period, self.payback_period_norm,
					self.metric
			]
		   		to: "res_data/policy/test_policy.csv" format:"csv" rewrite: (int(self) = 0) ? true : false header: true;
		}		
	}
}

experiment sobol_analysis type: batch until:(current_date.hour = 23 and current_date.minute = 55) repeat: 10 parallel: 10 {
	parameter "Number of electrical car agents" var: nb_electrical category: "Electrical Car" min:50 max:200 step:50;
	parameter "Number of gasoline car agents" var: nb_gasoline category: "Gasoline Car" <- 30;
	
	parameter "Number of active CS at C_parking" var: nb_activeCS_Cparking category: "C_parking" min:20 max:50 step:5;
	parameter "Number of fast active CS at C_parking" var: nb_activeCS_Cparking_fast category: "C_parking" min:2 max:10 step:2;
	
	parameter "Number of active CS at J_parking" var: nb_activeCS_Jparking category: "J_parking" <- 15;
	parameter "Number of fast active CS at J_parking" var: nb_activeCS_Jparking_fast category: "J_parking" <- 4;
	
	parameter "Add solar panel" var: add_solar category: "Renewable Energy" <- true;
	parameter "Number of solar panel" var: nb_solar category: "Renewable Energy" min: 200 max: 900 step: 100;
	
	parameter "Add wind turbine" var: add_wind category: "Renewable Energy" <- false;
	parameter "Number of wind turbine" var: nb_wind category: "Renewable Energy" <- 0;

	parameter "Expected payback period" var: payback_threshold category: "Renewable Energy" <- 60;
	
	parameter "Policy 1: Ban gasoline vehicles from active charging stations" var: policy_ban_gasoline category: "Policies" among: [true, false];
    parameter "Policy 2: Charge idle fees of 1,000 VND/min after 30 minutes of full charge" var: policy_idle_fee category: "Policies" among: [true, false];
    parameter "Policy 3: Relocate fully charged EVs to inactive charging stations" var: policy_relocation category: "Policies" among: [true, false];
    parameter "Policy 4: Notify users when nearby charging spots are available" var: policy_notification category: "Policies" among: [true, false];

	method sobol outputs:["avg_statisfied_day","self_consumption","self_sufficiency", "payback_period_norm", "metric"] sample:1000 report:"res_data/sobol/test_sobol.txt" results:"res_data/sobol/test_sobol_raw.csv";
}
