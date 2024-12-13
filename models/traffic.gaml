/**
* Name: traffic
* Based on the internal empty template. 
* Author: linhdo
* Tags: 
*/

model traffic

import "charging_station.gaml"
import "energy.gaml"


global {
	// Vehicle-related global variables
	int nb_electrical <- 50;
	int nb_gasoline <- 30;
	int min_work_start_1 <- 8;
	int max_work_start_1 <- 9;
	int min_work_start_2 <- 12;
	int max_work_start_2 <- 14;
	int min_work_end_2 <- 17;
	int max_work_end_2 <- 19;
	float min_speed <- 8 #km / #h;
	float max_speed <- 10 #km / #h;
	
	//Polices
	bool policy_prohibit_parking <- false; //prohibit gasoline cars from parking in active_CS slot
	bool policy_force_moving <- false; //force EVs to move to inactive parking slot when fully charged

	// Energy consumption 
	float charge_by_renew;
	float charge_by_bess;
	float charge_by_grid;
	float charge_by_grid_C;
	float charge_by_grid_J;
	
	// Energy Consumption 
	float total_energy_EVs <- 0.0;
	
	
	reflex update_bess_SoC {
        // Check if no car is charging and bess_SoC is below capacity
        if every(car_electrical where (each.is_charging = false)) and bess_SoC < bess_capacity {
            bess_SoC <- bess_SoC + renew_energy_generated;
            bess_SoC <- min(bess_SoC, bess_capacity);
        }
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
    float energy_from_renew;
    float energy_from_bess;

	init {
		if SoC <= 20 {
//			parking_area <- one_of(vinuni_Jparking);
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
		if priority_fast and parking_area.activeCS_fast > 0 {
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
	    }
	
	    if energy_needed > 0 and bess_SoC > 0 {
	        energy_from_bess <- min(bess_SoC, energy_needed);
	        charge_by_bess <- charge_by_bess + energy_from_bess;
	        total_energy_EVs <- total_energy_EVs + energy_from_bess; // Cập nhật tổng năng lượng sạc
	        bess_SoC <- bess_SoC - energy_from_bess;
	        energy_needed <- energy_needed - energy_from_bess;
	    }

		if energy_needed > 0 {
			if off_grid_C {
				if not off_grid_J {
					if parking_area = one_of(vinuni_Jparking) {
						charge_by_grid_J <- charge_by_grid_J + energy_needed;
						charge_by_grid <- charge_by_grid + energy_needed;
						total_energy_EVs <- total_energy_EVs + energy_needed; // Cập nhật tổng năng lượng sạc
				        energy_needed <- 0.0;
					}
				}
			} else {
				if off_grid_J {
					if parking_area = one_of(vinuni_Cparking) {
						charge_by_grid_C <- charge_by_grid_C + energy_needed;
						charge_by_grid <- charge_by_grid + energy_needed;
						total_energy_EVs <- total_energy_EVs + energy_needed; // Cập nhật tổng năng lượng sạc
				        energy_needed <- 0.0;
					}
				} else {
					charge_by_grid <- charge_by_grid + energy_needed;
				    total_energy_EVs <- total_energy_EVs + energy_needed; // Cập nhật tổng năng lượng sạc
				    energy_needed <- 0.0;
				}
			}
		}
	
	    // Sạc BESS với năng lượng dư từ nguồn tái tạo nếu không còn nhu cầu từ xe
	    if energy_needed = 0 and renew_energy_generated > 0 {
	        bess_SoC <- bess_SoC + renew_energy_generated;
	        bess_SoC <- min(bess_SoC, bess_capacity); // Đảm bảo không vượt quá dung lượng BESS
	        renew_energy_generated <- 0.0;
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


