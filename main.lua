----------------------------------------------------------------
-- Copyright (c) 2012 Christopher Waite
-- Bytesize Adventures
-- All Rights Reserved.
-- http://www.bytesizeadventures.com
----------------------------------------------------------------

-------------------------------
-- global variables
-------------------------------

-- screen
local screenSizeX = 1024
local screenSizeY = 768

-- grid
local gridX, gridY = 140, 140

local gridOffsetX = -152
local gridOffsetY = 280

-- input
local pointerX = nil;
local pointerY = nil;

-- frame per second
local totalFrames = 30

-- zone table
local zoneTable = {}

-- quantities
local currentCriminals = 100
local currentPolice = 100

-- resources
local criminalsPerMinute = 0
local policePerMinute = 0

-- game over
local gameOver = false
local paused = false

-- setup window
MOAISim.openWindow ( "Micro Mob", screenSizeX, screenSizeY )
MOAISim.setStep ( 1 / totalFrames )

-- setup viewport
viewport = MOAIViewport.new ()
viewport:setSize ( screenSizeX, screenSizeY )
viewport:setScale ( screenSizeX, screenSizeY )

--------------------------------
-- helper functions
--------------------------------

local function printf ( ... )
	return io.stdout:write ( string.format ( ... ))
end

local function printDebug (  )
	--printf ( "player: x:%d y%d\n", x1, y1 )
end

-- convert the mouse pointer position to a grid postion (1-100)
function convertPointToGrid( x,y )
	--relative to screen
	local gridPosX, gridPosY = 0, 0
	
	if x >= 290 and x <= 990 and y >= 34 and y <= 734 then
		gridPosX, gridPosY = (math.floor((x - 290)/140) + 1), (math.floor((y - 34)/140))
	end

	return (gridPosX + (gridPosY * 5))
end

function updateCurrentCriminalCountText()
	criminalQuantityTextBox:setString(string.format("Gangsters: %d", currentCriminals))
end

function updateCurrentPoliceCountText()
	policeQuantityTextBox:setString(string.format("Coppers: %d", currentPolice))
end

--------------------------------
-- input events
--------------------------------

function onKeyboardEvent ( key, down )

	if down == true then
		--printf ( "keyboard: %d down\n", key )
		if key == 97 then
			currentKey = "left"

		elseif key == 100 then
			currentKey = "right"

		elseif key == 115 then
			currentKey = "down"

		elseif key == 119 then
			currentKey = "up"

		end
	else
		if key == 97 then
			currentKey = ""

		elseif key == 100 then
			currentKey = ""

		elseif key == 115 then
			currentKey = ""

		elseif key == 119 then
			currentKey = ""

		end
	end
end

function onPointerEvent ( x,y )
	pointerX, pointerY = x, y
	if paused == false then
		local gridRef = convertPointToGrid(x,y)
		for i=1,25,1 do
			if gridRef == i then
				zoneTable[i]:showDefenceValue()
			else
				zoneTable[i]:hideDefenceValue()
			end
		end
	end
	--printf ("Pointing at %d %d\n", pointerX, pointerY)
end

function onMouseLeftEvent ( down )
	if down == true then
		--printf ( "Left Mouse Down\n" )
	else

		--printf ( "Left Mouse Up at %d\n", convertPointToGrid(pointerX, pointerY) )

		if gameOver == false then
			if paused == false then

				if pointerX >= 15 and pointerX <= 240 and pointerY >= 710 and pointerY <= 755 then

					pauseGame()

				elseif(convertPointToGrid(pointerX, pointerY) > 0) then
					
					local tempZone = zoneTable[convertPointToGrid(pointerX, pointerY)]

					--do something for each zone type

					-- neutral zones can be taken providing you have enought criminals to match the defence value
					if tempZone:returnZoneType() == "neutral" then
						
						if currentCriminals >= tempZone:returnDefenceValue() then
							gunshot:play()
							tempZone:setZone("criminals")
							currentCriminals = currentCriminals - tempZone:returnDefenceValue()
							updateCurrentCriminalCountText()
							updateCriminalsPerMinute()
						end

					-- police zones will initiate a fight - you can do this if you have enough criminals
					elseif tempZone:returnZoneType() == "police" then

						if currentCriminals >= tempZone:returnDefenceValue() then
							gunshotLoop:play()
							tempZone:setZone("fight")
							currentCriminals = currentCriminals - tempZone:returnDefenceValue()
							updateCurrentCriminalCountText()
						end

					-- you can remove criminals from a zone and return it to neutral
					elseif tempZone:returnZoneType() == "criminals" then

						tempZone:setZone("neutral")
						currentCriminals = currentCriminals + tempZone:returnDefenceValue()
						updateCurrentCriminalCountText()
						updateCriminalsPerMinute()

					end
					
				end
			-- paused
			else

				resumeGame()

			end

		-- interacting with game over layer
		else

			-- play again
			if pointerX >= 500 and pointerX <= 725 and pointerY >= 345 and pointerY <= 385 then

				exitGame()

			end

		end
	end
end

-------------------------
-- Objects
-------------------------

function createZone (x,y,type)

	local zone = MOAIProp2D.new ()
	
	local badgeBackground = MOAIProp2D.new ()
	badgeBackground:setDeck ( badgeNeutralQuad )
	badgeBackground:setLoc (x, y)
	gui:insertProp ( badgeBackground )

	badgeBackground:setVisible(false)

	if type == "neutral" then
		zone:setDeck ( zoneNeutralQuad )
	elseif type == "police" then
		zone:setDeck ( zonePoliceQuad )
		badgeBackground:setDeck ( badgePoliceQuad )
	elseif type == "criminals" then
		zone:setDeck ( zoneCriminalQuad )
		badgeBackground:setDeck ( badgeCriminalQuad )
	elseif type == "fight" then
		zone:setDeck ( zoneFightQuad )
		badgeBackground:setDeck ( badgeFightQuad )
	end

	zone:setLoc (x,y)
	layer:insertProp ( zone )

	local zoneType = type
	local defenceValue = (math.random(1,5)*25)
		
	-- defence value label
	local zoneDefenceTextBox = MOAITextBox.new()
	zoneDefenceTextBox:setStyle (style)
	zoneDefenceTextBox:setString (string.format("%d",defenceValue))
	zoneDefenceTextBox:setRect (x-20, y-20, x+20, y+20)
	zoneDefenceTextBox:setAlignment (1, 1)
	zoneDefenceTextBox:setShader (MOAIShaderMgr.getShader(MOAIShaderMgr.DECK2D_SHADER))
	zoneDefenceTextBox:setYFlip (true)

	gui:insertProp (zoneDefenceTextBox)

	zoneDefenceTextBox:setVisible(false)

	-- fight timer
	local timer = MOAITimer.new ()
	timer:setMode (0)
	timer:setSpan (5)

	timer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function ()
			
			-- when fight timer is finished

			-- determine outcome (simple random for now)
			local winner = math.random(1,2)
			if winner == 1 then
				zone:setZone("criminals")
			elseif winner == 2 then
				zone:setZone("police")
			end

			updateCriminalsPerMinute()
			updatePolicePerMinute()

		end
	)

	function zone:returnZoneType()
		return zoneType
	end

	function zone:destroy ()
		layer:removeProp(self)
		self = nil
	end

	function zone:setZone( type )
		if type == "neutral" then
			zoneType = "neutral"
			zone:setDeck ( zoneNeutralQuad )
			badgeBackground:setDeck ( badgeNeutralQuad )
		elseif type == "police" then
			zoneType = "police"
			zone:setDeck ( zonePoliceQuad )
			badgeBackground:setDeck ( badgePoliceQuad )
		elseif type == "criminals" then
			zoneType = "criminals"
			zone:setDeck ( zoneCriminalQuad )
			badgeBackground:setDeck ( badgeCriminalQuad )
		elseif type == "fight" then
			zoneType = "fight"
			zone:setDeck ( zoneFightQuad )
			badgeBackground:setDeck ( badgeFightQuad )
			timer:start()
		end
	end

	function zone:returnDefenceValue()
		return defenceValue
	end

	function zone:hideDefenceValue( )
		badgeBackground:setVisible(false)
		zoneDefenceTextBox:setVisible(false)
	end

	function zone:showDefenceValue( )
		badgeBackground:setVisible(true)
		zoneDefenceTextBox:setVisible(true)
	end

	return zone

end

-------------------------
-- Zone generation
-------------------------

function setupStartingZones()

	-- Police presence
	local startingPoliceZoneTable = {}
	local numPoliceZones = math.random(1,1)
	
	for i=1,numPoliceZones,1 do
		local randomZone = math.random(1,25)
		startingPoliceZoneTable[randomZone] = true
	end

	-- generate zones
	local x=gridOffsetX
	local y=gridOffsetY

	for i=1,25,1 do
		
		if startingPoliceZoneTable[i] == true then
			zoneTable[i] = createZone(x,y,"police")
		else
			zoneTable[i] = createZone(x,y,"neutral")
		end
		
		x = x + 140

		if i%5 == 0 then
			y = y - 140
			x = gridOffsetX
		end
	end

	-- add player start zone
	local startingZone = math.random(1,25)
	zoneTable[startingZone]:setZone("criminals")

end

function generateCityName()
	
	local firstWords = { "" }
	local secondWords = {"Crooks", "Mobster", "Gangster", "Vice", "Goon", "Hoodlum", "Bootleg", "Ritzy", "Sheba", "Cat's Meow"}
	local thirdWords = {" 'hood", "-opolis", "ville", " Springs", " Land", "ton", " Valley", " Falls", " Shire", "berg", " City"}

	return string.upper(firstWords[math.random(1)] .. secondWords[math.random(1,10)] .. thirdWords[math.random(1,11)])
end

-------------------------
-- Simulation Loop
-------------------------

function updateCriminalsPerMinute()
	local criminalDefenceValueOfZonesOwned = 0
	
	for i=1,25,1 do
		local tempZone = zoneTable[i]
		if tempZone:returnZoneType() == "criminals" then
			criminalDefenceValueOfZonesOwned = criminalDefenceValueOfZonesOwned + tempZone:returnDefenceValue()
		end
	end
	criminalsPerMinute = criminalDefenceValueOfZonesOwned/5
	criminalPerMinuteTextBox:setString (string.format("Fresh Blood: %d",criminalsPerMinute))
end

function updatePolicePerMinute()
	local policeDefenceValueOfZonesOwned = 0

	for i=1,25,1 do
		local tempZone = zoneTable[i]
		if tempZone:returnZoneType() == "police" then
			policeDefenceValueOfZonesOwned = policeDefenceValueOfZonesOwned + tempZone:returnDefenceValue()
		end
	end
	policePerMinute = policeDefenceValueOfZonesOwned/5
	policePerMinuteTextBox:setString (string.format("New Recruits: %d",policePerMinute))
end

function policeTurn()
	-- randomly try to take squares
	local randomSquare = math.random(1,25)
	local tempZone = zoneTable[randomSquare]

	if tempZone:returnZoneType() == "neutral" then
	
		if currentPolice >= tempZone:returnDefenceValue() then
			siren:play()
			tempZone:setZone("police")
			currentPolice = currentPolice - tempZone:returnDefenceValue()
			updateCurrentPoliceCountText()
			updatePolicePerMinute()
		end

	-- police zones will initiate a fight - you can do this if you have enough criminals
	elseif tempZone:returnZoneType() == "criminals" then

		if currentPolice >= tempZone:returnDefenceValue() then
			gunshotLoop:play()
			tempZone:setZone("fight")
			currentPolice = currentPolice - tempZone:returnDefenceValue()
			updateCurrentPoliceCountText()
		end

	end
end

function awardResources()
	-- increment the cpm
	currentCriminals = currentCriminals + criminalsPerMinute
	updateCurrentCriminalCountText()
	-- increment the ppm
	currentPolice = currentPolice + policePerMinute
	updateCurrentPoliceCountText()
end

-------------------------
-- Game Over, reset, main menu, tutorial
-------------------------

function exitGame()
	os.exit()
end

function pauseGame()
	timer:pause()
	policeTimer:pause()
	rulesLayer:setVisible( true )
	paused = true
end

function resumeGame()
	timer:start()
	policeTimer:start()
	rulesLayer:setVisible( false )
	paused = false
end

function checkForGameOver()
	-- its game over if you or the police take all squares
	local policeCount = 0
	local criminalCount = 0

	for i=1,25,1 do
		local tempZone = zoneTable[i]
		if tempZone:returnZoneType() == "police" then
			policeCount = policeCount + 1
		elseif tempZone:returnZoneType() == "criminals" then
			criminalCount = criminalCount + 1
		end
	end

	if criminalCount == 25 then
		gameOverStatusTextBox:setString("YOU WIN")
		timer:stop()
		timer = nil
		policeTimer:stop()
		policeTimer = nil
		gameOver = true
		music:stop()
		gameOverLayer:setVisible (true)
	elseif policeCount == 25 then
		gameOverStatusTextBox:setString("THE FUZZ WON")
		timer:stop()
		timer = nil
		policeTimer:stop()
		policeTimer = nil
		gameOver = true
		music:stop()
		gameOverLayer:setVisible (true)
	end
end

-------------------------
-- initialisation
-------------------------

function init ()
	
	-- setup layers
	layer = MOAILayer2D.new ()
	layer:setViewport ( viewport )
	MOAISim.pushRenderPass ( layer )

	gui = MOAILayer2D.new ()
	gui:setViewport ( viewport )
	MOAISim.pushRenderPass ( gui )

	gameOverLayer = MOAILayer2D.new ()
	gameOverLayer:setViewport ( viewport )
	MOAISim.pushRenderPass ( gameOverLayer )
	gameOverLayer:setVisible (false)

	rulesLayer = MOAILayer2D.new ()
	rulesLayer:setViewport ( viewport )
	MOAISim.pushRenderPass ( rulesLayer )
	rulesLayer:setVisible (false)

	-- setup fonts and styles
	charcodes = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?()&/-'
	text = ''

	font = MOAIFont.new ()
	font:loadFromBMFont ( "impact_plain.fnt" )
	font:preloadGlyphs ( charcodes, 18 )
	
	style = MOAITextStyle.new ()
	style:setFont ( font )
	style:setSize ( 16 )

	cityNameFont = MOAIFont.new ()
	cityNameFont:loadFromBMFont ( "impact_city.fnt" )
	cityNameFont:preloadGlyphs ( charcodes, 26 )
	
	cityNameStyle = MOAITextStyle.new ()
	cityNameStyle:setFont ( cityNameFont )
	cityNameStyle:setSize ( 26 )

	-- game over ui
	gameOverBackgroundQuad = MOAIGfxQuad2D.new ()
	gameOverBackgroundQuad:setTexture( "resources/game_over.png" )
	gameOverBackgroundQuad:setRect ( -248, -180.5, 248, 180.5 )

	gameOverBackground = MOAIProp2D.new ()
	gameOverBackground:setDeck ( gameOverBackgroundQuad )
	gameOverBackground:setLoc (100,0)
	gameOverLayer:insertProp ( gameOverBackground )

	gameOverStatusTextBox = MOAITextBox.new()
	gameOverStatusTextBox:setStyle (cityNameStyle)
	gameOverStatusTextBox:setString ("THE FUZZ WON")
	gameOverStatusTextBox:setAlignment (1,1)
	gameOverStatusTextBox:setRect (0, 180, 200, 130)
	gameOverStatusTextBox:setShader (MOAIShaderMgr.getShader(MOAIShaderMgr.DECK2D_SHADER))
	gameOverStatusTextBox:setYFlip (true)
	gameOverLayer:insertProp( gameOverStatusTextBox )

	rulesBackgroundQuad = MOAIGfxQuad2D.new()
	rulesBackgroundQuad:setTexture( "resources/rules.png" )
	rulesBackgroundQuad:setRect ( -349, -312.5, 349, 312.5 )

	rulesBackground = MOAIProp2D.new ()
	rulesBackground:setDeck ( rulesBackgroundQuad )
	rulesBackground:setLoc (100,0)
	rulesLayer:insertProp ( rulesBackground )

	-- setup input listeners
	MOAIInputMgr.device.keyboard:setCallback ( onKeyboardEvent )
	MOAIInputMgr.device.pointer:setCallback ( onPointerEvent )
	MOAIInputMgr.device.mouseLeft:setCallback ( onMouseLeftEvent )

	-- background
	backgroundQuad = MOAIGfxQuad2D.new ()
	backgroundQuad:setTexture( "resources/background.png" )
	backgroundQuad:setRect ( -512, -384, 512, 384 )

	background = MOAIProp2D.new ()
	background:setDeck ( backgroundQuad )
	background:setLoc (0,0)
	layer:insertProp ( background )
	
	-- setup gui elements

	-- gui
	guiBackgroundQuad = MOAIGfxQuad2D.new ()
	guiBackgroundQuad:setTexture( "resources/gui_background.png" )
	guiBackgroundQuad:setRect ( -128, -384, 128, 384 )

	guiBackground = MOAIProp2D.new ()
	guiBackground:setDeck ( guiBackgroundQuad )
	guiBackground:setLoc (-384,0)
	gui:insertProp ( guiBackground )

	randomCityNameTextBox = MOAITextBox.new()
	randomCityNameTextBox:setStyle (cityNameStyle)
	randomCityNameTextBox:setString (generateCityName())
	randomCityNameTextBox:setAlignment (1,1)
	randomCityNameTextBox:setRect (-480, 409, -286, 369)
	randomCityNameTextBox:setShader (MOAIShaderMgr.getShader(MOAIShaderMgr.DECK2D_SHADER))
	randomCityNameTextBox:setYFlip (true)
	gui:insertProp( randomCityNameTextBox )

	-- criminal gui
	criminalQuantityTextBox = MOAITextBox.new()
	criminalQuantityTextBox:setStyle (style)
	criminalQuantityTextBox:setString ("Test")
	criminalQuantityTextBox:setRect (-480, 254, -256, 224)
	criminalQuantityTextBox:setShader (MOAIShaderMgr.getShader(MOAIShaderMgr.DECK2D_SHADER))
	criminalQuantityTextBox:setYFlip (true)

	criminalPerMinuteTextBox = MOAITextBox.new()
	criminalPerMinuteTextBox:setStyle (style)
	criminalPerMinuteTextBox:setString (string.format("Fresh Blood: %d",criminalsPerMinute))
	criminalPerMinuteTextBox:setRect (-480, 174, -256, 144)
	criminalPerMinuteTextBox:setShader (MOAIShaderMgr.getShader(MOAIShaderMgr.DECK2D_SHADER))
	criminalPerMinuteTextBox:setYFlip (true)	

	gui:insertProp (criminalQuantityTextBox)
	gui:insertProp (criminalPerMinuteTextBox)

	-- police gui
	policeQuantityTextBox = MOAITextBox.new()
	policeQuantityTextBox:setStyle (style)
	policeQuantityTextBox:setString ("Test")
	policeQuantityTextBox:setRect (-480, 10, -256, -40)
	policeQuantityTextBox:setShader (MOAIShaderMgr.getShader(MOAIShaderMgr.DECK2D_SHADER))
	policeQuantityTextBox:setYFlip (true)

	policePerMinuteTextBox = MOAITextBox.new()
	policePerMinuteTextBox:setStyle (style)
	policePerMinuteTextBox:setString (string.format("New Recruits: %d",criminalsPerMinute))
	policePerMinuteTextBox:setRect (-480, -90, -256, -120)
	policePerMinuteTextBox:setShader (MOAIShaderMgr.getShader(MOAIShaderMgr.DECK2D_SHADER))
	policePerMinuteTextBox:setYFlip (true)	

	gui:insertProp (policeQuantityTextBox)
	gui:insertProp (policePerMinuteTextBox)

	-- Music and Sound Effects
	MOAIUntzSystem.initialize ()
	MOAIUntzSystem.setVolume (1)

	-- music
	music = MOAIUntzSound.new ()
	music:load ( 'resources/sounds/mob_music.wav' )
	music:setLooping ( true )
	music:setVolume (0.4)
	music:play()

	-- sound effects
	gunshot = MOAIUntzSound.new ()
	gunshot:load ( 'resources/sounds/gunshot.wav' )
	gunshot:setLooping ( false )

	siren = MOAIUntzSound.new ()
	siren:load ( 'resources/sounds/siren.wav' )
	siren:setVolume(0.5)
	siren:setLooping ( false )

	footsteps = MOAIUntzSound.new ()
	footsteps:load ( 'resources/sounds/footsteps.wav' )
	footsteps:setLooping ( false )

	gunshotLoop = MOAIUntzSound.new ()
	gunshotLoop:load ( 'resources/sounds/repeatshot.wav' )
	gunshotLoop:setLooping ( false )

	-- zone textures
	zoneNeutralQuad = MOAIGfxQuad2D.new ()
	zoneNeutralQuad:setTexture( "resources/grid_neutral_large.png" )
	zoneNeutralQuad:setRect ( -70, -70, 70, 70 )

	zonePoliceQuad = MOAIGfxQuad2D.new ()
	zonePoliceQuad:setTexture( "resources/grid_police_large.png" )
	zonePoliceQuad:setRect ( -70, -70, 70, 70 )

	zoneCriminalQuad = MOAIGfxQuad2D.new ()
	zoneCriminalQuad:setTexture( "resources/grid_criminal_large.png" )
	zoneCriminalQuad:setRect ( -70, -70, 70, 70 )

	zoneFightQuad = MOAIGfxQuad2D.new ()
	zoneFightQuad:setTexture( "resources/grid_fight_large.png" )
	zoneFightQuad:setRect ( -70, -70, 70, 70 )

	-- badge textures
	badgeNeutralQuad = MOAIGfxQuad2D.new ()
	badgeNeutralQuad:setTexture( "resources/badge_neutral.png" )
	badgeNeutralQuad:setRect ( -32, -30.5, 32, 30.5 )

	badgePoliceQuad = MOAIGfxQuad2D.new ()
	badgePoliceQuad:setTexture( "resources/badge_police.png" )
	badgePoliceQuad:setRect ( -32, -30.5, 32, 30.5 )

	badgeCriminalQuad = MOAIGfxQuad2D.new ()
	badgeCriminalQuad:setTexture( "resources/badge_criminal.png" )
	badgeCriminalQuad:setRect ( -32, -30.5, 32, 30.5 )

	badgeFightQuad = MOAIGfxQuad2D.new ()
	badgeFightQuad:setTexture( "resources/badge_fight.png" )
	badgeFightQuad:setRect ( -32, -30.5, 32, 30.5 )

	-- objects

	updateCurrentCriminalCountText()
	updateCurrentPoliceCountText()
	setupStartingZones()
	updateCriminalsPerMinute()
	updatePolicePerMinute()

	printDebug()

	-- timer
	timer = MOAITimer.new ()
	timer:setMode (2)
	timer:setSpan (15)

	timer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function ()
			
			footsteps:play()
			awardResources()

			--printf("Completed simulation cycle\n")
		end
	)
	
	timer:start()

	-- police timer
	policeTimer = MOAITimer.new()
	policeTimer:setMode (2)
	policeTimer:setSpan (1)

	policeTimer:setListener(MOAITimer.EVENT_TIMER_END_SPAN, function ()
			
			policeTurn()

			--printf("Police having a turn\n")
		end
	)

	policeTimer:start()

end

------------------------
-- game loop
------------------------

mainThread = MOAICoroutine.new ()
mainThread:run (

	function ()

		local frame = 1

		while gameOver==false do
			coroutine.yield ()

			if frame <= totalFrames then
				frame = frame + 1
			else
				frame = 1
			end

			--check for end game state
			if (gameOver == false and paused == false) then
				checkForGameOver()
			end

		end

	end
)

----------------------
-- start the game
----------------------

init ()