//From now on, just disable/enable serial here  //<>//
//you may still need to update your COM ports in the serialConfigure() calls below 
boolean fakeserial = true;

/*
  patterns2serial uses the movie2serial code and other code I've found around the web, 
 with a little bit of glue and a few patterns I've borrowed from older projects, 
 but it allows patterns to be drawn in processing.
 
 modified from movie2serial by Bob Eells, for use on L2Screen at Burning Flipside 2017.
 I'm fine with the license Paul used carrying over into this code as well.  Let's just 
 agree to not sue each other over blinky light code.
 */


/*  OctoWS2811 movie2serial.pde - Transmit video data to 1 or more
 Teensy 3.0 boards running OctoWS2811 VideoDisplay.ino
 http://www.pjrc.com/teensy/td_libs_OctoWS2811.html
 Copyright (c) 2013 Paul Stoffregen, PJRC.COM, LLC
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import processing.video.*;
import processing.serial.*;
import java.awt.Rectangle;

//Movie myMovie = new Movie(this, "/tmp/Toy_Story.avi");

PGraphics pg;
PGraphics pg_1;

int wp = 0; //wheel position, a counter that increments every draw, and cycles at 255.
float gamma = 1.7;

int numPorts=0;  // the number of serial ports in use
int maxPorts=24; // maximum number of serial ports

static int totalWidth = 600; //render width, you can bump this if you're not really writing to the display
static int totalHeight = 8;  //render height, you can bump this if you're not really writing to the display
static int max_pattern = 17; //actual pattern number of the final pattern in the list.
//static int total_images = 1; //set to one for a quick initial start, good for debugging and/or guess and check pattern coding.
static int total_images = 72; //one more than last name, since we index images on 0.

Serial[] ledSerial = new Serial[maxPorts];     // each port's actual Serial port
Rectangle[] ledArea = new Rectangle[maxPorts]; // the area of the movie each port gets, in % (0-100)
boolean[] ledLayout = new boolean[maxPorts];   // layout of rows, true = even is left->right

PImage[] ledImage = new PImage[maxPorts];      // image sent to each port

int[] gammatable = new int[256];
int errorCount=0;
float framerate=0;
boolean directionToggle = true;
int multiplier = 10;                           //used by text_test

PImage[] images = new PImage[total_images];    //array for our various image functions
PImage nowImage;                               //current image
PImage longImage;                              //only have one long image so far.
int current_pattern;

float angle=0;                                     //used by image_complex() 
float anglespeed=.01;                              //used by image_complex()
float anglemagnitude = 10;                         //used by image_complex() 

float angle2=0;                                    //used by image_complex()
float anglespeed2=.007;                            //used by image_complex()
float anglemagnitude2 = 300;                       //used by image_complex() 

void settings() {
  size(totalWidth, totalHeight);                   //set window size.
  framerate = 100;                                 //initial framerate
}

void setup() {
  String[] list = Serial.list();
  delay(20);
  println("Serial Ports List:");
  println(list);
  frameRate(framerate);  
  current_pattern = 17;
  for (int i=0; i<images.length; i++)
  {
    images[i] = loadImage("images/"+nf(i, 2)+".jpg");
  }
  longImage = loadImage("images/long01.jpg");

  nowImage = images[floor(random(images.length))];
  if (fakeserial)
  {
    fakeSerial(); //comment this out to stop faking serial connection, but uncomment the following and use the console to find your teensy ports.
  } else {
    serialConfigure("COM5");  // change these to your port names
    serialConfigure("COM6");  // change these to your port names
  }
  //  serialConfigure("/dev/ttyACM1");
  if (errorCount > 0) exit();
  for (int i=0; i < 256; i++) {
    gammatable[i] = (int)(pow((float)i / 255.0, gamma) * 255.0 + 0.5);
  }
  pg = createGraphics(totalWidth, totalHeight);
  pg.beginDraw();
  pg.background(0);
  pg.endDraw();
}

int j = 0; 
int k = 0;
int frequency = 1;
int oscillator = 0;
int x_wrap = 0;

// draw runs every time the screen is redrawn - show the pattern...
void draw() {
  //check our global speed variable.
  if (frequency != 0 && frameCount % frequency == 0)
  {
    callPattern(current_pattern);

    x_wrap = AddWithWrap(x_wrap, 1, pg.width);

    angle += anglespeed;
    if (angle >=6.28) angle = 0;
    angle2 += anglespeed2;
    if (angle2 >=6.28) angle2 = 0;

    if (wp < 255 && wp > -1)
    {
      wp++;
      oscillator = wp;
      if (directionToggle)
        oscillator = 255-wp;
    } else {
      directionToggle = ! directionToggle;
      if (random(5) < 2) anglespeed = -anglespeed;
      wp = 0;
    }               

    if (frameCount % 2000 == 0) {
      nowImage = images[floor(random(images.length))];
    }
  }



  for (int i=0; i < numPorts; i++) {
    // copy a portion of the screen's image to the LED image
    int xoffset = percentage(pg.width, ledArea[i].x);
    int yoffset = percentage(pg.height, ledArea[i].y);
    int xwidth =  percentage(pg.width, ledArea[i].width);
    int yheight = percentage(pg.height, ledArea[i].height);
    ledImage[i].copy(pg, xoffset, yoffset, xwidth, yheight, 
      0, 0, ledImage[i].width, ledImage[i].height);
    // convert the LED image to raw data
    byte[] ledData =  new byte[(ledImage[i].width * ledImage[i].height * 3) + 3];
    image2data(ledImage[i], ledData, ledLayout[i]);
    if (i == 0) {
      ledData[0] = '*';  // first Teensy is the frame sync master
      int usec = (int)((1000000.0 / framerate) * 0.75);
      ledData[1] = (byte)(usec);   // request the frame sync pulse
      ledData[2] = (byte)(usec >> 8); // at 75% of the frame time
    } else {
      ledData[0] = '%';  // others sync to the master board
      ledData[1] = 0;
      ledData[2] = 0;
    }
    // send the raw data to the LEDs  :-)
    if (!fakeserial) ledSerial[i].write(ledData);
    image(pg, 0, 0, totalWidth, totalHeight);
  }
}

//Patterns
void image_scroller(PImage img)
{
  pg.beginDraw();
  pg.image(img, 0-1200+oscillator*3, 0, img.width, img.height);
  pg.endDraw();
}

void image_zoomer(PImage img)
{
  pg.beginDraw();
  pg.image(img, 0-oscillator, 0-oscillator, img.width+oscillator*2, img.height+oscillator*2);  
  pg.endDraw();
}

void image_shaker(PImage img)
{
  pg.beginDraw();
  pg.image(img, 0-random(oscillator), 0-random(oscillator), img.width, img.height);
  pg.endDraw();
}

void image_panner(PImage img)
{
  pg.beginDraw();
  pg.image(img, 0-oscillator, 0-oscillator, img.width, img.height);
  pg.endDraw();
}

//void image_bounce(PImage img)
//simple up/down animation
void image_bounce(PImage img)
{
  pg.beginDraw();  
  int h_multiplier = img.height / 255;
  if (directionToggle)
  {
    pg.image(img, 0, 0-wp*h_multiplier, pg.width, img.height);
  } else {
    pg.image(img, 0, 0-255*h_multiplier+wp*h_multiplier, pg.width, img.height);
  }
  //pg.background(photo);
  pg.endDraw();
}

//void image_complex(PImage img) {
// A more "refined" image handler, by Chainsaw.
void image_complex(PImage img) {
  pg.beginDraw();
  pg.image(img, 0-anglemagnitude*(1+sin(angle)), 0-anglemagnitude*(1+cos(angle)));
  pg.translate(width/2-anglemagnitude*(1+sin(angle)), height/2-anglemagnitude*(1+cos(angle)));
  pg.rotate(angle);
  pg.image(img, 0-anglemagnitude*(1+sin(angle)), 0-anglemagnitude*(1+cos(angle)), img.width + anglemagnitude2*(1+sin(angle2)), img.height+ anglemagnitude2*(1+cos(angle2)));
  pg.endDraw();  
  for (int x = 0; x < pg.width; x++) {
    for (int y = 0; y < pg.height; y++ ) {
      int loc = x + y*pg.width;
      // Rotate hue by amount given in wheel
      pg.pixels[loc]  =color((hue(pg.pixels[loc]) + wp )%256, saturation(pg.pixels[loc]), brightness(pg.pixels[loc]));  // White
    }
  }
}

//void text_test()
//trying this out.  Caution: if you're going to use this, there's a lot to think about.
//political and technical
//political example: public perception based on what we write/allow written
//technical example: Not sure this is going to display right anyway.
void text_test()
{
  pg.beginDraw();
  pg.smooth();
  pg.background(0);
  pg.fill(255);
  pg.textAlign(CENTER, CENTER);
  int multiplier = pg.width / 255;
  pg.text("Hello World!", pg.width-wp*multiplier, pg.height/4);
  pg.endDraw();
}

//runs a circle around the ring
void play_ball() {
  pg.beginDraw();
  pg.fill(wheel_r(wp), wheel_g(wp), wheel_b(wp));
  pg.ellipse(x_wrap, 4, 8, 8);
  pg.endDraw();
}

//draws a bunch of random ovals.  Mostly just playing with shapes.
void ellipses() {
  pg.beginDraw();
  pg.smooth();
  pg.fill(random(255), random(255), random(255));
  pg.ellipse(random(pg.width), random(pg.height), random(20), random(20));
  pg.endDraw();
}

//void rand_columns(int number_to_draw){
//lights a randomized number of columns (0 to number_to_draw)
//number to draw
void rand_columns(int number_to_draw) {
  pg.beginDraw();
  //pg.background(0);
  pg.stroke(random(255), random(255), random(255), 100);
  for (int l=0; l< (int) random(number_to_draw); l++)
  {
    int k = (int) random(0, pg.width);
    pg.line(k, 0, k, pg.height);
  }
  pg.endDraw(); 
  if (j < pg.width) {
    j++;
  } else {
    j = 0;
  }
}

//void rand_dots(int number_to_draw){
//lights a randomized number of pods (0 to number_to_draw)
//with a random color.
void rand_dots(int number_to_draw) {
  pg.beginDraw();
  for (int l = 0; l < (int) random(number_to_draw); l++) {
    int x = (int) random(0, pg.width);
    int y = (int) random(0, pg.height);
    pg.stroke(random(255), random(255), random(255), 100);
    pg.point(x, y);
  }
  pg.endDraw();
}

//void stroke(int number_of_strokes, int distance, int max_r, int max_g, int max_b){
//special shoutout to jsonpoindexter, who made us realize we could make this go with this commit:
//https://github.com/jsonpoindexter/PGraphics/commit/39a6b33dcfa50162aa44faa7e8374964029c4bea
//todo: fix bug in number_of_strokes.
void stroke(int number_of_strokes, int distance, int max_r, int max_g, int max_b) {
  for (int k=0; k<number_of_strokes; k++)
  {
    int k_offset = 0;
    if (k != 0 && number_of_strokes != 0) {
      k_offset = pg.width / number_of_strokes;
    }
    pg.beginDraw();
    pg.strokeWeight(3);
    pg.background(0);
    pg.stroke(random(max_r), random(max_g), random(max_b), 100);
    int point_x = AddWithWrap(j, k_offset, pg.width);
    int r1 = int(random(distance));
    int r2 = int(random(distance));
    int sw = SubtractWithWrap(point_x, r1, pg.width);
    int aw = AddWithWrap(point_x, r2, pg.width);
    pg.line(j+k_offset, 0, random(sw, aw), pg.height);
    pg.endDraw();
  }
  if (j < pg.width) {
    j++;
  } else {
    j = 0;
  }
}

//void rain_columns(){
//progressively sends a rainbow wheel around the ring
void rain_columns() {
  pg.beginDraw();
  color c = Wheel(wp);
  pg.stroke(c);
  pg.line(j, 0, j, pg.height);
  pg.endDraw(); 
  if (j < pg.width) {
    j++;
  } else {
    j = 0;
  }
}

//void rain_columns_smooth(){
//progressively sends a rainbow wheel around the ring
void chase() {
  pg.beginDraw();
  pg.background(0);
  Wheel(pg,x_wrap);
  pg.line(x_wrap,0,x_wrap,8);
  pg.endDraw(); 
}

//void rainbros(){
//paints the whole screen with a rainbow (ROYGBIVW) Top->Bottom, one color per row.
void rainbros() {
  pg.beginDraw();
  //pg.background(0);
  pg.stroke(255, 0, 0, 100);
  pg.line(0, 0, pg.width, 0);
  pg.stroke(255, 165, 0, 100);
  pg.line(0, 1, pg.width, 1);
  pg.stroke(255, 255, 0, 100);
  pg.line(0, 2, pg.width, 2);
  pg.stroke(0, 255, 0, 100);
  pg.line(0, 3, pg.width, 3);
  pg.stroke(0, 0, 255, 100);
  pg.line(0, 4, pg.width, 4);
  pg.stroke(75, 0, 130, 100);
  pg.line(0, 5, pg.width, 5);
  pg.stroke(238, 130, 238, 100);
  pg.line(0, 6, pg.width, 6);
  pg.stroke(255, 255, 255, 100);
  pg.line(0, 7, pg.width, 7);

  pg.endDraw();
}

//void fireflies(int fade_amount, int r, int g, int b){
//simulate fireflies
//fade_amount is a percentage
void fireflies(int fade_amount, int r, int g, int b) {
  pg.strokeWeight(1);  
  pg.beginDraw();
  pg.stroke(r, g, b);
  pg.point(random(pg.width), random(pg.height));
  fade(fade_amount);  
  pg.endDraw();
}

//void randy(int fade_amount)
//randy accepts:
// a fade amount (% to fade towards black each frame) 
void randy(int fade_amount) {
  pg.beginDraw();
  pg.stroke(random(255), random(255), random(255));
  pg.point(random(pg.width), random(pg.height));
  fade(fade_amount);  
  pg.endDraw();
}

//sets a random row to a random color
void rand_rows() {
  pg.beginDraw();
  pg.stroke(random(255), random(255), random(255), 100);
  int row = (int) random(pg.height);
  pg.line(0, row, pg.width, row);
  pg.endDraw();
}

//void rainbow_fade_all()
//set the entire screen to a rotating colorwheel, all pixels same fade
void rainbow_fade_all()
{
  pg.beginDraw();
  int r = wheel_r(wp);
  int g = wheel_g(wp);
  int b = wheel_b(wp);
  pg.background(r, g, b);
  pg.endDraw();
}

//End of patterns.


//Helpful tools follow

void mouseClicked() {
  if (mouseX < pg.width / 2) {
    current_pattern--;
    if (current_pattern < 0)
      current_pattern = max_pattern;
  } else {
    current_pattern++;
    if (current_pattern > max_pattern)
      current_pattern = 0;
  }
}

void callPattern(int pattern_number) {
  //default all patterns to normal speed
  frequency = 1;
  //and RGB (HSB colormodes must be changed in their switch case)
  pg.colorMode(RGB);
  //and Image Mode LEFT
  pg.imageMode(CORNER); 
  
  

  switch(pattern_number) {
  case 0 :
    rainbros();
    break;
  case 1 :
    image_zoomer(nowImage);
    break;
  case 2 : 
    frequency = 5;
    image_shaker(nowImage);
    break;
  case 3 :
    image_bounce(nowImage);
    break;
  case 4 :
    rand_columns(wp);
    break;
  case 5 :
    ellipses();
    fade(20);
    break;
  case 6 : 
    text_test();
    break;
  case 7 : 
    rand_dots(100000);
    break;
  case 8 : 
    stroke(1, 50, 255, 255, 255);
    break;
  case 9 : 
    rain_columns();
    break;
  case 10 :
    frequency = 3;
    image_panner(nowImage);
    break;
  case 11 :
    fireflies(20, 0, 255, 0);
    break;
  case 12 :
    randy(20);
    break;
  case 13 : 
    rainbow_fade_all();
    break;      
  case 14:
    play_ball();
    off();
    break;
  case 15:
    frequency = 4;
    image_scroller(longImage);
    break;
  case 16:
    pg.colorMode(HSB);    
    pg.imageMode(CENTER); 
    image_complex(nowImage);
    break;
  case 17:
    pg.stroke(0,255,0);
    chase();
  default :
    off();
    break;
  }
}

//nope, not gonna document this any further
void off() {
  pg.beginDraw();
  //pg.background(0);
  pg.stroke(0, 0, 0, 100);
  pg.line(0, k, pg.width, k);
  pg.endDraw(); 
  if (k < pg.height) {
    k++;
  } else {
    k = 0;
  }
}

//set everything to a color 
void all(int r, int g, int b, int t) {
  pg.beginDraw();
  pg.background(r, g, b, t);
  pg.endDraw(); 
  /*
  pg.stroke(r,g,b, t);
   pg.line(0, k, pg.width, k);
   if (k < pg.height) {
   k++;
   } else {
   k = 0; 
   }
   */
}

//void fade(int howMuch) 
//how much is the percent transparency of the black layer being drawn in 
void fade(int howMuch)
{
  pg.beginDraw();
  pg.stroke(0, 0, 0, howMuch);
  for (int i=0; i<pg.height; i++)
  {
    pg.line(0, i, pg.width, i);
  }
  pg.endDraw();
}


//Get a nice rotating colorwheel.  Adapted from adafruit's Neopixel library.
//Fixed by chainsaw, since Bob can't math.
void Wheel(PGraphics p, int WheelPos) {
  int pos=WheelPos;
  if (pos < 85) {
    p.stroke(255-pos * 3, 0, pos * 3);
  } else if (pos < 170) {
    pos = pos - 85;
    p.stroke(0, pos * 3, 255 - pos * 3);
  } else if (pos > 169) {
    pos = pos - 170;
    p.stroke(pos * 3, 255 - pos * 3, 0);
  }
}

//Get a color from wheel instead.
color Wheel(int WheelPos) {
  int pos=WheelPos;
  color c = color(0);
  if(pos < 85) {
    c= color(255-pos * 3, 0, pos * 3);
  }
  else if(pos < 170) {
    pos = pos - 85;
    c=color(0, pos * 3, 255 - pos * 3);
  }
  else if(pos > 169) {
    pos = pos - 170;
    c=color(pos * 3, 255 - pos * 3, 0);
  }
  return c;
}

//return specific components from Wheel, 
//useful if you need the r,g,b values instead of stroke set for you
int wheel_r(int WheelPos) {
  int pos = WheelPos;
  int r = 0;
  if (pos < 85) {
    r = 255-pos * 3;
  } else if (pos < 170)
  {
    r = 0;
  } else if (pos > 169) {
    pos = pos-170;
    r = pos * 3;
  }
  return r;
}

//return specific components from Wheel, 
//useful if you need the r,g,b values instead of stroke set for you
int wheel_g(int WheelPos) {
  int pos = WheelPos;
  int g = 0;
  if (pos < 85) {
    g = 0;
  } else if (pos < 170)
  {
    pos = pos - 85;
    g = pos * 3;
  } else if (pos > 169) {
    pos = pos - 170;
    g = 255 - pos * 3;
  }
  return g;
}

//return specific components from Wheel, 
//useful if you need the r,g,b values instead of stroke set for you
int wheel_b(int WheelPos) {
  int pos = WheelPos;
  int b = 0;
  if (pos < 85) {
    b = pos * 3;
  } else if (pos < 170)
  {
    pos = pos - 85;
    b = 255 - pos * 3;
  } else if (pos > 169) {
    pos = pos - 170;
    b = 0;
  }
  return b;
}

// image2data converts an image to OctoWS2811's raw data format.
// The number of vertical pixels in the image must be a multiple
// of 8.  The data array must be the proper size for the image.
void image2data(PImage image, byte[] data, boolean layout) {
  int offset = 3;
  int x, y, xbegin, xend, xinc, mask;
  int linesPerPin = image.height / 8;
  int pixel[] = new int[8];

  for (y = 0; y < linesPerPin; y++) {
    if ((y & 1) == (layout ? 0 : 1)) {
      // even numbered rows are left to right
      xbegin = 0;
      xend = image.width;
      xinc = 1;
    } else {
      // odd numbered rows are right to left
      xbegin = image.width - 1;
      xend = -1;
      xinc = -1;
    }
    for (x = xbegin; x != xend; x += xinc) {
      for (int i=0; i < 8; i++) {
        // fetch 8 pixels from the image, 1 for each pin
        pixel[i] = image.pixels[x + (y + linesPerPin * i) * image.width];
        pixel[i] = colorWiring(pixel[i]);
      }
      // convert 8 pixels to 24 bytes
      for (mask = 0x800000; mask != 0; mask >>= 1) {
        byte b = 0;
        for (int i=0; i < 8; i++) {
          if ((pixel[i] & mask) != 0) b |= (1 << i);
        }
        data[offset++] = b;
      }
    }
  }
}

// translate the 24 bit color from RGB to the actual
// order used by the LED wiring.  GRB is the most common.
int colorWiring(int c) {
  int red = (c & 0xFF0000) >> 16;
  int green = (c & 0x00FF00) >> 8;
  int blue = (c & 0x0000FF);
  red = gammatable[red];
  green = gammatable[green];
  blue = gammatable[blue];
  return (green << 16) | (red << 8) | (blue); // GRB - most common wiring
}

// ask a Teensy board for its LED configuration, and set up the info for it.
void serialConfigure(String portName) {
  if (numPorts >= maxPorts) {
    println("too many serial ports, please increase maxPorts");
    errorCount++;
    return;
  }
  try {
    ledSerial[numPorts] = new Serial(this, portName);
    if (ledSerial[numPorts] == null) throw new NullPointerException();
    ledSerial[numPorts].write('?');
  } 
  catch (Throwable e) {
    println("Serial port " + portName + " does not exist or is non-functional");
    errorCount++;
    return;
  }
  delay(50);
  String line = ledSerial[numPorts].readStringUntil(10);
  if (line == null) {
    println("Serial port " + portName + " is not responding.");
    println("Is it really a Teensy 3.0 running VideoDisplay?");
    errorCount++;
    return;
  }
  String param[] = line.split(",");
  if (param.length != 12) {
    println("Error: port " + portName + " did not respond to LED config query");
    errorCount++;
    return;
  }
  // only store the info and increase numPorts if Teensy responds properly
  ledImage[numPorts] = new PImage(Integer.parseInt(param[0]), Integer.parseInt(param[1]), RGB);
  ledArea[numPorts] = new Rectangle(Integer.parseInt(param[5]), Integer.parseInt(param[6]), 
    Integer.parseInt(param[7]), Integer.parseInt(param[8]));
  ledLayout[numPorts] = (Integer.parseInt(param[5]) == 0);
  numPorts++;
  //println(Integer.parseInt(param[0]));
}

// scale a number by a percentage, from 0 to 100
int percentage(int num, int percent) {
  double mult = percentageFloat(percent);
  double output = num * mult;
  return (int)output;
}

// scale a number by the inverse of a percentage, from 0 to 100
int percentageInverse(int num, int percent) {
  double div = percentageFloat(percent);
  double output = num / div;
  return (int)output;
}

// convert an integer from 0 to 100 to a float percentage
// from 0.0 to 1.0.  Special cases for 1/3, 1/6, 1/7, etc
// are handled automatically to fix integer rounding.
double percentageFloat(int percent) {
  if (percent == 33) return 1.0 / 3.0;
  if (percent == 17) return 1.0 / 6.0;
  if (percent == 14) return 1.0 / 7.0;
  if (percent == 13) return 1.0 / 8.0;
  if (percent == 11) return 1.0 / 9.0;
  if (percent ==  9) return 1.0 / 11.0;
  if (percent ==  8) return 1.0 / 12.0;
  return (double)percent / 100.0;
}

//pretend we're an L2Screen installation and allow us to write to a monitor only
void fakeSerial() {
  ledImage[numPorts] = new PImage(300, 8, RGB);
  ledArea[numPorts] = new Rectangle(0, 0, 50, 100);
  ledLayout[numPorts] = false;
  numPorts++; 
  ledImage[numPorts] = new PImage(300, 8, RGB);
  ledArea[numPorts] = new Rectangle(0, 0, 0, 50);
  ledLayout[numPorts] = true;
  numPorts++;   
  fakeserial=true;
}

//int AddWithWrap(int a, int b, int wrap_at){
// adds with a wraparound
// int a = number to be added
// int b = number to be added
// int wrap_at = number to wrap beyond
int AddWithWrap(int a, int b, int wrap_at) {
  if (a+b < wrap_at)
  {
    return a+b;
  }
  return (a+b)-wrap_at;
}

//int SubtractWithWrap(int a, int b, int wrap_at){
// subtracts with a wraparound
// int a = number being subtracted from
// int b = number being subtracted
// int wrap_at = number to wrap beyond

int SubtractWithWrap(int a, int b, int wrap_at) {
  if (a-b > 0)
  {
    return a-b;
  }
  return (wrap_at+a)-b;
}