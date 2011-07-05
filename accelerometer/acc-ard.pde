/*
 *  Gyroscope and Accelerometer Integration
 *  By: Thilakshan Kanesalingam
 *  April 4, 2010
 *  4BI6 Biomedical Design, McMaster University
 *  
 *  Description:
 *  Takes raw ADC counts from the analog inputs of the Arduino from
 *  a single axis gyroscope and triple axis accelerometer and prints
 *  the angle of rotation (in radians) and x,y,z position (in cm) to
 *  the serial port at 9600 bps. Values are comma-delimited and each 
 *  sample set ends with a newline.
 *  The gyroscope data provides angular velocity in the x axis. The 
 *  value from each sample is normalized and integrated (trapezoidal 
 *  method) to give the angle of rotation (orientation).
 *  The angle of rotation is used to generate a rotation matrix about
 *  the z-axis. This rotation matrix is applied to the raw ADC counts 
 *  from the triple axis accelerometer to project acceleration in the
 *  x,y,z direction from the base frame of reference to the global
 *  frame of reference.
 *  The acceleration (x,y,z) in the global frame of reference is 
 *  normalized and double integrated (trapezoidal method) to obtain 
 *  position in the x,y,z direction.
 *  
 */

//initialize functions
void Initialize_Globals();
void Calibrate(void);
double make_radians_per_sec(double ADC_angular_rate);
double make_metres_per_sec2(double ADC_acceleration);
void Gyroscope(double x_gyro);
void UpdateRotationMatrix(double angle[3]);
void Accelerometer(double x_accel, double y_accel, double z_accel);
void Accel_Movement_End_Check(void);

//initialize global variables
double old_R[3][3] = {{1,0,0},{0,1,0},{0,0,1}};
double current_R[3][3] = {{0}};
double x_angular_rate[2];
double x_angle[2];
double x_acceleration[2], y_acceleration[2], z_acceleration[2];
double x_velocity[2], y_velocity[2], z_velocity[2];
double x_position[2], y_position[2], z_position[2];

double ss_gyro_x, ss_accel_x, ss_accel_y, ss_accel_z;
int countx_gyro, countx_accel, county_accel, countz_accel;
double start_time = 0;
double dt = 0; //time step between samples
float angle, x_pos, y_pos, z_pos;

void setup() {
    Initialize_Globals(); //initialize global variables
    Calibrate(); //calibrate
    Serial.begin(9600); //initialize the serial port
}

void loop() {
    //start time is the number of ms since the Arduino board began running the current program
    start_time = millis(); 
     
    Gyroscope(analogRead(0));  
    Accelerometer(analogRead(1), analogRead(2), analogRead(3));
    
    //output values to serial port as an ASCII numeric string
    Serial.print(angle, DEC);
    Serial.print(",");
    Serial.print(x_pos, DEC);
    Serial.print(",");
    Serial.print(y_pos, DEC);
    Serial.print(",");
    Serial.print(z_pos, DEC);
    Serial.print(",");
    Serial.print(analogRead(7), DEC); //flex sensor reading: index finger
    Serial.print(",");
    Serial.print(analogRead(5), DEC); //flex sensor reading: thumb
    Serial.println(); //print a newline and carriage return in the end    
    
    //delay 1ms before next read
    delay(1);
    
    //define time step as the difference between current time and start time (since program launch) in seconds
    dt = (millis() - start_time)/1000;
}

void Gyroscope(double x_gyro) {
    double w_d = 0.2; //window of discrimination for no-movement condition: 0.2 rad/s
    //subtract the zero-rate level to obtain positive and negative angular rate
    //convert from proportional ADC counts to radians per second
    x_angular_rate[1] = make_radians_per_sec(x_gyro) - make_radians_per_sec(ss_gyro_x);
  
    //apply discrimination window 
    if ((x_angular_rate[1] <= w_d) && (x_angular_rate[1] >= -w_d)) {x_angular_rate[1] = 0;}

    //integrate using first order approximation (trapezoidal method)
    // = rectangle area + triangle area
    // = (b-a)*f(a) + 0.5*(b-a)[f(b)-f(a)]
    x_angle[1] = x_angle[0] + (x_angular_rate[0] + ((x_angular_rate[1] - x_angular_rate[0])/2))*dt;
  
    //current velocity sent to previous velocity
    x_angular_rate[0] = x_angular_rate[1];
    double angle_vector[3] = {x_angle[1]-x_angle[0],0,0}; //angle vector for integrated angular velocity

    //if the angle is non-zero (with window) create a rotation matrix
    if (angle_vector[0] != 0) {UpdateRotationMatrix(angle_vector);}

    //current angle sent to previous angle
    x_angle[0] = x_angle[1];
    
    //final angle as float variable for serial output as radians
    //multiply by (180/3.14) for angle in degrees
    angle = x_angle[1];
}

void UpdateRotationMatrix(double angle[3]){ // Update R as each new sample becomes available
    double sum; //summation variable used in matrix multiplication
    int i, j, k; //counters

    //attitude update matrix is an elementary rotation matrix about z
    double attitude_update[3][3] = {{cos(angle[0]),-sin(angle[0]),0},
                                    {sin(angle[0]),cos(angle[0]),0},
                                    {0,0,1}};

    //Compute: Current Rotation Matrix = Old Rotation Matrix * Attitude Update Matrix
    //(multiplication of two 3x3 matrices)
    for (i=0; i<3; i++) {
        for (j=0; j<3; j++) {
            sum=0;
            for (k=0; k<3; k++) {
                sum = sum + old_R[i][k]*attitude_update[k][j];
                current_R[i][j] = sum;
            } 
        }  
    }
    
    //Send Current Rotation Matrix to Previous Rotation Matrix: old_R = current_R
    for (i=0; i<3; i++) {
        for (j=0; j<3; j++) {
            old_R[i][j] = current_R[i][j]; 
        }  
    }
}

void Accelerometer(double x_accel, double y_accel, double z_accel) {
    double w_d = 0.5; //window of discrimination for no-movement condition: 50 cm/s^2
    double wd_max = 2; //window of discrimination for gravity condition: 2 m/s^2
    double base_accel[3] = {0}; //base frame of reference
    double global_accel[3] = {0}; //global frame of reference
    int i=0, j=0; //counters

    //subtract the zero-rate level to obtain positive and negative acceleration
    //convert from proportional ADC counts to metres per second squared
    x_acceleration[1] = make_metres_per_sec2(x_accel) - make_metres_per_sec2(ss_accel_x);
    y_acceleration[1] = make_metres_per_sec2(y_accel) - make_metres_per_sec2(ss_accel_y);
    z_acceleration[1] = make_metres_per_sec2(z_accel) - make_metres_per_sec2(ss_accel_z);
    
    //apply discrimination window for no-movement condition 
    if ((x_acceleration[1] <= w_d) && (x_acceleration[1] >= -w_d)) {x_acceleration[1] = 0;}
    if ((y_acceleration[1] <= w_d) && (y_acceleration[1] >= -w_d)) {y_acceleration[1] = 0;}
    if ((z_acceleration[1] <= w_d) && (z_acceleration[1] >= -w_d)) {z_acceleration[1] = 0;}
  
    //if acceleration is very fast, its likely due to an unwanted gravity component, so ignore it
    if ((x_acceleration[1] >= wd_max) || (x_acceleration[1] <= -wd_max)) {x_acceleration[1] = 0;}
    if ((y_acceleration[1] >= wd_max) || (y_acceleration[1] <= -wd_max)) {y_acceleration[1] = 0;}
    if ((z_acceleration[1] >= wd_max) || (z_acceleration[1] <= -wd_max)) {z_acceleration[1] = 0;}
      
    //move acceleration signal in the base frame of reference to a new vector
    base_accel[0] = x_acceleration[1];
    base_accel[1] = y_acceleration[1];
    base_accel[2] = z_acceleration[1];
    
    //project acceleration into the global frame of reference: matrix and 
    vector multiplication
    for (i=0; i<3; i++) {
        for (j=0; j<3; j++) {
            global_accel[i] = global_accel[i] + current_R[i][j]*base_accel[j];
        }
    }

    //move projected acceleration back
    x_acceleration[1] = global_accel[0];
    y_acceleration[1] = global_accel[1];
    z_acceleration[1] = global_accel[2];
    
    //integrate using first order approximation (trapezoidal method)
    // = rectangle area + triangle area
    // = (b-a)*f(a) + 0.5*(b-a)[f(b)-f(a)]
    //double integrate each axis of acceleration to get position

    //first x integration
    x_velocity[1] = x_velocity[0] + (x_acceleration[0] + ((x_acceleration[1] - x_acceleration[0])/2.0))*dt;
    //second x integration
    x_position[1] = x_position[0] + (x_velocity[0] + ((x_velocity[1] - `x_velocity[0])/2))*dt;
  
    //same for y
    y_velocity[1] = y_velocity[0] + (y_acceleration[0] + ((y_acceleration[1] - y_acceleration[0])/2.0))*dt;
    y_position[1] = y_position[0] + (y_velocity[0] + ((y_velocity[1] - y_velocity[0])/2))*dt;
  
    //same for z
    z_velocity[1] = z_velocity[0] + (z_acceleration[0] + ((z_acceleration[1] - z_acceleration[0])/2.0))*dt;
    z_position[1] = z_position[0] + (z_velocity[0] + ((z_velocity[1] - z_velocity[0])/2))*dt;
    
    //current accel sent to previous accel
    x_acceleration[0] = x_acceleration[1];
    y_acceleration[0] = y_acceleration[1];
    z_acceleration[0] = z_acceleration[1];

    //same for velocity
    x_velocity[0] = x_velocity[1];
    y_velocity[0] = y_velocity[1];
    z_velocity[0] = z_velocity[1];

    //check for end of movement
    Accel_Movement_End_Check();

    //actual position sent back to previous position
    x_position[0] = x_position[1];
    y_position[0] = y_position[1];
    z_position[0] = z_position[1];

    //final position as float variable for serial output in cm
    x_pos = x_position[1]*100;
    y_pos = y_position[1]*100;
    z_pos = z_position[1]*100;
}

//initial values for global variables
void Initialize_Globals(){
    x_angular_rate[0] = 0;
    x_angle[0] = 0;
    
    x_acceleration[0] = 0;
    y_acceleration[0] = 0;
    z_acceleration[0] = 0;
    
    x_velocity[0] = 0;
    y_velocity[0] = 0;
    z_velocity[0] = 0;
    
    x_position[0] = 0;
    y_position[0] = 0;
    z_position[0] = 0;
    
    angle = 0;
    
    x_pos = 0;
    y_pos = 0;
    z_pos = 0;
    
    ss_gyro_x = 0;
    ss_accel_x = 0;
    ss_accel_y = 0;
    ss_accel_z = 0;
    
    countx_gyro = 0;
    countx_accel = 0;
    county_accel = 0;
    countz_accel = 0;
}

void Calibrate(void) {
    unsigned int count1;
    count1 = 0;
    do{ //accumulate samples
        ss_gyro_x = ss_gyro_x + analogRead(0);
        ss_accel_x = ss_accel_x + analogRead(1);
        ss_accel_y = ss_accel_y + analogRead(2);
        ss_accel_z = ss_accel_z + analogRead(3);
        count1++;
    }while(count1!=500); //500 times 
    
    //average the samples
    ss_gyro_x = ss_gyro_x/count1;
    ss_accel_x = ss_accel_x/count1;                
    ss_accel_y = ss_accel_y/count1;
    ss_accel_z = ss_accel_z/count1;
}

double make_radians_per_sec(double ADC_angular_rate){
    double Vref = 5; //arduino ADC 5V ref voltage
    double sensitivity = 0.0033; // 3.3mV/(degrees/sec) sensitivity (from gyro data sheet)
    
    //convert ADC value to voltage and divide by sensitivity
    return ((ADC_angular_rate*Vref/1024)/sensitivity)*(3.14/180);   
}

double make_metres_per_sec2(double ADC_acceleration){
  
    double Vref = 5; //arduino ADC 5V ref voltage
    double sensitivity = 0.33; // 0.33V/g sensitivity ratiometric when Vs = 3.3V (from accel data sheet)
      
    //convert ADC value to voltage and divide by sensitivity
    //convert standard gravity g to m/s^2 by multiplying by 9.80665 
    return ((ADC_acceleration*Vref/1024)/sensitivity)*9.80665;
}

void Accel_Movement_End_Check(void){
    //count the number of accel samples that equal zero
    if (x_acceleration[1]==0) {countx_accel++;}
    else {countx_accel = 0;}
    
    //if this number exceeds 5, we can assume that velocity is zero
    if (countx_accel >= 5) { 
        x_velocity[1]=0;
        x_velocity[0]=0; 
    } 
    
    //same for y
    if (y_acceleration[1]==0) {county_accel++;}
    else {county_accel = 0;}
    
    if (county_accel >= 5) { 
        y_velocity[1]=0;
        y_velocity[0]=0;  
    }
    
    //same for z
    if (z_acceleration[1]==0) {countz_accel++;}
    else {countz_accel = 0;}
    if (countz_accel >= 5) { 
        z_velocity[1]=0;
        z_velocity[0]=0;  
    }
}

