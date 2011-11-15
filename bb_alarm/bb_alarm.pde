#include "Wire.h"
#include "BlinkM_funcs.h"

//--- Define the output pins
#define ledPin 13

//--- BlinkM Definitions
byte blinkm_addr = 0x09;
int h, s, b;

//--- Other globals
float max_val = 10.0;

//--- Function to read in float
float readFloatFromBytes() {
  union u_tag {
    byte b[4];
    float val;
  } u;
  u.b[0] = Serial.read();
  u.b[1] = Serial.read();
  u.b[2] = Serial.read();
  u.b[3] = Serial.read();
  return u.val;
}

//--- Set colors based on a given value
void setColor(float val)
{
  // Hue is a number between 0.0 and 360.0
  // BlinkM takes color values from 0 to 255
  // We want colors to start at Blue and go to Red
  // Red is 0 and Blue is 240/360*255 = 170.
  // Because we want lower value to be Blue
  // and the higher magnitude to be Red we must
  // reverse the values.  Thus the following equation.
  h = int(170.0 * (val/max_val));
  s = 0xff; // Full Saturation
  b = 0xff; // Full Brightness
}

//--- Set the alarm
void alarm(float val)
{
  // Fix the limits of val between 0.0 and max_val
  if(val < 0.0)
  {
    val = 0.0;
  }
  else if(val > max_val)
  {
    val = max_val;
  }

  // Turn on the lights and motors
  digitalWrite(ledPin, HIGH);
  setColor(val);
  BlinkM_fadeToHSB(blinkm_addr, h, s, b);
  
  // Wait for 10 seconds equal
  delay(int(2.0 * 1000));
  
  // Turn off the lights and motors
  digitalWrite(ledPin, LOW);
  BlinkM_setRGB(blinkm_addr, 0x00, 0x00, 0x00);
}

void setup()
{
  // Initialize the serial port
  Serial.begin(19200);
  
  // Initialize the output pins
  pinMode(ledPin, OUTPUT);
  
  // Initialize the BlinkM
  BlinkM_beginWithPower();
  BlinkM_setFadeSpeed(blinkm_addr, 255);
  BlinkM_stopScript(blinkm_addr);
  
  // Color Startup
  for(float i = 0.0; i <= max_val; i=i+0.01){
    setColor(i);
    BlinkM_fadeToHSB(blinkm_addr, h, s, b);
    delay(2);
  }
  
  // Startup Test
  alarm(10.0);
}

void loop()
{
  // Wait until all 4 bytes are available
  if(Serial.available() == 4)
  {
    // Get the value and set the color
    float val = readFloatFromBytes();
    alarm(val);
    
    // Send a response back to python
    Serial.println(val);
  }
}
