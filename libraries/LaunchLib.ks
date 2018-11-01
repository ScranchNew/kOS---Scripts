// library of kOS functions

@LAZYGLOBAL OFF.

// ________________________________________________________________________________________________________________
// s:[Screen] Everything for printing information to the screen.
// ________________________________________________________________________________________________________________

s_Layout().

function s_Layout {
// Fills the screen with a layout for displaying the mission status
// Use the s_... functions (e.g.: s_Log() or s_Info_push()) to push Information to the layout
    DECLARE Parameter NewData TO lexicon("clear", True).
        // NewData: lexicon with "where to write":"what to write"

    IF (DEFINED layoutDone) = False OR (NewData:haskey("clear") AND NewData["clear"])
    {
        GLOBAL layoutDone TO True.          // make sure the declarations are only run once

        GLOBAL Logl TO 2.					// Line for mission log

        GLOBAL Ic TO 50.					// Info-column (name; e.g "Inclination.:")
        GLOBAL Ic2 TO Ic+15.				// Info-column (value; e.g "46°")
        GLOBAL Il TO 13.					// 1. line of info-are
        GLOBAL Mil TO 2.					// Line for mission-name
        GLOBAL Spl TO 5.					// Line for subprogram-name
        GLOBAL Stl TO 8.					// Line for subprogram-status

        IF (DEFINED mLog) = False OR (NewData:haskey("reset") AND NewData["reset"]) {
            GLOBAL mLog TO list().              // All lines logged
            GLOBAL mLogL TO 0.                  // The log line, that was last printed
            GLOBAL mMission TO "".              // The mission name
            GLOBAL mSubProg TO "".              // The subprogram name
            GLOBAL mStatus TO "".               // The program status
            GLOBAL mStage TO "".                // The current stage
            GLOBAL mInfo TO stack().            // The display information stack
            GLOBAL mInfoOff TO 0.               // The offset of the working information package on top of the stack
        }

        CLEARSCREEN.
        SET TERMINAL:HEIGHT TO 40.
        SET TERMINAL:WIDTH TO 80.
        SET TERMINAL:CHARHEIGHT TO 10.

        PRINT "Mission Log:" AT (0,0).
        PRINT "Mission:" AT (Ic-1,Mil-1).
        PRINT "Subprogram:" AT (Ic-1,Spl-1).
        PRINT "Status:" AT (Ic-1,Stl-1).
        PRINT "Stage:" AT (Ic,Il-2).
        PRINT "Info:" AT (Ic-1,Il-3).
    }

    IF NewData:istype("lexicon")
    {
        FOR key IN NewData:Keys
        {
            IF key = "Log" {            // Log a string at the current time by passing a string or a list of strings.
                LOCAL sTime TO TIME - missiontime.
                LOCAL mTime TO TIME - sTime.
                IF NewData[key]:istype("List")
                {
                    FOR line IN NewData[key]
                    {
                        mLog:ADD(list(mTime, line:TOSTRING)).
                    }
                } ELSE {
                    mLog:ADD(list(mTime, NewData[key]:TOSTRING)).
                }
                s_Print_Log().
            }
            ELSE IF key = "Mission" {   // Change the mission name string
                SET mMission TO NewData[key]:TOSTRING.
            }
            ELSE IF key = "Subprogram" {// Change the subprogram name string
                SET mSubProg TO NewData[key]:TOSTRING.
            }
            ELSE IF key = "Status" OR key = "State" {// Change the program state string
                SET mStatus TO NewData[key]:TOSTRING.
            }
            ELSE IF key = "Stage" {     // Change the stage infostring
                SET mStage TO NewData[key]:TOSTRING.
            }
            IF key = "Mission" OR key = "Subprogram" OR key = "Status" OR key = "State" OR key = "Stage" { // Prints Mission-changes
                s_Print_Mission().
            }
            ELSE IF key = "Info" {      // pushes a new info block or updates/removes the current info block
                LOCAL iType TO NewData[key]["Type"].

                // Pushes new information to the top of the infostack
                IF iType = "Push" AND NewData[key]["Info"]:LENGTH > 0
                {
                    IF mInfo:LENGTH > 0 {
                        SET mInfoOff TO mInfoOff + 1 + mInfo:PEEK():LENGTH.
                    }
                    mInfo:PUSH(NewData[key]["Info"]).
                }

                // Refreshes the information on top of the infostack
                ELSE IF iType = "Refresh" AND NewData[key]["Info"]:LENGTH > 0 AND mInfo:LENGTH > 0
                {
                    LOCAL Data TO mInfo:POP().
                    IF Data:LENGTH > NewData[key]["Info"]:LENGTH {
                        SET Data TO Data:SUBLIST(0, NewData[key]["Info"]:LENGTH).
                    }
                    FOR i IN RANGE(NewData[key]["Info"]:LENGTH) {
                        LOCAL NewInf TO NewData[key]["Info"][i].
                        IF i < Data:LENGTH {
                            IF NewInf[0] = "" {
                                SET Data[i][1] TO NewInf[1].
                            } ELSE {
                                SET Data[i] TO NewInf.
                            }
                        } ELSE {
                            Data:ADD(NewInf).
                        }
                    }
                    mInfo:PUSH(Data).
                }

                // Removes the information on top of the infostack
                ELSE IF iType = "Pop" 
                {
                    IF mInfo:LENGTH > 0 {
                        LOCAL Trash TO mInfo:POP().
                        LOCAL lCount TO 0.
                        FOR line in Trash {
                            PRINT "":PADRIGHT(14) AT (Ic ,Il + mInfoOff + lCount).
                            PRINT "":PADRIGHT(14) AT (Ic2,Il + mInfoOff + lCount).
                            SET lCount TO lCount + 1.
                        }
                        IF mInfo:LENGTH > 0 {
                            SET mInfoOff TO mInfoOff - 1 - mInfo:PEEK():LENGTH.
                        }
                    }
                }

                // Actually prints the information on top of the infostack
                IF iType = "Push" OR iType = "Refresh" AND mInfo:LENGTH > 0{
                    s_Print_Info().
                }
            } ELSE {RETURN False.}
        }
    } ELSE {RETURN False.}
    RETURN True.
}

function s_Print_Log {
//Prints the newest line in the mission log or reprints the whole thing
    DECLARE Parameter reprint TO False.

    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF mLog:LENGTH < TERMINAL:HEIGHT - Logl - 1 AND (reprint = False) {
        UNTIL mLogL >= mLog:LENGTH {
            PRINT (((mLog[mLogL][0]:year-1):TOSTRING + "." + (mLog[mLogL][0]:day-1):TOSTRING + "|" + mLog[mLogL][0]:CLOCK):PADRIGHT(15)
                    + mLog[mLogL][1]:TOSTRING:PADRIGHT(30):SUBSTRING(0,30)) AT (1,Logl + mLogL).
            SET mLogL TO mLogL + 1.
        }
    } ELSE {    //Reprints the whole log, only showing the part, that fits on screen (scrolled to the end)
        LOCAL maxLogHeight TO TERMINAL:HEIGHT - Logl - 1.
        LOCAL LogOff TO 0.
        FOR i IN RANGE(MAX(mLog:LENGTH - maxLogHeight, 0), mLog:LENGTH) {
            PRINT (((mLog[i][0]:year-1):TOSTRING + "." + (mLog[i][0]:day-1):TOSTRING + "|" + mLog[i][0]:CLOCK):PADRIGHT(15)
                    + mLog[i][1]:TOSTRING:PADRIGHT(30):SUBSTRING(0,30)) AT (1,Logl + LogOff).
            SET LogOff TO LogOff + 1.
        }
    }
}

function s_Logspace_Clear {
//Prints empty lines in the Log-space. Useful if you want to use that space for a temporary UI
    FOR i IN RANGE(0,TERMINAL:HEIGHT - Logl - 1) {
        PRINT "":PADRIGHT(45) AT (1, Logl + i).
    }
}

function s_Choose_from_List {
// lets you choose an item from a list using the console
    DECLARE Parameter name, itemList.

    s_Logspace_Clear().
    PRINT "Choose one " + name + " from the list:" AT (1, Logl).
    PRINT "Your choice: " AT (1, Logl + 2).

    LOCAL inputstring TO "".
    LOCAL correctInput TO False.
    LOCAL choiceNum TO -1.                          // chosen item
    LOCAL topItem TO 0.                             // item at top of the screen
    LOCAL listSpace TO TERMINAL:HEIGHT - Logl - 9.  // Items shown at once

    PRINT "Up 1: [up-key]     | Up 1 page: [page-up]    " AT (1, Logl + 5).
    PRINT "_____________________________________________" AT (1, Logl + 6).
    PRINT "_____________________________________________" AT (1, TERMINAL:HEIGHT - 3).
    PRINT "Down 1: [down-key] | Down 1 page: [page-down]" AT (1, TERMINAL:HEIGHT - 2).

    LOCAL pLine TO LogL + 7.
    FOR item IN RANGE(topItem, MIN(listSpace, itemList:LENGTH)) 
    {
        PRINT "[" + item + "] :" AT (1,pLine).
        PRINT itemList[item]:TOSTRING:padright(35):substring(0,35) AT (10,pLine).
        SET pLine TO pLine + 1.
    }

    TERMINAL:Input:CLEAR().
    UNTIL correctInput
    {
        LOCAL retPress TO False.
        UNTIL retPress
        {
            LOCAL char TO TERMINAL:Input:GetChar().
            if char <> TERMINAL:Input:Return
            {
                LOCAL moved TO False.
                if char = TERMINAL:Input:Backspace AND inputString:LENGTH > 0      // Backspace
                {
                    SET inputString TO inputString:substring(0,inputString:length - 1).
                } ELSE IF "0123456789":CONTAINS(char)           // Number
                {
                    SET inputString TO inputString + char.
                } ELSE IF char = TERMINAL:Input:UPCURSORONE     // Directions
                {
                    SET topItem TO MAX(0, topItem - 1).
                    SET moved TO True.
                } ELSE IF char = TERMINAL:Input:DOWNCURSORONE
                {
                    SET topItem TO MIN(topItem + 1, MAX(0,  itemList:LENGTH-listSpace)).
                    SET moved TO True.
                } ELSE IF char = TERMINAL:Input:PAGEUPCURSOR
                {
                    SET topItem TO MAX(0, topItem - listSpace).
                    SET moved TO True.
                } ELSE IF char = TERMINAL:Input:PAGEDOWNCURSOR
                {
                    SET topItem TO MIN(topItem + listSpace, MAX(0,  itemList:LENGTH-listSpace)).
                    SET moved TO True.
                }
                IF moved {
                    LOCAL pLine TO LogL + 7.
                    FOR item IN RANGE(topItem, MIN(listSpace, itemList:LENGTH)) 
                    {
                        PRINT "[" + item + "]" AT (1,pLine).
                        PRINT itemList[item]:TOSTRING:padright(20):substring(0,20) AT (7,pLine).
                        SET pLine TO pLine + 1.
                    }
                }
                Print inputString:padright(20):substring(0,20) AT (10, Logl + 1).
                LOCAL inputNum TO inputString:TONUMBER(-1).
                IF inputNum < itemList:length AND inputNum >= 0 {
                    PRINT itemList[floor(inputNum)]:TOSTRING:padright(20):substring(0,20) AT (10, Logl + 3).
                } ELSE {
                    PRINT "":padright(20):substring(0,20) AT (10, Logl + 3).
                }
            } ELSE {
                SET retPress TO True.
            }
        }
        SET choiceNum TO inputString:TONUMBER(-1).
        IF choiceNum >= itemList:length OR choiceNum < 0
        {
            PRINT "":padright(20):substring(0,20) AT (10, Logl + 3).
            SET inputString TO "".
            Print inputString:padright(20):substring(0,20) AT (10, Logl + 1).
        } ELSE {
            SET choiceNum TO floor(choiceNum).
            SET correctInput TO True.
        }
    }
    s_Logspace_Clear().
    s_Print_Log().
    Return choiceNum.
}

function s_Print_Mission {
//Reprints all the mission info (Mission name, Subprogram name, Status, Stage)
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }
    PRINT mMission:PADRIGHT(29):SUBSTRING(0,29) AT (Ic, Mil).
    PRINT mSubProg:PADRIGHT(29):SUBSTRING(0,29) AT (Ic, Spl).
    PRINT mStatus:PADRIGHT(29):SUBSTRING(0,29) AT (Ic, Stl).
    PRINT mStage:PADRIGHT(14):SUBSTRING(0,14) AT (Ic2,Il-2).
}

function s_Print_Info {
//Prints the newly changed info or the whole info-stack
    DECLARE Parameter reprint TO False.

    IF reprint {
        LOCAL reverseInfo TO stack().
        UNTIL mInfo:LENGTH = 0 {    // Deletes all info from the stack and stores it.
            reverseInfo:PUSH(mInfo:POP()).
            LOCAL lCount TO 0.
            FOR line in Trash {
                PRINT "":PADRIGHT(14) AT (Ic ,Il + mInfoOff + lCount).
                PRINT "":PADRIGHT(14) AT (Ic2,Il + mInfoOff + lCount).
                SET lCount TO lCount + 1.
            }
            IF mInfo:LENGTH > 0 {
                SET mInfoOff TO mInfoOff - 1 - mInfo:PEEK():LENGTH.
            }
        }

        UNTIL reverseInfo:LENGTH = 0 {  // Pushes it back to the stack and prints it.
            IF mInfo:LENGTH > 0 {
                SET mInfoOff TO mInfoOff + 1 + mInfo:PEEK():LENGTH.
            }
            mInfo:PUSH(reverseInfo:POP()).
            s_Print_Info().
        }
    } ELSE {                            // Prints the top of the info stack.
        LOCAL Data TO mInfo:PEEK().
        LOCAL lCount TO 0.
        FOR line IN Data {
            PRINT line[0]:TOSTRING:PADRIGHT(14):SUBSTRING(0,14) AT (Ic ,Il + mInfoOff + lCount).
            PRINT line[1]:TOSTRING:PADRIGHT(14):SUBSTRING(0,14) AT (Ic2,Il + mInfoOff + lCount).
            SET lCount TO lCount + 1.
        }
    }
}

function s_Log {
//logs text to layout
    DECLARE Parameter text.
            //text:string or list of strings. text to log
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    RETURN s_Layout(lexicon("Log", text)).
}

function s_Info_push {
// pushes a new info block to the layout. This will now be the working block
    DECLARE Parameter name, text.
            //name: Name of info
            //text: Text of info
    
    IF (name:TYPENAME = "list" AND text:TYPENAME <> "list") OR (name:TYPENAME <> "list" AND text:TYPENAME = "list") {
        RETURN False.
    }

    // Adds tupels of name and info to the pushList
    LOCAL pushList TO list().
    IF name:TYPENAME = "list" {
        FOR i in RANGE(name:LENGTH) {
            IF text:LENGTH > i {
                pushList:ADD(list(name[i], text[i])).
            } ELSE {
                pushList:ADD(list(name[i], "")).
            }
        }
    } ELSE {
        pushList:ADD(list(name, text)).
    }

    IF DEFINED layoutDone = False {
        s_Layout().
    }
    // Pushes the info
    RETURN s_Layout(lexicon("Info", lexicon("Type", "Push", "Info", pushList))).
}

function s_Info_ref {
// refreshes the current info block in the layout
    DECLARE Parameter name, text.
            //name: Name of info
            //text: Text of info
    

    // Adds tupels of name and info to the pushList
    LOCAL refList TO list().
    IF name <> "" {
        IF (name:TYPENAME = "list" AND text:TYPENAME <> "list") OR (name:TYPENAME <> "list" AND text:TYPENAME = "list") {
            RETURN False.
        }
        IF name:TYPENAME = "list" {
            FOR i in RANGE(text:LENGTH) {
                IF name:LENGTH > i {
                    refList:ADD(list(name[i], text[i])).
                } ELSE {
                    refList:ADD(list("", text[i])).
                }
            }
        } ELSE {
            refList:ADD(list(name, text)).
        }
    } ELSE {
        IF text:TYPENAME = "list" {
            For i in RANGE(text:LENGTH) {
                refList:ADD(list("", text[i])).
            }
        } ELSE {
            refList:ADD(list("",text)).
        }
    }

    IF DEFINED layoutDone = False {
        s_Layout().
    }
    // Pushes the info
    RETURN s_Layout(lexicon("Info", lexicon("Type", "Refresh", "Info", refList))).
}

function s_Info_pop {
// Deletes the working info block in the layout.
    RETURN s_Layout(lexicon("Info", lexicon("Type", "Pop"))).
}

function s_Info_Clear {
// clears information in layout.
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    // Prints empty strings to all information fields
    LOCAL l TO Il.

    PRINT "":PADRIGHT(30) AT (Ic,spl).
    PRINT "":PADRIGHT(30) AT (Ic,stl).

    UNTIL mInfo:LENGTH < 1 {
        s_Info_pop().
    }
}

function s_Mission {
// prints missionname to layout
    DECLARE Parameter name.
            //name: Name of mission
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    RETURN s_Layout(lexicon("Mission", name)).
}

function s_Sub_Prog {
// prints subprogramname to layout
    DECLARE Parameter name.
            //name: Name of mission
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    RETURN s_Layout(lexicon("Subprogram", name)).
}

function s_Status {
// prints programstate to layout
    DECLARE Parameter name.
            //name: Name of mission
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }
    
    RETURN s_Layout(lexicon("Status", name)).
}

function s_Stage {
// prints programstate to layout
    DECLARE Parameter name.
            //name: Name of mission
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }
    
    RETURN s_Layout(lexicon("Stage", name)).
}

// ________________________________________________________________________________________________________________
// a:[Auto] Small functions for improved usability.
// ________________________________________________________________________________________________________________

function a_Stage {
// Checks if staging is neccessary and does if it is
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF (DEFINED lastStage) = False
    {
        GLOBAL lastStage TO 0.  // The missiontime the last staging event happened
    }

    // leaves at least 2 seconds between staging actions
    IF missiontime - lastStage > 2 OR SHIP:STATUS = "Prelaunch"
    {
        LOCAL eng TO 0.
        LIST engines IN eng.

        // Stages if an engine is flamed out, one of the fuel resources is depleted or the ship is in the launch pad

        LOCAL stageFlag TO False.
        IF AVAILABLETHRUST = 0 OR SHIP:STATUS = "Prelaunch"
        {
            SET stageFlag TO True.
        } else {
            FOR e IN eng
            {
                IF e:flameout
                {
                    SET stageFlag TO True.
                    BREAK.
                }
            }   
            // The fuels checked are LiquidFuel, Oxidizer and SolidFuel (Not in this order)
            IF  (STAGE:RESOURCES[0]:AMOUNT = 0 AND STAGE:RESOURCES[0]:CAPACITY > 0) OR 
                (STAGE:RESOURCES[2]:AMOUNT = 0 AND STAGE:RESOURCES[2]:CAPACITY > 0) OR
                (STAGE:RESOURCES[4]:AMOUNT = 0 AND STAGE:RESOURCES[4]:CAPACITY > 0) {
                SET stageFlag to True.
            }
        }

        IF stageFlag
        {
            IF missiontime > 1  // The launch event will not log
            {
                s_Log("Stage " + STAGE:NUMBER).
            }
            s_Stage(STAGE:NUMBER-1).
            STAGE.
            SET lastStage TO missiontime.
            RETURN True.
        }
    }
    RETURN False.
}

function a_Check_Target {
// checks if a target fills certain criteria.
    DECLARE Parameter targ TO 0, targType TO 0.
                    // targ: 0: choose targetet vessel else set to the target
                    // targType:0: All allowed          // you can add_ them to get combinations (e.g.: 1 + 2 means Vessels and Dockingports allowed)
                    //          1: Vessel
                    //          2: Dockingport
                    //          4: Body
                    //          8: rendevouzable

    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    LOCAL cVes TO 0.
    LOCAL cDoc TO 0.
    LOCAL cBod TO 0.
    LOCAL cRen TO 0.

    SET targType TO MOD(targType, 16).
    IF targType >= 8 {
        SET cRen TO 1.
        SET targType TO targType - 8.
    }
    IF targType >= 4 {
        SET cBod TO 1.
        SET targType TO targType - 4.
    }
    IF targType >= 2 {
        SET cDoc TO 1.
        SET targType TO targType - 2.
    }
    IF targType >= 1 {
        SET cVes TO 1.
    }

    IF targ = 0 {
        IF HASTARGET {
            SET targ TO TARGET.
        } ELSE {
            s_Status("Error: No target chosen").
            RETURN False.
        }
    }

    LOCAL targParent TO targ.

    // Spaghetti code to check all possibilities
    IF targ:TYPENAME = "DOCKINGPORT" AND cDoc = False {
        s_Status("Error: Target is DOCKINGPORT").
        RETURN False.
    } ELSE IF targ:TYPENAME = "DOCKINGPORT" {
        SET targParent TO targ:SHIP.
    } 
    IF targ:TYPENAME = "BODY" AND cBod = False {
        s_Status("Error: Target is BODY").
        RETURN False.
    }
    IF targ:TYPENAME <> "VESSEL" AND targ:TYPENAME <> "BODY" AND targ:SHIP:TYPENAME = "VESSEL" AND cVes {
        IF NOT (targ:TYPENAME = "DOCKINGPORT" AND cDoc) {
            SET targ TO targ:SHIP.
        }
    }
    IF targ:TYPENAME = "VESSEL" AND cVes = False {
        s_Status("Error: Target is VESSEL").
        RETURN False.
    }
    IF targ:TYPENAME <> "VESSEL" AND targ:TYPENAME <> "BODY" AND targ:SHIP:TYPENAME <> "VESSEL" AND cRen {
        s_Status("Error: Target not ORBITABLE").
        RETURN False.
    }
    IF targ:name:contains("Sun") AND cRen {
        s_Status("Error: Can't rendevouz with sun.").
        RETURN False.
    } ELSE IF targ = SHIP AND cRen {
        s_Status("Error: Can't rendevouz with yourself").
        RETURN False.
    }
    IF SHIP:BODY <> targParent:BODY AND cRen {
        s_Status("Error: Target not in same SOI").
        RETURN False.
    }
    IF targ:TYPENAME <> "BODY" AND (targ:TYPENAME = "VESSEL" OR targ:SHIP:TYPENAME = "VESSEL") AND cRen {
        IF targParent:OBT:PERIAPSIS < BODY:ATM:HEIGHT  OR targParent:OBT:APOAPSIS < 0{
            s_Status("Error: Target not in orbit").
            RETURN False.
        }
    }
    RETURN targ.
}

function a_Prompt_Target {
// prompts the player to select a target. 
    DECLARE Parameter useList TO False.

    If useList 
    {
        LOCAL targType TO s_Choose_from_List("targettype",list("Vessel","Body","SpaceObject")).
        LOCAL targList TO list().
        LOCAL listString TO "".
        LOCAL counter TO 0.
        IF targType = 0 {
            SET listString TO "Vessel".
            LIST targets IN targList.
            FOR targ in RANGE(0, targList:LENGTH) {
                IF targList[counter]:type = "SpaceObject" {
                    targList:REMOVE(counter).
                } ELSE {
                    SET counter TO counter + 1.
                }
            }
        } ELSE IF targType = 2 {
            SET listString TO "SpaceObject".
            FOR targ in RANGE(0, targList:LENGTH) {
                IF targList[counter] <> "SpaceObject" {
                    targList:REMOVE(counter).
                } ELSE {
                    SET counter TO counter + 1.
                }
            }
        } ELSE {
            SET listString TO "Body".
            LIST bodies in targList.
        }
        LOCAL targNum TO s_Choose_from_List(listString, targList).
        SET TARGET TO targList[targNum].
    }
    ELSE
    {
        s_Info_push("Select target: ","").
        LOCAL correctInput TO False.
        Terminal:Input:CLEAR.
        UNTIL correctInput
        {
            LOCAL retPress TO False.
            LOCAL char TO " ".
            UNTIL retPress
            {
                IF Terminal:input:hasChar() {
                    SET char TO Terminal:Input:GetChar().
                }
                if char <> Terminal:Input:Return
                {
                    IF HASTARGET {
                        s_Info_ref("", TARGET:NAME).
                    } ELSE {
                        s_Info_ref("", "No selection").
                    }
                } ELSE {
                    SET retPress TO True.
                }
            }
            IF NOT HASTARGET {
                SET retPress TO False.
            } ELSE {
                SET correctInput TO True.
            }
        }
        s_Info_pop().
    }
    RETURN TARGET.
}

function a_Wait_For_Enter {
// waits until an enter keypress. Great for debugging
    UNTIL False{
        LOCAL char TO TERMINAL:INPUT:GETCHAR().
        if char = TERMINAL:INPUT:RETURN{BREAK.}
    }
}

function a_Clamp {
// clamps a value via modulo between two values. 
// E.g.: a_Clamp(-45,360, 0) = 325 or a_Clamp(270,180,-180) = -90.
// Great for working with angles.
    DECLARE Parameter v, b_max, b_min TO 0.
    LOCAL m TO b_max - b_min.
    RETURN MOD(MOD(v, m) - b_min + m, m) + b_min.
}

function a_Warp_To {
// Time warps to or for a specified TIME
// E.g.: a_Warp_To(20, 0) warps 20 seconds into the future
//       a_Warp_To(time:seconds + 20, 1) does the same
    DECLARE Parameter step, mode TO 0.
            // step: timestamp/TIME amount.
            // mode: switches between relative[0] and absolute[1] TIME warping

    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    s_Sub_Prog("WarpTo").

    s_Info_push("Time to warp:" , "").

    IF mode = 0
    {
        SET step TO TIME:SECONDS + step.
    }

    s_Info_ref("", (step - TIME):CLOCK).

    KUNIVERSE:TIMEWARP:CANCELWARP.
    WAIT 1.
    IF SHIP:STATUS = "ORBITING" OR SHIP:STATUS = "SUB_ORBITAL" OR SHIP:STATUS = "LANDED" OR SHIP:STATUS = "PRELAUNCH" OR SHIP:STATUS = "ESCAPING"
    {
        WarpTo(step-1).
        SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
        s_Status("On Rails timewarp").
    } ELSE {
        s_Status("Can't warp right now").
    }

    UNTIL (step - TIME:SECONDS) < 120
    {
        s_Info_ref("", (step - TIME):CLOCK).
        IF SHIP:STATUS = "ORBITING" OR SHIP:STATUS = "SUB_ORBITAL" OR SHIP:STATUS = "LANDED" OR SHIP:STATUS = "PRELAUNCH" OR SHIP:STATUS = "ESCAPING"
        {
            WarpTo(step-1).
        SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
            s_Status("On Rails timewarp").
        } ELSE {
            s_Status("Can't warp right now").
        }
        WAIT 10.
    }
    UNTIL (step - TIME:SECONDS) < 1
    {
        s_Info_ref("", (step - TIME):CLOCK).
        WAIT 0.25.
    }
    s_Info_pop().
}

// ________________________________________________________________________________________________________________
// c:[Calc] Small functions that RETURN up-to-date calculated information.
// ________________________________________________________________________________________________________________

function c_Orb_Vel {
// RETURN orbital speed at a given altitude for a given orbit
    DECLARE Parameter pBody TO 0, pNode1 TO 0, pNode2 TO 0, pAlt TO 0, goalPos TO 1.
            // pBody:body	,the chosen body
            // pNode1:int	,node1
            // pNode2:int	,node2
            // pAlt:int	    ,where to calculate the velocity
            // goalPos:int  ,[1] if distances are measured from the surface of the BODY
            //              ,[0] if from measured center of the BODY
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF pBody = 0 {SET pBody TO BODY.}
    IF pNode1 = 0 {SET pNode1 TO APOAPSIS.}
    IF pNode2 = 0 {SET pNode2 TO PERIAPSIS.}
    IF pAlt = 0 {SET pAlt TO ALTITUDE.}

    LOCAL pAlt TO pAlt + pBody:RADIUS*goalPos.

    LOCAL SMA TO (pNode1+pNode2)/2+pBody:RADIUS*goalPos.
    RETURN SQRT(pBody:MU*(2/pAlt-1/SMA)).
}

function c_Simple_Man {
// creates a maneuver-node for a pro-/retrograde Apo-/Periapsis burn.
    DECLARE Parameter x1, x2.
            // x1:bool	,at Apoapsis? (1 equals Ap, everything else Pe)
            // x2:int	,new other node altitude
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    s_Sub_Prog("c_Simple_Man").

    LOCK THROTTLE TO 0.

    LOCAL burnPoint TO APOAPSIS.
    LOCAL esta is 0.

    IF x1 <> 1 {
        SET burnPoint TO PERIAPSIS.
        LOCK esta TO ETA:PERIAPSIS.
    } ELSE {
        LOCK esta TO ETA:APOAPSIS.
    }

    LOCAL vdiff TO c_Orb_Vel(0,x2,burnPoint,burnPoint) - c_Orb_Vel(0,0,0,burnPoint).

    LOCAL burnNode is Node(TIME:SECONDS+esta,0,0,vdiff).
    RETURN burnNode.
}

function c_Circ_Man {
// calculates a maneuver node for a maneuver given as transition between two combinations of velocities outward and forward in orbit
    DECLARE Parameter dTime, vStart, vEnd, incChange IS 0.
            // dTime:[int]:                         time, when to start the manouver
            // vStart:[list](vTangential, vRadial): velocity combination at start
            // vEnd:[list](vTangential, vRadial):   velocity combination at the end
            // incChange:[float]:                   additional inclination change

            // For example if the radial velocity (pointing in the up-direction) is 0, you are at apoapsis or periapsis.
            // In a circular orbit there is only tangential velocity.

    LOCAL _alpha TO ARCTAN(vStart[1]/vStart[0]).

    LOCAL vec_End TO V( COS(incChange) * vEnd[0],
                        SIN(incChange) * vEnd[0],
                        vEnd[1]).

    LOCAL vec_Start TO V(vStart[0],
                       0,
                       vStart[1]).

    LOCAL delt_Vec TO vec_End - vec_Start.
    LOCAL man_Vec TO V( COS(_alpha) * delt_Vec:X + SIN(_alpha) * delt_Vec:Z,
                        -SIN(_alpha)* delt_Vec:X + COS(_alpha) * delt_Vec:Z,
                        delt_Vec:Y).
    
    RETURN node(TIME:SECONDS + dTime, man_Vec:Y, man_Vec:Z, man_Vec:X).
}

function c_Inc_Change {
// creates a maneuver-node to change the orbital inclination.
    DECLARE Parameter inc, mode TO 0.
                    // The target inclination either:
                    //      absolute:   mode=[0]
                    //      relative:   mode=[1]
    LOCAL myANDN TO c_AsDe_Anomaly(OBT, 0).
    LOCAL ANnext TO True.
    LOCAL nextNode TO myANDN["AN"].
    IF a_Clamp(nextNode[0] - OBT:TRUEANOMALY,180,-180) < 0 {
        SET nextNode TO myANDN["DN"].
        SET ANnext TO False.
    }
    LOCAL myVNode TO c_Orbit_Velocity_Vector(nextNode[0]).
    LOCAL deltTime TO c_Time_from_Mean_An(a_Clamp(nextNode[2]-c_MeanAN(),360)).
    IF mode = 0 {
        IF ANnext {
            SET inc TO inc - ABS(myANDN["relInc"]).
        } ELSE {
            SET inc TO ABS(myANDN["relInc"]) - inc.
        }
    }
    RETURN c_Circ_Man(deltTime,myVNode,myVNode,inc).
}

function c_Orbit_Velocity_Vector {
// calculates the radial and tangential components of the orbital velocity of an orbit at a given true anomaly
// The radial velocity is positive in the up direction
// The tangential velocity is always positive
    DECLARE Parameter truAn, orbt TO OBT.
            // truAn: The true anomaly at that point
            // orbt: The orbit

    LOCAL _mu TO orbt:BODY:MU.
    LOCAL _sma TO orbt:SEMIMAJORAXIS.
    LOCAL _e TO orbt:ECCENTRICITY.
    LOCAL _i TO orbt:INCLINATION.

    LOCAL _h TO SQRT(_mu * _sma * (1-_e^2)).
    LOCAL _r TO _sma * (1-_e^2) / (1 + _e * COS(truAn)).

    LOCAL v_forw TO _h / _r.
    LOCAL v_rad TO _mu * _e * SIN(truAn) / _h.
    RETURN list(v_forw, v_rad).
} 

function c_Orbit_Vector {
// calculates the normal vector of the orbit, the vector pointing along the Ascending Node of the orbit
// and a forward vector perpendicular to both using the solarprimevector as x-axis and north as z-axis.

// !!Warning this is using a right-handed coordinate system!!
    DECLARE Parameter orbit.
    
    LOCAL inc TO ref:INCLINATION.
    LOCAL omg TO ref:LAN.
    LOCAL v_n TO v(SIN(inc)*SIN(omg),-SIN(inc)*COS(omg),COS(inc)).
    LOCAL v_Lan TO v(COS(omg), SIN(omg),0).
    LOCAL v_Forw TO v(-SIN(omg)*COS(inc), COS(omg)*COS(inc),SIN(inc)).
    RETURN list(v_n, v_Lan, v_Forw).
}

function c_AsDe_Anomaly {
// calculates the ascending and descending node from one orbit to another.
    DECLARE Parameter ref TO OBT, targ TO 1.
            // ref:  orbit:  the reference orbit for the ascending and descending node.
            // targ: Int: [0]: calculate for the current body
            //            [1]: calculate for the current target
            //       vessel: calculate for that vessel
            //       body:   calculate for that body
            //       orbit:  calculate for that orbit

    // Returns a lexicon of 3 items:
    //      ["AN"]:     a list containing the [0]: True Anomaly of the Ascending Node
    //                                        [1]: Eccentric Anomaly of the Ascending Node
    //                                        [2]: Mean Anomaly of the Ascending Node
    //                                        [3]: Altitude of the Ascending Node above the BODY
    //      ["DN"]:     a list containing the same items as ["AN"] for the Descending Node
    //      ["relInc"]: the relative inclination between the orbits
    
    IF targ = 1 {
        IF HASTARGET {
            SET targ TO TARGET.
            IF targ:TYPENAME = "PART" {
                SET targ TO targ:SHIP.
            }
        } ELSE {
            s_Status("No target set").
            RETURN False.
        }
    }
    IF targ:TYPENAME = "vessel" OR targ:TYPENAME = "body" {
        IF targ:HASOBT {
            SET targ TO targ:OBT.
        } ELSE {
            s_Status("Target does not have orbit").
            RETURN False.
        }
    }

    LOCK THROTTLE TO 0.
    RCS OFF.
    WAIT 1.

    LOCAL inc TO ref:INCLINATION.
    LOCAL omg TO ref:LAN.
    LOCAL v_n TO v(SIN(inc)*SIN(omg),-SIN(inc)*COS(omg),COS(inc)).
    LOCAL v_n_t TO v(0,0,1).
    IF targ:TYPENAME = "ORBIT" AND targ <> ref{
        LOCAL inc_t TO targ:INCLINATION.
        LOCAL omg_t TO targ:LAN.
        SET v_n_t TO v(SIN(inc_t)*SIN(omg_t),-SIN(inc_t)*COS(omg_t),COS(inc_t)).
    }
    LOCAL v_x TO VCRS(v_n_t, v_n):NORMALIZED.               // Vector towards the ascending node
    LOCAL relInc TO VANG(v_n_t, v_n).                       // Angle between orbits.

    LOCAL v_Lan TO v(COS(omg), SIN(omg),0).
    LOCAL v_Forw TO v(-SIN(omg)*COS(inc), COS(omg)*COS(inc),SIN(inc)).
    LOCAL beta TO VANG(v_x,v_Lan).
    IF VDOT(v_x,v_Forw) < 0 {
        SET beta TO -beta.
    }

    LOCAL orbNodes TO lexicon("AN",list(a_Clamp(beta - ref:ARGUMENTOFPERIAPSIS, 360)),"DN",list(a_Clamp(beta - ref:ARGUMENTOFPERIAPSIS + 180, 360))).  // true Anomaly
    FOR _node in orbNodes:Keys {
        LOCAL eccAn TO a_Clamp(2* ARCTAN(SQRT((1-ref:ECCENTRICITY)/(1+ref:ECCENTRICITY))*TAN(orbNodes[_node][0]/2)), 360).   // eccentric Anomaly
        orbNodes[_node]:ADD(eccAn).
        LOCAL meaAn TO a_Clamp((eccAn*CONSTANT:PI/180 - ref:ECCENTRICITY * SIN(eccAn))*180/CONSTANT:PI, 360).      // mean Anomaly
        orbNodes[_node]:ADD(meaAn).
        LOCAL altNo TO ref:SEMIMAJORAXIS*(1-ref:ECCENTRICITY^2)/(1+ref:ECCENTRICITY*COS(orbNodes[_node][0])).  // orbit height of node
        orbNodes[_node]:ADD(altNo - OBT:BODY:RADIUS).
    }
    SET orbNodes["relInc"] TO relInc.
    RETURN(orbNodes).
}

function c_Time_from_Mean_An {
// calculates the time it takes to pass a given amount of mean anomaly given the orbital period
    DECLARE Parameter meaAn, priod TO OBT:PERIOD.
            // meaAn: the amount of mean anomaly    // priod: the orbital period
    RETURN(priod * meaAn/360).
}

function c_Mean_An_from_Tru {
// calculates the Mean Anomaly from the True one
    DECLARE Parameter phi, ec.
    LOCAL E TO 2 * ARCTAN(TAN(phi/2) * SQRT((1- ec)/(1 + ec))).
    RETURN a_Clamp(((E * CONSTANT:PI / 180 - ec * SIN(E)) * 180 / CONSTANT:PI), 360).
}

function c_Tru_An_from_Mean {
// calculates the True Anomaly from the Mean one
// As this can't be analytically solved, it is only an approximation and takes a good bit of processing power to make exact.
// I suggest raising the allowed operations per tick for kOS.

    DECLARE Parameter M, ec.
    SET M TO a_Clamp(M, 180, -180).

    LOCAL err TO 180*ec^3.
    LOCAL phi_m TO M + 180/CONSTANT:PI*(2*ec-0.25*ec^3)*sin(M) + 180/CONSTANT:PI*(1.25*ec^2)*sin(2*M) + 180/CONSTANT:PI*(13/12*ec^3)*sin(3*M).
    LOCAL phi_0 TO 0.
    LOCAL phi_1 TO 0.
    IF M > 0 {
        SET phi_0 TO MAX(0, phi_m - err).
        SET phi_1 TO MIN(180, phi_m + err).
    } ELSE {
        SET phi_0 TO MAX(-180, phi_m - err).
        SET phi_1 TO MIN(0, phi_m + err).
    }
    LOCAL M_m TO a_Clamp(c_Mean_An_from_Tru(phi_m, ec), 180, -180).
    UNTIL ABS(M_m - M) < 0.001 {
        IF M_m > M {
            SET phi_1 TO phi_m.
            SET phi_m TO (phi_0 + phi_1)/2.
        } ELSE {
            SET phi_0 TO phi_m.
            SET phi_m TO (phi_0 + phi_1)/2.
        }
        SET M_m TO a_Clamp(c_Mean_An_from_Tru(phi_m, ec), -180, 180).
    }
    RETURN a_Clamp(phi_m,360).
}

function c_r_from_Tru {
// calculates the height over the BODY center from the true anomaly
    DECLARE Parameter phi, ec TO OBT:ECCENTRICITY, sma TO OBT:SEMIMAJORAXIS.
    RETURN sma * (1 - ec^2) / (1 + ec*COS(phi)).
}

function c_Tru_from_r {
// calculates the true anomaly from the height over the center of the BODY
    DECLARE Parameter r, ec TO OBT:ECCENTRICITY, sma TO OBT:SEMIMAJORAXIS.
    RETURN 180 - ARCCOS((sma * ec^2 - sma + r)/(ec*r)).
}

function c_Orbit_Pos {
// calculates the position in orbit in relation to the parent body and the solarprimevector
// It uses the solarprimevector as x-axis and north as z-axis.

// !!Warning this is using a right-handed coordinate system!!

    DECLARE Parameter orb TO False,
                      phi TO OBT:TRUEANOMALY, 
                      argPe TO OBT:ARGUMENTOFPERIAPSIS, 
                      lan TO OBT:LAN, 
                      ec TO OBT:ECCENTRICITY, 
                      inc TO OBT:INCLINATION, 
                      sma TO OBT:SEMIMAJORAXIS.

    IF orb:TYPENAME = "Orbit" {
        SET phi TO orb:TRUEANOMALY.
        SET argPe TO orb:ARGUMENTOFPERIAPSIS.
        SET lan TO orb:LAN.
        SET ec TO orb:ECCENTRICITY.
        SET inc TO orb:INCLINATION.
        SET sma TO orb:SEMIMAJORAXIS.
    }
    
    LOCAL r TO c_r_from_Tru(phi, ec, sma).
    RETURN V((-sin(lan)*cos(inc)*sin(phi + argPe)+cos(lan)*cos(phi + argPe))*r, 
             (sin(lan)*cos(phi + argPe)+cos(lan)*cos(inc)*sin(phi + argPe))*r,
              sin(inc)*sin(phi + argPe)*r).
}

function c_Orbit_Period {
// calculates the orbit period of a given sma (Semimajoraxis) and mu (BODY:MU / Gravitational parameter) combination
    DECLARE Parameter a, mu TO BODY:MU.
    RETURN 2*CONSTANT:PI * SQRT((a)^3/mu).
}

function c_Closest_Approach {
// calculates the closest approaches between orbit 1 and orbit 2
// As this can't be analytically solved it is only an approximation and can take a lot of processing power (Uses "c_Tru_An_from_Mean()" a lot).
// I suggest raising the allowed operations per tick for kOS.

    DECLARE Parameter orb1, orb2, phi_min TO 0, delt_phi TO 360, phi_start TO orb1:TRUEANOMALY, epoch_start TO TIME:SECONDS.
    // It RETURNs a list of [n]: Encounter-lists with each having:
        // [0]: The distance at Encounter
        // [1]: Mean Anomaly of orbit 1 at Encounter
        // [2]: True Anomaly of orbit 1 at Encounter
        // [3]: Mean Anomaly of orbit 2 at Encounter
        // [4]: True Anomaly of orbit 2 at Encounter
        // [5]: Radius in orbit 1 at Encounter from center of BODY

    LOCAL div TO 8.

    LOCAL M1_0 TO a_Clamp(orb1:MEANANOMALYATEPOCH + (epoch_start - orb1:EPOCH) * 360/orb1:PERIOD, 360).
    LOCAL M2_0 TO a_Clamp(orb2:MEANANOMALYATEPOCH + (epoch_start - orb2:EPOCH) * 360/orb2:PERIOD, 360).

    LOCAL distList TO list().
    FOR i IN RANGE(0,div) {
        LOCAL phi TO phi_min + i*delt_phi/div.
        LOCAL phi1 TO a_Clamp(phi_start + phi, 360).
        LOCAL pos1 TO c_Orbit_Pos(False, phi1, orb1:ARGUMENTOFPERIAPSIS, orb1:LAN, orb1:ECCENTRICITY, orb1:INCLINATION, orb1:SEMIMAJORAXIS).
        LOCAL M1 TO c_Mean_An_from_Tru(phi1, orb1:ECCENTRICITY).
        LOCAL T TO a_Clamp(M1 - M1_0, 360) * orb1:PERIOD / 360.
        LOCAL M2 TO a_Clamp(M2_0 + T * 360 / orb2:PERIOD, 360).
        LOCAL phi2 TO c_Tru_An_from_Mean(M2, orb2:ECCENTRICITY).
        LOCAL pos2 TO c_Orbit_Pos(False, phi2, orb2:ARGUMENTOFPERIAPSIS, orb2:LAN, orb2:ECCENTRICITY, orb2:INCLINATION, orb2:SEMIMAJORAXIS).
        distList:ADD(list((pos1 - pos2):MAG, M2, phi2)).
    }
    LOCAL retList TO list().
    LOCAL lastDist TO distList[div - 1][0].
    LOCAL nextDist TO distList[1][0].
    FOR i in RANGE(0,div) {
        IF i = div - 1 {
            SET nextDist TO distList[0][0].
        } ELSE {
            SET nextDist TO distList[i+1][0].
        }
        IF distList[i][0] < lastDist AND distList[i][0] < nextDist {
            LOCAL phiClose TO phi_min + i * delt_phi/div.
            LOCAL rClose TO c_r_from_Tru(phiClose, orb1:ECCENTRICITY, orb1:SEMIMAJORAXIS).
            IF rClose * delt_phi * CONSTANT:PI/(180*div) < 100 {
                LOCAL M1 TO c_Mean_An_from_Tru(phiClose + phi_start, orb1:ECCENTRICITY).
                retList:ADD(list(distList[i][0], M1, phiClose + phi_start, distList[i][1], distList[i][2], rClose)).
            } ELSE {
                LOCAL subRetList TO c_Closest_Approach(orb1, orb2, phiClose - delt_phi/div, 2*delt_phi/div, phi_start, epoch_start).
                FOR Ret in subRetList {
                    retList:ADD(Ret).
                }
            }
        }
        SET lastDist TO distList[i][0].
    }
    RETURN retList.
}

function c_MeanAN {
// calculates the mean anomaly of an orbit a given time from now
    DECLARE Parameter orb TO OBT, dTime TO 0.
                    // orb: the orbit 
                    // dTime: time from now
    RETURN a_Clamp(orb:MEANANOMALYATEPOCH + 360 * (TIME:SECONDS + dTime - orb:EPOCH) / orb:PERIOD, 360).
}

function c_Equ_TruAn {
// calculates the True Anomaly for the second orbit where both positions have the same rotation around the z axis
// useful for some kind of rendevouz calculations

    DECLARE Parameter phi_1, orb1, orb2.
    LOCAL lan_1 TO orb1:LAN.
    LOCAL arPe_1 TO orb1:ARGUMENTOFPERIAPSIS.
    LOCAL lan_2 TO orb2:LAN.
    LOCAL arPe_2 TO orb2:ARGUMENTOFPERIAPSIS.

    LOCAL phi_2 TO arctan(sin(phi_1+arPe_1+lan_1-lan_2)/cos(phi_1+arPe_1+lan_1-lan_2)).
    IF cos(phi_1+arPe_1+lan_1-lan_2) < 0 {
        SET phi_2 TO -phi_2 + 180.
    }
    RETURN a_Clamp(phi_2 - arPe_2, 360).
}

function c_Safe_Orientation {
// calculates an orientation where all extendable solar panels will be exposed as much as possible.

    LOCAL sParts TO SHIP:PARTS.
    LOCAL sPanels TO list().
    FOR item IN sParts {
        IF item:name = "largeSolarPanel" {
            sPanels:ADD(list(item, 15.25)).
        } ELSE IF item:name = "solarPanels3" OR item:name = "solarPanels4" {
            sPanels:ADD(list(item, 1)).
        }
    }
    LOCAL currentVector TO V(0,0,0).
    for panel in sPanels {
        LOCAL pVec TO panel[0]:FACING:STARVECTOR.
        SET pVec TO (pVec*pVec:Y/ABS(pVec:Y)):VEC.
        SET currentVector TO currentVector + panel[1]*pVec.
    }
    SET currentVector TO currentVector:NORMALIZED.
    LOCAL rotVec TO VCRS(currentVector, V(0,1,0)).
    LOCAL neededRotation TO ANGLEAXIS(VANG(currentVector, V(0,1,0)), rotVec).
    LOCAL newFacing TO neededRotation * SHIP:FACING:VECTOR.
    LOCAL newTop TO neededRotation * SHIP:FACING:TOPVECTOR.
    LOCAL newDir TO LOOKDIRUP(newFacing, newTop).
    RETURN newDir.
}

// ________________________________________________________________________________________________________________
// p:[Program] Scripts to perform complex maneuvers.
// ________________________________________________________________________________________________________________

function p_Orb_Burn {
// executes a given maneuver-node.
    DECLARE Parameter manNode.
            //manNode:node	,the manouver node to execute.

    IF (DEFINED deltaVdone) = False {
        RUNPATH("libraries/DeltaVLib").
    }
    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    LOCAL nodeBackup TO list().
    FOR node IN allNodes
    {
        IF node <> manNode{
            nodeBackup:ADD(node).
        }
        REMOVE node.
    }
    ADD manNode.

    s_Sub_Prog("p_Orb_Burn").
    s_Info_push("deltaV:", round(manNode:DELTAV:MAG ,1) + " m/s").

    LOCAL scale TO (manNode:DELTAV:MAG + 1)/manNode:DELTAV:MAG.

    SET manNode:PROGRADE TO manNode:PROGRADE * scale.
    SET manNode:RADIALOUT TO manNode:RADIALOUT * scale.
    SET manNode:NORMAL TO manNode:NORMAL * scale.

    LOCAL LOCK acc TO AVAILABLETHRUST/MASS.
    LOCAL LOCK safeacc TO MAX(acc, 0.001).
    SAS off.

    LOCAL burnMean TO calc_Burn_Mean(manNode:DELTAV:MAG)[0].

    if manNode:ETA - burnMean - 5 > 3600 {
        s_Status("orienting panels").
        LOCAL safeOrientation TO c_Safe_Orientation().
        LOCK STEERING TO safeOrientation.
        WAIT UNTIL ((safeOrientation * -FACING):PITCH + (safeOrientation * -FACING):YAW + (safeOrientation * -FACING):ROLL) < 10.
        a_Warp_To(manNode:ETA - burnMean - 5 - 1200).

        s_Sub_Prog("p_Orb_Burn").
    }
    LOCK STEERING TO manNode:DELTAV.
    WAIT UNTIL (VANG(FACING:VECTOR, manNode:DELTAV) < 10) OR (manNode:ETA < burnMean + 5).
    // warp to node with TIME for turning and some tolerance
    a_Warp_To(manNode:ETA - burnMean - 5).

    s_Sub_Prog("p_Orb_Burn").
    WAIT UNTIL manNode:ETA < burnMean.

    // do the burn, THROTTLE down when below 30 m/s.
    LOCK STEERING TO manNode:deltav.
    LOCK THROTTLE TO ((manNode:DELTAV:MAG/20)^2+0.02)*20/safeacc.
    s_Status("burning").
    s_Log("Executing node").

    UNTIL manNode:DELTAV:MAG < 1{
        a_Stage().
        s_Info_ref("", round(manNode:DELTAV:MAG - 1,1) + " m/s ").
        WAIT 0.
    }
    UNLOCK STEERING.
    LOCK THROTTLE TO 0.
    REMOVE manNode.

    s_Status("burn clomplete ").
    FOR node IN nodeBackup
    {
        ADD node.
    }
    s_Info_pop().
    RETURN True.
}

function p_Launch {
// launches into a circular with a given apoapsis, periapsis and inclination
    DECLARE Parameter pAlt1 TO 150000, pAlt2 TO pAlt1, pInc TO 0.
            //pAlt:int	,orbit height
            //pInc:int	,orbit inclination

    LOCAL incPID_ks TO list(0.04, 0.07, 0.03).
    LOCAL thrPID_ks TO list(0.001, 0.00001, 0).

    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF SHIP:STATUS <> "LANDED" AND SHIP:STATUS <> "PRELAUNCH"
    {
        s_Status("Error: Ship not landed").
        RETURN False.
    }

    LOCAL peAlt TO MIN(pAlt1, pAlt2).
    LOCAL apAlt is MAX(pAlt1, pAlt2).
    SET pInc TO a_Clamp(pInc, 180, -180).

    s_Sub_Prog("p_Launch").

    s_Info_push(list("Periapsis:",             "Apoapsis:",              "Obt. inc.:"),
                list(round(peAlt/1000) + "km", round(apAlt/1000) + "km", round(pInc) + "°")).

    s_Status("Engine warmup").

    // startup procedure
    LOCAL tnow TO TIME:SECONDS.
    a_Stage().
    LOCK THROTTLE TO (TIME:SECONDS - tnow)/5.
    WAIT until (TIME:SECONDS - tnow > 5).
    a_Stage().
    s_Stage(STAGE:NUMBER - 1).

    LOCAL LOCK acc TO AVAILABLETHRUST/MASS.
    LOCAL LOCK safeAcc TO MAX(acc, 0.0001).
    LOCAL LOCK twr TO safeacc/(BODY:MU/(BODY:RADIUS^2)).

    LOCAL sheight TO BODY:ATM:HEIGHT/4.
    IF NOT BODY:ATM:EXISTS
    {
        SET sheight TO peAlt/5.
    }

    LOCAL vRef TO c_Orb_Vel(0, 70000 - BODY:RADIUS, peAlt, MAX(BODY:ATM:HEIGHT, 20000)).	// inclination control
    LOCAL Linc TO ARCTAN((vRef * SIN(pInc)/SQRT(2))/(vRef * COS(pInc)/SQRT(2) - VELOCITY:ORBIT:MAG)).
    IF pInc >= 0 
    {
        IF Linc < 0 { SET Linc TO Linc + 180.}
    } ELSE {
        IF Linc > 0 { SET Linc TO Linc - 180.}
    }

    LOCAL LOCK Lang TO ARCTAN(sheight/(ALTITUDE * SQRT(MAX(TWR, 1)/2))).			// angle follows log(x) curve.
    LOCK STEERING TO HEADING(90-Linc,Lang).

    LOCAL incPIDon TO False.
    LOCAL incPID TO PIDLOOP(incPID_ks[0], incPID_ks[1], incPID_ks[2], -5, 5).
    SET incPID:SETPOINT TO pInc.

    LOCAL rIncl TO 0.
    IF pInc >= 0 {
        LOCK rIncl TO ORBIT:INCLINATION.
    } ELSE {
        LOCK rIncl TO -ORBIT:INCLINATION.
    }

    IF ABS(pInc) > 0.5
    {
        WHEN (ABS(rIncl - pInc) < 0.3 AND Lang < 55) THEN {
            s_Log("Target inclination reached").
            incPID:RESET.
            SET incPIDon TO True.
            ON SHIP:STATUS {incPID:RESET.}
        }
    }
    // precise burn when close to target trajectory
    LOCAL throt TO 1.
    LOCK THROTTLE TO throt.
    LOCAL thrPID TO PIDLOOP(thrPID_ks[0], 0, thrPID_ks[2], 0, 1).
    SET thrPID:SETPOINT TO peAlt.

    s_Log("Liftoff!").
    s_Status("ascending").

    WHEN Lang < 80 then
    {
        s_Log("Starting gravity turn").
        s_Status("Gravity turn").
    }

    WHEN ALTITUDE > BODY:ATM:HEIGHT * 0.7 THEN{
        TOGGLE ag1.						// open fairings
        s_Log("Opening fairing").
        LOCAL timeFairing TO MISSIONTIME.
        WHEN missiontime > timeFairing + 5 THEN {
            TOGGLE ag2.                 // solar panels, etc
            s_Log("Deploying electronics").
        }
    }

    WHEN APOAPSIS / peAlt>= 1  THEN
    {
        SET thrPID:KI TO thrPID_ks[1].
    }

    UNTIL (APOAPSIS >= peAlt - 1 and SHIP:STATUS	<> "FLYING")		//autostageing and PID
    {
        a_Stage().
        SET thrPID:KP TO thrPID_ks[0]/TWR.
        SET throt TO thrPID:UPDATE(TIME:SECONDS, APOAPSIS).
        IF incPIDon
        {
            SET Linc TO pInc + incPID:UPDATE(TIME:SECONDS, rIncl).
        }
        WAIT 0.
    }

    s_Log("Coast to Apoapsis").
    IF p_Orb_Burn(c_Simple_Man(1, apAlt))			// circularize
    {
        s_Sub_Prog("p_Launch").
        s_Log("Orbit complete").
    } ELSE {
        s_Status("Could not circularize orbit").
        s_Info_pop().
        RETURN False.
    }

    TOGGLE ag3.							// deploy mission hardware
    s_Log("Deploying mission hardware").
    s_Info_pop().
    RETURN True.
}

function p_Launch_To_Rendevouz {
// Launches into an orbit of the same inclination as a given target for a rendevouz.
    DECLARE Parameter targ TO 0.

    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF SHIP:STATUS <> "LANDED" AND SHIP:STATUS <> "PRELAUNCH"
    {
        s_Status("Can't launch in current state").
        RETURN False.
    }

    s_Sub_Prog("p_Launch_To_Rendevouz").
    s_Status("Checking for Errors").

    SET targ TO a_Check_Target(targ, 1+4+8).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+4+8).
    }

    s_Status("Calculating parameters").

    LOCAL SMA TO (targ:OBT:APOAPSIS + targ:OBT:PERIAPSIS)/2.                                            // calculating a sensible orbit height
    LOCAL minAlt TO BODY:ATM:HEIGHT + 20000.
    LOCAL goalAlt TO BODY:RADIUS / 4.
    LOCAL goalDist TO goalAlt / 6.

    SET goalAlt TO MIN(MIN(SMA - goalDist, goalAlt), targ:OBT:PERIAPSIS).
    IF goalAlt < minAlt {
        SET goalAlt TO SMA + goalDist.
    }

    LOCAL vRef TO c_Orb_Vel(0, 70000 - BODY:RADIUS, goalAlt, MAX(BODY:ATM:HEIGHT, 20000)).	            // calculating when to start the launch

    IF (DEFINED deltaVdone) = False {
        RUNPATH("libraries/DeltaVLib").
    }

    LOCAL insertTime TO calc_Burn_Mean(vRef).
    SET insertTime TO 5 + insertTime[1] - insertTime[0]/SQRT(2).

    LOCAL insertLanAng TO insertTime*360 / BODY:ROTATIONPERIOD.

    LOCAL upVec TO UP:FOREVECTOR.
    LOCAL forVec TO VCRS(NORTH:FOREVECTOR, UP:FOREVECTOR).
    LOCAL solVec TO SOLARPRIMEVECTOR.
    LOCAL upProd TO VDOT(upVec, solVec).
    LOCAL forProd TO VDOT(forVec, solVec).
    LOCAL lanAng TO a_Clamp(ARCCOS(upProd), 360).
    IF forProd < 0 {SET lanAng TO 360 - lanAng.}

    LOCAL dLan TO a_Clamp(targ:OBT:LAN - lanAng - insertLanAng, 360).
    LOCAL goalInc TO targ:OBT:INCLINATION.
    IF dLan > 180 {
        SET dLan TO dLan - 180.
        SET goalInc TO -goalInc.
    }
    LOCAL dTime TO dLan / 360 * BODY:ROTATIONPERIOD.
    LOCAL dTTime TO time - dTime.
    SET dTTime TO time - dTTime.

    s_Status("Calculations complete").
    s_Log(list("Launch calculations complete:", "Wait " + dTTime:CLOCK + " for launch")).
    a_Warp_To(dTime).
    p_Launch(goalAlt, goalAlt, goalInc).
}

function p_Slow_Rendevouz {
// Rendevouz the craft with a given target.
    DECLARE Parameter targ TO 0.
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF SHIP:STATUS <> "ORBITING"
    {
        s_Status("Ship needs to be in orbit").
        RETURN False.
    }

    s_Sub_Prog("p_Slow_Rendevouz").
    s_Status("Checking for Errors").

    SET targ TO a_Check_Target(targ, 1+4+8).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+4+8).
    }

    s_Status("Calc. transfer burn").

    LOCAL myANDN TO c_AsDe_Anomaly(SHIP:OBT, targ:OBT).                           // AS and DEscending node from my orbit to target orbit
    LOCAL tarANDN TO c_AsDe_Anomaly(targ:OBT, SHIP:OBT).        // AS and DEscending node from target orbit to my orbit
    LOCAL relInc TO myANDN["relInc"].

    LOCAL useDE TO True.
    IF tarANDN["DN"][3] - myANDN["AN"][3] > tarANDN["AN"][3] - myANDN["DN"][3] {    // Burn so the transfer-orbit is as cicular as possible
        SET useDE TO False.
    }

    LOCAL myNode TO myANDN["DN"].
    LOCAL tarNode TO tarANDN["DN"].
    IF useDE = False {
        SET myNode TO myANDN["AN"].
        SET tarNode TO tarANDN["AN"].
        SET relInc TO -relInc.
    }

    LOCAL vMyNode TO c_Orb_Vel(0, myNode[3], tarNode[3], myNode[3]).    // calculates parameter
    LOCAL vCurrentMyNode TO c_Orbit_Velocity_Vector(myNode[0]).

    LOCAL earlyIncChange TO 0.                                          // if the target node is lower do an early inclinatino Change
    IF myNode[3] > tarNode[3] {
        SET earlyIncChange TO 1.
    }

    LOCAL meanAnToNode TO a_Clamp(myNode[2] - c_MeanAN(), 360).

    LOCAL timeToNode TO c_Time_from_Mean_An(meanAnToNode).

    s_Log("Calculated transfer maneuver").

    LOCAL manNode TO c_Circ_Man(timeToNode, vCurrentMyNode, list(vMyNode, 0), earlyIncChange * relInc).
    p_Orb_Burn(manNode).

    s_Status("Calc. wait burn").

    SET timeToNode TO ETA:APOAPSIS + earlyIncChange * (ETA:PERIAPSIS - ETA:APOAPSIS).
    LOCAL phiAtNode TO 180 - 180 * earlyIncChange.
    LOCAL tarPhiOfNode TO c_Equ_TruAn(phiAtNode, OBT, targ:OBT).

    LOCAL tarMeanAnAtNode TO c_MeanAN(targ:OBT, timeToNode).
    LOCAL tarDeltAnAtNode TO a_Clamp(tarMeanAnAtNode - tarPhiOfNode, 360).
    LOCAL targPosStart TO tarDeltAnAtNode / 360.
    LOCAL waitMyOrbNum TO 0.
    LOCAL targPosNew TO 0.

    UNTIL targPosNew OR waitMyOrbNum > 5
    {
        SET waitMyOrbNum TO waitMyOrbNum + 1.
        LOCAL minPosNew TO waitMyOrbNum * MIN(1, OBT:PERIOD / targ:OBT:PERIOD) + targPosStart.
        LOCAL maxPosNew TO waitMyOrbNum * MAX(1, OBT:PERIOD / targ:OBT:PERIOD) + targPosStart.
        IF FLOOR(minPosNew) < FLOOR(maxPosNew){
            SET targPosNew TO FLOOR(minPosNew) + 1.
        }
    }

    IF waitMyOrbNum > 5 {
        SET waitMyOrbNum TO 0.
        SET targPosNew TO 0.
        UNTIL targPosNew
        {
            SET waitMyOrbNum TO waitMyOrbNum + 1.
            LOCAL minPosNew TO waitMyOrbNum * MIN(1, OBT:PERIOD / targ:OBT:PERIOD) + targPosStart.
            LOCAL maxPosNew TO waitMyOrbNum * MAX(1, OBT:PERIOD / targ:OBT:PERIOD)*1.25 + targPosStart.
            IF FLOOR(minPosNew) < FLOOR(maxPosNew){
                SET targPosNew TO FLOOR(minPosNew) + 1.
            }
        }
    }

    s_Info_push("Wait for", waitMyOrbNum + " orbits").

    LOCAL waitPeriod TO (targPosNew - targPosStart) * targ:OBT:PERIOD.
    LOCAL wait_orbit_period TO waitPeriod / waitMyOrbNum.

    LOCAL sma_0 TO OBT:SEMIMAJORAXIS.
    LOCAL sma_wait TO ((wait_orbit_period/(2*CONSTANT:PI))^2*BODY:MU)^(1/3).
    LOCAL sma_1 TO targ:OBT:SEMIMAJORAXIS.

    LOCAL r_wait TO BODY:RADIUS + APOAPSIS + earlyIncChange * (PERIAPSIS - APOAPSIS).

    LOCAL ap_hohman TO MAX(r_wait, 2*sma_wait - r_wait).
    LOCAL pe_hohman TO MIN(r_wait, 2*sma_wait - r_wait).

    LOCAL x TO (sma_wait - sma_0) / (sma_1 - sma_0).
    IF x > 1 OR x < 0 {SET x TO 0.5.}

    SET relInc TO -relInc.
    LOCAL inc_wait TO x * relInc.

    SET vMyNode TO c_Orb_Vel(0, PERIAPSIS, APOAPSIS, r_wait-BODY:RADIUS).
    LOCAL vAfterNode TO c_Orb_Vel(0, pe_hohman, ap_hohman, r_wait, 0).
    

    s_Log("Calculated wait maneuver").

    SET manNode TO c_Circ_Man(timeToNode, list(vMyNode, 0), list(vAfterNode, 0), (1-earlyIncChange) * inc_wait).
    p_Orb_Burn(manNode).

    s_Log("Waiting").
    LOCAL didBurn TO 1.
    UNTIL waitMyOrbNum < 2 {
        IF didBurn {
            a_Warp_To(OBT:PERIOD*0.95).
        } ELSE {
            a_Warp_To(OBT:PERIOD).
        }
        SET waitMyOrbNum TO waitMyOrbNum - 1.
        s_Info_ref("", waitMyOrbNum + " orbits").

        SET timeToNode TO ETA:APOAPSIS + earlyIncChange * (ETA:PERIAPSIS - ETA:APOAPSIS).

        SET tarMeanAnAtNode TO c_MeanAN(targ:OBT, timeToNode).
        SET tarDeltAnAtNode TO a_Clamp(tarMeanAnAtNode - tarPhiOfNode, 360).
        SET targPosStart TO tarDeltAnAtNode / 360.

        LOCAL minPosNew TO waitMyOrbNum * MIN(1, OBT:PERIOD / targ:OBT:PERIOD)*0.95 + targPosStart.
        SET targPosNew TO FLOOR(minPosNew) + 1.

        SET waitPeriod TO (targPosNew - targPosStart) * targ:OBT:PERIOD.
        SET wait_orbit_period TO waitPeriod / waitMyOrbNum.

        SET sma_wait TO ((wait_orbit_period/(2*CONSTANT:PI))^2*BODY:MU)^(1/3).
        SET r_wait TO BODY:RADIUS + APOAPSIS + earlyIncChange * (PERIAPSIS - APOAPSIS).

        SET ap_hohman TO MAX(r_wait, 2*sma_wait - r_wait).
        SET pe_hohman TO MIN(r_wait, 2*sma_wait - r_wait).

        SET vMyNode TO c_Orb_Vel(0, PERIAPSIS, APOAPSIS, r_wait-BODY:RADIUS).
        SET vAfterNode TO c_Orb_Vel(0, pe_hohman, ap_hohman, r_wait, 0).
        IF ABS(vMyNode - vAfterNode) > 1 OR waitMyOrbNum = 1 {
            SET didBurn TO 1.
            SET manNode TO c_Circ_Man(timeToNode, list(vMyNode, 0), list(vAfterNode, 0), 0).
            p_Orb_Burn(manNode).
        } ELSE {
            SET didBurn TO 0.
        }
    }
    s_Info_pop().
    a_Warp_To(OBT:PERIOD*0.75).

    IF targ:TYPENAME = "Vessel" {
        p_Match_Orbit().
    }
}

function p_Direct_Rendevouz {
// Rendevouz the craft with a given target.
    DECLARE Parameter targ TO 0.
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF SHIP:STATUS <> "ORBITING"
    {
        s_Status("Ship needs to be in orbit").
        RETURN False.
    }

    s_Sub_Prog("p_Rendevouz").
    s_Status("Checking for Errors").

    SET targ TO a_Check_Target(targ, 1+4+8).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+4+8).
    }

    LOCAL dirOutwards TO True.
    IF OBT:SEMIMAJORAXIS > targ:OBT:SEMIMAJORAXIS {
        SET dirOutwards TO False.
        IF OBT:PERIAPSIS < targ:OBT:APOAPSIS {
            s_Status("Error: Orbit-alt intersect").
            RETURN False.
        }
    } ELSE {
        IF OBT:APOAPSIS > targ:OBT:PERIAPSIS {
            s_Status("Error: Orbit-alt intersect").
            RETURN False.
        }
    }

    s_Log("Calculating direct transfer").
    s_Status("Calc. transfer burn").

    LOCAL myANDN TO c_AsDe_Anomaly(OBT, targ:OBT).

    LOCAL k TO targ:OBT:SEMIMAJORAXIS/OBT:SEMIMAJORAXIS.
    LOCAL goal_phase_angle TO a_Clamp(180 - 180 * SQRT((0.5+k/2)^3) / k^(3/2), 360).

    LOCAL current_phase_angle TO a_Clamp(targ:OBT:TRUEANOMALY + targ:OBT:ARGUMENTOFPERIAPSIS + targ:OBT:LAN
                                     - OBT:TRUEANOMALY - OBT:ARGUMENTOFPERIAPSIS - OBT:LAN, 360).

    LOCAL phase_angle_per_s TO 360/targ:OBT:PERIOD - 360/OBT:PERIOD.

    LOCAL d_t_trans TO a_Clamp(current_phase_angle - goal_phase_angle, 360) /-phase_angle_per_s.
    IF phase_angle_per_s > 0 {
        SET d_t_trans TO a_Clamp(goal_phase_angle - current_phase_angle, 360) / phase_angle_per_s.
    }

    LOCAL my_phi_trans TO a_Clamp(OBT:TRUEANOMALY + 360*d_t_trans/OBT:PERIOD, 360).

    LOCAL d_ang_encounter TO SIN(a_Clamp(myANDN["AN"][0] - my_phi_trans, 360))^2 * myANDN["relInc"].

    LOCAL my_r_trans TO c_r_from_Tru(my_phi_trans).
    LOCAL tar_r_trans TO c_r_from_Tru(a_Clamp(targ:OBT:TRUEANOMALY + 360*d_t_trans/targ:OBT:PERIOD + 180 - goal_phase_angle,360)
                                     ,targ:OBT:ECCENTRICITY, targ:OBT:SEMIMAJORAXIS).

    LOCAL my_v_0_trans TO c_Orbit_Velocity_Vector(my_phi_trans).
    LOCAL my_v_1_trans TO c_Orb_Vel(0,my_r_trans, tar_r_trans, my_r_trans, 0).
    LOCAL trans_node TO c_Circ_Man(d_t_trans, my_v_0_trans, list(my_v_1_trans, 0), 0).
    p_Orb_Burn(trans_node).

    s_Log("Calculating inc. change").
    LOCAL r_inc_ch TO (my_r_trans + tar_r_trans)/2.
    LOCAL ec_inc_ch TO ABS(tar_r_trans - my_r_trans)/(tar_r_trans + my_r_trans).
    LOCAL phi_inc_ch TO c_Tru_from_r(r_inc_ch, ec_inc_ch, r_inc_ch).
    IF dirOutwards = False  AND phi_inc_ch < 180{
        SET phi_inc_ch TO 360 - phi_inc_ch.
    }
    LOCAL M_inc_ch TO c_Mean_An_from_Tru(phi_inc_ch, ec_inc_ch).
    IF dirOutwards = False  AND M_inc_ch < 180{
        SET M_inc_ch TO 360 - M_inc_ch.
    }
    LOCAL t_inc_ch TO c_Time_from_Mean_An(a_Clamp(M_inc_ch - c_MeanAN(),360)).

    LOCAL beta_inc_ch TO ARCTAN(TAN(d_ang_encounter)/SIN(180 - phi_inc_ch)).
    IF a_Clamp(myANDN["AN"][0] - my_phi_trans, 360) < 180 {
        SET beta_inc_ch TO -beta_inc_ch. 
    }
    IF dirOutwards = False {
        SET beta_inc_ch TO -beta_inc_ch. 
    }

    LOCAL v_0_inc_ch TO c_Orbit_Velocity_Vector(phi_inc_ch, OBT).
    LOCAL inc_node TO c_Circ_Man(t_inc_ch, v_0_inc_ch, v_0_inc_ch, beta_inc_ch).
    p_Orb_Burn(inc_node).

    IF targ:TYPENAME = "Vessel" {
        p_Match_Orbit().
    }
}

function p_Match_Orbit {
// Matches orbital velocity at the closest approach
    DECLARE Parameter targ TO 0, maxDist TO 0.05.

    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF SHIP:STATUS <> "ORBITING"
    {
        s_Status("Ship needs to be in orbit").
        RETURN False.
    }

    s_Sub_Prog("p_Match_Orbit").
    s_Status("Checking for Errors").

    SET targ TO a_Check_Target(targ, 1+8).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+8).
    }

    s_Status("Get closest intersect").
    LOCAL encounters TO c_Closest_Approach(OBT, targ:OBT).
    s_Log("Calculated matching maneuver").
    LOCAL minDist TO encounters[0][5] * 3.
    LOCAL minEnc TO list().
    FOR enc in encounters {
        IF enc[0] < minDist {
            SET minEnc TO enc.
            SET minDist TO enc[0].
        }
    }
    IF minDist > maxDist * minEnc[5] {RETURN False.}

    LOCAL myANDN TO c_AsDe_Anomaly().
    LOCAL incChange TO myANDN["relInc"].
    IF a_Clamp(myANDN["AN"][0] - OBT:TRUEANOMALY, 360) < a_Clamp(myANDN["DN"][0] - OBT:TRUEANOMALY, 360) {
        SET incChange TO - incChange.
    }

    LOCAL v_0 TO c_Orbit_Velocity_Vector(minEnc[2], OBT).
    LOCAL v_1 TO c_Orbit_Velocity_Vector(minEnc[4], targ:OBT).
    LOCAL t_burn TO c_Time_from_Mean_An(a_Clamp(minEnc[1] - c_MeanAN(),360)).
    LOCAL burnNode TO c_Circ_Man(t_burn, v_0, v_1, incChange).
    p_Orb_Burn(burnNode).
    s_Log("Orbit matched").
    RETURN True.
}

function p_Close_Dist {
// closes the distance to the target if they are already close together in orbit
    DECLARE Parameter targ IS 0.

    LOCAL maxSpeed TO 25.

    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF SHIP:STATUS <> "ORBITING"
    {
        s_Status("Ship needs to be in orbit").
        RETURN False.
    }

    s_Sub_Prog("p_Close_Dist").
    s_Status("Checking Target").

    SET targ TO a_Check_Target(targ, 1+8).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+8).
    }

    LOCAL LOCK dist_raw TO targ:POSITION - SHIP:POSITION.
    LOCAL LOCK vel_raw TO OBT:VELOCITY:ORBIT - targ:OBT:VELOCITY:ORBIT.

    IF dist_raw:MAG > 0.1 * (ALTITUDE + BODY:RADIUS) {
        s_Status("Vessels too far apart").
        RETURN False.
    }

    LOCAL v_Pro TO PROGRADE:FOREVECTOR.
    LOCAL v_Rad TO PROGRADE:TOPVECTOR.
    LOCAL v_Nor TO -PROGRADE:STARVECTOR.
    
    LOCAL LOCK vel TO V(VDOT(v_Pro, vel_raw), VDOT(v_Rad, vel_raw), VDOT(v_Nor, vel_raw)).
    LOCAL LOCK dist TO V(VDOT(v_Pro, dist_raw), VDOT(v_Rad, dist_raw), VDOT(v_Nor, dist_raw)).

    LOCAL LOCK acc TO MAX(AVAILABLETHRUST,0.0001)/MASS.

    LOCAL transSpeed TO MIN(maxSpeed, 3*acc*SQRT(dist:MAG-100/acc)).

    LOCAL burnTime TO transSpeed/acc.                                           // time for one start or stop burn
    LOCAL coastTime TO (dist:MAG-100)/transSpeed - transSpeed/acc.              // time spent coasting

    LOCAL LOCK targVelVec TO (transSpeed + 1) * dist_raw:NORMALIZED.
    LOCAL LOCK dVelVec TO targVelVec - vel_raw.

    SAS OFF.
    RCS OFF.
    LOCK STEERING TO LOOKDIRUP(dVelVec,UP:VECTOR).

    s_Log("Burning to close distance").

    WAIT UNTIL VANG(dVelVec, FACING:VECTOR) < 10.
    LOCK THROTTLE TO ((dVelVec:MAG/10)^2+0.02)*20/acc.
    s_Info_push("deltaV:", round(dVelVec:MAG-1,1) + " m/s ").
    UNTIL dVelVec:MAG < 1{
        a_Stage().
        s_Info_ref("", round(dVelVec:MAG-1,1) + " m/s ").
        WAIT 0.
    }
    LOCK THROTTLE TO 0.
    s_Info_pop().

    LOCAL LOCK etaTime TO (dist:MAG-100)/transSpeed - 1/2 * transSpeed/acc.     // time until deceleration

    UNTIL etaTime < 30 {
        IF etaTime > 150 {
            a_Warp_To(100).
            WAIT UNTIL VANG(dVelVec, FACING:VECTOR) < 10.
            LOCK THROTTLE TO ((dVelVec:MAG/10)^2+0.02)*20/acc.
            s_Info_push("deltaV:", round(dVelVec:MAG-1,1) + " m/s ").
            UNTIL dVelVec:MAG < 1{
                a_Stage().
                s_Info_ref("", round(dVelVec:MAG-1,1) + " m/s ").
                WAIT 0.
            }
            LOCK THROTTLE TO 0.
            s_Info_pop().
        } ELSE {
            LOCK STEERING TO LOOKDIRUP(dVelVec, UP:VECTOR).
            WAIT UNTIL (VANG(dVelVec, FACING:VECTOR) < 10).
            a_Warp_To(etaTime - 30).
        }
    }
    UNLOCK targVelVec.
    LOCAL targVelVec TO -1 * dist_raw:NORMALIZED.
    WAIT UNTIL (etaTime < 0).
    LOCK THROTTLE TO ((dVelVec:MAG/10)^2+0.02)*20/acc.
    s_Info_push("deltaV:", round(dVelVec:MAG-1,1) + " m/s ").
    UNTIL dVelVec:MAG < 1{
        a_Stage().
        s_Info_ref("", round(dVelVec:MAG-1,1) + " m/s ").
        WAIT 0.
    }
    LOCK THROTTLE TO 0.
    s_Info_pop().
    s_Log("Distance closed").
}

function p_Dock {
// Docks with a fitting Docking Port on the target vessel
    DECLARE Parameter targ TO 0.

    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF SHIP:STATUS <> "ORBITING"
    {
        s_Status("Ship needs to be in orbit").
        RETURN False.
    }

    s_Sub_Prog("p_Dock").
    s_Status("Checking Target").

    SET targ TO a_Check_Target(targ, 1+2+8).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+2+8).
    }

    IF (targ:POSITION - ship:POSITION):MAG > 1000 {
        s_Status("Too far apart").
        RETURN False.
    }

    LOCAL smallPort TO 0.
    LOCAL medPort TO 0.
    LOCAL bigPort TO 0.

    FOR port in SHIP:DOCKINGPORTS {
        IF (port:STATE = "Ready" OR port:STATE = "Disabled") {
            IF port:name = "dockingPort3" {
                SET smallPort TO smallPort + 1.
            } ELSE IF port:name = "dockingPort2" OR port:name = "dockingPort1" OR port:name = "dockingPortLateral" OR port:name = "mk2DockingPort" {
                SET medPort TO medPort + 1.
            } ELSE IF port:name = "dockingPortLarge" {
                SET bigPort TO bigPort + 1.
            }
        }
    }
    IF smallPort + medPort + bigPort = 0 {
        s_Status("Error no port on ship").
        RETURN False.
    }

    LOCAL targPort TO 0.
    LOCAL portType TO 0.

    IF targ:TYPENAME = "DOCKINGPORT" {
        LOCAL portViable TO 1.
        LOCAL pportType TO 0.
        IF (targ:STATE = "Ready") {
            IF smallPort AND targ:name = "dockingPort3" {
                SET pportType TO 1.
            } ELSE IF medPort AND targ:name = "dockingPort2" OR targ:name = "dockingPort1" OR targ:name = "dockingPortLateral" OR targ:name = "mk2DockingPort" {
                SET pportType TO 2.
            } ELSE IF bigPort AND targ:name = "dockingPortLarge" {
                SET pportType TO 3.
            } ELSE {
                SET portViable TO 0.
            }
        } ELSE {
            SET portViable TO 0.
        }
        IF portViable {
            SET targPort TO targ.
            SET portType TO pportType.
        } ELSE {
            SET targ TO targ:SHIP.
        }
    }

    IF targ:TYPENAME = "VESSEL" {
        LOCAL bestFacing TO 180.
        LOCAL bestDist TO 2000.

        FOR port in targ:DOCKINGPORTS {
            LOCAL portViable TO 1.
            LOCAL pportType TO 0.
            IF (port:STATE = "Ready") {
                IF smallPort AND port:name = "dockingPort3" {
                    SET pportType TO 1.
                } ELSE IF medPort AND port:name = "dockingPort2" OR port:name = "dockingPort1" OR port:name = "dockingPortLateral" OR port:name = "mk2DockingPort" {
                    SET pportType TO 2.
                } ELSE IF bigPort AND port:name = "dockingPortLarge" {
                    SET pportType TO 3.
                } ELSE {
                    SET portViable TO 0.
                }
            } ELSE {
                SET portViable TO 0.
            }
            IF portViable {
                LOCAL pFacing TO VANG(port:FACING:VECTOR, (SHIP:POSITION - port:POSITION):NORMALIZED).
                LOCAL pDist TO (SHIP:POSITION - port:POSITION):MAG.
                IF 15/90*pFacing + pDist - 5* pportType < 15/90*bestFacing + bestDist - 5*portType {
                    SET targPort TO port.
                    SET bestFacing TO pFacing.
                    SET bestDist TO pDist.
                    SET portType TO pportType.
                }
            }
        }
        IF targPort <> 0 {
            SET TARGET TO targPort.
        } ELSE {
            s_Status("Error: No fitting port").
            RETURN False.
        }
    }

    LOCAL myPort TO 0.
    FOR port in SHIP:DOCKINGPORTS {
        LOCAL pType TO 0.
        IF port:name = "dockingPort3" {
            SET pType TO 1.
        } ELSE IF port:name = "dockingPort2" OR port:name = "dockingPort1" OR port:name = "dockingPortLateral" OR port:name = "mk2DockingPort" {
            SET pType TO 2.
        } ELSE IF port:name = "dockingPortLarge" {
            SET pType TO 3.
        }
        IF pType = portType AND (port:STATE = "Ready" OR port:STATE = "Disabled") {
            SET myPort TO port.
            IF myPort = SHIP:CONTROLPART {
                BREAK.
            }
        }
    }
    IF myPort:TYPENAME = "DOCKINGPORT" {
        myPort:controlfrom().
        IF myPort:STATE = "Disabled" {
            TOGGLE ag10.
        }
    } ELSE {
        RETURN False.
    }

    IF (DEFINED DockLibDone) = False {
        RUNPATH("libraries/DockLib").
    }
    s_Log("Starting docking procedure").
    s_Status("Translating to dock.").
    dock_with_port(0, 1, 0, 1.5, 1).
    s_Log("Docked").
}

// [QUIT] Always called last in a scrip. Closes everything.
// _________________________________________________

function Quit {
// call last in a script. Asks user to quit the program so it stays in a controlled state

    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    s_Info_Clear().

    s_Sub_Prog("Quit").
    s_Log("program ended").

    LOCK THROTTLE to 0.
    Brakes OFF.
    s_Info_push("Use brakes to ", "quit !").
    WAIT until brakes.				// using brakes finishes program
    Brakes OFF.
    UNLOCK STEERING.
    Sas ON.
    Rcs OFF.
    s_Layout().
}