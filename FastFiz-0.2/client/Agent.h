/* Agent.h
 * ----------------
 * Written by: Brennan Saeta
 * Stanford, Summer 2009
 */

#ifndef _AGENT_H_
#define _AGENT_H_

#include <string>
#include <stdio.h>
#include <xmlrpc-c/client_simple.hpp>
#include <libconfig.hh>
#include "Rules.h"
#include "AIBase.h"

using namespace std;


class Agent {
  public:
    Agent(Pool::AIBase* ai, string serverURL, int id,string password):
      _password(password), _id(id), _ai(ai), _serverURL(serverURL) {};

    Agent(Pool::AIBase* ai, string serverURL, string config, string password, string owner = ""):
      _password(password), _id(registerAgent(serverURL,ai->getName(),config,password,owner)), _ai(ai), _serverURL(serverURL) {};

    ~Agent();
    
    
    int agentID() {
      return _id;
    }
    
    /** Run a single shot. Returns true iff a shot was processed */
    bool singleShot();
    

  private:
    string _password;
    
    int _id;
    Pool::AIBase *_ai;
    string _serverURL;
    
    /** Ask server for shot, return true if shot is available.
        Shot information is returned via passed parameters.
      */
    bool getShot(int& stateid, int& gameid, Pool::GameState*& gs, Pool::Noise*& noise);
    
    /** Submit a shot to server. stateid and gameid identify the shot,
        shot is the actual paramters to send. Returns true on success,
        false if shot could not be processed.
      */
    bool submitShot(int stateid, int gameid, const Pool::GameShot & shot);
    
    static int registerAgent(string serverURL, string name, string config, string password, string ownerId);
    
};





#endif