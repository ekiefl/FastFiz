#include "FastFiz.h"
#include "Rules.h"
#include "LogFile.h"
#include <iostream>


using namespace Pool;


int main ( int argc, char **argv )
{
  long n=0;
  int bad=0;
  try
  {
   LogWriter lw("FFTest4.log",GT_EIGHTBALL,0,"Test Agent");
   TableState ots;
   ShotParams osp;
   while (1) {
    try
    {
      /*{
        ots.fromString("16 0.028575 1 0 0.60431381110930182388 0.59085294022396528391 0.028574999999999999706 1 1 0.55622573687054666092 0.55997160185468064508 0.028574999999999999706 1 2 0.5293589817771304773 0.50953054741636627512 0.028574999999999999706 1 3 0.16346078218488124811 1.6896475093815499502 0.028574999999999999706 1 4 0.5008320370176422287 0.46000948196868601814 0.028574999999999999706 1 5 0.55798515876694565474 0.46000872597724107305 0.028574999999999999706 1 6 0.61528147801696042585 0.4600792080360247005 0.028574999999999999706 1 7 0.47074608625385705452 0.40959998221734483792 0.028574999999999999706 1 8 0.52942227387421225693 0.41050810472711174448 0.028574999999999999706 1 9 0.58658305105015451364 0.41052811929876187325 0.028574999999999999706 1 10 0.64373322927768716895 0.41050972919932693372 0.028574999999999999706 1 11 0.23360592459913137597 0.047397392379312404398 0.028574999999999999706 1 12 0.50087529741192193811 0.36057364095802585391 0.028574999999999999706 1 13 0.5580747405245281012 0.36097821798710683083 0.028574999999999999706 1 14 0.86578021984754438556 0.83603555478215829666 0.028574999999999999706 1 15 1.0682771581544105999 0.48509451588213942097");
        TableState ts = ots;
        osp=ShotParams(0,0,25,81.091904119165576503,5);
        ts.executeShot(osp,true);
      }*/
      while (1){
      if (!(n%100)) {
        cerr << '.';
      }
      EightBallState es;
      //lw.write(es);
      TableState ts = es.tableState();
      ShotParams sp(0.0,0.0,25.0,270.0,5.0);
      ts.setBall(Ball::CUE,Ball::STATIONARY,0.48,1.67705);
      //lw.write(myGs,0);
      ots=ts; osp=sp;
      if (ts.isPhysicallyPossible(sp)==TableState::OK_PRECONDITION) {
        Shot *myShot=ts.executeShot (sp,false,true);n++;
        delete myShot;
      }
      //cerr << ts;
      ShotParams sp2(0.0,0.0,25.0,(360.0*rand())/RAND_MAX,5.0); // random direction
      ots=ts; osp=sp2;
      if (ts.isPhysicallyPossible(sp2)==TableState::OK_PRECONDITION) {
       Shot *myShot=ts.executeShot (sp2,false,true);
       delete myShot;
      }
      //cerr << ts;
     }
    }
    catch ( BadShotException e )
    {
      cout << "bad shot exception: " << e.getTypeString() << endl;
      cerr << ots << endl;
      cerr << osp << endl;
      lw.comment(e.getTypeString());
      lw.write(ots);
      lw.write(osp);
    }
    catch ( char const* c )
    {
      cout << c << endl;
      lw.comment(c);
      lw.write(ots);
      lw.write(osp);
      cerr << ots;
      cerr << osp;
    }
    catch ( ... )
    {
      cout << "an exception occured" << endl;
      lw.write(ots);
      lw.write(osp);
      cerr << ots;
      cerr << osp;
    }
    bad++;
    cerr << "n=" << n << ";bad=" << bad <<endl;
   }
  }
  catch ( char * c )
  {
    cout << c << endl;
  }
  catch ( ... )
  {
    cout << "exception in program" << endl;
  }
  return 0;
}

