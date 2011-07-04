
#include "SoftwareSerial.h"
#include "SparkFunSerLCD.h"

SparkFunSerLCD lcd(2,2,16); // desired pin, rows, cols

void setup () {
  lcd.setup();
}

void loop () {
  delay(1000);
  lcd.at(1,2,"Who do I love?");
  delay(2000);
  lcd.off();
  delay(1000);
  lcd.on();
  lcd.at(2,3,"<3 Megan <3");
  delay(1000);
  lcd.empty();
}
