 
`timescale 1ns / 1ps
 
//////////////////////////////////////////////////////////////////////////////////
// DONKEY KONG - EE 354 Final Project
// Author:  S. Burton
//////////////////////////////////////////////////////////////////////////////////
 
module vga_demo(ClkPort, vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b, Sw0, Sw1, btnU,btnC, btnD,btnL, btnR,
St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar,
An0, An1, An2, An3, Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp,
LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7);
 
    // Input/Outputs
	input ClkPort, Sw0, btnU, btnD,btnL,btnC, btnR, Sw0, Sw1;
	output St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar;
	output vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b;
	output An0, An1, An2, An3, Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp;
	output LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7;
	reg vga_r, vga_g, vga_b;
	
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//  LOCAL SIGNALS
   //
 
	wire    reset, ClkPort, board_clk, clk, button_clk;
	BUF BUF1 (board_clk, ClkPort);
	BUF BUF2 (reset, Sw0);
 
	reg [27:0]    DIV_CLK;
	always @ (posedge board_clk, posedge reset) begin : CLOCK_DIVIDER
    	if (reset)
     	   DIV_CLK <= 0;
    	else
    	    DIV_CLK <= DIV_CLK + 1'b1;
	end
 
	assign    button_clk = DIV_CLK[18];
	assign    clk = DIV_CLK[1];
	assign     {St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar} = {5'b11111};
    
    
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Game Logic
    //
    
    reg[1:0] gameState;     // Title, Play, GameOver
    
    // Hero Position & Vertical Speed
    reg [9:0] positionX;
    reg [9:0] positionY;
    reg [9:0] velocityY;
    reg lookLeft;           // What dir are we facing
    reg collide;            // Have we landed?
    reg[9:0] platPos;       // Height of the platform hero is on
    
    // Barrel Position and move direction
    reg[9:0] barrelX;
    reg[9:0] barrelY;
    reg[9:0] barrelV;       // Vertical speed
    reg[9:0] barrelS;       // Horizontal speed
    reg barrelDir;
    reg barrelCol;          // Has the barrel landed?
    reg[9:0] barrelPlat;    // Height of the platform the barrel is on
    reg everyOtherSpeed;    // Do we increment barrel speed this go, or next
    
    
    reg[10:0] justDied;     // Have we just died (flash & button de-bounce)
    reg[2:0] hasJumped;     // Get bonus for jumping up platforms
    reg[17:0] totalScore;   // Score
    reg[17:0] ourScore;     // Displayed score
    
    // Hold digit values for score (00000 - 99999)
    reg[4:0] digit1;
    reg[4:0] digit2;
    reg[4:0] digit3;
    reg[4:0] digit4;
    reg[4:0] digit5;
    
    reg[9:0] j;	// Which platform are we checking
    always @(posedge DIV_CLK[14]) begin
    	j <= j + 1;
    	if (~(j == 63)) begin
    		if (j >= NUM_PLATS) begin
    			if (j == 64) begin	// End of loop, reset incrementors
    				platPos = 300;
    				collide = 0;
    
    				barrelPlat = 300;
    				barrelCol = 0;
    
    				j <= 0;
    			end
   			 end
    		else begin
    			// Player collision check
    			// Right Char        Left Plat    Left Char    Right Plat
    			if (positionX + 12 >= platX[j] && positionX <= platX[j] + 20) begin
    				// Middle Char        Top Plat        Bottom Char        Top Plat
    				if (positionY + 8 <= platY[j] && positionY + 16 >= platY[j]) begin
    					if (velocityY <= 7) begin    // Going down
   							collide = 1;
    						if (platY[j] < platPos)
    							platPos = platY[j];
    					end
    				end
    			end
    
    			// Barrel collision check
    			if (barrelX + 16 >= platX[j] && barrelX <= platX[j] + 20) begin
    				// Middle Bar        Top Plat        Bottom Bar        Top Plat
    				if (barrelY + 8 <= platY[j] && barrelY + 16 >= platY[j]) begin
    					if (barrelV <= 5) begin    // Going down
   							barrelCol = 1;
    						if (platY[j] < barrelPlat)
    							barrelPlat = platY[j];
    					end
    				end
    			end
    		end
    	end
    	else begin    // Game logic
    		if(reset | (btnD & btnC)) begin    // Reset game button
   			health <= 3;
    			hasJumped[2:0] <= 3'b000;
    			positionX <= 10;
    			positionY <= 210;
    			velocityY <= 7;
    			totalScore <= 0;
    
    			barrelDir <= 0;
    			barrelS <= 1;
    			barrelV <= 5;
    			barrelX <= platX[NUM_PLATS - 2];
    			barrelY <= -20;
    			justDied <= 32;
    			gameState <= 0;
    			lookLeft <= 0;
    			everyOtherSpeed <= 1;
    		end
    		else begin		// Not resetting
    			if (gameState == 1) begin	// Actual game play
    				if(btnR && ~btnL && (positionX < 309)) begin	// Move right
   						positionX <= positionX + 3;
    					lookLeft <= 0;
    				end
    				else if(btnL && ~btnR && (positionX > 0)) begin	// Move left
    					positionX <= positionX - 3;
    					lookLeft <= 1;
    				end
    
    				if (barrelCol) begin				// Barrel has landed
    					barrelV <= 5;
    					barrelY <= barrelPlat - 16;
    				end
    
    				if (~barrelCol) begin					// Barrel falling
    					barrelY <= barrelY - barrelV + 5;
   						barrelX <= barrelX;
    				end
    
    				// Barrel direction controls
    				if (barrelDir) begin    // Barrel going right
    					if (barrelV > 3)
    						barrelX <= barrelX + barrelS;
   			 			if (barrelX > 300) begin		// Hit edge, change dir
    						barrelDir <= 0;
    						barrelX <= 300;
    					end
    				end
    				else begin	// Barrel going left
    					if (barrelV > 3)	// Move when not falling
    						barrelX <= barrelX - barrelS;
    					if (barrelX < 10 || barrelY >= platY[0] - 16) begin
    						if (barrelY >= platY[0] - 16) begin    // Put barrel back to top
    							if (barrelX > 320) begin
    								barrelDir <= 0;
    								barrelV <= 5;
    								barrelX <= platX[NUM_PLATS - 2];
    								barrelY <= -20;
    							end
    						end
    						else begin	// Change dir
    							barrelDir <= 1;
   								barrelX <= 10;
    						end
    					end
    				end
    
   					if (barrelV > 0 && ~barrelCol)	// Barrel falling
    					barrelV <= barrelV - 1;
    
    				if (velocityY > 0 && ~collide)	// Hero falling
    					velocityY <= velocityY - 1;
    
    				if (collide) begin	// Hero landed
    					velocityY <= 7;
    					positionY <= platPos - 16;
    				end
    
    				if (btnU && collide) begin	// Jump
    					velocityY <= 14;
    				end
    
    				if (~collide)	// Hero falling
   						positionY <= positionY - velocityY + 7;
    
    				if (positionX > 309)	// World boundary
    					positionX <= 309;
    				if (positionX > 350)
    					positionX <= 0;
    
   			 		// Points for each level we go up
    				if (positionY <= platY[29] - 16 && ~hasJumped[0]) begin	// First level
    					totalScore <= totalScore + 125;
    					hasJumped[0] <= 1;
    				end
    				if (positionY <= platY[30] - 16 && ~hasJumped[1]) begin	// Second level
    					totalScore <= totalScore + 250;
    					hasJumped[1] <= 1;
    				end
    
    				if (justDied > 0)	// Flash counter
    					justDied <= justDied - 1;
    
    				// Check collision with barrel
    				if (positionX + 10 >= barrelX && positionX < barrelX + 16 && positionY + 14 > barrelY && positionY < barrelY + 16 && justDied == 0) begin
    					if (health > 0) begin // We survived
    						justDied <= 128;
    						health <= health - 1;
    						positionX <= 10;
    						positionY <= 210;
    						velocityY <= 7;
    						hasJumped[2:0] <= 3'b000;
    
    						barrelDir <= 0;
   						if (barrelS > 1)
    							barrelS <= barrelS - 1;
    						barrelV <= 5;
    						barrelX <= platX[NUM_PLATS - 2];
    						barrelY <= -20;
    						lookLeft <= 0;
    					end
    					else begin		// We died
    						justDied <= 32;
    						gameState <= 2;
    					end
    				end
    
    
    				// Win when get to top platform
    				if (positionY <= platY[NUM_PLATS - 1] - 16 && positionX >= platX[NUM_PLATS - 1] + 20) begin
    					totalScore <= totalScore + 500;
    					positionX <= 10;
   					positionY <= 210;
    					velocityY <= 7;
    					hasJumped[2:0] <= 3'b000;
    
    					barrelDir <= 0;
    					if (barrelS < 10) begin
    						everyOtherSpeed <= ~everyOtherSpeed;
    						if (everyOtherSpeed)
    							barrelS <= barrelS + 1;
    					end
    					barrelV <= 5;
    					barrelX <= platX[NUM_PLATS - 2];
    					barrelY <= -20;
    					lookLeft <= 0;
    				end
    
    			end
    			else if (gameState == 0) begin
    				positionY <= 500;
   					barrelY <= 500;
    				if (justDied > 0)
    					justDied <= justDied - 1;
    				if (justDied == 0 && (btnD | btnU | btnC | btnL | btnR)) begin
    					gameState <= 1;
    					health <= 3;
    					hasJumped[2:0] <= 3'b000;
    					positionX <= 10;
    					positionY <= 210;
    					velocityY <= 7;
    					totalScore <= 0;
    
    					barrelDir <= 0;
    					barrelS <= 1;
    					barrelV <= 5;
    					barrelX <= platX[NUM_PLATS - 2];
    					barrelY <= -20;
    					justDied <= 0;
    					lookLeft <= 0;
    					everyOtherSpeed <= 1;
    				end
    			end
    			else if (gameState == 2) begin
    				if (justDied > 0)
    					justDied <= justDied - 1;
    				if (justDied==0 && (btnD | btnU | btnC | btnL | btnR)) begin
    					gameState <= 0;
    					justDied <= 32;
    				end
    			end
    		end
   		end
    end
    
    // Increment displayed score to match actual score
    always @(posedge DIV_CLK[18]) begin SCORE:
    	if (reset | (btnC & btnD)) begin	// Reset score on game reset
    		digit1 <= 0;
    		digit2 <= 0;
    		digit3 <= 0;
    		digit4 <= 0;
    		digit5 <= 0;
    		ourScore <= 0;
    	end
    	else begin
    		if (totalScore == 0) begin	// Reset score on game reset
    			ourScore <= 0;
    			digit1 <= 0;
   				digit2 <= 0;
    			digit3 <= 0;
    			digit4 <= 0;
    			digit5 <= 0;
    		end
    		if (totalScore > ourScore) begin	// Add to displayed score to get to actual
    			digit1 <= digit1 + 1;
    			ourScore <= ourScore + 1;
    		end
    		if (digit1 == 9) begin  // Check for wrap for digits
   				digit2 <= digit2 + 1;
    			digit1 <= 0;
    			if (digit2 == 9) begin
    				digit3 <= digit3 + 1;
    				digit2 <= 0;
    				if (digit3 == 9) begin
   						digit4 <= digit4 + 1;
    					digit3 <= 0;
    					if (digit4 == 9) begin
    						digit5 <= digit5 + 1;
    						digit4 <= 0;
    						if (digit5 == 9) begin
    							digit5 <= digit5;
    						end
    					end
    				end
    			end
    		end
    	end
    end
    
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // VGA Display Control
    //
    
	 wire inDisplayArea;
	 wire [9:0] CounterX;    // Counters represent pixels on screen
	 wire [9:0] CounterY;
	 // Module to draw the pixels in VGA
    hvsync_generator syncgen(.clk(clk), .reset(reset),.vga_h_sync(vga_h_sync), .vga_v_sync(vga_v_sync), .inDisplayArea(inDisplayArea), .CounterX(CounterX), .CounterY(CounterY));
    
	 
    wire [8:0] ScaleX;        // Scales represent 1/2 resolution of screen (2x size) for gameplay
    wire [8:0] ScaleY;
    assign ScaleX = CounterX[9:1];
    assign ScaleY = CounterY[9:1];
    
    wire [6:0] TitleX;        // Titles represent 1/8 resolution (8x size) for title screens
    wire [6:0] TitleY;
    assign TitleX = ScaleX[8:2];
    assign TitleY = ScaleY[8:2];
    
    // Registers for each component's RGB
    reg scoreR, scoreG, scoreB, peachWR, peachWG, peachWB, heartR, heartW, gameOverW, titleWhite, barrelR, barrelG, heroR, heroG, heroB, platR;
    
    // Int i for the platform for loop
    integer i;
    always @(posedge clk) begin DRAW:
    
        if (gameState == 1) begin   // Game play - draw everything
        
            // Find hero sprite RGB based on hero position and sprite table
            heroR = ((heroSpriteR[ScaleY - positionY][11-(ScaleX - positionX)]&~lookLeft)|(heroSpriteR[ScaleY - positionY][ScaleX - positionX]&lookLeft)) & (ScaleX >= positionX && ScaleX < positionX+12 && ScaleY >= positionY && ScaleY < positionY+16);
            heroG = ((heroSpriteG[ScaleY - positionY][11-(ScaleX - positionX)]&~lookLeft)|(heroSpriteG[ScaleY - positionY][ScaleX - positionX]&lookLeft)) & (ScaleX >= positionX && ScaleX < positionX+12 && ScaleY >= positionY && ScaleY < positionY+16);
            heroB = ((heroSpriteB[ScaleY - positionY][11-(ScaleX - positionX)]&~lookLeft)|(heroSpriteB[ScaleY - positionY][ScaleX - positionX]&lookLeft)) & (ScaleX >= positionX && ScaleX < positionX+12 && ScaleY >= positionY && ScaleY < positionY+16);
    
            // Make hero flash if just died
            heroR = heroR & ~justDied[4];
            heroG = heroG & ~justDied[4];
            heroB = heroB & ~justDied[4];
    
            // Find platform colour based on each position and sprite table
            platR = 0;
            for (i=0;i<NUM_PLATS;i=i+1) begin
                platR = platR | (platSpriteR[ScaleY - platY[i]][ScaleX - platX[i]] & (ScaleX >= platX[i] && ScaleX < platX[i]+10 && ScaleY >= platY[i] && ScaleY <platY[i]+10));
                platR = platR | (platSpriteR[ScaleY - platY[i]][ScaleX - platX[i]-10] & (ScaleX >= platX[i]+10 && ScaleX < platX[i]+20 && ScaleY >= platY[i] && ScaleY <platY[i]+10));
                //platR = platR | (platSpriteR[ScaleY - platY[i]][ScaleX - platX[i]-20] & (ScaleX >= platX[i]+20 && ScaleX < platX[i]+30 && ScaleY >= platY[i] && ScaleY <platY[i]+10));
                //platR = platR | (platSpriteR[ScaleY - platY[i]][ScaleX - platX[i]-30] & (ScaleX >= platX[i]+30 && ScaleX < platX[i]+40 && ScaleY >= platY[i] && ScaleY <platY[i]+10));
            end
            
            // Find score colour based on each digit's value, and sprite tables
            scoreR = 0;
            scoreR = scoreR | (ScaleX >= 10 && ScaleX < 16 && ScaleY >= 20 && ScaleY < 26 && digit5 == 0) & number0[ScaleY-20][ScaleX-10];
            scoreR = scoreR | (ScaleX >= 10 && ScaleX < 16 && ScaleY >= 20 && ScaleY < 26 && digit5 == 1) & number1[ScaleY-20][ScaleX-10];
            scoreR = scoreR | (ScaleX >= 10 && ScaleX < 16 && ScaleY >= 20 && ScaleY < 26 && digit5 == 2) & number2[ScaleY-20][ScaleX-10];
            scoreR = scoreR | (ScaleX >= 10 && ScaleX < 16 && ScaleY >= 20 && ScaleY < 26 && digit5 == 3) & number3[ScaleY-20][ScaleX-10];
            scoreR = scoreR | (ScaleX >= 10 && ScaleX < 16 && ScaleY >= 20 && ScaleY < 26 && digit5 == 4) & number4[ScaleY-20][ScaleX-10];
            scoreR = scoreR | (ScaleX >= 10 && ScaleX < 16 && ScaleY >= 20 && ScaleY < 26 && digit5 == 5) & number5[ScaleY-20][ScaleX-10];
            scoreR = scoreR | (ScaleX >= 10 && ScaleX < 16 && ScaleY >= 20 && ScaleY < 26 && digit5 == 6) & number6[ScaleY-20][ScaleX-10];
            scoreR = scoreR | (ScaleX >= 10 && ScaleX < 16 && ScaleY >= 20 && ScaleY < 26 && digit5 == 7) & number7[ScaleY-20][ScaleX-10];
            scoreR = scoreR | (ScaleX >= 10 && ScaleX < 16 && ScaleY >= 20 && ScaleY < 26 && digit5 == 8) & number8[ScaleY-20][ScaleX-10];
            scoreR = scoreR | (ScaleX >= 10 && ScaleX < 16 && ScaleY >= 20 && ScaleY < 26 && digit5 == 9) & number9[ScaleY-20][ScaleX-10];
            
            scoreR = scoreR | (ScaleX >= 20 && ScaleX < 26 && ScaleY >= 20 && ScaleY < 26 && digit4 == 0) & number0[ScaleY-20][ScaleX-20];
            scoreR = scoreR | (ScaleX >= 20 && ScaleX < 26 && ScaleY >= 20 && ScaleY < 26 && digit4 == 1) & number1[ScaleY-20][ScaleX-20];
            scoreR = scoreR | (ScaleX >= 20 && ScaleX < 26 && ScaleY >= 20 && ScaleY < 26 && digit4 == 2) & number2[ScaleY-20][ScaleX-20];
            scoreR = scoreR | (ScaleX >= 20 && ScaleX < 26 && ScaleY >= 20 && ScaleY < 26 && digit4 == 3) & number3[ScaleY-20][ScaleX-20];
            scoreR = scoreR | (ScaleX >= 20 && ScaleX < 26 && ScaleY >= 20 && ScaleY < 26 && digit4 == 4) & number4[ScaleY-20][ScaleX-20];
            scoreR = scoreR | (ScaleX >= 20 && ScaleX < 26 && ScaleY >= 20 && ScaleY < 26 && digit4 == 5) & number5[ScaleY-20][ScaleX-20];
            scoreR = scoreR | (ScaleX >= 20 && ScaleX < 26 && ScaleY >= 20 && ScaleY < 26 && digit4 == 6) & number6[ScaleY-20][ScaleX-20];
            scoreR = scoreR | (ScaleX >= 20 && ScaleX < 26 && ScaleY >= 20 && ScaleY < 26 && digit4 == 7) & number7[ScaleY-20][ScaleX-20];
            scoreR = scoreR | (ScaleX >= 20 && ScaleX < 26 && ScaleY >= 20 && ScaleY < 26 && digit4 == 8) & number8[ScaleY-20][ScaleX-20];
            scoreR = scoreR | (ScaleX >= 20 && ScaleX < 26 && ScaleY >= 20 && ScaleY < 26 && digit4 == 9) & number9[ScaleY-20][ScaleX-20];
            
            scoreR = scoreR | (ScaleX >= 30 && ScaleX < 36 && ScaleY >= 20 && ScaleY < 26 && digit3 == 0) & number0[ScaleY-20][ScaleX-30];
            scoreR = scoreR | (ScaleX >= 30 && ScaleX < 36 && ScaleY >= 20 && ScaleY < 26 && digit3 == 1) & number1[ScaleY-20][ScaleX-30];
            scoreR = scoreR | (ScaleX >= 30 && ScaleX < 36 && ScaleY >= 20 && ScaleY < 26 && digit3 == 2) & number2[ScaleY-20][ScaleX-30];
            scoreR = scoreR | (ScaleX >= 30 && ScaleX < 36 && ScaleY >= 20 && ScaleY < 26 && digit3 == 3) & number3[ScaleY-20][ScaleX-30];
            scoreR = scoreR | (ScaleX >= 30 && ScaleX < 36 && ScaleY >= 20 && ScaleY < 26 && digit3 == 4) & number4[ScaleY-20][ScaleX-30];
            scoreR = scoreR | (ScaleX >= 30 && ScaleX < 36 && ScaleY >= 20 && ScaleY < 26 && digit3 == 5) & number5[ScaleY-20][ScaleX-30];
            scoreR = scoreR | (ScaleX >= 30 && ScaleX < 36 && ScaleY >= 20 && ScaleY < 26 && digit3 == 6) & number6[ScaleY-20][ScaleX-30];
            scoreR = scoreR | (ScaleX >= 30 && ScaleX < 36 && ScaleY >= 20 && ScaleY < 26 && digit3 == 7) & number7[ScaleY-20][ScaleX-30];
            scoreR = scoreR | (ScaleX >= 30 && ScaleX < 36 && ScaleY >= 20 && ScaleY < 26 && digit3 == 8) & number8[ScaleY-20][ScaleX-30];
            scoreR = scoreR | (ScaleX >= 30 && ScaleX < 36 && ScaleY >= 20 && ScaleY < 26 && digit3 == 9) & number9[ScaleY-20][ScaleX-30];
            
            scoreR = scoreR | (ScaleX >= 40 && ScaleX < 46 && ScaleY >= 20 && ScaleY < 26 && digit2 == 0) & number0[ScaleY-20][ScaleX-40];
            scoreR = scoreR | (ScaleX >= 40 && ScaleX < 46 && ScaleY >= 20 && ScaleY < 26 && digit2 == 1) & number1[ScaleY-20][ScaleX-40];
            scoreR = scoreR | (ScaleX >= 40 && ScaleX < 46 && ScaleY >= 20 && ScaleY < 26 && digit2 == 2) & number2[ScaleY-20][ScaleX-40];
            scoreR = scoreR | (ScaleX >= 40 && ScaleX < 46 && ScaleY >= 20 && ScaleY < 26 && digit2 == 3) & number3[ScaleY-20][ScaleX-40];
            scoreR = scoreR | (ScaleX >= 40 && ScaleX < 46 && ScaleY >= 20 && ScaleY < 26 && digit2 == 4) & number4[ScaleY-20][ScaleX-40];
            scoreR = scoreR | (ScaleX >= 40 && ScaleX < 46 && ScaleY >= 20 && ScaleY < 26 && digit2 == 5) & number5[ScaleY-20][ScaleX-40];
            scoreR = scoreR | (ScaleX >= 40 && ScaleX < 46 && ScaleY >= 20 && ScaleY < 26 && digit2 == 6) & number6[ScaleY-20][ScaleX-40];
            scoreR = scoreR | (ScaleX >= 40 && ScaleX < 46 && ScaleY >= 20 && ScaleY < 26 && digit2 == 7) & number7[ScaleY-20][ScaleX-40];
            scoreR = scoreR | (ScaleX >= 40 && ScaleX < 46 && ScaleY >= 20 && ScaleY < 26 && digit2 == 8) & number8[ScaleY-20][ScaleX-40];
            scoreR = scoreR | (ScaleX >= 40 && ScaleX < 46 && ScaleY >= 20 && ScaleY < 26 && digit2 == 9) & number9[ScaleY-20][ScaleX-40];
            
            scoreR = scoreR | (ScaleX >= 50 && ScaleX < 56 && ScaleY >= 20 && ScaleY < 26 && digit1 == 0) & number0[ScaleY-20][ScaleX-50];
            scoreR = scoreR | (ScaleX >= 50 && ScaleX < 56 && ScaleY >= 20 && ScaleY < 26 && digit1 == 1) & number1[ScaleY-20][ScaleX-50];
            scoreR = scoreR | (ScaleX >= 50 && ScaleX < 56 && ScaleY >= 20 && ScaleY < 26 && digit1 == 2) & number2[ScaleY-20][ScaleX-50];
            scoreR = scoreR | (ScaleX >= 50 && ScaleX < 56 && ScaleY >= 20 && ScaleY < 26 && digit1 == 3) & number3[ScaleY-20][ScaleX-50];
            scoreR = scoreR | (ScaleX >= 50 && ScaleX < 56 && ScaleY >= 20 && ScaleY < 26 && digit1 == 4) & number4[ScaleY-20][ScaleX-50];
            scoreR = scoreR | (ScaleX >= 50 && ScaleX < 56 && ScaleY >= 20 && ScaleY < 26 && digit1 == 5) & number5[ScaleY-20][ScaleX-50];
            scoreR = scoreR | (ScaleX >= 50 && ScaleX < 56 && ScaleY >= 20 && ScaleY < 26 && digit1 == 6) & number6[ScaleY-20][ScaleX-50];
            scoreR = scoreR | (ScaleX >= 50 && ScaleX < 56 && ScaleY >= 20 && ScaleY < 26 && digit1 == 7) & number7[ScaleY-20][ScaleX-50];
            scoreR = scoreR | (ScaleX >= 50 && ScaleX < 56 && ScaleY >= 20 && ScaleY < 26 && digit1 == 8) & number8[ScaleY-20][ScaleX-50];
            scoreR = scoreR | (ScaleX >= 50 && ScaleX < 56 && ScaleY >= 20 && ScaleY < 26 && digit1 == 9) & number9[ScaleY-20][ScaleX-50];
            
            // Score defaults to white, so make G=B=R
            scoreG = scoreR;
            scoreB = scoreR;
    
            // Find Peach RGB based on her position & sprite tables
            peachWR = peachR[ScaleY-(platY[NUM_PLATS-1]-23)][12-(ScaleX-(platX[NUM_PLATS-1]+25))] & (ScaleX >= platX[NUM_PLATS-1]+25 && ScaleX < platX[NUM_PLATS-1]+13+25 && ScaleY >= platY[NUM_PLATS-1]-23 && ScaleY < platY[NUM_PLATS-1]-23+23);
            peachWG = peachG[ScaleY-(platY[NUM_PLATS-1]-23)][12-(ScaleX-(platX[NUM_PLATS-1]+25))] & (ScaleX >= platX[NUM_PLATS-1]+25 && ScaleX < platX[NUM_PLATS-1]+13+25 && ScaleY >= platY[NUM_PLATS-1]-23 && ScaleY < platY[NUM_PLATS-1]-23+23);
            peachWB = peachB[ScaleY-(platY[NUM_PLATS-1]-23)][12-(ScaleX-(platX[NUM_PLATS-1]+25))] & (ScaleX >= platX[NUM_PLATS-1]+25 && ScaleX < platX[NUM_PLATS-1]+13+25 && ScaleY >= platY[NUM_PLATS-1]-23 && ScaleY < platY[NUM_PLATS-1]-23+23);
    
            // Fing barrel RGB based on position and sprite table
            barrelR = bSpriteR[ScaleY-barrelY][ScaleX-barrelX] & (ScaleX >= barrelX && ScaleX < barrelX + 16 && ScaleY >= barrelY && ScaleY < barrelY + 16);
            barrelG = ((bSpriteGA[ScaleY-barrelY][ScaleX-barrelX]&DIV_CLK[25])|bSpriteGB[ScaleY-barrelY][ScaleX-barrelX]&~DIV_CLK[25]) & (ScaleX >= barrelX && ScaleX < barrelX + 16 && ScaleY >= barrelY && ScaleY < barrelY + 16);
    
            // Find each heart's RGB basex on position and sprite table
            heartR = 0;
            heartW = 0;
            heartR = heartR | hSpriteR[ScaleY-30][ScaleX-10] & (ScaleX >= 10 && ScaleX < 19 && ScaleY >= 30 && ScaleY < 40 && health>0);
            heartR = heartR | hSpriteR[ScaleY-30][ScaleX-20] & (ScaleX >= 20 && ScaleX < 29 && ScaleY >= 30 && ScaleY < 40 && health>1);
            heartR = heartR | hSpriteR[ScaleY-30][ScaleX-30] & (ScaleX >= 30 && ScaleX < 39 && ScaleY >= 30 && ScaleY < 40 && health>2);
            heartW = heartW | hSpriteW[ScaleY-30][ScaleX-10] & (ScaleX >= 10 && ScaleX < 19 && ScaleY >= 30 && ScaleY < 40 && health>0);
            heartW = heartW | hSpriteW[ScaleY-30][ScaleX-20] & (ScaleX >= 20 && ScaleX < 29 && ScaleY >= 30 && ScaleY < 40 && health>1);
            heartW = heartW | hSpriteW[ScaleY-30][ScaleX-30] & (ScaleX >= 30 && ScaleX < 39 && ScaleY >= 30 && ScaleY < 40 && health>2);
    
            // Don't overlap characters - Mario should be shown in front of other sprites
            peachWR = (peachWR & ~heroG & ~heroB);
            peachWG = (peachWG & ~heroR & ~heroB);
            peachWB = (peachWB & ~heroG & ~heroR);
    
            platR = (platR & ~heroG & ~heroB);
            barrelR = (barrelR & ~heroG & ~heroB);
            barrelG = (barrelG & ~heroR & ~heroB);
    
            // If score recently added (ourScore not yet up to total) make score flash RGB
            if (totalScore > ourScore) begin
                if (DIV_CLK[26:25] == 0) begin  // Red
                    scoreG = 0;
                    scoreB = 0;
                end
                if (DIV_CLK[26:25] == 1) begin  // Green
                    scoreR = 0;
                    scoreB = 0;
                end
                if (DIV_CLK[26:25] == 2) begin  // Blue
                    scoreG = 0;
                    scoreR = 0;
                end
                if (DIV_CLK[26:25] == 3) begin  // Purple
                    scoreG = 0;
                end
            end
    
            // Send our colour info to the VGA module
            vga_r <= (platR | heroR | scoreR | peachWR | barrelR | heartR) & inDisplayArea;
            vga_g <= (heroG | scoreG | peachWG | barrelG | heartW) & inDisplayArea;
            vga_b <= (heroB | scoreB | peachWB | heartW) & inDisplayArea;
        end
        else if (gameState == 0) begin  // Title Screen
        
            // Find title colour based on title sprite
            titleWhite = titleW[TitleY - MAIN_TITLE_Y][25-(TitleX - MAIN_TITLE_X)] & (TitleX >= MAIN_TITLE_X && TitleX < MAIN_TITLE_X+26 && TitleY >= MAIN_TITLE_Y && TitleY < MAIN_TITLE_Y+12);
            
            // Send to VGA
            vga_r <= (titleWhite) & inDisplayArea;
            vga_g <= (titleWhite) & inDisplayArea;
            vga_b <= (titleWhite) & inDisplayArea;
        end
        else if (gameState == 2) begin    // GameOver Screen
    
            // Find score colour based on each digit's value, and sprite tables
            scoreR = 0;
            
            scoreR = scoreR | (TitleX >= SCORE_X && TitleX < SCORE_X+6 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit5 == 0) & number0[TitleY-SCORE_Y][TitleX-SCORE_X];
            scoreR = scoreR | (TitleX >= SCORE_X && TitleX < SCORE_X+6 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit5 == 1) & number1[TitleY-SCORE_Y][TitleX-SCORE_X];
            scoreR = scoreR | (TitleX >= SCORE_X && TitleX < SCORE_X+6 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit5 == 2) & number2[TitleY-SCORE_Y][TitleX-SCORE_X];
            scoreR = scoreR | (TitleX >= SCORE_X && TitleX < SCORE_X+6 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit5 == 3) & number3[TitleY-SCORE_Y][TitleX-SCORE_X];
            scoreR = scoreR | (TitleX >= SCORE_X && TitleX < SCORE_X+6 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit5 == 4) & number4[TitleY-SCORE_Y][TitleX-SCORE_X];
            scoreR = scoreR | (TitleX >= SCORE_X && TitleX < SCORE_X+6 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit5 == 5) & number5[TitleY-SCORE_Y][TitleX-SCORE_X];
            scoreR = scoreR | (TitleX >= SCORE_X && TitleX < SCORE_X+6 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit5 == 6) & number6[TitleY-SCORE_Y][TitleX-SCORE_X];
            scoreR = scoreR | (TitleX >= SCORE_X && TitleX < SCORE_X+6 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit5 == 7) & number7[TitleY-SCORE_Y][TitleX-SCORE_X];
            scoreR = scoreR | (TitleX >= SCORE_X && TitleX < SCORE_X+6 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit5 == 8) & number8[TitleY-SCORE_Y][TitleX-SCORE_X];
            scoreR = scoreR | (TitleX >= SCORE_X && TitleX < SCORE_X+6 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit5 == 9) & number9[TitleY-SCORE_Y][TitleX-SCORE_X];
            
            scoreR = scoreR | (TitleX >= SCORE_X+10 && TitleX < SCORE_X+16 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit4 == 0) & number0[TitleY-SCORE_Y][TitleX-(SCORE_X+10)];
            scoreR = scoreR | (TitleX >= SCORE_X+10 && TitleX < SCORE_X+16 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit4 == 1) & number1[TitleY-SCORE_Y][TitleX-(SCORE_X+10)];
            scoreR = scoreR | (TitleX >= SCORE_X+10 && TitleX < SCORE_X+16 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit4 == 2) & number2[TitleY-SCORE_Y][TitleX-(SCORE_X+10)];
            scoreR = scoreR | (TitleX >= SCORE_X+10 && TitleX < SCORE_X+16 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit4 == 3) & number3[TitleY-SCORE_Y][TitleX-(SCORE_X+10)];
            scoreR = scoreR | (TitleX >= SCORE_X+10 && TitleX < SCORE_X+16 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit4 == 4) & number4[TitleY-SCORE_Y][TitleX-(SCORE_X+10)];
            scoreR = scoreR | (TitleX >= SCORE_X+10 && TitleX < SCORE_X+16 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit4 == 5) & number5[TitleY-SCORE_Y][TitleX-(SCORE_X+10)];
            scoreR = scoreR | (TitleX >= SCORE_X+10 && TitleX < SCORE_X+16 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit4 == 6) & number6[TitleY-SCORE_Y][TitleX-(SCORE_X+10)];
            scoreR = scoreR | (TitleX >= SCORE_X+10 && TitleX < SCORE_X+16 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit4 == 7) & number7[TitleY-SCORE_Y][TitleX-(SCORE_X+10)];
            scoreR = scoreR | (TitleX >= SCORE_X+10 && TitleX < SCORE_X+16 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit4 == 8) & number8[TitleY-SCORE_Y][TitleX-(SCORE_X+10)];
            scoreR = scoreR | (TitleX >= SCORE_X+10 && TitleX < SCORE_X+16 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit4 == 9) & number9[TitleY-SCORE_Y][TitleX-(SCORE_X+10)];
            
            scoreR = scoreR | (TitleX >= SCORE_X+20 && TitleX < SCORE_X+26 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit3 == 0) & number0[TitleY-SCORE_Y][TitleX-(SCORE_X+20)];
            scoreR = scoreR | (TitleX >= SCORE_X+20 && TitleX < SCORE_X+26 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit3 == 1) & number1[TitleY-SCORE_Y][TitleX-(SCORE_X+20)];
            scoreR = scoreR | (TitleX >= SCORE_X+20 && TitleX < SCORE_X+26 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit3 == 2) & number2[TitleY-SCORE_Y][TitleX-(SCORE_X+20)];
            scoreR = scoreR | (TitleX >= SCORE_X+20 && TitleX < SCORE_X+26 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit3 == 3) & number3[TitleY-SCORE_Y][TitleX-(SCORE_X+20)];
            scoreR = scoreR | (TitleX >= SCORE_X+20 && TitleX < SCORE_X+26 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit3 == 4) & number4[TitleY-SCORE_Y][TitleX-(SCORE_X+20)];
            scoreR = scoreR | (TitleX >= SCORE_X+20 && TitleX < SCORE_X+26 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit3 == 5) & number5[TitleY-SCORE_Y][TitleX-(SCORE_X+20)];
            scoreR = scoreR | (TitleX >= SCORE_X+20 && TitleX < SCORE_X+26 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit3 == 6) & number6[TitleY-SCORE_Y][TitleX-(SCORE_X+20)];
            scoreR = scoreR | (TitleX >= SCORE_X+20 && TitleX < SCORE_X+26 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit3 == 7) & number7[TitleY-SCORE_Y][TitleX-(SCORE_X+20)];
            scoreR = scoreR | (TitleX >= SCORE_X+20 && TitleX < SCORE_X+26 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit3 == 8) & number8[TitleY-SCORE_Y][TitleX-(SCORE_X+20)];
            scoreR = scoreR | (TitleX >= SCORE_X+20 && TitleX < SCORE_X+26 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit3 == 9) & number9[TitleY-SCORE_Y][TitleX-(SCORE_X+20)];
            
            scoreR = scoreR | (TitleX >= SCORE_X+30 && TitleX < SCORE_X+36 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit2 == 0) & number0[TitleY-SCORE_Y][TitleX-(SCORE_X+30)];
            scoreR = scoreR | (TitleX >= SCORE_X+30 && TitleX < SCORE_X+36 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit2 == 1) & number1[TitleY-SCORE_Y][TitleX-(SCORE_X+30)];
            scoreR = scoreR | (TitleX >= SCORE_X+30 && TitleX < SCORE_X+36 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit2 == 2) & number2[TitleY-SCORE_Y][TitleX-(SCORE_X+30)];
            scoreR = scoreR | (TitleX >= SCORE_X+30 && TitleX < SCORE_X+36 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit2 == 3) & number3[TitleY-SCORE_Y][TitleX-(SCORE_X+30)];
            scoreR = scoreR | (TitleX >= SCORE_X+30 && TitleX < SCORE_X+36 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit2 == 4) & number4[TitleY-SCORE_Y][TitleX-(SCORE_X+30)];
            scoreR = scoreR | (TitleX >= SCORE_X+30 && TitleX < SCORE_X+36 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit2 == 5) & number5[TitleY-SCORE_Y][TitleX-(SCORE_X+30)];
            scoreR = scoreR | (TitleX >= SCORE_X+30 && TitleX < SCORE_X+36 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit2 == 6) & number6[TitleY-SCORE_Y][TitleX-(SCORE_X+30)];
            scoreR = scoreR | (TitleX >= SCORE_X+30 && TitleX < SCORE_X+36 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit2 == 7) & number7[TitleY-SCORE_Y][TitleX-(SCORE_X+30)];
            scoreR = scoreR | (TitleX >= SCORE_X+30 && TitleX < SCORE_X+36 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit2 == 8) & number8[TitleY-SCORE_Y][TitleX-(SCORE_X+30)];
            scoreR = scoreR | (TitleX >= SCORE_X+30 && TitleX < SCORE_X+36 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit2 == 9) & number9[TitleY-SCORE_Y][TitleX-(SCORE_X+30)];
            
            scoreR = scoreR | (TitleX >= SCORE_X+40 && TitleX < SCORE_X+46 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit1 == 0) & number0[TitleY-SCORE_Y][TitleX-(SCORE_X+40)];
            scoreR = scoreR | (TitleX >= SCORE_X+40 && TitleX < SCORE_X+46 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit1 == 1) & number1[TitleY-SCORE_Y][TitleX-(SCORE_X+40)];
            scoreR = scoreR | (TitleX >= SCORE_X+40 && TitleX < SCORE_X+46 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit1 == 2) & number2[TitleY-SCORE_Y][TitleX-(SCORE_X+40)];
            scoreR = scoreR | (TitleX >= SCORE_X+40 && TitleX < SCORE_X+46 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit1 == 3) & number3[TitleY-SCORE_Y][TitleX-(SCORE_X+40)];
            scoreR = scoreR | (TitleX >= SCORE_X+40 && TitleX < SCORE_X+46 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit1 == 4) & number4[TitleY-SCORE_Y][TitleX-(SCORE_X+40)];
            scoreR = scoreR | (TitleX >= SCORE_X+40 && TitleX < SCORE_X+46 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit1 == 5) & number5[TitleY-SCORE_Y][TitleX-(SCORE_X+40)];
            scoreR = scoreR | (TitleX >= SCORE_X+40 && TitleX < SCORE_X+46 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit1 == 6) & number6[TitleY-SCORE_Y][TitleX-(SCORE_X+40)];
            scoreR = scoreR | (TitleX >= SCORE_X+40 && TitleX < SCORE_X+46 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit1 == 7) & number7[TitleY-SCORE_Y][TitleX-(SCORE_X+40)];
            scoreR = scoreR | (TitleX >= SCORE_X+40 && TitleX < SCORE_X+46 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit1 == 8) & number8[TitleY-SCORE_Y][TitleX-(SCORE_X+40)];
            scoreR = scoreR | (TitleX >= SCORE_X+40 && TitleX < SCORE_X+46 && TitleY >= SCORE_Y && TitleY < SCORE_Y+6 && digit1 == 9) & number9[TitleY-SCORE_Y][TitleX-(SCORE_X+40)];
            
            // Score defaults to white, so make G=B=R
            scoreG = scoreR;
            scoreB = scoreR;
    
            // Score should flash always on GameOver
            if (DIV_CLK[26:25] == 0) begin  // Red
                scoreG = 0;
                scoreB = 0;
            end
            if (DIV_CLK[26:25] == 1) begin  // Green
                scoreR = 0;
                scoreB = 0;
            end
            if (DIV_CLK[26:25] == 2) begin  // Blue
                scoreG = 0;
                scoreR = 0;
            end
            if (DIV_CLK[26:25] == 3) begin  // Purple
                scoreG = 0;
            end
    
            // Find GameOver text title based on sprite table
            gameOverW = gameOver[TitleY - TITLE_Y][31-(TitleX - TITLE_X)] & (TitleX >= TITLE_X && TitleX < TITLE_X+32 && TitleY >= TITLE_Y && TitleY < TITLE_Y+15);
            
            
            // Send to VGA
            vga_r <= (scoreR | gameOverW) & inDisplayArea;
            vga_g <= (scoreG | gameOverW) & inDisplayArea;
            vga_b <= (scoreB | gameOverW) & inDisplayArea;
        end
    end
    
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Board LEDs & SSD -- not used, but must be assigned a value
    //
    
    wire LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7;
    
    assign LD0 = 0;
    assign LD1 = 0;
    
    assign LD2 = 0;
    assign LD4 = 0;
    
    assign LD3 = 0;
    assign LD5 = 0;
    assign LD6 = 0;
    assign LD7 = 0;
    
    reg     [3:0]    SSD;
    wire     [3:0]    SSD0, SSD1, SSD2, SSD3;
    wire     [1:0] ssdscan_clk;
    
    assign SSD3 = 4'b1111;
    assign SSD2 = 4'b1111;
    assign SSD1 = 4'b1111;
    assign SSD0 = 4'b1111;
    
    assign ssdscan_clk = DIV_CLK[19:18];
    assign An0    = !(~(ssdscan_clk[1]) && ~(ssdscan_clk[0]));
    assign An1    = !(~(ssdscan_clk[1]) &&  (ssdscan_clk[0]));
    assign An2    = !( (ssdscan_clk[1]) && ~(ssdscan_clk[0]));
    assign An3    = !( (ssdscan_clk[1]) &&  (ssdscan_clk[0]));
    
    always @ (ssdscan_clk, SSD0, SSD1, SSD2, SSD3) begin : SSD_SCAN_OUT
        case (ssdscan_clk)
            2'b00: SSD = SSD0;
            2'b01: SSD = SSD1;
            2'b10: SSD = SSD2;
            2'b11: SSD = SSD3;
        endcase
    end
    
    reg [6:0]  SSD_CATHODES;
    assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp} = {SSD_CATHODES, 1'b1};
    always @ (SSD) begin : HEX_TO_SSD
        case (SSD)
            4'b1111: SSD_CATHODES = 7'b1111111 ; //Nothing
            4'b0000: SSD_CATHODES = 7'b0000001 ; //0
            4'b0001: SSD_CATHODES = 7'b1001111 ; //1
            4'b0010: SSD_CATHODES = 7'b0010010 ; //2
            4'b0011: SSD_CATHODES = 7'b0000110 ; //3
            4'b0100: SSD_CATHODES = 7'b1001100 ; //4
            4'b0101: SSD_CATHODES = 7'b0100100 ; //5
            4'b0110: SSD_CATHODES = 7'b0100000 ; //6
            4'b0111: SSD_CATHODES = 7'b0001111 ; //7
            4'b1000: SSD_CATHODES = 7'b0000000 ; //8
            4'b1001: SSD_CATHODES = 7'b0000100 ; //9
            4'b1010: SSD_CATHODES = 7'b0001000 ; //10 or A
            default: SSD_CATHODES = 7'bXXXXXXX ;
        endcase
    end
    
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Game Parameters
    //
    
    // Title Position Parameters
    parameter MAIN_TITLE_X = 30;
    parameter MAIN_TITLE_Y = 20;
    parameter TITLE_X = 25;
    parameter TITLE_Y = 20;
    parameter SCORE_X = 18;
    parameter SCORE_Y = 40;
    
    // Platform Position Info
    parameter NUM_PLATS = 46;
    
    wire[9:0] platX[NUM_PLATS-1:0];        // Holds X,Y coords of platforms
    wire[9:0] platY[NUM_PLATS-1:0];
    
    // First row
    assign platX[0] = 0;
    assign platY[0] = 230;
    assign platX[1] = 20;
    assign platY[1] = 230;
    assign platX[2] = 40;
    assign platY[2] = 230;
    assign platX[3] = 60;
    assign platY[3] = 230;
    assign platX[4] = 80;
    assign platY[4] = 230;
    assign platX[5] = 100;
    assign platY[5] = 230;
    assign platX[6] = 120;
    assign platY[6] = 230;
    assign platX[7] = 140;
    assign platY[7] = 230;
    assign platX[8] = 160;
    assign platY[8] = 228;
    assign platX[9] = 180;
    assign platY[9] = 226;
    assign platX[10] = 200;
    assign platY[10] = 224;
    assign platX[11] = 220;
    assign platY[11] = 222;
    assign platX[12] = 240;
    assign platY[12] = 220;
    assign platX[13] = 260;
    assign platY[13] = 218;
    assign platX[14] = 280;
    assign platY[14] = 216;
    assign platX[15] = 300;
    assign platY[15] = 214;
    
    // Second row
    assign platX[16] = 0;
    assign platY[16] = 154;
    assign platX[17] = 20;
    assign platY[17] = 156;
    assign platX[18] = 40;
    assign platY[18] = 158;
    assign platX[19] = 60;
    assign platY[19] = 160;
    assign platX[20] = 80;
    assign platY[20] = 162;
    assign platX[21] = 100;
    assign platY[21] = 164;
    assign platX[22] = 120;
    assign platY[22] = 166;
    assign platX[23] = 140;
    assign platY[23] = 168;
    assign platX[24] = 160;
    assign platY[24] = 170;
    assign platX[25] = 180;
    assign platY[25] = 172;
    assign platX[26] = 200;
    assign platY[26] = 174;
    assign platX[27] = 220;
    assign platY[27] = 176;
    assign platX[28] = 240;
    assign platY[28] = 178;
    assign platX[29] = 260;
    assign platY[29] = 180;
    
    // Third row
    assign platX[30] = 40;
    assign platY[30] = 120;
    assign platX[31] = 60;
    assign platY[31] = 118;
    assign platX[32] = 80;
    assign platY[32] = 116;
    assign platX[33] = 100;
    assign platY[33] = 114;
    assign platX[34] = 120;
    assign platY[34] = 112;
    assign platX[35] = 140;
    assign platY[35] = 110;
    assign platX[36] = 160;
    assign platY[36] = 108;
    assign platX[37] = 180;
    assign platY[37] = 106;
    assign platX[38] = 200;
    assign platY[38] = 104;
    assign platX[39] = 220;
    assign platY[39] = 104;
    assign platX[40] = 240;
    assign platY[40] = 104;
    assign platX[41] = 260;
    assign platY[41] = 104;
    assign platX[42] = 280;
    assign platY[42] = 104;
    
    // Barrel Spawn Pos
    assign platX[44] = 300;
    assign platY[44] = 104;
    
    // Top One
    assign platX[43] = 260;
    assign platY[43] = 68;
    assign platX[45] = 240;
    assign platY[45] = 68;
    
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Game Sprites
    //
    
    // Health Sprite (Red and White)
    reg[2:0] health;
    wire[8:0] hSpriteR[9:0];
    assign hSpriteR[0] = 9'b 011000110;
    assign hSpriteR[1] = 9'b 111101111;
    assign hSpriteR[2] = 9'b 111111111;
    assign hSpriteR[3] = 9'b 111111111;
    assign hSpriteR[4] = 9'b 111111111;
    assign hSpriteR[5] = 9'b 111111111;
    assign hSpriteR[6] = 9'b 011111110;
    assign hSpriteR[7] = 9'b 001111100;
    assign hSpriteR[8] = 9'b 000111000;
    assign hSpriteR[9] = 9'b 000010000;
    
    wire[8:0] hSpriteW[9:0];
    assign hSpriteW[0] = 9'b 000000000;
    assign hSpriteW[1] = 9'b 000000000;
    assign hSpriteW[2] = 9'b 000000100;
    assign hSpriteW[3] = 9'b 000000010;
    assign hSpriteW[4] = 9'b 000000000;
    assign hSpriteW[5] = 9'b 000000000;
    assign hSpriteW[6] = 9'b 000000000;
    assign hSpriteW[7] = 9'b 000000000;
    assign hSpriteW[8] = 9'b 000000000;
    assign hSpriteW[9] = 9'b 000000000;
    
    // Number Sprites (White)
    wire[5:0] number0[5:0];
    assign number0[0] = 6'b011110;
    assign number0[1] = 6'b110001;
    assign number0[2] = 6'b101001;
    assign number0[3] = 6'b100101;
    assign number0[4] = 6'b100011;
    assign number0[5] = 6'b011110;
    
    wire[5:0] number1[5:0];
    assign number1[0] = 6'b001000;
    assign number1[1] = 6'b001100;
    assign number1[2] = 6'b001010;
    assign number1[3] = 6'b001000;
    assign number1[4] = 6'b001000;
    assign number1[5] = 6'b111110;
    
    wire[5:0] number2[5:0];
    assign number2[0] = 6'b011110;
    assign number2[1] = 6'b100001;
    assign number2[2] = 6'b100000;
    assign number2[3] = 6'b011110;
    assign number2[4] = 6'b000001;
    assign number2[5] = 6'b111111;
    
    wire[5:0] number3[5:0];
    assign number3[0] = 6'b011110;
    assign number3[1] = 6'b100001;
    assign number3[2] = 6'b011000;
    assign number3[3] = 6'b100000;
    assign number3[4] = 6'b100001;
    assign number3[5] = 6'b011110;
    
    wire[5:0] number4[5:0];
    assign number4[0] = 6'b010000;
    assign number4[1] = 6'b011000;
    assign number4[2] = 6'b010100;
    assign number4[3] = 6'b010010;
    assign number4[4] = 6'b111111;
    assign number4[5] = 6'b010000;
    
    wire[5:0] number5[5:0];
    assign number5[0] = 6'b111111;
    assign number5[1] = 6'b000001;
    assign number5[2] = 6'b011111;
    assign number5[3] = 6'b100000;
    assign number5[4] = 6'b100001;
    assign number5[5] = 6'b011110;
    
    wire[5:0] number6[5:0];
    assign number6[0] = 6'b011110;
    assign number6[1] = 6'b000001;
    assign number6[2] = 6'b011111;
    assign number6[3] = 6'b100001;
    assign number6[4] = 6'b100001;
    assign number6[5] = 6'b011110;
    
    wire[5:0] number7[5:0];
    assign number7[0] = 6'b111111;
    assign number7[1] = 6'b100000;
    assign number7[2] = 6'b010000;
    assign number7[3] = 6'b001000;
    assign number7[4] = 6'b000100;
    assign number7[5] = 6'b000100;
    
    wire[5:0] number8[5:0];
    assign number8[0] = 6'b011110;
    assign number8[1] = 6'b100001;
    assign number8[2] = 6'b011110;
    assign number8[3] = 6'b100001;
    assign number8[4] = 6'b100001;
    assign number8[5] = 6'b011110;
    
    wire[5:0] number9[5:0];
    assign number9[0] = 6'b011110;
    assign number9[1] = 6'b100001;
    assign number9[2] = 6'b100001;
    assign number9[3] = 6'b011111;
    assign number9[4] = 6'b100000;
    assign number9[5] = 6'b011110;
    
    // Princess Peach Sprites (RGB)
    wire[12:0] peachR[22:0];
    assign peachR[0] = 13'b 0010110100000;
    assign peachR[1] = 13'b 0011111100000;
    assign peachR[2] = 13'b 0111111110000;
    assign peachR[3] = 13'b 1111111111000;
    assign peachR[4] = 13'b 0111101111100;
    assign peachR[5] = 13'b 0011101111100;
    assign peachR[6] = 13'b 0111111111100;
    assign peachR[7] = 13'b 0011111111100;
    assign peachR[8] = 13'b 0111111111100;
    assign peachR[9] = 13'b 0111111111100;
    assign peachR[10]= 13'b 0011111111100;
    assign peachR[11]= 13'b 0011111111110;
    assign peachR[12]= 13'b 0111111111110;
    assign peachR[13]= 13'b 0111111111110;
    assign peachR[14]= 13'b 1111111111110;
    assign peachR[15]= 13'b 0111111111110;
    assign peachR[16]= 13'b 0001111111100;
    assign peachR[17]= 13'b 0011111111110;
    assign peachR[18]= 13'b 0111111111111;
    assign peachR[19]= 13'b 0111111111111;
    assign peachR[20]= 13'b 1111111111111;
    assign peachR[21]= 13'b 1111111111111;
    assign peachR[22]= 13'b 1111111111111;
    
    wire[12:0] peachG[22:0];
    assign peachG[0] = 13'b 0010110100000;
    assign peachG[1] = 13'b 0011111100000;
    assign peachG[2] = 13'b 0000000000000;
    assign peachG[3] = 13'b 0000000000000;
    assign peachG[4] = 13'b 0000101000000;
    assign peachG[5] = 13'b 0001101101000;
    assign peachG[6] = 13'b 0111111101000;
    assign peachG[7] = 13'b 0011111111000;
    assign peachG[8] = 13'b 0100011111000;
    assign peachG[9] = 13'b 0100111100000;
    assign peachG[10]= 13'b 0011111100000;
    assign peachG[11]= 13'b 0000011000000;
    assign peachG[12]= 13'b 0000110000000;
    assign peachG[13]= 13'b 0010000110000;
    assign peachG[14]= 13'b 1111111110000;
    assign peachG[15]= 13'b 0111111100000;
    assign peachG[16]= 13'b 0000000000000;
    assign peachG[17]= 13'b 0000000000000;
    assign peachG[18]= 13'b 0000000000000;
    assign peachG[19]= 13'b 0000000000000;
    assign peachG[20]= 13'b 0000000000000;
    assign peachG[21]= 13'b 0000000000000;
    assign peachG[22]= 13'b 0000000000000;
    
    wire[12:0] peachB[22:0];
    assign peachB[0] = 13'b 0000000000000;
    assign peachB[1] = 13'b 0000000000000;
    assign peachB[2] = 13'b 0000000000000;
    assign peachB[3] = 13'b 0000000000000;
    assign peachB[4] = 13'b 0000000000000;
    assign peachB[5] = 13'b 0000000000000;
    assign peachB[6] = 13'b 0000000000000;
    assign peachB[7] = 13'b 0000000000000;
    assign peachB[8] = 13'b 0000000000000;
    assign peachB[9] = 13'b 0000000000000;
    assign peachB[10]= 13'b 0000000000000;
    assign peachB[11]= 13'b 0000100010000;
    assign peachB[12]= 13'b 0001001111000;
    assign peachB[13]= 13'b 0001111001000;
    assign peachB[14]= 13'b 0000000001000;
    assign peachB[15]= 13'b 0000000010000;
    assign peachB[16]= 13'b 0000011110000;
    assign peachB[17]= 13'b 0011111111110;
    assign peachB[18]= 13'b 0111111111111;
    assign peachB[19]= 13'b 0111111111111;
    assign peachB[20]= 13'b 1111000000111;
    assign peachB[21]= 13'b 0000000000000;
    assign peachB[22]= 13'b 0000011110000;
    
    // Barrel Sprites (RG)
    wire[15:0] bSpriteR[15:0];
    assign bSpriteR[0] = 16'b 0000011111100000;
    assign bSpriteR[1] = 16'b 0001111111111000;
    assign bSpriteR[2] = 16'b 0011111111111100;
    assign bSpriteR[3] = 16'b 0111111111111110;
    assign bSpriteR[4] = 16'b 0111111111111110;
    assign bSpriteR[5] = 16'b 1111111111111111;
    assign bSpriteR[6] = 16'b 1111111111111111;
    assign bSpriteR[7] = 16'b 1111111111111111;
    assign bSpriteR[8] = 16'b 1111111111111111;
    assign bSpriteR[9] = 16'b 1111111111111111;
    assign bSpriteR[10]= 16'b 1111111111111111;
    assign bSpriteR[11]= 16'b 0111111111111110;
    assign bSpriteR[12]= 16'b 0111111111111110;
    assign bSpriteR[13]= 16'b 0011111111111100;
    assign bSpriteR[14]= 16'b 0001111111111000;
    assign bSpriteR[15]= 16'b 0000011111100000;
    
    wire[15:0] bSpriteGA[15:0];
    assign bSpriteGA[0] = 16'b 0000000000000000;
    assign bSpriteGA[1] = 16'b 0000001001000000;
    assign bSpriteGA[2] = 16'b 0000111001110000;
    assign bSpriteGA[3] = 16'b 0001111001111000;
    assign bSpriteGA[4] = 16'b 0011111001111100;
    assign bSpriteGA[5] = 16'b 0011111001111100;
    assign bSpriteGA[6] = 16'b 0111111001111110;
    assign bSpriteGA[7] = 16'b 0000000000000000;
    assign bSpriteGA[8] = 16'b 0000000000000000;
    assign bSpriteGA[9] = 16'b 0111111001111110;
    assign bSpriteGA[10]= 16'b 0011111001111100;
    assign bSpriteGA[11]= 16'b 0011111001111100;
    assign bSpriteGA[12]= 16'b 0011111001111100;
    assign bSpriteGA[13]= 16'b 0000111001110000;
    assign bSpriteGA[14]= 16'b 0000001001000000;
    assign bSpriteGA[15]= 16'b 0000000000000000;
    
    wire[15:0] bSpriteGB[15:0];
    assign bSpriteGB[0] = 16'b 0000000000000000;
    assign bSpriteGB[1] = 16'b 0000001111000000;
    assign bSpriteGB[2] = 16'b 0000111111110000;
    assign bSpriteGB[3] = 16'b 0000011111100000;
    assign bSpriteGB[4] = 16'b 0011001111001100;
    assign bSpriteGB[5] = 16'b 0011100110011100;
    assign bSpriteGB[6] = 16'b 0111110000111110;
    assign bSpriteGB[7] = 16'b 0111111001111110;
    assign bSpriteGB[8] = 16'b 0111111001111110;
    assign bSpriteGB[9] = 16'b 0111110000111110;
    assign bSpriteGB[10]= 16'b 0011100110011100;
    assign bSpriteGB[11]= 16'b 0011001111001100;
    assign bSpriteGB[12]= 16'b 0000011111100000;
    assign bSpriteGB[13]= 16'b 0000111111110000;
    assign bSpriteGB[14]= 16'b 0000001111000000;
    assign bSpriteGB[15]= 16'b 0000000000000000;
    
    // Hero Sprites (RGB)
    wire [11:0] heroSpriteR[15:0];
    assign heroSpriteR[0]= 12'b 000111110000;
    assign heroSpriteR[1]= 12'b 001111111110;
    assign heroSpriteR[2]= 12'b 001111111000;
    assign heroSpriteR[3]= 12'b 011111111110;
    assign heroSpriteR[4]= 12'b 011111111111;
    assign heroSpriteR[5]= 12'b 011111111110;
    assign heroSpriteR[6]= 12'b 000111111100;
    assign heroSpriteR[7]= 12'b 000010000000;
    assign heroSpriteR[8]= 12'b 000010010000;
    assign heroSpriteR[9]= 12'b 000011110000;
    assign heroSpriteR[10]=12'b 110111111011;
    assign heroSpriteR[11]=12'b 111111111111;
    assign heroSpriteR[12]=12'b 111111111111;
    assign heroSpriteR[13]=12'b 001110011100;
    assign heroSpriteR[14]=12'b 011100001110;
    assign heroSpriteR[15]=12'b 111100001111;
    
    wire [11:0] heroSpriteG[15:0];
    assign heroSpriteG[0]= 12'b 000000000000;
    assign heroSpriteG[1]= 12'b 000000000000;
    assign heroSpriteG[2]= 12'b 001111111000;
    assign heroSpriteG[3]= 12'b 011111111110;
    assign heroSpriteG[4]= 12'b 011111111111;
    assign heroSpriteG[5]= 12'b 011111111110;
    assign heroSpriteG[6]= 12'b 000111111100;
    assign heroSpriteG[7]= 12'b 000000000000;
    assign heroSpriteG[8]= 12'b 000000000000;
    assign heroSpriteG[9]= 12'b 000000000000;
    assign heroSpriteG[10]=12'b 110010010011;
    assign heroSpriteG[11]=12'b 111000000111;
    assign heroSpriteG[12]=12'b 110000000011;
    assign heroSpriteG[13]=12'b 000000000000;
    assign heroSpriteG[14]=12'b 011100001110;
    assign heroSpriteG[15]=12'b 111100001111;
    
    wire [11:0] heroSpriteB[15:0];
    assign heroSpriteB[0]= 12'b 000000000000;
    assign heroSpriteB[1]= 12'b 000000000000;
    assign heroSpriteB[2]= 12'b 000000000000;
    assign heroSpriteB[3]= 12'b 000000010000;
    assign heroSpriteB[4]= 12'b 000000001000;
    assign heroSpriteB[5]= 12'b 000000011110;
    assign heroSpriteB[6]= 12'b 000000000000;
    assign heroSpriteB[7]= 12'b 001101110000;
    assign heroSpriteB[8]= 12'b 011101101110;
    assign heroSpriteB[9]= 12'b 111100001111;
    assign heroSpriteB[10]=12'b 001000000100;
    assign heroSpriteB[11]=12'b 000000000000;
    assign heroSpriteB[12]=12'b 000000000000;
    assign heroSpriteB[13]=12'b 000000000000;
    assign heroSpriteB[14]=12'b 000000000000;
    assign heroSpriteB[15]=12'b 000000000000;
    
    // Platform Sprites (Red only)
    wire [9:0] platSpriteR[9:0];
    assign platSpriteR[0]= 10'b 1111111111;
    assign platSpriteR[1]= 10'b 1111111111;
    assign platSpriteR[2]= 10'b 1111111111;
    assign platSpriteR[3]= 10'b 1100000011;
    assign platSpriteR[4]= 10'b 0110000110;
    assign platSpriteR[5]= 10'b 0011001100;
    assign platSpriteR[6]= 10'b 0001111000;
    assign platSpriteR[7]= 10'b 1111111111;
    assign platSpriteR[8]= 10'b 1111111111;
    assign platSpriteR[9]= 10'b 1111111111;
    
    // Game Over Sprite (White)
    wire[31:0] gameOver[14:0];
    assign gameOver[0] = 32'b 00111111000111000110001101111111;
    assign gameOver[1] = 32'b 01100000001101100111011101100000;
    assign gameOver[2] = 32'b 11000000011000110111111101100000;
    assign gameOver[3] = 32'b 11000111011000110110101101111100;
    assign gameOver[4] = 32'b 11000011011111110110001101100000;
    assign gameOver[5] = 32'b 01100011011000110110001101100000;
    assign gameOver[6] = 32'b 00111111011000110110001101111111;
    assign gameOver[7] = 32'b 00000000000000000000000000000000;
    assign gameOver[8] = 32'b 01111110011000110111111101111110;
    assign gameOver[9] = 32'b 11000011011000110110000001100011;
    assign gameOver[10]= 32'b 11000011011000110110000001100011;
    assign gameOver[11]= 32'b 11000011011101110111110001100111;
    assign gameOver[12]= 32'b 11000011001111100110000001111100;
    assign gameOver[13]= 32'b 11000011000111000110000001101110;
    assign gameOver[14]= 32'b 01111110000010000111111101100111;
    
    // Title Sprite (White)
    wire[25:0] titleW[11:0];
    assign titleW[0] = 26'b 11100111010010100101110101;
    assign titleW[1] = 26'b 11010101011010101001000101;
    assign titleW[2] = 26'b 11010101011110111001110111;
    assign titleW[3] = 26'b 11010101010110101001000010;
    assign titleW[4] = 26'b 11100111010010100101110010;
    assign titleW[5] = 26'b 00000000000000000000000000;
    assign titleW[6] = 26'b 00000000000000000000000000;
    assign titleW[7] = 26'b 00011010111101001001110000;
    assign titleW[8] = 26'b 00011110110101101011000000;
    assign titleW[9] = 26'b 00011100110101111011011000;
    assign titleW[10]= 26'b 00011010110101011011001000;
    assign titleW[11]= 26'b 00011010111101001001110000;
    
        
endmodule
        
        
 
 

