package stanford.pool.client;

import java.util.Vector;
import java.util.HashMap;


import com.fredhat.gwt.xmlrpc.client.XmlRpcClient;
import com.fredhat.gwt.xmlrpc.client.XmlRpcRequest;
import com.google.gwt.user.client.rpc.AsyncCallback;

public class Shot {
	public Vector<Vector<BallShift>> ball;
	int shotID;
	public fizPoint[] start_state;
	public fizPoint[] display_state;
	private double endTime;
	public double glStartTime;
	public String shotInfoStr;
	public boolean loaded;
	public int calledBall;
	public int calledPocket;

	public double phi; 

	public Shot(int numBalls)
	{
		loaded = false;
		start_state = new fizPoint[numBalls];
		display_state = new fizPoint[numBalls];
		ball = new Vector<Vector<BallShift>>(numBalls);
		for(int i = 0; i < numBalls; i++)
			ball.add(new Vector<BallShift>());
	}

	public void setString(Object shotInfoObj, String url)
	{
		HashMap shotInfo = (HashMap)shotInfoObj;
		shotInfoStr = "";

		XmlRpcClient client = new XmlRpcClient(url);
		addWithName(client, "agentID", "Agent ID: ", shotInfo);
		addWithName(client, "opp_agentid", "Opponent ID: ", shotInfo);
		addWithName(client, "turntype", "Turn type: ", shotInfo);

		String colorPlaying = "" + shotInfo.get("playing_solids");

		if(colorPlaying.equals(""))
			shotInfoStr += "Open table; ";
		else if(colorPlaying.equals("1"))
			shotInfoStr += "Solids playing; ";
		else if(colorPlaying.equals("0"))
			shotInfoStr += "Stripes playing; ";

		shotInfoStr+= "Time left: " + shotInfo.get("timeleft") + "; ";
		shotInfoStr+= "Opponent time left: " + shotInfo.get("opp_timeleft") + "; ";

		shotInfoStr += "\n";

		shotInfoStr += "phi: " + shotInfo.get("phi") + " degrees; ";
		shotInfoStr += "theta: " + shotInfo.get("theta") + " degrees; ";
		shotInfoStr += "v: " + shotInfo.get("v") + " m/s; ";
		shotInfoStr += "a: " + shotInfo.get("a") + " mm; ";	
		shotInfoStr += "b: " + shotInfo.get("b") + " mm; ";

		shotInfoStr += "\n";

		shotInfoStr += "Pre-noise: ";
		shotInfoStr += "phi: " + shotInfo.get("nl_phi") + " degrees; ";
		shotInfoStr += "theta: " + shotInfo.get("nl_theta") + " degrees; ";
		shotInfoStr += "v: " + shotInfo.get("nl_v") + " m/s; ";
		shotInfoStr += "a: " + shotInfo.get("nl_a") + " mm; ";	
		shotInfoStr += "b: " + shotInfo.get("nl_b") + " mm; ";
		
		calledBall = (Integer)shotInfo.get("ball");
		calledPocket = (Integer)shotInfo.get("pocket");
		
		}

	private void addWithName(XmlRpcClient client, String funcName, String displayName, HashMap shotInfo)
	{
		Object[] nameParams = new Object[]{funcName, shotInfo.get(funcName)};
		final String display = displayName;
		XmlRpcRequest<String> request = new XmlRpcRequest<String>(client, "coltext", nameParams, new AsyncCallback<String>() {
			public void onSuccess(String response) {
				shotInfoStr+= display + response + "; ";
			}

			public void onFailure(Throwable response) {
				String failedMsg = response.getMessage();
				shotInfoStr+= display + " unavailable; ";
			}
		});
		request.execute();
	}

	public double getEndTime()
	{
		if(endTime!=0)
			return endTime;
		for(Vector<BallShift> curBall: ball)
		{
			BallShift last = curBall.get(curBall.size() - 1);
			endTime = Math.max(last.time, endTime);
		}
		return endTime;
	}

}
