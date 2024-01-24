/* Agent.cpp
 * ----------------
 * This file implements Agent.h
 * This is where the connections to register agents is implemented.
 * Written by: Brennan Saeta
 * Stanford, Summer 2009
 */

#include "Agent.h"
#include "Rules.h"
#include <libconfig.hh>
#include <xmlrpc-c/client_simple.hpp>
#include <xmlrpc-c/client.hpp>
#include <string>

using namespace std;

Agent::~Agent()
{
  return;
}

int Agent::registerAgent(string serverURL, string name, string config, string password, string ownerId)
{
  xmlrpc_c::clientSimple serverConnection;
  xmlrpc_c::value result;
  serverConnection.call(serverURL, "register_agent", "ssss", &result, name.c_str(),
                        config.c_str(), password.c_str(),ownerId.c_str());
  // Errors should throw an xmlrpc exception, that should be caught by client
  return xmlrpc_c::value_int(result);
}


/* This function contacts the server and asks for a shot.
 * If everything is successful, it returns 0, and stores the information in
 * the GameState _gs
 * If things don't work out, there are a couple error modes:
 * (1): there are no pending shots.
 * (2): there was an error with the server.
 */

bool Agent::submitShot(int gameid, int stateid, const Pool::GameShot & shot) {
  if (shot.decision == Pool::DEC_CONCEDE) {
    cerr << "Warning: Conceding game!" << endl;
  }
  
  cerr << gameid << " " << _id << " " << _password.c_str() << " " << stateid << " " << shot.params.a << " "
       << shot.params.b << " " << shot.params.theta << " " << shot.params.phi << " " << shot.params.v << " "
       << shot.cue_x << " " << shot.cue_y << " " <<  shot.ball << " " << shot.pocket << " " << shot.decision
       << " " << shot.timeSpent << endl;
  
  xmlrpc_c::clientSimple serverConnection;
  xmlrpc_c::value result;
  serverConnection.call(_serverURL, "submit_shot", "iisidddddddiiid", &result,
              gameid, _id, _password.c_str(), stateid, shot.params.a,
              shot.params.b, shot.params.theta, shot.params.phi, shot.params.v,
              shot.cue_x, shot.cue_y, shot.ball, shot.pocket, shot.decision, shot.timeSpent);
  xmlrpc_c::value_boolean const result_boolean(result);
  bool const resultStatus(static_cast<bool>(result_boolean));
  //cerr << "The status of the submission is: " << resultStatus << endl;
  return resultStatus;
}

/* This function handles a single shot.
 * It returns true if a shot was processed, and
 * false otherwise.
 */
bool Agent::singleShot()
{
  int stateid, gameid;
  Pool::GameState *gs;
  Pool::Noise *noise;
  if (!getShot(stateid, gameid,gs,noise)) return false;
  Pool::GameShot shot(_ai->computeShot(*gs, noise));
  while (!submitShot(gameid, stateid, shot)) {
    if (shot.decision == Pool::DEC_CONCEDE) throw "Server won't let me concede!";
    cerr << "Submit shot returned error, re-computing." << endl;
    shot=_ai->reComputeShot();
  }
  delete gs;
  delete noise;
  return true;  
}

bool Agent::getShot(int &stateid, int &gameid, Pool::GameState *& gs, Pool::Noise *& noise)
{
  /* Connect to the server, call the "get_shot" method. */
  xmlrpc_c::clientSimple serverConnection;
  xmlrpc_c::value result;
  serverConnection.call(_serverURL, "get_shot", "is", &result,
                        _id, _password.c_str());
  
  /* Extract the result xmlrpc_c::value first into a struct, then into a map. */
  xmlrpc_c::value_struct const result_struct(result);
  
  map<string, xmlrpc_c::value> gameStateMap(static_cast
      <map<string, xmlrpc_c::value> >(result_struct));
  
  const xmlrpc_c::value shot_avail_val=gameStateMap["shot_available"];
  const xmlrpc_c::value_boolean shot_avail_bool(shot_avail_val);
  bool const shot_avail(static_cast<bool>(shot_avail_bool));
  if (!shot_avail) return false;
  /* Store the State ID and the Game ID values to be used
  * when the shot is submitted.
  */
  const xmlrpc_c::value game_id_val=gameStateMap["gameid"];
  const xmlrpc_c::value_int game_id_int(game_id_val);
  int const game_id(static_cast<int>(game_id_int));
  gameid = game_id;
  
  const xmlrpc_c::value state_id_val=gameStateMap["stateid"];
  const xmlrpc_c::value_int state_id_int(state_id_val);
  int const state_id(static_cast<int>(state_id_int));
  stateid = state_id;
  
  /* Build a GameState. */
  const xmlrpc_c::value state_info_val=gameStateMap["state_info"];
  xmlrpc_c::value_string state_info_str(state_info_val);
  string const state_info(static_cast<string>(state_info_str));
  cerr << "Parsing game state from server: " << state_info << endl;
  gs = Pool::GameState::Factory(state_info);
  cerr << "Parsed gs is: " << *gs << endl;
  
  /* Get noise. */
  map<string, xmlrpc_c::value>::const_iterator itr(gameStateMap.find("noise_info"));
  if (itr !=  gameStateMap.end()) {
    xmlrpc_c::value_string noise_info_str(itr->second);
    string const noise_info(static_cast<string>(noise_info_str));
    noise = Pool::Noise::Factory(noise_info);
  } else {
    noise = NULL;
  }
 
  return true;
}
