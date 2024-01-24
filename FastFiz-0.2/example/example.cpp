/** Simple example of using the FastFiz library without writing an AI
 */
#include "FastFiz.h"
#include "Rules.h"
#include "LogFile.h"
#include <iostream>
#include <string>
#include <map>
#include <cstdlib>
#include <ctime>

using namespace Pool;

int main(int argc, char * const argv[]) {
  // Output version info
  cerr << getFastFizVersion() << endl;
  cerr << getRulesVersion() << endl;
  
  // Generate Gaussian noise using tournament values.
  GaussianNoise gn;
  
  // Create a new eight ball state with no time limits.
  EightBallState myState(0,0); 
  GameState& st = myState;
  cerr << "Initial racked Game State is: " << st << endl;
  
  // Start a log file
  LogWriter lw("example.log",GT_EIGHTBALL,&gn,"Example Agent");
  
  // A typical break shot
  GameShot myShot = {ShotParams(0.0,0.0,25.0,270.0,5.0), // Shot parameters
    0.48,1.67705, // Cue position
    Ball::UNKNOWN_ID,Table::UNKNOWN_POCKET, // No need to call ball/pocket
    DEC_NO_DECISION, // No decision to make.
    0.0}; // No time spent.
  
  // Noise is added, shot executed, and log written.
  ShotResult res = lw.LogAndExecute(st,myShot);
  
  cerr << "Shot result is: " << res << endl;
  
  if (res == SR_OK) { // If you kept your turn
    lw.write(st);
    srand ( time(NULL) );
    GameShot myNextShot = {
      ShotParams(0.0,0.0,25.0,(360.0*rand())/RAND_MAX,5.0), // random direction
      0.0, 0.0, // cue position not needed
      Ball::THREE,Table::SW, // call a ball and a pocket
      DEC_NO_DECISION, // No decision to make.
      0.0}; // No time spent.
    lw.write(myNextShot); // write shot to log file, even if not successful.
    res = st.executeShot(myNextShot); // Execute the shot on the table (no noise added).
    cerr << "Second shot result is " << res << endl;
  }
  
  lw.write(st);
  return 0;
}
