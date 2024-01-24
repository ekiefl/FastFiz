/* AI.h
 * -------------------
 * Template header file for implementing an AI.
 */
#ifndef _AI_H_
#define _AI_H_


#include "Rules.h"
#include "AIBase.h"


class AI : public Pool::AIBase
{
  public:
    AI(libconfig::Config &config, Stopwatch *stopwatch): AIBase(config,stopwatch) {};
    virtual bool forGame(Pool::GameType gt) {return (gt==Pool::GT_EIGHTBALL);}
  protected:
    virtual void breakShot();
    virtual void otherShot();
    virtual Pool::Decision decide(); // optional

};

#endif