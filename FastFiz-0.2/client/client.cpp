/* This is the client written for the Pool
 * client and servers.
 * Written by: Brennan Saeta
 * Under the supervision of: Alon Altman
 * Stanford University, Summer, 2009
 */
#include "Rules.h"
#include <stdio.h>
#include <libconfig.hh>
#include <string>
#include "Agent.h"
#include <map>
#include <xmlrpc.h>
#include <xmlrpc_client.h>
#include "../AI/AI.h"
#include <libconfig.hh>
#include "Stopwatch.h"
#include <sys/wait.h>

// Seconds to wait before assuming process hanged
#define HANG_TIMEOUT 1000 
#define RESTART_ITERATIONS 100

using namespace std;

enum ClientMode {CM_ERROR,CM_SINGLE,CM_LOOP,CM_LOOP_WAIT,CM_REGISTER,CM_FORK};

bool makechild() {
  int childpid=fork();
  if (childpid==-1) {
    perror("Cannot fork!");
    exit(1);
  } else if (!childpid) {
    return true; //child
  }
  return false; //parent
}

void syntaxerror (char * const argv[]) {
  cerr << "Usage: " <<argv[0] << " -u <XMLRPC endpoint url> [-c <config file>] [-m r|l|w|f|s] [-i <agenid>] [-p <password>] [-t r|c|v]" << endl
       << "  -c  Specify config file name. Default: client.conf" << endl
       << "  -u  Specify XMLRPC endpoint URL for server. Default: from config file" << endl
       << "  -m  Specify mode of execution: (r)egister and return id, (l)oop, (w)ait for shots, (s)ingle shot, (f)ork. Default: single" << endl
       << "  -t  Specify time model: (r)eal time, (c)pu time, (v)irtual time, (V)irtual time, sim steps. Default: Real Time" << endl
       << "  -i  Supply agentid (agent will not register)." << endl
       << "  -p  Specify password. Default: Supplied by AI." << endl
       << "  -f  Specify number of clients to fork in fork mode. Default: 1" << endl
       << "  -o  Owner ID for new agent (username or userid)." << endl;
  exit(2);
}

int main(int argc, char* const argv[]) {
  const char *conffn="client.conf";
  const char *endpoint=NULL;
  const char *password=NULL;
  Stopwatch* stopwatch=NULL;
  unsigned int agentid=0;
  unsigned int fork_count=1;
  unsigned long iter=RESTART_ITERATIONS;
  const char *ownerId=NULL;
  char c;
  ClientMode cm=CM_SINGLE;
  while ((c = getopt (argc, argv, "ht:c:u:i:m:p:f:o:")) != -1) {
    switch (c) {
      case 'h':
        syntaxerror(argv);
      case 'o': /* Owner id */
        ownerId=optarg;
        break;
      case 'c': /* Config file name */
        conffn=optarg;
        break;
      case 'u': /* XMLRPC endpoint */
        endpoint=optarg;
        break;
      case 'i': /* supply agentid */
        agentid=atoi(optarg);
        break;
      case 'f': /* supply agentid */
        fork_count=atoi(optarg);
        break;
      case 't': /* time model*/
        switch (optarg[0]) {
          case 'r':
            stopwatch=new RealTimeStopwatch(); break;
          case 'c':
            stopwatch=new CPUStopwatch(); break;
          case 'v':
            stopwatch=new VirtualStopwatch(); break;
          case 'V':
            stopwatch=new VirtualStopwatch2(); break;
          default:
            syntaxerror(argv); break;
        }
        break;
      case 'm': /* mode */
        switch (optarg[0]) {
          case 'f':
            cm=CM_FORK; break;
          case 'r':
            cm=CM_REGISTER; break;
          case 'l':
            cm=CM_LOOP; break;
          case 'w':
            cm=CM_LOOP_WAIT; break;
          case 's':
            cm=CM_SINGLE; break;
          default:
            syntaxerror(argv); break;
        }
        break;
      case 'p': /* password */
        password=optarg;
        break;
      default:
        syntaxerror(argv);
        break;
    }
  }

  if (!conffn) {
    syntaxerror(argv);
  }
  
  if (!stopwatch) {
    stopwatch=new RealTimeStopwatch(); 
  }
  
  libconfig::Config config;
  config.setAutoConvert(true);
  try {
    //cout << "Creating Config" << endl;
    config.readFile(conffn);
  } catch (libconfig::ParseException& e) {
    cerr << e.getError() << " in line " << e.getLine() << " of config file "<< conffn <<"." << endl;
    exit(1);
  } catch (libconfig::FileIOException& e) {
    cerr << "I/O error reading config file " << conffn << " (-h for help)" << endl;
    exit(1);
  };
  AI* myAI = new AI(config,stopwatch);
  string endpoint_str,pass_str,owner_str;
  if (endpoint) {
    endpoint_str=endpoint;
  } else {
    try {
      endpoint_str=(const char*)config.lookup("endpoint");
    } catch (libconfig::SettingNotFoundException& e) {
      cerr << "No XMLRPC endpoint specified (-h for help)" << endl;
      exit(1);
    }
  }
  if (password) {
    pass_str=password;
  } else {
    pass_str=myAI->getPassword();
  }
  if (ownerId) {
    owner_str=ownerId;
  } else {
    owner_str=myAI->getOwner();
  }
  Agent* agent;
  if (agentid) {
    agent=new Agent(myAI,endpoint_str,agentid,pass_str);
  } else {
    agent=new Agent(myAI,endpoint_str,conffn,pass_str,owner_str);
    cerr << "Agent registered. id = " << agent->agentID() << endl;
  }

  
  if (cm==CM_REGISTER) {
    exit(agent->agentID());
  }
  
  if (cm==CM_FORK) {
    for (int i=0;i<fork_count;++i) {
      if (makechild()) goto child;
    }
    // Parent
    while (1) {
      int status;
      int endedpid=wait(&status);
      if (endedpid==-1) {
        exit(0);
      } else {
        cerr << "Process " << endedpid << " ended with status " << status << endl;
        if (FILE * file = fopen("./STOP", "r")) { /* Stop condition */
          fclose(file);
        } else {
          if (makechild()) goto child;
        }
      }
    }
    exit(0);
  }
  
child:
  VirtualStopwatch vsw1;
  VirtualStopwatch2 vsw2;
  vsw1.restart();
  vsw2.restart();
  do {
    if (FILE * file = fopen("./STOP", "r")) { /* Stop condition */
      fclose(file);
      break;
    }
    //VirtualStopwatch vsw;
    //vsw.restart();
    bool shotDone=true;
    try {
      alarm(HANG_TIMEOUT);
      shotDone = agent->singleShot();
      alarm(0);
    } catch (girerr::error& e) {
      cerr << "XMLRPC error: " << e.what() << endl;
    } catch (char *e) {
      cerr << "String error: " << e << endl;
    }
    //cerr << (long)(vsw.getElapsed()/3e-3) << " simulations " << "Stopwatch: " << stopwatch->getElapsed() << endl;
    if (!shotDone) {cerr << "No more shots available" << endl;}
    if (!shotDone) {
      if (cm==CM_LOOP) break;
      if (cm==CM_LOOP_WAIT || cm == CM_FORK) sleep(5);
    }
    cerr << vsw1.getElapsed() << " <<< " << vsw2.getElapsed() << endl;
  } while (cm!=CM_SINGLE && (cm!=CM_FORK || --iter));  
  delete agent; delete myAI; delete stopwatch;
  return 0;
}
