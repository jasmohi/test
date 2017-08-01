class StairTool
require 'sketchup'

Sketchup.send_action "showRubyPanel:"
UI.menu("PlugIns").add_item("Draw stairs") {

prompts = ['Stair Shape: ', 'Stair Direction:', 'Height:', 'Stair Width:', 'Max. Tread Rise:', 'Tread Run:', 'Gap Between Flights:', 'Landing Position(No of Steps):', 
'Landing Depth:', 'Waiting Step (none, up or down):', 'Handrail Side (both, none, left or right):', 'Handrail Height:', 'Head Height:']

options = ['S|L|U', 'left|right', '', '', '', '', '', '', '', 'none|up|down', 'both|none|left|right']
defaults = ['S', 'right', 3300.mm, 1000.mm, 190.mm, 240.mm, 100.mm, 10, 1500.mm, 'none', 'both', 865.mm, 2100.mm]
inputs = UI.inputbox( prompts, defaults, options, 'Stairway Builder' )
    
input = {
    stairShape: inputs[0].to_s,
    direction: inputs[1].to_s,
    height: inputs[2].to_f,
    width: inputs[3].to_f,
    maxrise: inputs[4].to_f,
    run: inputs[5].to_f,
    gapBwFlights: inputs[6].to_f,
    landingPosition: inputs[7].to_i,
    landingDepth: inputs[8].to_f,
    waitingStep: inputs[9].to_s,
    handRailSide: inputs[10].to_s,
    handRailHeight: inputs[11].to_f,
    headHeight: inputs[12].to_f
}

    stairs= (input[:height]/input[:maxrise]).ceil    
    rise= ((input[:height]/stairs.mm)).mm
    stairsAfterLandingP= stairs - input[:landingPosition]

    Sketchup.active_model.start_operation "Stairs"
    
    model = Sketchup.active_model
    parentGroup =  model.entities.add_group
    entities = parentGroup.entities

    groupStairs =  parentGroup.entities.add_group
    groupStairsAftLandingPos =  parentGroup.entities.add_group

    def noOfStepsToCreate(input, steps, entities, rise, groupDef)
        (0..steps -1).each { |i|
            point = Geom::Point3d.new 0, input[:run]*i, rise*i
            t = Geom::Transformation.new point
            entities.add_instance groupDef, t
        }
    end
    
    def transformGroup(point, group)
        t = Geom::Transformation.new point
        group.transform! t
    end

    # L shape Waiting Step
    def lShapeWaitingStep(input, rise, group)
        groupWaitingStep = group.entities.add_group
        entitiesWaitingStep = groupWaitingStep.entities
        landingStep = entitiesWaitingStep.add_face [0, 0, 0], [input[:width], 0, 0], [input[:width], input[:width], 0], [0, input[:width], 0]
        point = Geom::Point3d.new 0, (input[:run] * (input[:landingPosition]-1).mm).to_mm, (rise * (input[:landingPosition]-1).mm).to_mm
        transformGroup(point, groupWaitingStep)
        landingStep.reverse!
        landingStep.pushpull rise
    end

    # U shape Waiting Step
    def uShapeWaitingStep(input, rise, group)
        groupWaitingStep = group.entities.add_group
        entitiesWaitingStep = groupWaitingStep.entities
        if input[:waitingStep] == 'none'
            landingStep = entitiesWaitingStep.add_face [0, 0, 0], [(input[:width] * 2) + input[:gapBwFlights], 0, 0], [(input[:width] * 2) + input[:gapBwFlights], input[:landingDepth], 0], [0, input[:landingDepth], 0]
        elsif input[:waitingStep] == 'up'
            landingStep = entitiesWaitingStep.add_face [0, 0, 0], [input[:width] + input[:gapBwFlights], 0, 0], [input[:width] + input[:gapBwFlights], -input[:run], 0], [(input[:width] * 2) + input[:gapBwFlights], -input[:run], 0], [(input[:width] * 2) + input[:gapBwFlights], 0, 0], [(input[:width] * 2) + input[:gapBwFlights], input[:landingDepth], 0], [0, input[:landingDepth], 0]
        elsif input[:waitingStep] == 'down'  
            landingStep = entitiesWaitingStep.add_face [0, 0, 0], [input[:width], 0, 0], [input[:width], input[:run], 0], [(input[:width] * 2) + input[:gapBwFlights], input[:run], 0], [(input[:width] * 2) + input[:gapBwFlights], input[:landingDepth], 0], [0, input[:landingDepth], 0]
        end
        if input[:direction] == 'right'
            x = 0
        else
            entitiesWaitingStep.transform_entities(Geom::Transformation.rotation(ORIGIN,[0,1,0],(180.degrees)),landingStep) 
            x = input[:width]
        end
        point = Geom::Point3d.new x, (input[:run] * (input[:landingPosition]-1).mm).to_mm, (rise * (input[:landingPosition]-1).mm).to_mm
        transformGroup(point, groupWaitingStep)
        face = groupWaitingStep.entities.find {
        |a| a.is_a? Sketchup::Face }
        if input[:direction] == 'right' then face.reverse! end
        face.pushpull rise                   
    end

    def createStairs(input, stairs, rise, group, groupStairs)
        group1 =  group.entities.add_group
        entities1 = group1.entities
        entities1.add_face [0, 0, 0], [input[:width], 0, 0], [input[:width], 0, rise], [0, 0, rise]
        entities1.add_face [0, 0, rise], [input[:width], 0, rise], [input[:width], input[:run], rise], [0, input[:run], rise]
        groupDef = group1.definition
        unless input[:stairShape] == 'S' then stairs = input[:landingPosition] - 1 end
        entities2 = groupStairs.entities
        noOfStepsToCreate(input, stairs, entities2, rise, groupDef)

        group1.erase!
        return groupDef
    end
                
    # U Shape
    def uShapeStairsAfterLanding(input, group, stairsAfterLandingP, rise, groupDef, groupStairsAftLandingPos)
        entities3 = groupStairsAftLandingPos.entities
        noOfStepsToCreate(input, stairsAfterLandingP, entities3, rise, groupDef)
        angle = 180 
        entities3.transform_entities(Geom::Transformation.rotation(ORIGIN,[0,0,1],(angle.degrees)),groupStairsAftLandingPos)
        if input[:direction] == 'right' 
            x = (input[:width] * 2) + input[:gapBwFlights]
        else 
            x = -input[:gapBwFlights] 
        end
        if input[:waitingStep] == 'none'
            y = (input[:run] * (input[:landingPosition]-1).mm).to_mm
        elsif input[:waitingStep] == 'up'
            y = (input[:run] * (input[:landingPosition]-2).mm).to_mm
        elsif input[:waitingStep] == 'down'
            y = (input[:run] * (input[:landingPosition]).mm).to_mm
        end                
        point = Geom::Point3d.new x, y, (rise * input[:landingPosition].mm).to_mm
        transformGroup(point, groupStairsAftLandingPos)
    end
    
    # L Shape 
    def lShapeStairsAfterLanding(input, group, stairsAfterLandingP, rise, groupDef, groupStairsAftLandingPos)
        entities3 = groupStairsAftLandingPos.entities
        noOfStepsToCreate(input, stairsAfterLandingP, entities3, rise, groupDef)
             
        if input[:direction] == 'right' then angle = 270 else angle = 90 end 
        entities3.transform_entities(Geom::Transformation.rotation(ORIGIN,[0,0,1],(angle.degrees)),groupStairsAftLandingPos)
        if input[:direction] == 'right' 
            x = input[:width] 
            y = (input[:run] * (input[:landingPosition]+3).mm).to_mm 
        else 
            x = 0 
            y = (input[:run] * (input[:landingPosition]-1).mm).to_mm  
        end 
        point = Geom::Point3d.new x, y, (rise * input[:landingPosition].mm).to_mm
        transformGroup(point, groupStairsAftLandingPos)
    end
 
#Creating Stairs
 groupDef = createStairs(input, stairs, rise, parentGroup, groupStairs)
 if input[:stairShape] == 'L'
    lShapeStairsAfterLanding(input, parentGroup, stairsAfterLandingP, rise, groupDef, groupStairsAftLandingPos) 
    lShapeWaitingStep(input, rise, parentGroup)    
 elsif input[:stairShape] == 'U'
    uShapeStairsAfterLanding(input, parentGroup, stairsAfterLandingP, rise, groupDef, groupStairsAftLandingPos) 
    uShapeWaitingStep(input, rise, parentGroup)
 end

def explodeGroup(group, isStairs)
    entityArray = group.explode
    if isStairs == true
        entityArray.each {
        |i| i.explode
        }
    end    
    return entityArray
end

explodeGroup(groupStairs, true)
explodeGroup(groupStairsAftLandingPos, true)

def explodeAndfindFacesFromGroup(group)
    entityArray = explodeGroup(group, false)
    edges = entityArray.grep (Sketchup::Edge)
    edges.first.find_faces
end

def createLinesBeforeWaitingStep(input, rise, parentGroup, stairs)
    groupLines = parentGroup.entities.add_group
    entitiesLines = groupLines.entities
    if input[:stairShape] == 'S'
        y1 = y2 = (input[:run] * stairs.mm).to_mm
        z1 = (rise * (stairs-1).mm).to_mm
        z2 = (rise * stairs.mm).to_mm
    else
        y1 = (input[:run] * input[:landingPosition].mm).to_mm
        y2 = (input[:run] * (input[:landingPosition]-1).mm).to_mm
        z1 = z2 = (rise * (input[:landingPosition]-1).mm).to_mm
    end
    point1 = Geom::Point3d.new(0, 0, 0)
    point2 = Geom::Point3d.new(0, input[:run], 0)
    point3 = Geom::Point3d.new(0, y1, z1)
    point4 = Geom::Point3d.new(0, y2, z2)
    line1 = entitiesLines.add_line point1, point2, point3, point4

    groupLines1 = parentGroup.entities.add_group
    entitiesLines1 = groupLines1.entities
    line1_1 = entitiesLines1.add_line point1, point2, point3, point4
    point = Geom::Point3d.new input[:width], 0, 0
    transformGroup(point, groupLines)
    explodeAndfindFacesFromGroup(groupLines)
    explodeAndfindFacesFromGroup(groupLines1)
end

def createLinesAfterWaitingStep(input, rise, group, stairsAfterLandingP, parentGroup)
    entitiesLines = group.entities
    point0 = Geom::Point3d.new(0, 0, rise)
    point1 = Geom::Point3d.new(0, 0, 0)
    point2 = Geom::Point3d.new(0, -(input[:run] * stairsAfterLandingP.mm).to_mm, (rise * (stairsAfterLandingP).mm).to_mm)
    point3 = Geom::Point3d.new(0, -(input[:run] * (stairsAfterLandingP).mm).to_mm, (rise * (stairsAfterLandingP+1).mm).to_mm)
    line1 = entitiesLines.add_line point0, point1, point2, point3

    groupLines1 = parentGroup.entities.add_group
    entitiesLines1 = groupLines1.entities
    line1_1 = entitiesLines1.add_line point0, point1, point2, point3
    if input[:stairShape] == 'U'
        if input[:direction] == 'right' 
            x = (input[:width] * 2) + input[:gapBwFlights]
            x1 = input[:width] + input[:gapBwFlights]
        else 
            x = -(input[:width] + input[:gapBwFlights])
            x1 = -input[:gapBwFlights] 
        end
        if input[:waitingStep] == 'none'
            y = y1 = (input[:run] * (input[:landingPosition]-1).mm).to_mm
        elsif input[:waitingStep] == 'up'
            y = y1 = (input[:run] * (input[:landingPosition]-2).mm).to_mm
        elsif input[:waitingStep] == 'down'
            y = y1 = (input[:run] * (input[:landingPosition]).mm).to_mm
        end  
    else
        y = (input[:run] * (input[:landingPosition]-1).mm).to_mm + input[:width]
        y1 = (input[:run] * (input[:landingPosition]-1).mm).to_mm
        if input[:direction] == 'right' then angle = 90 else angle = 270 end
        entitiesLines.transform_entities(Geom::Transformation.rotation(ORIGIN,[0,0,1],(angle.degrees)),group)
        entitiesLines1.transform_entities(Geom::Transformation.rotation(ORIGIN,[0,0,1],(angle.degrees)),groupLines1)
        
        if input[:direction] == 'right' 
            x = x1 = input[:width]
        else 
            x = x1 = 0
        end
    end              
    point = Geom::Point3d.new x, y, (rise * (input[:landingPosition]-1).mm).to_mm
    transformGroup(point, group)
    point1 = Geom::Point3d.new x1, y1, (rise * (input[:landingPosition]-1).mm).to_mm
    transformGroup(point1, groupLines1)
    explodeAndfindFacesFromGroup(group)
    explodeAndfindFacesFromGroup(groupLines1)
end

def createEdgesBeforeWaitingStep(input, rise, entities, stairs)
    point1 = Geom::Point3d.new(0, input[:run], 0)
    point2 = Geom::Point3d.new(input[:width], input[:run], 0)
    line1 = entities.add_line point1, point2
    line1.find_faces

    if input[:stairShape] == 'S'
        z = (rise * (stairs-1).mm).to_mm
        y = (input[:run] * stairs.mm).to_mm
    else
        z = (rise * (input[:landingPosition]-1).mm).to_mm
        y = (input[:run] * input[:landingPosition].mm).to_mm
    end
    point3 = Geom::Point3d.new(0, y, z)
	point4 = Geom::Point3d.new(input[:width], y, z)
    line2 = entities.add_line point3, point4
    line2.find_faces
end

def createEdgesAfterWaitingStep(input, rise, entities, stairsAfterLandingP)
    if input[:stairShape] == 'U'
        if input[:direction] == 'right' 
            x = x2 = (input[:width] * 2) + input[:gapBwFlights]
            x1 = x3 = input[:width] + input[:gapBwFlights]
        else 
            x = x2 = -(input[:width] + input[:gapBwFlights])
            x1 = x3 = -input[:gapBwFlights] 
        end
        if input[:waitingStep] == 'none'
            y = y2 = (input[:run] * (input[:landingPosition]-1).mm).to_mm
            y1 = y3 = (input[:run] * (input[:landingPosition] - (stairsAfterLandingP+1)).mm).to_mm    
        elsif input[:waitingStep] == 'up'
            y = y2 = (input[:run] * (input[:landingPosition]-2).mm).to_mm
            y1 = y3 = (input[:run] * (input[:landingPosition] - (stairsAfterLandingP+2)).mm).to_mm    
        elsif input[:waitingStep] == 'down'
            y = y2 = (input[:run] * (input[:landingPosition]).mm).to_mm
            y1 = y3 = (input[:run] * (input[:landingPosition] - (stairsAfterLandingP)).mm).to_mm
            
        end   
    elsif 
        y = y1 =  (input[:run] * (input[:landingPosition]-1).mm).to_mm
        y2 = y3 = (input[:run] * (input[:landingPosition]-1).mm).to_mm + input[:width]
        if input[:direction] == 'right' 
            x = x1 = input[:width]
            x2 = x3 = input[:width] + (input[:run] * stairsAfterLandingP.mm).to_mm
        else 
            x = x1 = 0
            x2 = x3 = -(input[:run] * stairsAfterLandingP.mm).to_mm
        end
    end
    point1 = Geom::Point3d.new(x1, y, (rise * (input[:landingPosition]-1).mm).to_mm)
    point2 = Geom::Point3d.new(x, y2, (rise * (input[:landingPosition]-1).mm).to_mm)
    line1 = entities.add_line point1, point2
    line1.find_faces

    point3 = Geom::Point3d.new(x3, y1, (rise * ((input[:landingPosition] + stairsAfterLandingP)-1).mm).to_mm)
	point4 = Geom::Point3d.new(x2, y3, (rise * ((input[:landingPosition] + stairsAfterLandingP)-1).mm).to_mm)
    line2 = entities.add_line point3, point4
    line2.find_faces
end

createLinesBeforeWaitingStep(input, rise, parentGroup, stairs)
createEdgesBeforeWaitingStep(input, rise, entities, stairs)
if input[:stairShape] != 'S'
    groupLines = parentGroup.entities.add_group
    createLinesAfterWaitingStep(input, rise, groupLines, stairsAfterLandingP, parentGroup)
    createEdgesAfterWaitingStep(input, rise, entities, stairsAfterLandingP)
end

#a=(Sketchup.active_model.selection[0].explode.find_all{|e|e if e.respond_to?(:bounds)}).uniq
#a=(array.find_all{|e|e if e.respond_to?(:bounds)})#.uniq
#gr = parentGroup.entities.add_group(a)

# Hand Rails
def createHandRails(input, rise, stairs, stairsAfterLandingP, parentGroup)
    groupHandRails =  parentGroup.entities.add_group
    entities2 = groupHandRails.entities
    if input[:stairShape] == 'S'
	    y2 = input[:run] * stairs
	    point1 = Geom::Point3d.new(0, 0, rise + input[:handRailHeight])
	    point2 = Geom::Point3d.new(0, y2, (rise * (stairs+1)) + input[:handRailHeight])
	    point3 = Geom::Point3d.new(input[:width], 0, rise + input[:handRailHeight])
	    point4 = Geom::Point3d.new(input[:width], y2, (rise * (stairs+1)) + input[:handRailHeight])

	    if input[:handRailSide] == 'both'
		    line = entities2.add_line point1, point2
		    line = entities2.add_line point3, point4
	    elsif input[:handRailSide] == 'left'
		    line = entities2.add_line point1, point2
	    elsif input[:handRailSide] == 'right'
		    line = entities2.add_line point3, point4
	end

    elsif input[:stairShape] == 'L'
	    y2 = input[:run] * (input[:landingPosition]  - 1)
	    point1 = Geom::Point3d.new(0, 0, rise + input[:handRailHeight])
	    point2 = Geom::Point3d.new(0, y2, (rise * input[:landingPosition]) + input[:handRailHeight])
	    point3 = Geom::Point3d.new(input[:width], 0, rise + input[:handRailHeight])
	    point4 = Geom::Point3d.new(input[:width], y2, (rise * input[:landingPosition]) + input[:handRailHeight])
        if input[:direction] == 'right'
            x1 = 0
            x2 = input[:width] - input[:run]
            x3 = input[:width] + (stairsAfterLandingP*input[:run])
            x4 = input[:width]
            x5 = input[:width] + (stairsAfterLandingP * input[:run])
        else
            x1 = input[:width]
            x2 = input[:run]
            x3 = -(stairsAfterLandingP*input[:run])
            x4 = 0
            x5 = -((stairsAfterLandingP * input[:run]))
        end
        point16 = Geom::Point3d.new(x1, y2 + input[:width], (rise * input[:landingPosition]) + input[:handRailHeight])
	    point17 = Geom::Point3d.new(x2, y2 + input[:width], (rise * input[:landingPosition]) + input[:handRailHeight])
	    point18 = Geom::Point3d.new(x3, y2 + input[:width], (rise * input[:landingPosition]) + (rise*(stairsAfterLandingP+1)) + input[:handRailHeight])
	    point19 = Geom::Point3d.new(x4, y2, (rise * input[:landingPosition]) + rise + input[:handRailHeight])
        point20 = Geom::Point3d.new(x5, y2, (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1)) + input[:handRailHeight])
        if input[:direction] == 'right'
		    if input[:handRailSide] == 'both'
			    line = entities2.add_line point3, point4
			    line = entities2.add_line point1, point2, point16, point17, point18 
			    line = entities2.add_line point19, point20
		    elsif input[:handRailSide] == 'left'
			    line = entities2.add_line point1, point2, point16, point17, point18
		    elsif input[:handRailSide] == 'right'
			    line = entities2.add_line point3, point4
			    line = entities2.add_line point19, point20
		    end
	    else
		    if input[:handRailSide] == 'both'
			    line = entities2.add_line point1, point2
    			line = entities2.add_line point3, point4, point16, point16, point17, point18  
	    		line = entities2.add_line point19, point20
		    elsif input[:handRailSide] == 'left'
			    line = entities2.add_line point1, point2
    			line = entities2.add_line point19, point20
	    	elsif input[:handRailSide] == 'right'
		    	line = entities2.add_line point3, point4, point16, point16, point17, point18  
		    end
	    end

    elsif input[:stairShape] == 'U'
	    y0 = input[:run] * (input[:landingPosition]  - 1)
	    point1 = Geom::Point3d.new(0, 0, rise + input[:handRailHeight])
	    point2 = Geom::Point3d.new(0, y0, (rise * input[:landingPosition]) + input[:handRailHeight])
	    point3 = Geom::Point3d.new(input[:width], 0, rise + input[:handRailHeight])
        point4 = Geom::Point3d.new(input[:width], y0, (rise * input[:landingPosition]) + input[:handRailHeight])
        if input[:direction] == 'right'
            x1 = 0
            x2 = input[:width] + input[:width] + input[:gapBwFlights]
            x3 = input[:width] + input[:gapBwFlights]
        else
            x1 = input[:width]
            x2 = -(input[:width] + input[:gapBwFlights])
            x3 = -input[:gapBwFlights]
        end
        
        if input[:waitingStep] == 'none'
            y1 = y0 + input[:landingDepth]
            y2 = y0 + input[:run]
            y3 = input[:run] * (input[:landingPosition] - (stairsAfterLandingP + 1))
            y4 = y0
        
        elsif input[:waitingStep] == 'up'
            y1 = y0 + input[:landingDepth]
            y2 = y0
            y3 = (input[:run] * (input[:landingPosition] - (stairsAfterLandingP + 1)))-input[:run]
            y4 = y0-input[:run]
        elsif input[:waitingStep] == 'down'
            y1 = y0 + input[:landingDepth]
            y2 = y0 + (input[:run]*2)
            y3 = (input[:run] * (input[:landingPosition] - (stairsAfterLandingP)))
            y4 = y0 + input[:run]
        end
        point16 = Geom::Point3d.new(x1, y1, (rise * input[:landingPosition]) + input[:handRailHeight])
		point17 = Geom::Point3d.new(x2, y1, (rise * input[:landingPosition]) + input[:handRailHeight])
		point18 = Geom::Point3d.new(x2, y2, (rise * input[:landingPosition])  + input[:handRailHeight])
		point19 = Geom::Point3d.new(x2, y3, (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1))  + input[:handRailHeight])
		point20 = Geom::Point3d.new(x3, y4, (rise * input[:landingPosition]) + rise + input[:handRailHeight])
        point21 = Geom::Point3d.new(x3, y3, (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1)) + input[:handRailHeight])		
        pointu = Geom::Point3d.new(x2, y4, (rise * input[:landingPosition]) + rise + input[:handRailHeight])
		if input[:direction] == 'right'
			if input[:handRailSide] == 'both'
				line = entities2.add_line point3, point4
				line = entities2.add_line point1, point2, point16, point17, point18, point19
				line = entities2.add_line point20, point21
			elsif input[:handRailSide] == 'left'
				line = entities2.add_line point1, point2, point16, point17, point18, point19
			elsif input[:handRailSide] == 'right'
				line = entities2.add_line point3, point4 
				pointu = Geom::Point3d.new(input[:width] + input[:width] + input[:gapBwFlights], y2, (rise * input[:landingPosition]) + rise + input[:handRailHeight])
                line = entities2.add_line pointu, point19
			end
		else	
			if input[:handRailSide] == 'both'
				line = entities2.add_line point1, point2
				line = entities2.add_line point3, point4, point16, point17, point18, point19
				line = entities2.add_line point20, point21
			elsif input[:handRailSide] == 'left'
				line = entities2.add_line point1, point2
				line = entities2.add_line point20, point21
			elsif input[:handRailSide] == 'right'
				line = entities2.add_line point3, point4, point16, point17, point18, point19
			end
		end
	end
end

# Head Height
def createHeadHeight(input, rise, stairs, stairsAfterLandingP, parentGroup)
    groupHeadHeight =  parentGroup.entities.add_group
    entities3 = groupHeadHeight.entities
    if input[:stairShape] == 'S'
        y2 = input[:run] * stairs
	    entities3.add_face [0, 0, rise + input[:headHeight]], [input[:width], 0, rise + input[:headHeight]], [input[:width], y2, (rise * (stairs+1)) + input[:headHeight]], [0, y2, (rise * (stairs+1)) + input[:headHeight]]

    elsif input[:stairShape] == 'L'
        y2 = input[:run] * (input[:landingPosition]  - 1)
	    entities3.add_face [0, 0, rise + input[:headHeight]], [input[:width], 0, rise + input[:headHeight]], [input[:width], y2, (rise * input[:landingPosition]) + input[:headHeight]], [0, y2, (rise * input[:landingPosition]) + input[:headHeight]]
	    entities3.add_face [0, y2, (rise * input[:landingPosition]) + input[:headHeight]], [0, y2 + input[:width], (rise * input[:landingPosition]) + input[:headHeight]], [input[:width], y2 + input[:width], (rise * input[:landingPosition]) + input[:headHeight]], [input[:width], y2, (rise * input[:landingPosition]) + input[:headHeight]]
        if input[:direction] == 'right'
            x1 = input[:width]
            x2 = input[:width] + (stairsAfterLandingP * input[:run]) 
        else
            x1 = 0
            x2 = -(stairsAfterLandingP * input[:run])
        end
        entities3.add_face [x1, y2 + input[:width], (rise * input[:landingPosition]) + rise + input[:headHeight]], [x1, y2, (rise * input[:landingPosition]) + rise + input[:headHeight]], [x2, y2, (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1)) + input[:headHeight]], [x2, y2 + input[:width], (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1)) + input[:headHeight]]

    elsif input[:stairShape] == 'U'	
        y2 = input[:run] * (input[:landingPosition]  - 1)
        entities3.add_face [0, 0, rise + input[:headHeight]], [input[:width], 0, rise + input[:headHeight]], [input[:width], y2, (rise * input[:landingPosition]) + input[:headHeight]], [0, y2, (rise * input[:landingPosition]) + input[:headHeight]]
        if input[:direction] == 'right'
            x1 = 0
            x2 = input[:width]+input[:gapBwFlights]
            x3 = input[:width]+input[:width]+input[:gapBwFlights]
            x4 = input[:width]
        else
            x1 = input[:width]
            x2  = -input[:gapBwFlights]
            x3 = -(input[:width]+input[:gapBwFlights])
            x4 = 0
        end
	    if input[:waitingStep] == 'none'
			entities3.add_face [x1, y2, (rise * input[:landingPosition]) + input[:headHeight]], [x1, y2 + input[:landingDepth], (rise * input[:landingPosition]) + input[:headHeight]], [x3 , y2 + input[:landingDepth], (rise * input[:landingPosition]) + input[:headHeight]], [x3, y2, (rise * input[:landingPosition]) + input[:headHeight]]
			entities3.add_face [x2, y2, (rise * input[:landingPosition]) + rise + input[:headHeight]], [x3, y2, (rise * input[:landingPosition]) + rise + input[:headHeight]], [x3, input[:run] * (input[:landingPosition] - (stairsAfterLandingP + 1)), (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1)) + input[:headHeight]], [x2, input[:run] * (input[:landingPosition] - (stairsAfterLandingP + 1)), (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1)) + input[:headHeight]]
        elsif input[:waitingStep] == 'up'
            entities3.add_face [x1, y2, (rise * input[:landingPosition]) + input[:headHeight]], [x1, y2 + input[:landingDepth], (rise * input[:landingPosition]) + input[:headHeight]], [x3 , y2 + input[:landingDepth], (rise * input[:landingPosition]) + input[:headHeight]], [x3, y2 - input[:run], (rise * input[:landingPosition]) + input[:headHeight]], [x2, y2 - input[:run], (rise * input[:landingPosition]) + input[:headHeight]], [x2, y2 , (rise * input[:landingPosition]) + input[:headHeight]], [x1, y2, (rise * input[:landingPosition]) + input[:headHeight]]
            entities3.add_face [x2, y2 - input[:run], (rise * input[:landingPosition]) +rise+ input[:headHeight]], [x3, y2 - input[:run], (rise * input[:landingPosition]) +rise+ input[:headHeight]], [x3, input[:run] * (input[:landingPosition] - (stairsAfterLandingP + 2)), (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1)) + input[:headHeight]], [x2, input[:run] * (input[:landingPosition] - (stairsAfterLandingP + 2)), (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1)) + input[:headHeight]]
	    elsif input[:waitingStep] == 'down'
            entities3.add_face [x1, y2, (rise * input[:landingPosition]) + input[:headHeight]], [x1, y2 + input[:landingDepth], (rise * input[:landingPosition]) + input[:headHeight]], [x3 , y2 + input[:landingDepth], (rise * input[:landingPosition]) + input[:headHeight]], [x3, y2 + input[:run], (rise * input[:landingPosition]) + input[:headHeight]], [x4, y2 + input[:run], (rise * input[:landingPosition]) + input[:headHeight]], [x4, y2, (rise * input[:landingPosition]) + input[:headHeight]]         
            entities3.add_face [x2, y2+input[:run], (rise * input[:landingPosition])+rise + input[:headHeight]], [x3, y2+input[:run], (rise * input[:landingPosition])+rise + input[:headHeight]], [x3, input[:run] * (input[:landingPosition] - (stairsAfterLandingP)), (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1)) + input[:headHeight]], [x2, input[:run] * (input[:landingPosition] - (stairsAfterLandingP)), (rise * input[:landingPosition]) + (rise * (stairsAfterLandingP+1)) + input[:headHeight]]
        end 
    end
end

if input[:handRailSide] != 'none'
    createHandRails(input, rise, stairs, stairsAfterLandingP, parentGroup)
end
createHeadHeight(input, rise, stairs, stairsAfterLandingP, parentGroup)

Sketchup.active_model.commit_operation  
}
end