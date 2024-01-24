package stanford.pool.client;

public class BallShift {
	public int ballID; //which number ball
	public double time;
	
	//the changes to that ball
	public int state;
	public fizPoint r; 
	public fizVector v; 
	public fizVector w;
	
	
	public BallShift(int ballID, int new_state, fizPoint r, fizVector v, fizVector w)
	{
		this.ballID = ballID; 
		state = new_state;
		this.r = r;
		this.v = v;
		this.w = w;
		time = 0;
	}
	public BallShift()
	{
		r = new fizPoint();
		v = new fizVector();
		w = new fizVector();
	}
}
