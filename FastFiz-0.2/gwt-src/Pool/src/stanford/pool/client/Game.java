package stanford.pool.client;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Vector;

import stanford.pool.client.Pool.loadedCallback;

import com.fredhat.gwt.xmlrpc.client.XmlRpcRequest;
import com.fredhat.gwt.xmlrpc.client.XmlRpcClient;
import com.google.gwt.user.client.rpc.AsyncCallback;

// coltext



public class Game {
	/*
	 * enum BallType { CUE, ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, 
                NINE, TEN, ELEVEN, TWELVE, THIRTEEN, FOURTEEN,
                FIFTEEN, UNKNOWN_ID };
	 */
	//pool constants

	public boolean gameLoaded;

	private int numBalls;

	private final static int NOTINPLAY = 0;
	private final static int STATIONARY = 1;
	private final static int SPINNING = 2;
	private final static int SLIDING = 3;
	private final static int ROLLING = 4;
	private final static int POCKETED_SW = 5;
	private final static int POCKETED_W = 6;
	private final static int POCKETED_NW = 7;
	private final static int POCKETED_NE = 8;
	private final static int POCKETED_E = 9;
	private final static int POCKETED_SE = 10;
	private final static int SLIDING_SPINNING = 11;
	private final static int ROLLING_SPINNING = 12;
	private final static int UNKNOWN_STATE = 13;

	private final static double mu_r = .015;//rolling
	private final static double mu_s = 0.2; //sliding
	private final static double mu_sp = .044; //spinning
	private final static double radius = 0.028575; 
	private final static double EPSILON = 1e-7;
	private final static double g = 9.81;

	private final static double length = 2.236;
	private final static double width = 1.116;

	private ArrayList gameArr;

	private double gameTime;
	/* Width: 1.116
	Head String: 1.677
	Cue Length: 1.45
	Rail Height: 0.040005
	Mu Sliding: 
	Mu Rolling: 0.015
	Mu Spinning: 0.044
	Ball Radius: 
	 */

	private Vector<Shot> nl_shot; //Array of all of the noiseless shots
	private Vector<Shot> shot; //Shot array of all the shots to be displayed in sequence
	public double[] shotStarts; //Times each shot begins--public for use in display by applet
	private String gameID; //Which game from database to display
	private String gameURL;
	private int numShots;
	private int numLoadedShots;
	public loadedCallback ldr;
	
	/* Based on the number of balls and appropriate game
	 * 
	 */
	public Game(int numBalls, String gameID, String gameURL, loadedCallback loader)
	{
		this.numBalls = numBalls;
		this.gameID = gameID;
		this.gameURL = gameURL;
		gameLoaded = false;
		numLoadedShots = 0;
		numShots = 0;
		ldr = loader;
		collectInformation();
	}

	public int getNumShots()
	{
		return numShots;
	}
	
	public void collectInformation() {
		shot = new Vector<Shot>();
		nl_shot = new Vector<Shot>();
		qGame();


		//This code adds in an extra even for sliding balls where needed due to poolfiz error
		//		int shotCount = 0; //for debugging
		//		for(Shot s: shot)
		//		{
		//		//	System.out.println("Shot number: " + shotCount);
		//			shotCount++;
		//			for(Vector<BallShift> ball: s.ball)
		//			{
		//				for(int i = 0; i < ball.size(); i++)
		//				{
		//					BallShift b = ball.get(i);
		//					if(b.state == SLIDING)
		//					{
		//					     //Equation (11) in Leckie/Greenspan
		//					     double u_o = v_mag(v_add(b.v, v_mult(radius, v_cross(v_from(0, 0, 1), b.w))));
		//					     double duration = 2*u_o/(7*mu_s*g);
		//					     if(i < ball.size() + 1)
		//					     {
		//					    	 BallShift nextBall = ball.get(i + 1);
		//					    	 if(b.ballID==0)
		//		//			    	 	System.out.println("Checking to add event at time " + b.time); //debug
		//					    	 if(nextBall.time > b.time + duration)
		//					    	 {
		//		//			    		System.out.println("Event added for ball " + b.ballID + " at time " + b.time); //debug
		//					    		BallShift newEvent = new BallShift();
		//					    		newEvent.ballID = b.ballID;
		//					    		newEvent.time = b.time;
		//					   		  	newEvent.r = new fizPoint(b.r.x, b.r.y);
		//					   		  	newEvent.v = new fizVector(b.v.x, b.v.y, b.v.z);
		//					   		  	newEvent.w = new fizVector(b.w.x, b.w.y, b.w.z);
		//					   		  	newEvent.state = ROLLING;
		//					   		  	generateNewEvent(newEvent, duration);
		//					   		  	ball.insertElementAt(newEvent, i + 1);
		//					    	 }
		//					     }
		//					 }
		//				}
		//			}
		//		}
	}

	/* Used to generate extra events left out in poolfiz error
	 * 
	 */
	public void generateNewEvent(BallShift b, double duration)
	{
		double t = duration;

		// double t = newTime - oldTime;
		fizVector u_o;

		fizPoint new_r = new fizPoint(b.r.x, b.r.y);
		fizVector new_v = new fizVector(b.v.x, b.v.y, b.v.z);
		fizVector new_w = new fizVector(b.w.x, b.w.y, b.w.z);

		double cos_phi = 1.0, sin_phi = 0.0;
		if(v_mag(b.v) > 0)
		{
			//Used for shifting in and out of a ball-centric reference frame
			cos_phi = v_norm(b.v).x;
			sin_phi = v_norm(b.v).y;

			//Rotate by -phi; v should end up along the x-axis, so the equations will work
			b.v = v_rotate(b.v, cos_phi, -sin_phi);
			b.w = v_rotate(b.w, cos_phi, -sin_phi);
		}


		u_o = v_norm(v_add(b.v, v_mult(radius, v_cross(v_from(0, 0, 1), b.w))));
		// System.out.println("V: (" + b.v.x + ", " + b.v.y + ", " + b.v.z + ")");
		// System.out.println("Value of t: " + t);

		new_r.x = v_mag(b.v)*t - (0.5)*mu_s*g*t*t*u_o.x;

		new_r.y = -(0.5)*mu_s*g*t*t*u_o.y;
		//	        if(new_r.y<-3||new_r.x<-3)
		//	        // System.out.println("subtracting: "+ v_mag(b.v)*t + " - " + (0.5)*mu_s*g*t*t*u_o.x);
		new_v = v_add(b.v, v_mult(-mu_s*g*t, u_o));
		new_w = v_add(b.w, v_mult(-(5.0*mu_s*g)/(2.0*radius)*t, v_cross(u_o, v_from(0, 0, 1))));
		new_w.z = updateSpinning(b.w.z, t, mu_sp, radius, true);

		new_r = p_rotate(new_r, cos_phi, sin_phi);
		b.r = p_add(b.r, new_r);
		b.v = v_rotate(new_v, cos_phi, sin_phi);
		b.w = v_rotate(new_w, cos_phi, sin_phi);
		b.time = b.time + duration;

	}



	/* For display use
	 *@param shot
	 *@return end time of shot 
	 */
	public double getEndTime(int shotID) //should take parameter of which shot
	{
		if(shot == null || shot.get(shotID)==null)
			return 0;
		else
			return shot.get(shotID).getEndTime();
	}

	/*
	 * @return total time of shot array
	 */
	public double getGameTime()
	{
		return gameTime;
	}

	/* Initialized the array of shot start times based on collected information
	 * 
	 */

	/* Tells which shot to display at the given time
	 * @param time
	 * @return int shotID
	 */
	public int getShotAtTime(double time) //should take parameter of which shot
	{
		double totalTime = 0;
		for(int i = 0; i< shot.size(); i++)
		{
			totalTime+=getEndTime(i);
			if(time<=totalTime)
				return i;
		}
		return shot.size() - 1;
	}

	public double getShotEndTime(int shotID, boolean withoutNoise)
	{
		if(withoutNoise){
			return nl_shot.get(shotID).getEndTime();
		}
		else{
			return shot.get(shotID).getEndTime();
		}
	}
	
	public void resetShotStarts()
	{
		shotStarts = new double[shot.size()];
		
		for(int i = 1; i < shotStarts.length; i++)
		{
			if(shot.get(i).loaded)
				shotStarts[i] = shotStarts[i - 1] + getEndTime(i - 1);
		}
		gameTime = shotStarts[shot.size() - 1] + getEndTime(shot.size() - 1);
	}

	public int getCalledBall(int shotID)
	{
		if(shotID == 0){
			//Break shot, return -1
			return -1;
		}
		if((shotID < 0) || (shotID > shot.size())){
			return -1;
		}
		return shot.get(shotID).calledBall;
	}
	
	public int getCalledPocket(int shotID)
	{
		if(shotID == 0){
			//Break shot, return -1
			return -1;
		}
		if((shotID < 0) || (shotID > shot.size())){
			return -1;
		}
		return shot.get(shotID).calledPocket;
	}
	
	
	/* returns an array with the locations of each ball at the given time in the given shot
	 * @param int shot
	 * @param double time
	 * @return fizPoint[] state at given shot + time
	 */
	public fizPoint[] getState(int shotID, double time, boolean withoutNoise)  //will add param shot
	{
	//	ballShiftStr = "";
		fizPoint[] state = new fizPoint[numBalls];

		for(int i = 0; i < numBalls; i++)
		{
			int lastEventIndex = getEventIndex(shotID, i, time, withoutNoise);
			BallShift lastEvent;
			//	// System.out.println("For ball " + i + " event " + lastEventIndex);
			if(lastEventIndex==-1) {
				if(withoutNoise){
					lastEvent = nl_shot.get(shotID).ball.get(i).get(0);
				}
				else{
					lastEvent = shot.get(shotID).ball.get(i).get(0);
				}
			}
			else
				if(withoutNoise){
					lastEvent = nl_shot.get(shotID).ball.get(i).get(lastEventIndex);
				}
				else{
					lastEvent = shot.get(shotID).ball.get(i).get(lastEventIndex);
				}
				state[i] = updateBall(lastEvent, time);
			//		System.out.println("Ball " + i + ": " + state[i].x + ", " + state[i].y);
			//		System.out.println("state: " + shot.get(shotID).ball.get(i).get(lastEventIndex).state);
		}
		return state;
	}

	/* Finds the event to use for a specific ball at the given time in the given shot
	 * @return ID of the event to use
	 */
	private int getEventIndex(int shotID, int curBall, double time, boolean withoutNoise)
	{
		//	// System.out.println("Ball " + curBall);
		if(withoutNoise){
			for(int i = 0; i < nl_shot.get(shotID).ball.get(curBall).size(); i++)
			{
				BallShift b = nl_shot.get(shotID).ball.get(curBall).get(i);
				//		// System.out.println("Event " + i + " at " + b.time);
				if(b.time > time)
					return i - 1;
			}
			return nl_shot.get(shotID).ball.get(curBall).size() - 1;
		}
		else{
			for(int i = 0; i < shot.get(shotID).ball.get(curBall).size(); i++)
			{
				BallShift b = shot.get(shotID).ball.get(curBall).get(i);
				//		// System.out.println("Event " + i + " at " + b.time);
				if(b.time > time)
					return i - 1;
			}
			return shot.get(shotID).ball.get(curBall).size() - 1;
		}
	}

	/* Uses XML RPC to get game info 
	 * 
	 */

	private void qGame()
	{
		/*	Array of
		 Hash:	
		   - state -- current table state encoded as before
		   - agentid,opp_agentid - agents
		   - a,b,theta,phi,v,cue_x,cue_y,decision,ball,pocket - shot parameters (remember to set cue position in state!)
		   - nl_a,nl_b,nl_theta,nl_phi,nl_v - noiseless shot info
		   - timespent,turntype,playing_solids, timeleft,timeleft_opp - general info */
		XmlRpcClient client = new XmlRpcClient(gameURL);

		HashMap params = new HashMap();
		params.put("gameid", gameID);
		String methodName;
		if(gameID == "") methodName = "gettestgame"; 
		else methodName = "getgame";

		Object[] gameParams = new Object[]{params};
		XmlRpcRequest<ArrayList> request = new XmlRpcRequest<ArrayList>(client, methodName, gameParams, new AsyncCallback<ArrayList>(){
			public void onSuccess(ArrayList gameArr)
			{				
				setGameArray(gameArr);
				int index = 0;
				shotStarts = new double[gameArr.size()];
				numShots = gameArr.size();
				if(shotStarts.length>0)
					shotStarts[0] = 0;
				for(Object shotParams: gameArr)
				{
					HashMap shotMap = (HashMap)shotParams;
					if(index + 1 < gameArr.size())
						shotStarts[index + 1] = shotStarts[index] + (Double)shotMap.get("duration");
					else
						gameTime = shotStarts[index] + (Double)shotMap.get("duration");
					Shot curShot = new Shot(numBalls);
					shot.add(curShot);
					Shot nlShot = new Shot(numBalls);
					nl_shot.add(nlShot);
					index++;
					//qShot(shotParams, shotIndex);
				}
//				gameLoaded = true;
				qShot();
			}
			public void onFailure(Throwable response) 
			{
				System.out.println(response.getMessage() + " GameID = " + gameID + " did not load.");
			}
		});
		request.execute();
	}

	private void shotLoaded(boolean withoutNoise)
	{
		if(!withoutNoise){
			numLoadedShots++;
			ldr.shotLoaded(numShots, numLoadedShots);
			if(numLoadedShots == numShots){
				gameLoaded = true;
				
			}
		}
		else{
			//Noiseless Shot
			ldr.noiselessShotLoaded();
		}
	}

	private void setGameArray(ArrayList gameArr)
	{
		this.gameArr = gameArr;
	}
	/*
	 *@return number of shots in the game 
	 */
	public int numShots()
	{
		if(shot==null)
			return 0;
		else
			return shot.size();
	}

	public String getShotInfo(int currentShot)
	{
		return shot.get(currentShot).shotInfoStr;
	}

	public double getPhi(int shotID)
	{
		return shot.get(shotID).phi;
	}

	public void executeInteractiveShot(int currentShot, double phi, double theta, double a, double b, double v)
	{
		// Create the client, identifying the server
		XmlRpcClient client = new XmlRpcClient(gameURL);		    
		Object shotParamArr[] = new Object[1];
		shotParamArr[0] = gameArr.get(currentShot);
		
		//Overwrite the shot parameters to be without noise, everything else is the same
		HashMap shotInfo = (HashMap)shotParamArr[0];
		shotInfo.put("phi", phi);
		shotInfo.put("theta", theta);
		shotInfo.put("v", v);
		shotInfo.put("a", a);
		shotInfo.put("b", b);
		
		String methodName = "execshot";
		if(gameID=="") methodName = "testshot";
		XmlRpcRequest<ArrayList> request = new XmlRpcRequest<ArrayList>(client, methodName, shotParamArr, new ShotCallback(currentShot,true));
		request.execute();
	}
	
	/* 
	 * Loads the noiseless version of the specified shot
	 */
	public void qNoiselessShot(int currentShot)
	{
		if(nl_shot.get(currentShot).loaded){
			ldr.noiselessShotLoaded();
			return;
		}
		// Create the client, identifying the server
		XmlRpcClient client = new XmlRpcClient(gameURL);		    
		Object shotParamArr[] = new Object[1];
		shotParamArr[0] = gameArr.get(currentShot);
		
		//Overwrite the shot parameters to be without noise, everything else is the same
		HashMap shotInfo = (HashMap)shotParamArr[0];
		shotInfo.put("phi", shotInfo.get("nl_phi"));
		shotInfo.put("theta", shotInfo.get("nl_theta"));
		shotInfo.put("v", shotInfo.get("nl_v"));
		shotInfo.put("a", shotInfo.get("nl_a"));
		shotInfo.put("b", shotInfo.get("nl_b"));
		
		String methodName = "execshot";
		if(gameID=="") methodName = "testshot";
		XmlRpcRequest<ArrayList> request = new XmlRpcRequest<ArrayList>(client, methodName, shotParamArr, new ShotCallback(currentShot,true));
		request.execute();
	}
	
	/* Called within the qGame to organize the events for each shot based on the balls they affect
	 * 
	 */
	private void qShot()
	{

		//Store the shot's phi for displaying the cue stick 
		//			HashMap shotParamsMap = (HashMap)shotParams;

		//	curShot.phi = (Double)shotParamsMap.get("phi");

		// Create the client, identifying the server
		XmlRpcClient client = new XmlRpcClient(gameURL);		    
		Object shotParamArr[] = new Object[1];
		shotParamArr[0] = gameArr.get(0);
		String methodName = "execshot";
		if(gameID=="") methodName = "testshot";
		XmlRpcRequest<ArrayList> request = new XmlRpcRequest<ArrayList>(client, methodName, shotParamArr, new ShotCallback(0,false));
		request.execute();
	}

	//Handles both noiseless and normal shots
	class ShotCallback implements AsyncCallback<ArrayList>{
		private int shotIndex;
		private boolean noiseless; // if this is true, then this is a noiseless shot
		public ShotCallback(int shotIndex, boolean nl)
		{
			super();
			this.shotIndex = shotIndex;
			this.noiseless = nl;
		}

		public void onSuccess(ArrayList response)
		{
			Shot curShot;
			if(noiseless){	
				curShot = nl_shot.get(shotIndex);
			}
			else{
				curShot = shot.get(shotIndex);
				curShot.setString(gameArr.get(shotIndex), gameURL);
			}
			//Extract all the shot information, including physics
			fillShot(response, curShot);
			
			if(!noiseless){
				int nextShotIndex = shotIndex + 1;
				if(nextShotIndex<shot.size()){
					XmlRpcClient client = new XmlRpcClient(gameURL);		    
					Object shotParamArr[] = new Object[1];
					shotParamArr[0] = gameArr.get(nextShotIndex);
					String methodName = "execshot";
					if(gameID=="") methodName = "testshot";
					XmlRpcRequest<ArrayList> request = new XmlRpcRequest<ArrayList>(client, methodName, shotParamArr, new ShotCallback(nextShotIndex, false));
					request.execute();
				}		
			}
			shotLoaded(noiseless);
			curShot.loaded = true;
		}
		public void onFailure(Throwable response)
		{
			System.out.println(response.getMessage() + " cheese");
		}
	}
	

	/*
	 * This function extracts all of the shot information that was returned
	 * by the xmlrpc call.  
	 */
	public void fillShot(ArrayList response, Shot curShot)
	{
		for(Object o: response)
		{
			HashMap events = (HashMap)o;
			ArrayList initState = (ArrayList)(events.get("state"));
			if(initState!=null)
			{
				for(Object stateObj: initState)
				{
					HashMap stateElem = (HashMap)stateObj;
					BallShift curShift = new BallShift();
					HashMap pos = (HashMap)stateElem.get("pos");
					curShift.ballID = (Integer)stateElem.get("id");
					if(curShift.ballID!=0)
					{
						curShift.r.x = makeDouble(pos.get("x"));
						curShift.r.y = makeDouble(pos.get("y"));
						curShift.time = makeDouble(events.get("time"));
						HashMap vel = (HashMap)stateElem.get("velocity");
						curShift.v.x = makeDouble(vel.get("x"));
						curShift.v.y = makeDouble(vel.get("y"));
						curShift.v.z = makeDouble(vel.get("z"));
						HashMap spin = (HashMap)stateElem.get("spin");
						curShift.w.x = makeDouble(spin.get("x"));
						curShift.w.y = makeDouble(spin.get("y"));
						curShift.w.z = makeDouble(spin.get("z"));
						curShift.state = (Integer)stateElem.get("state");
						curShot.ball.get(curShift.ballID).add(curShift);
					}
					curShot.start_state[curShift.ballID] = new fizPoint(makeDouble(pos.get("x")), makeDouble(pos.get("y")));
					//theoretically should identify cue ball and update that better (ie velocity + spin)
				}
			}

			ArrayList changesList = (ArrayList)(events.get("changes"));
			if(changesList!=null ) {

				for(Object changeElem: changesList)
				{
					HashMap changeMap = (HashMap)changeElem;
					BallShift curShift = new BallShift();
					curShift.time = makeDouble(events.get("time"));
					HashMap vel = (HashMap)changeMap.get("velocity");
					curShift.v.x = makeDouble(vel.get("x"));
					curShift.v.y = makeDouble(vel.get("y"));
					curShift.v.z = makeDouble(vel.get("z"));
					HashMap spin = (HashMap)changeMap.get("spin");
					curShift.w.x = makeDouble(spin.get("x"));
					curShift.w.y = makeDouble(spin.get("y"));
					curShift.w.z = makeDouble(spin.get("z"));
					HashMap pos = (HashMap)changeMap.get("pos");
					curShift.r.x = makeDouble(pos.get("x"));
					curShift.r.y = makeDouble(pos.get("y"));
					curShift.ballID = (Integer)changeMap.get("id");
					curShift.state = (Integer)changeMap.get("state");
					curShot.ball.get(curShift.ballID).add(curShift);
				}
			}
		}			
	}

	public boolean isLoaded(int shotIndex)
	{
		return shot.get(shotIndex).loaded;
	}

	/* For debugging. Prints an event for a ball
	 * 
	 */
//	private void printBallShift(BallShift b)
//	{
//		 ballShiftStr = ballShiftStr + "Ball: " + b.ballID + 
//			"  State: " + b.state + 
//			"  Pos: (" + b.r.x + ", " + b.r.y + ")" +
//			"  Vel: (" + b.v.x + ", " + b.v.y + ", " + b.v.z +")" + 
//			"  Spin: (" + b.w.x + ", " + b.w.y + ", " + b.w.z +")" + "\n" +
//			" from event time " + b.time;
//	}
//	
	
//	public String ballShiftStr;

	/**
	 * @return figure out what to cast as and return it
	 */
	private double makeDouble(Object o)
	{
		if(o.getClass().getName().equals("java.lang.Double"))
			return (Double)o;
		else 
			return 0.0; //(Integer)o;
	}

	/* Tells whether the given ball is pocketed
	 * @return true iff pocketed
	 * 
	 */
	public boolean pocketed(BallShift b)
	{
		return !(b.state==STATIONARY||b.state==SPINNING||b.state==ROLLING||b.state==SLIDING);
	}

	/* Gives the position of the given ball at the given time based on the given event, assumed the most recent event
	 * From fastfiz.cpp
	 * @author Alex Landau
	 * @param most recent event for ball
	 * @param time for which position is requested
	 * @return new position of ball
	 */
	public fizPoint updateBall(BallShift b, double newtime) {
		double t = newtime - b.time;
		//		void updateBall(double oldTime, double newTime)
		//		{
		if(pocketed(b))
		{
		//	printBallShift(b);
			return new fizPoint(-1, -1);
		}
		if(!(b.state == SPINNING || b.state == ROLLING || b.state == SLIDING))
		{
		//	printBallShift(b);
			return b.r;
		}
		// double t = newTime - oldTime;
		fizVector u_o;
		fizPoint old_r = new fizPoint(b.r.x, b.r.y);
		fizVector old_v = new fizVector(b.v.x, b.v.y, b.v.z);
		fizVector old_w = new fizVector(b.w.x, b.w.y, b.w.z);
		fizPoint new_r = new fizPoint(b.r.x, b.r.y);
		fizVector new_v = new fizVector(b.v.x, b.v.y, b.v.z);
		fizVector new_w = new fizVector(b.w.x, b.w.y, b.w.z);

		double cos_phi = 1.0, sin_phi = 0.0;
		if(v_mag(b.v) > 0)
		{
			//Used for shifting in and out of a ball-centric reference frame
			cos_phi = v_norm(b.v).x;
			sin_phi = v_norm(b.v).y;

			//Rotate by -phi; v should end up along the x-axis, so the equations will work
			b.v = v_rotate(b.v, cos_phi, -sin_phi);
			b.w = v_rotate(b.w, cos_phi, -sin_phi);
		}

		//New velocity, spin, etc. depends on whether it's sliding, rolling, or spinning... or still
		switch(b.state)
		{
		case SPINNING:
			new_w.x = 0;
			new_w.y = 0;
			new_w.z = updateSpinning(b.w.z, t, mu_sp, radius, false);
			break;

		case SLIDING:
			//Equations (4)-(8) in Leckie/Greenspan 

			u_o = v_norm(v_add(b.v, v_mult(radius, v_cross(v_from(0, 0, 1), b.w))));
			// System.out.println("V: (" + b.v.x + ", " + b.v.y + ", " + b.v.z + ")");
			// System.out.println("Value of t: " + t);

			new_r.x = v_mag(b.v)*t - (0.5)*mu_s*g*t*t*u_o.x;

			new_r.y = -(0.5)*mu_s*g*t*t*u_o.y;
			//	        if(new_r.y<-3||new_r.x<-3)
			//	        	// System.out.println("substracting: "+ v_mag(b.v)*t + " - " + (0.5)*mu_s*g*t*t*u_o.x);
			new_v = v_add(b.v, v_mult(-mu_s*g*t, u_o));
			new_w = v_add(b.w, v_mult(-(5.0*mu_s*g)/(2.0*radius)*t, v_cross(u_o, v_from(0, 0, 1))));
			new_w.z = updateSpinning(b.w.z, t, mu_sp, radius, true);

			new_r = p_rotate(new_r, cos_phi, sin_phi);
			new_r = p_add(b.r, new_r);

			new_v = v_rotate(new_v, cos_phi, sin_phi);
			new_w = v_rotate(new_w, cos_phi, sin_phi);
			break;

		case ROLLING:
			//Equations (12)-(14) and (8) in Leckie/Greenspan
			new_r = v_to_p(v_add(v_mult(t, b.v), v_mult(-(0.5)*mu_r*g*t*t, v_norm(b.v))));
			new_v = v_add(b.v, v_mult(-mu_r*g*t, v_norm(b.v)));
			new_w = v_mult((v_mag(new_v)/v_mag(b.v)), b.w);
			new_w.z = updateSpinning(b.w.z, t, mu_sp, radius, false);
			new_r = p_rotate(new_r, cos_phi, sin_phi);
			new_r = p_add(b.r, new_r);
			new_v = v_rotate(new_v, cos_phi, sin_phi);
			new_w = v_rotate(new_w, cos_phi, sin_phi);
			break;

		default:
			b.r = old_r;
		b.v = old_v;
		b.w = old_w;
		//Not moving or not in play; do nothing
		//printBallShift(b);
		return old_r;
		}
		if(Math.abs(new_v.x) < EPSILON)
			new_v.x = 0;
		if(Math.abs(new_v.y) < EPSILON)
			new_v.y = 0;
		if(Math.abs(new_v.z) < EPSILON)
			new_v.z = 0;
		if(Math.abs(new_w.x) < EPSILON)
			new_w.x = 0;
		if(Math.abs(new_w.y) < EPSILON)
			new_w.y = 0;
		if(Math.abs(new_w.z) < EPSILON)
			new_w.z = 0;

		BallShift newBall = new BallShift(b.ballID, b.state, new_r, new_v, new_w);
		
		//printBallShift(newBall);
		
		b.r = old_r;
		b.v = old_v;
		b.w = old_w;	
		
		return new_r;
	}

	/* Used by update ball to calculate spin
	 * 
	 */
	double updateSpinning(double w_z, double t, double mu_sp, double R, boolean isSliding)
	{
		if(Math.abs(w_z) < EPSILON)
			return 0;
		//The sliding factor is to match Poolfiz
		double new_w_z = w_z - 5*mu_sp*g*t/(2*R) * (w_z > 0 ? 1 : -1) * (isSliding ? 0.25 : 1);
		if ((new_w_z * w_z) <= 0.0) //Stop it at zero
			new_w_z = 0;
		return new_w_z;
	}

	//linear algebra utility methods for physics
	public static fizPoint v_to_p(fizVector v)
	{
		fizPoint result = new fizPoint();
		result.x = v.x;
		result.y = v.y;
		return result;
	}

	fizPoint p_from(double x, double y)
	{
		fizPoint result = new fizPoint();
		result.x = x;
		result.y = y;
		return result;
	}

	fizPoint p_add(fizPoint p1, fizPoint p2)
	{
		return p_from(p1.x + p2.x, p1.y + p2.y);
	}


	fizPoint p_rotate(fizPoint p, double cos_phi, double sin_phi)
	{
		return p_from(p.x*cos_phi - p.y*sin_phi, 
				p.x*sin_phi + p.y*cos_phi);
	}


	fizVector v_rotate(fizVector v, double cos_phi, double sin_phi)
	{
		fizVector result = new fizVector();
		result.x = v.x*cos_phi - v.y*sin_phi;
		result.y = v.x*sin_phi + v.y*cos_phi;
		result.z = v.z;
		return result;
	}

	static fizVector v_from(double x, double y, double z)
	{
		fizVector result = new fizVector();
		result.x = x;
		result.y = y;
		result.z = z;
		return result;
	}

	fizVector v_add(fizVector v1, fizVector v2)
	{
		return v_from(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z);
	}
	fizVector v_add(fizVector v1, fizVector v2, fizVector v3)
	{
		return v_from(v1.x + v2.x + v3.x, v1.y + v2.y + v3.y, v1.z + v2.z + v3.z);
	}
	public static fizVector v_mult(double c, fizVector v)
	{
		return v_from(c * v.x, c * v.y, c * v.z);
	}
	double v_dot(fizVector v1, fizVector v2)
	{
		return (v1.x*v2.x + v1.y*v2.y + v1.z*v2.z);
	}
	fizVector v_cross(fizVector v1, fizVector v2)
	{
		return v_from(v1.y*v2.z - v1.z*v2.y, v1.z*v2.x - v1.x*v2.z, v1.x*v2.y - v1.y*v2.x);
	}
	private static double v_mag(fizVector v)
	{
		return Math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z);
	}

	public static fizVector v_norm(fizVector v)
	{
		//return v_mult(1/v_mag(v), v);
		double mag = v_mag(v);
		if (mag == 0) {
			//    throw 0;
		}
		fizVector result = new fizVector();
		result.x = v.x/mag;
		result.y = v.y/mag;
		result.z = v.z/mag;
		return result;
	}
}
