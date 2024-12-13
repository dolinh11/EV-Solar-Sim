/**
* Name: energy
* Based on the internal empty template. 
* Author: linhdo
* Tags: 
*/


model energy

/* Insert your model definition here */

global {
	
//	file energy_realtime <- csv_file("../includes/average_by_time_data.csv",",");
//	file energy_realtime <- csv_file("../includes/energy_data.csv",",");

//	file energy_realtime <- csv_file("../includes/average_by_spring.csv",",");
//	file energy_realtime <- csv_file("../includes/average_by_summer.csv",",");
	file energy_realtime <- csv_file("../includes/average_by_autumn.csv",",");
//	file energy_realtime <- csv_file("../includes/average_by_winter.csv",",");

	// Energy Real-time Data
	int current_row <- 0;
	matrix data <- matrix(energy_realtime);
	
	// Renewable Energy Cost
	float solar_capex_unit <- 18000000.0; // 18tr VND/ 1kWp
	float solar_opex <- 600000.0; // 600k
	float solar_capex;
	
	float wind_capex_unit <- 76000000.0; //  76tr VND/ 3kWh
	float wind_opex <- 1200000.0; // 1tr2
	float wind_capex;
	
	float solar_cost;
	float wind_cost;
	float renew_invest_cost;
	float payback_process;
		
	init {
		//convert the file into a matrix
//		matrix data <- matrix(energy_realtime);
		//loop on the matrix rows (skip the first header line)
		loop i from: 1 to: data.rows -1{
			//loop on the matrix columns
			loop j from: 0 to: data.columns -1{
				write "data rows:"+ i +" colums:" + j + " = " + data[j,i];
			}	
		}
		
		solar_capex <- solar_capex_unit * nb_solar * 0.61;
		solar_cost <- solar_capex + solar_opex;
		
		wind_capex <- wind_capex_unit * nb_wind;
		wind_cost <- wind_capex + wind_opex;
		
		renew_invest_cost <- solar_cost + wind_cost;
		payback_process <- solar_cost + wind_cost;		
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
	
	// Energy-related variables
	bool add_solar <- true; 
	int nb_solar <- 100;
	bool add_wind <- true;
	int nb_wind <- 4;
	int nb_bess <- 1;

	// total renewable energy generate
	float total_renew_energy <- 0.0;
	float total_solar_energy <- 0.0;
	float total_wind_energy <- 0.0;
	
	float renew_energy_generated;
	float solar_energy_generated;
	float wind_energy_generated;
	
	// BESS 
	float bess_capacity <- 80000.0;
	float bess_SoC <- 0.0;
	
	//On-Off Grid
	bool off_grid_C <- false;
	bool off_grid_J <- false;
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
	float P_rated <- 250.0;
	
	init {
	}
	
	reflex generate_energy when: add_wind {
		if wind_speed >= v_cut_in and wind_speed <= v_r {
			wind_energy_generated <- nb_wind * P_rated * (( wind_speed * wind_speed * wind_speed - 42.875) / (1728 - 42.875));
		} else if wind_speed >= v_r and wind_speed <= v_cut_out {
			wind_energy_generated <- nb_wind * P_rated;
		} else {
			wind_energy_generated <- 0.0;
		}
	}
}