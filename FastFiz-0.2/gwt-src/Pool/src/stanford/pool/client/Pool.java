package stanford.pool.client;

import java.util.MissingResourceException;
import com.google.gwt.i18n.client.NumberFormat;

import com.google.gwt.core.client.EntryPoint;
import com.google.gwt.core.client.GWT;
import com.google.gwt.event.dom.client.ClickEvent;
import com.google.gwt.event.dom.client.ClickHandler;
import com.google.gwt.event.dom.client.ChangeHandler;
import com.google.gwt.event.dom.client.ChangeEvent;
import com.google.gwt.event.dom.client.KeyCodes;
import com.google.gwt.event.dom.client.KeyUpEvent;
import com.google.gwt.event.dom.client.KeyUpHandler;
import com.google.gwt.event.dom.client.MouseEvent;
import com.google.gwt.event.logical.shared.ValueChangeEvent;
import com.google.gwt.event.logical.shared.ValueChangeHandler;
import com.google.gwt.user.client.ui.Button;
import com.google.gwt.user.client.ui.ButtonBase;
import com.google.gwt.user.client.ui.ClickListener;
import com.google.gwt.user.client.ui.CustomButton;
import com.google.gwt.user.client.ui.DialogBox;
import com.google.gwt.user.client.ui.DisclosurePanel;
import com.google.gwt.user.client.ui.HasHorizontalAlignment;
import com.google.gwt.user.client.ui.HasVerticalAlignment;
import com.google.gwt.user.client.ui.HorizontalPanel;
import com.google.gwt.user.client.ui.ListBox;
import com.google.gwt.user.client.ui.MouseListener;
import com.google.gwt.user.client.ui.Panel;
import com.google.gwt.user.client.ui.PushButton;
import com.google.gwt.user.client.ui.RootPanel;
import com.google.gwt.user.client.ui.TextBox;
import com.google.gwt.user.client.ui.ToggleButton;
import com.google.gwt.user.client.ui.VerticalPanel;
import com.google.gwt.user.client.ui.Image;
import com.google.gwt.user.client.ui.Widget;
import com.google.gwt.user.client.ui.Label;


import gwt.canvas.client.*;
import com.google.gwt.user.client.ui.AbsolutePanel;
import com.google.gwt.core.client.Duration;
import com.google.gwt.user.client.Timer;
import com.google.gwt.widgetideas.client.SliderBar;
import com.google.gwt.widgetideas.graphics.client.GWTCanvas;
import com.google.gwt.user.client.ui.ChangeListener;

import com.google.gwt.i18n.client.Dictionary;



/**
 * Entry point classes define <code>onModuleLoad()</code>.
 */
public class Pool implements EntryPoint {

	/**
	 * This is the entry point method.
	 */

	private float delay;
	private int fps;
	private double timeJump;
	private boolean animating;
	

	
	boolean beforeShot;
	double pauseTime;
	double pauseDelay;

	private Game game;
	private int numBalls = 16;
	private final static double radius = 0.028575; 
	private final double SCALE = 400;
	private fizPoint[] display_state;
	private int currentShot;
	private double displayTime;
	private final static double EPSILON = 1E7;
	final double TABLE_LENGTH = 2.236;
	final double TABLE_WIDTH = 1.116;
	
	final Image noload_img = new Image("http://altman.stanford.edu/pool/gwt/blank.png");
	final Image loading_img = new Image("http://altman.stanford.edu/pool/gwt/loading.png");
	final Image normal_img = new Image("pooltable.png");
	final Image outline_img = new Image("http://altman.stanford.edu/pool/gwt/ldr_outline.png");
	final Image bar_img = new Image("http://altman.stanford.edu/pool/gwt/ldr_bar.png");
	final Image nlshot_img = new Image("http://www.stanford.edu/~cja/nslshot.png");
	final Image glowring_img = new Image("http://www.stanford.edu/~cja/glowring.png");
	final Image pocketring_img = new Image("http://www.stanford.edu/~cja/glowring.png");
	
	//final Image bar_img = new Image("images/next.png");
	public double table_width;
	public double table_height;
	int background_mode = -1;
	
	double cushwidth = .02*SCALE*TABLE_WIDTH; 
	double xoff = cushwidth;
	double yoff = cushwidth;

	boolean currentShotNoiseless = false;
	boolean noiselessShotLoaded = false;
	
	boolean firstGameLoaded = false;
	final AbsolutePanel poolTable = new AbsolutePanel();
	final SliderBar slider = new SliderBar(0, 1);
	final SliderBar speedSlider = new SliderBar(100, 1000);
	final ListBox savedGames = new ListBox();
	final Label debugLabel = new Label("nothing yet");
	public loadedCallback loader = new loadedCallback();
	int loadedGame = -1;
	String[] gamesToLoad ={""};
	String[] gameDescriptors={""};
	String gameURL;
	
	final Button loadGame = new Button("Load Game", new ClickHandler()
	{
		public void onClick(ClickEvent event) {
			noiselessShotOff();
			animating = false;
			int index = savedGames.getSelectedIndex();
			if((index != -1) && (index != loadedGame) && (index < gamesToLoad.length)){
				loadedGame = index;
				loader.changeBackground(1);
				bar_img.setWidth("5px");
				game = new Game(numBalls, gamesToLoad[index], gameURL, loader);				
			}
		}
	});
	final Button toggleInteractiveMode = new Button("Toggle Interactive Mode", new ClickHandler()
	{
		public void onClick(ClickEvent event) {
			// Resimulate the current shot with new noise
			if(!interactiveMode){
				interactiveMode = true;
				v_slider.setEnabled(true);
				//poolTable.getWidgetPosition(image[i], starty, startx);
				if(image[0].isVisible()){
					cue_x = (int)(poolTable.getWidgetLeft(image[0]) + SCALE*radius);
					cue_y = (int)(poolTable.getWidgetTop(image[0]) + SCALE*radius);
					debugLabel.setText("cuex =" + cue_x + " cuey = " + cue_y);
					canvas.beginPath();
					canvas.moveTo(cue_x, cue_y);
					
				}
				else{
					interactiveMode = false;
				}
				
				//debugLabel.setText("Interactive Mode on!");
			}
			else{
				interactiveMode = false;
				v_slider.setEnabled(false);
				theta_canvas.clear();
				theta_canvas.beginPath();
				theta_canvas.moveTo(tcx, tcy);
				theta_canvas.lineTo(0,tcy);
				theta_canvas.closePath();
				theta_canvas.stroke();
				canvas.clear();
				debugLabel.setText("Interactive Mode off");
			}
		}
	});
	
	final Image[] image = new Image[numBalls];
	final Image[] playpause = new Image[2];
	final Timer timer = new AnimationTimer();
	
	private ButtonBase[] button;
	
	final DisclosurePanel shotInfoPanel = new DisclosurePanel("Shot Information", true);
	final Label shotInfoText = new Label();
	
	/*
	 * For interactive part.  Getting shot parameters from the user
	 */
	// The parameters
	private double iphi=0.0;
	private double itheta=10.0;
	private double ia=0.0;
	private double ib=0.0;
	private double iv=2.5;
	//Text Boxes to display and accept input
	private TextBox tphi = new TextBox();
	private TextBox ttheta = new TextBox();
	private TextBox ta = new TextBox();
	private TextBox tb = new TextBox();
	private TextBox tv = new TextBox();
	//Labels 
	final Label lphi = new Label("phi"); 
	final Label ltheta = new Label("theta"); 
	final Label la = new Label("a"); 
	final Label lb = new Label("b"); 
	final Label lv = new Label("v"); 

	//Button for execution
	final Button interactiveShot = new Button("Execute Shot", new ClickHandler()
	{
		public void onClick(ClickEvent event) {
			//What to do to execute the shot
			//noiselessShotOn();
			//game.executeInteractiveShot(currentShot, iphi, itheta, ia, ib, iv);
		}
	});
	//Stuff for drawing lines on the image (to determine phi)
	private final Canvas canvas = new Canvas();
	private boolean interactiveMode = false;
	private boolean lineStarted = false;
	private int line_x;
	private int line_y;
	private int cue_x;
	private int cue_y;	
	
	//Stuff for a and b
	final Image cueball_img = new Image("http://www.stanford.edu/~cja/cueball.png");
	final Image cuex_img = new Image("http://www.stanford.edu/~cja/cuex.png");
	final Canvas ab_canvas = new Canvas();
	private int ab_x=0;
	private int ab_y=0;
	private int ab_mx;
	private int ab_my;
	private boolean ab_dragStarted = false;
	
	//Stuff for theta
	private final Canvas theta_canvas = new Canvas();
	private double tcx = 0;
	private double tcy = 0;
	double tc_line_x;
	double tc_line_y;
	boolean tc_lineStarted = false;
	
	//Stuff for v
	final SliderBar v_slider = new SliderBar(0, 4.5);
		
	public void onModuleLoad() {
		

		String gameID;

		
		/*
		 * viewerMode is the mode that the gwt should load into: Options are:
		 * 	0 - Only view specified game (as on the webpage for a specific game or shot)
		 *  1 - Allow to select a demo game to be viewed
		 *  2 - Interactive mode
		 *  . . . more to come as needed
		 */
		int viewerMode;
		
		
		try
		{
			Dictionary params = Dictionary.getDictionary("GameInfo");
			try
			{
				gameURL = params.get("gameURL");
			}
			catch(MissingResourceException e)
			{
				gameURL = "http://altman.stanford.edu/pool/api.pl";
			}
			try
			{
				gameID = params.get("gameID");
			}
			catch(MissingResourceException e)
			{
				gameID = "";
			}
			try
			{
				String fpsStr = params.get("fps");
				fps = Integer.parseInt(fpsStr);
			}
			catch(MissingResourceException e)
			{
				fps = 50;
			}
			try
			{
				String gwtMode = params.get("mode");
				viewerMode = Integer.parseInt(gwtMode);
			}
			catch(MissingResourceException e)
			{
				viewerMode = 0;
			}
			try
			{
				//gamesToLoad = params.get("");
				String demoGames = params.get("demoGames");
				gamesToLoad = demoGames.split("\\,");
				String dbo = "";
				String gamenames = params.get("descriptions");
				gameDescriptors = gamenames.split("\\,");
				for(int i =0; i< gamesToLoad.length ;i++ )
				{
					dbo += i + " => " + gamesToLoad[i] + " <= ";
				}
				//debugLabel.setText(dbo);
			}
			catch(MissingResourceException e)
			{
				if(viewerMode == 1){
					viewerMode = 0;
				}
			}
			
			
			delay = 1000/fps;
			timeJump = 1.0/(double)fps;
		}
		catch(MissingResourceException e)
		{
			gameURL = "http://altman.stanford.edu/pool/api.pl";
			gameID = "";
			fps = 50;
			delay = 1000/fps;
			timeJump = 1.0/(double)fps;
			viewerMode = 0;
		}
		
		//Declarations
		HorizontalPanel interPanel = new HorizontalPanel();
		HorizontalPanel loadGamePanel = new HorizontalPanel();
		double tableWidth = Math.round(SCALE*TABLE_LENGTH + 2*yoff) ;
		double tableHeight = Math.round(SCALE*TABLE_WIDTH + 2*yoff);
		table_width = tableWidth;	
		table_height = tableHeight;
		debugLabel.setVisible(false);
		
		if(viewerMode == 2){ //This is an interactive game mode
			canvas.addMouseListener(new MouseListener(){
				public void onMouseDown(Widget sender, int x, int y) {
					if(interactiveMode){
						lineStarted = true;
						line_x = x;
						line_y = y;
						draw_phi(true);
					}		
				}
				public void onMouseEnter(Widget sender) {}
				public void onMouseLeave (Widget sender) {}	
				public void onMouseMove(Widget sender, int x, int y) {
					if(interactiveMode && lineStarted){
						line_x = x;
						line_y = y;
						draw_phi(true);
					}
				}
				public void onMouseUp(Widget sender, int x, int y) {
					if(interactiveMode && lineStarted){
						line_x = x;
						line_y = y;
						draw_phi(true);
						lineStarted = false;
					}
				}
			});
			theta_canvas.addMouseListener(new MouseListener(){
				public void onMouseDown(Widget sender, int x, int y) {
					if(interactiveMode){
						tc_lineStarted = true;
						tc_line_x = x;
						tc_line_y = y;
						draw_theta(true);
					}		
				}
				public void onMouseEnter(Widget sender) {}
				public void onMouseLeave (Widget sender) {}
				public void onMouseMove(Widget sender, int x, int y) {
					if(interactiveMode && tc_lineStarted){
						tc_line_x = x;
						tc_line_y = y;
						draw_theta(true);
					}
				}
				public void onMouseUp(Widget sender, int x, int y) {
					if(interactiveMode && tc_lineStarted){
						tc_line_x = x;
						tc_line_y = y;
						draw_theta(true);
						tc_lineStarted = false;
					}
				}
			});
			ab_canvas.addMouseListener(new MouseListener(){
				public void onMouseDown(Widget sender, int x, int y) {
					if(interactiveMode){
						ab_x = x;
						ab_y = y;
						ab_dragStarted = true;
						draw_ab(true);
					
					}		
				}
				public void onMouseEnter(Widget sender) {}
				public void onMouseLeave (Widget sender) {}
			
				public void onMouseMove(Widget sender, int x, int y) {
					if(interactiveMode && ab_dragStarted){
						ab_x = x;
						ab_y = y;
						ab_dragStarted = true;
						draw_ab(true);				
					}
				}
				public void onMouseUp(Widget sender, int x, int y) {
					if(interactiveMode && ab_dragStarted){
						ab_x = x;
						ab_y = y;
						ab_dragStarted = false;
						draw_ab(true);
					}
				}
			});
		
			tphi.addValueChangeHandler( new ValueChangeHandler(){
				public void onValueChange(ValueChangeEvent event){
					iphi = new Double(tphi.getText());
					draw_phi(false);
				}
			});
			ttheta.addValueChangeHandler( new ValueChangeHandler(){
				public void onValueChange(ValueChangeEvent event){
					itheta = new Double(ttheta.getText());
					draw_theta(false);
				}
			});
			ta.addValueChangeHandler( new ValueChangeHandler(){
				public void onValueChange(ValueChangeEvent event){
					ia = new Double(ta.getText());
					draw_ab(false);
				}
			});
			tb.addValueChangeHandler( new ValueChangeHandler(){
				public void onValueChange(ValueChangeEvent event){
					ib = new Double(tb.getText());
					draw_ab(false);
				}
			});
			tv.addValueChangeHandler( new ValueChangeHandler(){
				public void onValueChange(ValueChangeEvent event){			
					iv = new Double(tv.getText());
					v_slider.setCurrentValue(new Double(tv.getText()));
				}
			});
			v_slider.addChangeListener(new ChangeListener(){
				public void onChange(Widget sender) {
					if(interactiveMode){
						tv.setText("" + v_slider.getCurrentValue());
					}
				}
			});
			
			canvas.setWidth((int)tableWidth);
			canvas.setHeight((int)tableHeight);
			poolTable.setWidgetPosition(canvas, 0, 0);
			canvas.setVisible(true);
			canvas.setBackgroundColor(Canvas.TRANSPARENT);
			//canvas.setBackgroundColor("#98eeff");
			canvas.setLineWidth(2.0);
			canvas.setStrokeStyle("#000000");
			poolTable.add(canvas);
			/*
			 * The interactive portion
			 */
			VerticalPanel ilblPanel = new VerticalPanel();
			ilblPanel.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_RIGHT);
			ilblPanel.add(lphi);
			ilblPanel.add(ltheta);
			ilblPanel.add(la);
			ilblPanel.add(lb);
			ilblPanel.add(lv);
			ilblPanel.setSpacing(7);
			
			VerticalPanel itxtPanel = new VerticalPanel();
			itxtPanel.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_CENTER);
			itxtPanel.add(tphi);
			itxtPanel.add(ttheta);
			itxtPanel.add(ta);
			itxtPanel.add(tb);
			itxtPanel.add(tv);
			itxtPanel.add(interactiveShot);
			itxtPanel.setCellHeight(interactiveShot, "30px");
			
			VerticalPanel vthetaPanel = new VerticalPanel();
			vthetaPanel.setSpacing(7);
			v_slider.setWidth((tableWidth/4) + "px");
			v_slider.setEnabled(false);
			v_slider.setTitle("Adjust velocity of shot");
			v_slider.setMaxValue(4.5);
			v_slider.setMinValue(0.0);
			v_slider.setStepSize(0.1);
			v_slider.setCurrentValue(2.5);
			
			theta_canvas.setWidth((int)(tableWidth/4));
			theta_canvas.setLineWidth(5);
			theta_canvas.beginPath();
			tcx = theta_canvas.getWidth();
			tcy = theta_canvas.getHeight();
			debugLabel.setText("Dim of tc = (" + tcx + "," + tcy + ")");
			theta_canvas.moveTo(tcx, tcy);
			theta_canvas.lineTo(0,tcy);
			theta_canvas.closePath();
			theta_canvas.stroke();
			
			vthetaPanel.add(v_slider);
			vthetaPanel.add(theta_canvas);
			
			ab_mx = (int)(tableWidth/8);
			ab_my = (int)(tableWidth/8);
			
			ab_canvas.setWidth(ab_mx);
			ab_canvas.setWidth(ab_my);
			ab_canvas.setLineWidth(5);
			
			draw_ab(true);
			
			toggleInteractiveMode.setWidth("300px");
			
			interPanel.add(ab_canvas);
			interPanel.add(ilblPanel);
			interPanel.add(itxtPanel);
			interPanel.add(vthetaPanel);
			interPanel.add(toggleInteractiveMode);
		}//end mode 2 if (view saved logs)
		if(viewerMode == 1){
			for(int ix=0;ix<gamesToLoad.length;ix++){
				if(ix < gameDescriptors.length){
					savedGames.addItem(gameDescriptors[ix]);
				}
				else{
					savedGames.addItem("Demo game " + ix);
				}
			}
			savedGames.setVisibleItemCount(1);
			savedGames.setName("Select game to view");
			
			loadGamePanel.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_LEFT);
			loadGamePanel.setVerticalAlignment(HasVerticalAlignment.ALIGN_MIDDLE);
			loadGamePanel.setSpacing(30);
			
			loadGamePanel.add(savedGames);
			loadGamePanel.add(loadGame);
			loadGamePanel.setCellHeight(loadGame, "30px");
			loadGamePanel.add(debugLabel);
		} //end mode 1 if
		if(viewerMode == 0){
			game = new Game(numBalls, gameID, gameURL, loader);
		} // end mode 0 if (just view single game)
		
		//Needed for everything
				
		poolTable.setStyleName(".gwt-AbsolutePanel");
		poolTable.setSize(tableWidth + "px", tableHeight + "px");
		
		currentShot = 0;
		displayTime = 0;
		beforeShot = true;
		pauseTime = 0;
		pauseDelay = .9;
		animating = true;
		
		VerticalPanel vertPane = new VerticalPanel();
		vertPane.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_CENTER);

		initImages();

		ToggleButton paintButton = new ToggleButton(playpause[0], playpause[1]);
		paintButton.addClickHandler(new PlayClickHandler());

		PushButton nextShotFreeze = new PushButton(new Image("images/next.png"));
		nextShotFreeze.setTitle("Next shot & stop");
		nextShotFreeze.addClickHandler(new ClickHandler()
		{
			public void onClick(ClickEvent event) {
				noiselessShotOff();
				changeAnimating(false);
				if(currentShot + 1 < game.numShots())
				{
					currentShot++;
					shotInfoText.setText(game.getShotInfo(currentShot));
					displayTime = 0;
					slider.setCurrentValue(game.shotStarts[currentShot], false);
					startPause();
				}
				else
				{
					displayTime = game.getGameTime() - game.shotStarts[currentShot];
					slider.setCurrentValue(game.getGameTime(), false);
				}
			}
		});
		
		PushButton lastShotFreeze = new PushButton(new Image("images/previous.png"));
		lastShotFreeze.setTitle("Previous shot & stop");
		lastShotFreeze.addClickHandler(new ClickHandler()
		{
			public void onClick(ClickEvent event) {
				noiselessShotOff();
				changeAnimating(false);
		    	if(displayTime < .5&&currentShot>0)
		    	{
		    		currentShot--;
		    	}
				shotInfoText.setText(game.getShotInfo(currentShot));
				displayTime = 0;
				slider.setCurrentValue(game.shotStarts[currentShot], false);
				startPause();
			}
		});
		
		PushButton lastShot = new PushButton(new Image("images/slower.png"));
		lastShot.setTitle("Last shot & play");
		lastShot.addClickHandler(new ClickHandler()
		{
			public void onClick(ClickEvent event) {
				noiselessShotOff();
				if(displayTime < .5&&currentShot>0)
		    	{		    	
		    		currentShot--;
		    	}
				shotInfoText.setText(game.getShotInfo(currentShot));
		    	displayTime = 0;
		    	slider.setCurrentValue(game.shotStarts[currentShot], false);
		    	changeAnimating(true);
		    	startPause();
			}
		});
		
		PushButton nextShot = new PushButton(new Image("images/faster.png"));
		nextShot.setTitle("Next shot & play");
		nextShot.addClickHandler(new ClickHandler()
		{
			public void onClick(ClickEvent event) {
				noiselessShotOff();
				if(currentShot + 1 < game.numShots())
				{
					currentShot++;
					shotInfoText.setText(game.getShotInfo(currentShot));
					displayTime = 0;
					slider.setCurrentValue(game.shotStarts[currentShot], false);
					changeAnimating(true);
					startPause();
				}
				else
				{
					displayTime = game.getGameTime() - game.shotStarts[currentShot];
					slider.setCurrentValue(game.getGameTime(), false);
					changeAnimating(false);
				}
			}
		});
		
		Image nlimg = new Image("http://www.stanford.edu/~cja/nonoise.png");
		nlimg.setSize("15px", "10px");
		PushButton noiselessShot = new PushButton(nlimg);
		noiselessShot.setTitle("Simulate current shot without noise");
		playpause[0].setSize("15px", "10px");
		noiselessShot.addClickHandler(new ClickHandler()
		{
			public void onClick(ClickEvent event) {
				noiselessShotOn();
			}
		});
		
		button = new ButtonBase[6];
		button[0] = lastShotFreeze;
		button[1] = lastShot;
		button[2] = paintButton;
		button[3] = nextShot;
		button[4] = nextShotFreeze;
		button[5] = noiselessShot;
		
		noload_img.setSize(tableWidth + "px", tableHeight + "px");
		loading_img.setSize(tableWidth + "px", tableHeight + "px");
		normal_img.setSize(tableWidth + "px", tableHeight + "px");
		outline_img.setSize((tableWidth/4)+8 + "px", (tableHeight/16)+8 + "px");
		bar_img.setSize("10px", (tableHeight/16) + "px");
		nlshot_img.setSize((tableWidth/4)+8 + "px", (tableHeight/8) + "px");
		glowring_img.setSize("40px", "40px");
		pocketring_img.setSize("100px","100px");
		
		poolTable.add(pocketring_img);
		poolTable.add(glowring_img);
		poolTable.add(normal_img);
		poolTable.add(loading_img);
		poolTable.add(noload_img);
		poolTable.add(outline_img);
		poolTable.add(bar_img);
		poolTable.add(nlshot_img);
	
		normal_img.setVisible(false);
		loading_img.setVisible(false);
		noload_img.setVisible(false);
		outline_img.setVisible(false);
		bar_img.setVisible(false);
		nlshot_img.setVisible(false);
		glowring_img.setVisible(false);
		pocketring_img.setVisible(false);
		
		poolTable.setWidgetPosition(bar_img, (int)(3*tableWidth/8), (int)(tableHeight/2));
		poolTable.setWidgetPosition(outline_img, (int)(3*tableWidth/8)-4, (int)(tableHeight/2)-4);
		poolTable.setWidgetPosition(nlshot_img, (int)(3*tableWidth/8), (int)(7*tableHeight/16));
		
		if(viewerMode == 1){
			loader.changeBackground(0); //NoLoadYet view
		}
		else{
			loader.changeBackground(1); // Loading background
		}
		
		/*
		 * Set up the row of playback control buttons below
		 */
		HorizontalPanel buttonPanel = new HorizontalPanel();
		buttonPanel.setHorizontalAlignment(HasHorizontalAlignment.ALIGN_CENTER);
		for(ButtonBase b: button)
		{
			b.setEnabled(false);
			b.setSize("15px", "10px");
			buttonPanel.add(b);
		}
		
		button[2].setEnabled(true);
		vertPane.add(buttonPanel);

		HorizontalPanel sliderPanel = new HorizontalPanel();
		slider.setSize(tableWidth*.75 + "px", 30 + "px");
		slider.setMaxValue(25);
		slider.setStepSize(timeJump/2);
		slider.setTitle("Select game time");
		slider.setEnabled(false);
		
		speedSlider.setStepSize(1);
		speedSlider.addChangeListener(new SpeedListener());
		speedSlider.setCurrentValue(750);
		speedSlider.setSize(tableWidth*.25 + "px", 30 + "px");
		speedSlider.setTitle("Adjust playback speed");
		
		sliderPanel.add(slider);
		sliderPanel.add(speedSlider);
		
		vertPane.add(sliderPanel);
		shotInfoText.setWidth(tableWidth + "px");
		shotInfoPanel.add(shotInfoText);
	
		VerticalPanel totalPanel = new VerticalPanel();

		if(viewerMode == 1){
			totalPanel.add(loadGamePanel);
		}
		totalPanel.add(poolTable);
		if(viewerMode == 2){
			totalPanel.add(interPanel);
		}
		totalPanel.add(vertPane);
		totalPanel.add(shotInfoPanel);
		
		if(RootPanel.get("pooltable")!=null) 
		{
			RootPanel.get("pooltable").add(totalPanel);
		}
		else
		{
			RootPanel.get().add(totalPanel);	
		}
	}

	private void draw_ab(boolean from_mouse) {
		ab_canvas.clear();
		ab_canvas.beginPath();
		ab_canvas.arc(ab_mx/2, ab_my/2, ab_mx/2, 0.0, 2*Math.PI, true);
		ab_canvas.moveTo(ab_mx/2, 0);
		ab_canvas.setLineWidth(1);
		ab_canvas.lineTo(ab_mx/2, ab_my);
		ab_canvas.moveTo(0, ab_my/2);
		ab_canvas.lineTo(ab_mx, ab_my/2);
		
		ab_canvas.stroke();
		ab_canvas.setLineWidth(5);
		//Determine where ab_x and ab_y go to on the screen
		//Max value for a and b is +/- 16
		ab_canvas.closePath();
		ab_canvas.beginPath();
		
		//Get the right value for these
		if(!from_mouse){		
			//Draw the x where it should be
			ab_x = (int)((((double)ab_mx)/2) + (ia*((double)ab_mx)/32.0)); 
			ab_y = (int)((((double)ab_my)/2) + (ib*((double)ab_my)/32.0));
			//Determine the actual values and set them
			
		}
		else{
			ia = ((double)ab_x - ((double)ab_mx/2.0))*(32.0/(double)ab_mx);
			ib = ((double)ab_y - ((double)ab_my/2.0))*(32.0/(double)ab_my);
			if(interactiveMode){
				ta.setText(""+ia);
				tb.setText(""+ib);
			}
		}
		if(interactiveMode){
			int xsize = 10;
			ab_canvas.moveTo(ab_x-xsize,ab_y-xsize);
			ab_canvas.lineTo(ab_x+xsize,ab_y+xsize);
			ab_canvas.stroke();
			ab_canvas.closePath();
			ab_canvas.beginPath();
			ab_canvas.moveTo(ab_x-xsize,ab_y + xsize);
			ab_canvas.lineTo(ab_x + xsize, ab_y - xsize);
			ab_canvas.stroke();
		}
	}

	private void draw_theta(boolean from_mouse)
	{
		//Ensure that tc_line_x and tc_line_y are correct
		if(!from_mouse){
			double r = tcy*4/5;
			tc_line_x = (int)(r*Math.cos(itheta*Math.PI/180.0));
			tc_line_y = tcy - (int)(r*Math.sin(itheta*Math.PI/180.0));
		}
		else{
			itheta = getInteractiveTheta();
			ttheta.setText("" + itheta);
		}

		if(interactiveMode){
			theta_canvas.clear();
			theta_canvas.beginPath();
			theta_canvas.moveTo(tcx, tcy);
			theta_canvas.lineTo(0,tcy);
			theta_canvas.lineTo((double)tc_line_x, (double)tc_line_y);
			theta_canvas.stroke();			
		}
	}
	private double getInteractiveTheta(){
		return (Math.atan2((double)(tcy - tc_line_y), (double)(tc_line_x)))*180/Math.PI;
	}
	
	private void draw_phi(boolean from_mouse)
	{
		//First make sure that line_x and line_y are correct
		if(!from_mouse){
			//Calculate what they should be from the current iphi value
			double r = (double)canvas.getHeight();
			line_x = cue_x + (int)(r*Math.sin(iphi*Math.PI/180.0));
			line_y = cue_y + (int)(r*Math.cos(iphi*Math.PI/180.0));
		}
		else{
			iphi = getInteractivePhi();
			tphi.setText(""+iphi);
		}
		
		if(interactiveMode){
			canvas.clear();
			canvas.beginPath();
			canvas.moveTo(cue_x, cue_y);
			canvas.lineTo(line_x, line_y);
			canvas.closePath();
			canvas.stroke();	
		}
	}
	
	private double getInteractivePhi(){
		return (Math.PI + Math.atan2((double)(cue_x - line_x), (double)(cue_y - line_y)))*180/Math.PI;
	}
	

	private void initImages()
	{
		//TODO add load listener
		for(int i = 0; i < numBalls; i++)
		{
			String imageURL = "http://altman.stanford.edu/pool/ballimg.pl?id=" + i;// + "&size=" + (int)Math.round(SCALE*radius*2);
			image[i] = new Image(imageURL);
			image[i].setVisible(false);
			poolTable.add(image[i]);
		}
		
		playpause[0] = new Image("images/play.png");
		playpause[1] = new Image("images/pause.png");
		playpause[0].setSize("15px", "10px");
		playpause[1].setSize("15px", "10px");
	}

	private void noiselessShotOff()
	{
		if(!currentShotNoiseless){
			return;
		}
		currentShotNoiseless = false;
		noiselessShotLoaded = false;
		loader.changeBackground(2);
		nlshot_img.setVisible(false);
		changeAnimating(false);
	}
	
	private void noiselessShotOn()
	{
		if(currentShotNoiseless){
			return;
		}
		startPause();
		noiselessShotLoaded = false;
		currentShotNoiseless = true;
		changeAnimating(false);	
		disableControls();
		loader.changeBackground(3);
		nlshot_img.setVisible(true);
		//debugLabel.setText("Queueing shot " + currentShot);
		game.qNoiselessShot(currentShot);
		
	}
	
	private void onGameLoad()
	{
		enableControls();		
		currentShot = 0;
		startPause();
		changeAnimating(false);
		if(!firstGameLoaded){
			//Anything that needs to be done only the first time a game has loaded
			slider.addChangeListener(new SliderListener());
			firstGameLoaded = true;
		}
		//Set up slider values
		slider.setMaxValue(game.getGameTime());
		slider.setCurrentValue(0.0, true);
		//Set up the shotInfoText
		shotInfoText.setText(game.getShotInfo(currentShot));
		paint();
	}
	
	private void enableControls()
	{
		slider.setEnabled(true);
		for(ButtonBase b: button)
		{
			b.setEnabled(true);
		}
	}
	
	private void disableControls()
	{
		slider.setEnabled(false);
		for(ButtonBase b: button)
		{
			b.setEnabled(false);
		}
	}
	
	
	private void changeAnimating(boolean newValue)
	{
		animating = newValue;
		((ToggleButton) button[2]).setDown(animating);
		timer.schedule(1);
	}
	
	
	private class SpeedListener implements ChangeListener
	{
		
		public void onChange(Widget sender)
		{
			SliderBar slider = (SliderBar)sender;
			double sliderValue = slider.getCurrentValue();
			delay = (float)(4.0*(slider.getMaxValue() - sliderValue + fps)/(double)fps);
		}
	}

	private class SliderListener implements ChangeListener
	{
		public void onChange(Widget sender)
		{
			double totalTime = ((SliderBar)sender).getCurrentValue();
			int prevShot = currentShot;
			currentShot = game.getShotAtTime(totalTime);
			if(prevShot != currentShot){
				shotInfoText.setText(game.getShotInfo(currentShot));
			}
			try
			{
				displayTime = totalTime - game.shotStarts[currentShot];
				paint();
			}
			catch(Exception e)
			{
				displayTime = 0;
			}
			if(!beforeShot&&Math.abs(displayTime) < EPSILON)
				startPause();
			else
				beforeShot = false;

		}
	}
	
	private void startPause()
	{
		pauseTime = 0;
		displayTime = 0;
		beforeShot = true;
	}

	private class AnimationTimer extends Timer {

		public void run() {
			if(!currentShotNoiseless){
				//debugLabel.setText("Current shot is " + currentShot);
			}
			if(currentShotNoiseless && !noiselessShotLoaded){
				return;
			}
			if(animating)
			{
				// Execute the animations.
				if(beforeShot)
				{
					addGlowRing(game.getCalledBall(currentShot),game.getCalledPocket(currentShot));
					pauseTime += timeJump;
					if(pauseTime > pauseDelay) {
						beforeShot = false;
						pauseTime = 0;
						//Disable the highlights of ball and pocket
					}
					else{
						//enable the highlights of ball and pocket
					}
				}
				if(!beforeShot)
				{
					noGlowRing();
					displayTime += timeJump;
					try
					{
						//Are we past the end of the current shot?
						if(displayTime > game.getShotEndTime(currentShot,currentShotNoiseless))
						{
							 if(currentShotNoiseless){
								 //Return to beginning of this shot, but without noise
								 startPause();
								 noiselessShotOff();
							 }	
							 else{
								 //Normal shot
								 //Is it the last shot
								 if(currentShot == game.numShots()-1)
								 {
									 //We have reached the end of the game if we are past the end of this shot and it is the last shot								 
									 changeAnimating(false);
									 displayTime = game.getEndTime(currentShot);
								 }
								 else{
									 //Go to the next shot
									 currentShot++;
									 startPause();
									 shotInfoText.setText(game.getShotInfo(currentShot));								 
								 }								 
							 }
						}
					}
					catch(IndexOutOfBoundsException e)
					{
						System.out.println(e.getMessage());
					}
				}
				schedule(Math.round(delay));
				slider.setCurrentValue(game.shotStarts[currentShot] + displayTime, false);		
			}
			paint();
		}
	}

	private void paint()
	{
		if(currentShotNoiseless){
			display_state = game.getState(currentShot, displayTime, true);
		}
		else{
			display_state = game.getState(currentShot, displayTime, false);
		}
		//	String currentState = game.ballShiftStr;
	//	shotInfoText.setText("Time: " + displayTime + "\n" + currentState);
		for(int i = 0; i < numBalls; i++)
		{
			fizPoint curBall = display_state[i];
			if(!(curBall.x==-1&&curBall.y==-1))
			{
				int startx = (int)(SCALE*curBall.x + xoff - SCALE*radius);
				int starty = (int)(SCALE*curBall.y + yoff - SCALE*radius);
				poolTable.setWidgetPosition(image[i], starty, startx);
				image[i].setVisible(true);
			}
			else
			{
				image[i].setVisible(false);
			}
		}
	}
	
	private void addGlowRing(int ballNum, int pocketNum)
	{
		if((ballNum == -1) || (pocketNum == -1)){
			return;
		}
		int ballx = poolTable.getWidgetLeft(image[ballNum]);
		int bally = poolTable.getWidgetTop(image[ballNum]);
		int offset = 10;
		poolTable.setWidgetPosition(glowring_img, ballx-offset, bally-offset);
		glowring_img.setVisible(true);
		
		
		offset = 50;
		int px = -100;
		int py = -100;
		//debugLabel.setText("pocket " + pocketNum);
		switch(pocketNum){
		case 0:
			px = -offset;
			py = -offset;
			break;
		case 1:
			px = (int)(table_width/2) - offset + 3;
			py = -offset;
			break;
		case 2:
			px = (int)(table_width) - offset;
			py = -offset;
			break;
		case 3:
			px = (int)(table_width) - offset;
			py = (int)(table_height) - offset;
			break;
		case 4:
			px = (int)(table_width/2) - offset + 3;
			py = (int)(table_height) - offset;
			break;
		case 5:
			px = -offset;
			py = (int)(table_height) - offset;
			break;
		default:
			break;
		}
		
		poolTable.setWidgetPosition(pocketring_img, px, py);
		pocketring_img.setVisible(true);
	}
	
	private void noGlowRing()
	{
		glowring_img.setVisible(false);
		pocketring_img.setVisible(false);
	}
	
	public class loadedCallback{
		public void shotLoaded(int totShots, int ldShots)
		{
			//debugLabel.setText("Loading shot " + ldShots + " of " + totShots);
			bar_img.setWidth((table_width/4)*(((double)ldShots)/((double)totShots)) + "px");
			if(totShots == ldShots){
				//The game has loaded
				//Switch to normal view
				changeBackground(2); 
				// Take care of business to do with a game having loaded
				onGameLoad();
				paint();
			}
		}
		
		public void noiselessShotLoaded()
		{
			changeBackground(2);
			enableControls();
			noiselessShotLoaded = true;
			paint();
		}
		
		public void changeBackground(int bckgrnd)
		{
			/* 
			 * This function only changes the background.  Everything else needs to be done by the caller
			 * 0 = no game loaded background
			 * 1 = loading game background
			 * 2 = normal game background
			 * 3 = loading noiseless shot background
			 */
			if(bckgrnd == background_mode){
				//Changing to the same background image
				return;
			}
			
			switch(background_mode){
				case 0:
					noload_img.setVisible(false);
					break;
				case 1:
					loading_img.setVisible(false);
					bar_img.setVisible(false);
					outline_img.setVisible(false);
					break;
				case 2:
					normal_img.setVisible(false);
					if(!currentShotNoiseless){
						for(int i=0;i<numBalls;i++)
						{	
							image[i].setVisible(false);
					
						}
					}
					break;
				case 3:
					loading_img.setVisible(false);
					break;
				default:
					break;
			}
			background_mode = bckgrnd;
			switch(bckgrnd){
				case 0:
					noload_img.setVisible(true);
					break;
				case 1:
					loading_img.setVisible(true);
					bar_img.setVisible(true);
					outline_img.setVisible(true);
					break;
				case 2:
					normal_img.setVisible(true);					
					break;
				case 3:
					loading_img.setVisible(true);
				default:
					break;
			}
		}
	}
	
	private class PlayClickHandler implements ClickHandler {
		public void onClick(ClickEvent event) {
			if(currentShotNoiseless){
				if(noiselessShotLoaded){
					changeAnimating(!animating);
				}
				else{
					animating = false;
				}
			}
			else{
				if(game.gameLoaded)
				{
					changeAnimating(!animating);
				}
			}
		}
	}
}
