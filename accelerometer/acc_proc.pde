/*
 *  Hand Simulation
 *  By: Thilakshan Kanesalingam
 *  April 4, 2010
 *  4BI6 Biomedical Design, McMaster University
 *  Description:
 *  Takes ASCII values from the serial port at 9600 bps. Values should 
 *  be comma-delimited and each sample set should end with a newline.
 *  Angle (rad) and X,Y position (cm) are used to draw three lines 
 *  representing a hand. The hands orientation changes based on the 
 *  angle. The hands position changes based on the X,Y displacement.
 */

import processing.serial.*;
Serial myPort;
int maxSensors = 6; //the Arduino has a maximum of 6 possible inputs
float angle_old=0, x_old=0, y_old=0, fd_old=0; //previous values used to cover old drawing

void setup () {
    println(Serial.list()); //list all available serial ports
    myPort = new Serial(this, Serial.list()[0], 9600);
    myPort.clear();
    myPort.bufferUntil('\n'); // only generate a serialEvent() when a newline is detected (end of sample)
    size(800,600);  
    //size(1000, 676); // office
    //size(640, 376); //food
    //PImage b;
    //b = loadImage("office.jpg");
    //b = loadImage("food.jpg");
    //background(b);
    background(0); // set initial background
    smooth(); //turn on anti aliasing
}

void draw () {
    //keeps the program running
}

void serialEvent (Serial myPort) {
    String inString = myPort.readStringUntil('\n'); //get the ASCII string
    if (inString != null) { //if it's not empty
        inString = trim(inString); //trim off any whitespace

        float incomingValues[] = float(split(inString, ",")); //convert to an array of floats
        float angle=0, x=0, y=0; //angle, position (x,y)
        float thumb=0, index=0, fd=0; //thumb and index flexion (proportional values), fd is finger distance used to draw hand
        int x_offset = 450, y_offset = 500; //offsets to determine start position of hand
        
        //draw circle (equal width and height of ellipse)
        stroke(255);
        fill(255);
        ellipse(400, 100, 45, 45);

        if (incomingValues.length <= maxSensors && incomingValues.length > 0) {
            //loop through each array element (each sensor output)
            for (int i = 0; i < incomingValues.length; i++) { 
            
                angle = incomingValues[0];
                x = -incomingValues[1]*25; //amplify 25x
                y = incomingValues[2]*25; //amplify 25x
                //re-map thumb and index finger flexion to values between 0 and 100
                //100 corresponds to no flexion and 0 to complete flexion
                //the ADC count from the fingers increase when flexed; the reverse is required
                index = abs(map(incomingValues[4], 0, 750, -100, 0));
                thumb = abs(map(incomingValues[5], 250, 655, -100, 0));
                fd = (index + thumb)/2; //use average of thumb and index finger flexion for finger distances
                
                //outline colour
                stroke(255);
                //vertical line

                line(x + x_offset,y + y_offset,x + x_offset - fd*sin(angle),y + 
                y_offset - fd*cos(angle));
                        //bottom line (thumb)
                        line(x + x_offset,y + y_offset,x + x_offset - fd*cos(angle),y + 
                y_offset + fd*sin(angle));
                        //top line (index finger)
                line(x + x_offset - fd*sin(angle),y + y_offset - fd*cos(angle),x + 
                x_offset - fd*sin(angle)- fd*cos(angle),y + y_offset - fd*cos(angle)+ 
                fd*sin(angle));
                        
                //if there is a change in position/orientation
                if ((angle != angle_old) || (x != x_old) || (y != y_old) || (fd != fd_old)) {
                    //create a black box around the old position to clear the old hand
                    stroke(0); //outline colour
                    fill(0); //fill colour
                    rect(x_old + x_offset-200,y_old + y_offset-200,400,400);
                              
                    //the black box shouldn't cover the circle so draw the circle again
                    stroke(255);
                    fill(255);
                    ellipse(400, 100, 45, 45);
                    
                    //set old values to current values
                    angle_old = angle;
                    x_old = x;
                    y_old = y;
                    fd_old = fd;
                 
                }       
            }
        }
    }
}
