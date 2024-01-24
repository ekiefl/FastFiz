/* AI.h
 * -------------------
 * Template c++ file for implementing an AI.
 */

#include "AI.h"

void AI::breakShot()
{
  //sleep(3); /* time to think... */
  //for (long int i=1;i<100000000;i++) sqrt(i);
  shot.params.a=0.0;
  shot.params.b=8.0;
  shot.params.theta=5.0;
  shot.params.phi=275.0;
  shot.params.v=4.5;
  shot.cue_x=0.48;
  shot.cue_y=1.67705;
  //if (noise) cerr<<(*noise)<<endl;
}

void AI::otherShot()
{
  shot.decision=Pool::DEC_CONCEDE;
}

Pool::Decision AI::decide()
{
  return AIBase::decide();
}