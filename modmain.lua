_G = GLOBAL
assert = _G.assert
error = _G.error
require = _G.require

local KEYP1 = GLOBAL.KEY_CTRL
local Vector3 = GLOBAL.Vector3
local TheInput = GLOBAL.TheInput
local GROUND = GLOBAL.GROUND

local ToggleButton = GetModConfigData("togglekey")
local GeometryMode = "enabled"
local DialogOpen = false

local PopupDialogScreen = require "screens/popupdialog"
 
local function TogglePopup(inst)

	local function initialize()
		DialogOpen = false
		TheFrontEnd:PopScreen()
		_G.SetPause(false)
	end

    local function enabledchoice(inst)
    	initialize()
		GeometryMode = "enabled"
		print("Assisted Geometry is now enabled.")
    end
 
    local function disabledchoice(inst)
    	initialize()
		GeometryMode = "disabled"
		print("Assisted Geometry is now disabled.")
    end
 
    _G.SetPause(true)
    DialogOpen = true
    local options = {
        {text="Enabled", cb = enabledchoice},
        {text="Disabled", cb = disabledchoice},
    }
 
    TheFrontEnd:PushScreen(PopupDialogScreen(
 
    "Choose Assisted Geometry Mode",
    "Choose one of the below",
 
    options))
end


----------placer-----
local function newOnUpdate(self, dt)
	local pt = TheInput:GetWorldPosition()

	if not (GeometryMode == "disabled") and not TheInput:ControllerAttached() then
		if self.snap_to_tile and GLOBAL.GetWorld().Map then
			pt = Vector3(GLOBAL.GetWorld().Map:GetTileCenterPoint(pt:Get()))
		elseif self.snap_to_meters then
			pt = Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
		elseif not TheInput:IsKeyDown(KEYP1) then
			pt = Vector3( pt.x+.25-(pt.x+.25)%.5, 0, pt.z+.25-(pt.z+.25)%.5)
		end
	end

    local active_item = _G.GetPlayer().components.inventory:GetActiveItem()
	if active_item and active_item:HasTag("wallbuilder") then
		pt = Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
	end

    if TheInput:ControllerAttached() then
    	self.snap_to_grid = true
    	if self.snap_to_meters or (GeometryMode == "disabled") then
    		self.snap_to_grid = false
    	end
		if self.snap_to_tile and GLOBAL.GetWorld().Map then
			pt = Vector3(GLOBAL.GetPlayer().entity:LocalToWorldSpace(0,0,0))
			pt = Vector3(GLOBAL.GetWorld().Map:GetTileCenterPoint(pt:Get()))
			self.inst.Transform:SetPosition(pt:Get())
		elseif self.snap_to_grid then
			pt = Vector3(GLOBAL.GetPlayer().entity:LocalToWorldSpace(0,0,0))
			pt = Vector3(math.floor(pt.x)+.25, 0, math.floor(pt.z)+.25)
			self.inst.Transform:SetPosition(pt:Get())
		elseif self.snap_to_meters then
			pt = Vector3(GLOBAL.GetPlayer().entity:LocalToWorldSpace(0,0,0))
			pt = Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
			self.inst.Transform:SetPosition(pt:Get())
		else
			if self.inst.parent == nil then
				GLOBAL.GetPlayer():AddChild(self.inst)
				self.inst.Transform:SetPosition(1,0,0)
			end
		end
	else
		self.inst.Transform:SetPosition(pt:Get())	
	end
	
	self.can_build = true
	if self.testfn then
		self.can_build = self.testfn(Vector3(self.inst.Transform:GetWorldPosition()))
	end
	
	if not (GeometryMode == "disabled") then
		self.inst.AnimState:SetMultColour(0,0,0,.5)
	else 
		self.inst.AnimState:SetMultColour(255,255,255,1.0)
	end
	local color = self.can_build and Vector3(.1,.5,.1) or Vector3(.5,.1,.1)
	self.inst.AnimState:SetAddColour(color.x, color.y, color.z ,0)
end

local function geomplace(inst)
	inst.OnUpdate = newOnUpdate
end


----------builder-----
local function newCanBuildAtPoint(self, pt, recipe)
	if not (GeometryMode == "disabled") then
		local ground = GLOBAL.GetWorld()
	    local tile = GROUND.GRASS
	    if ground and ground.Map then
	        tile = ground.Map:GetTileAtPoint(pt:Get())
	    end
		if tile == GROUND.IMPASSABLE then
			return false
		else
			local ents = TheSim:FindEntities(pt.x,pt.y,pt.z, 6)
			for k, v in pairs(ents) do
				if v ~= self.inst and (not v.components.placer) and not v:HasTag("player") and not v:HasTag("FX") and v.entity:IsVisible() and not (v.components.inventoryitem and v.components.inventoryitem.owner )then
					local min_rad = recipe.min_spacing or 2+1.2
					local dsq = GLOBAL.distsq(Vector3(v.Transform:GetWorldPosition()), pt)
					if dsq < min_rad*min_rad then
						return false
					end
				end
			end
		end
		return true
	else
		local ground = GLOBAL.GetWorld()
	    local tile = GROUND.GRASS
	    if ground and ground.Map then
	        tile = ground.Map:GetTileAtPoint(pt:Get())
	    end
		if tile == GROUND.IMPASSABLE then
			return false
		else
			local ents = TheSim:FindEntities(pt.x,pt.y,pt.z, 6, nil, {'player', 'fx', 'NOBLOCK'})
			for k, v in pairs(ents) do
				if v ~= self.inst and (not v.components.placer) and v.entity:IsVisible() and not (v.components.inventoryitem and v.components.inventoryitem.owner ) then
					local min_rad = recipe.min_spacing or 2+1.2
					if recipe.name == "treasurechest" and v.prefab == "pond" then
						min_rad = min_rad + 1
					end
					local dsq = GLOBAL.distsq(Vector3(v.Transform:GetWorldPosition()), pt)
					if dsq <= min_rad*min_rad then
						return false
					end
				end
			end
		end
		return true
	end
end
local function newMakeRecipe(self, recipe, pt, onsuccess)
    if recipe then
    	self.inst:PushEvent("makerecipe", {recipe = recipe})
		pt = pt or Point(self.inst.Transform:GetWorldPosition())
		if not (GeometryMode == "disabled") then
			if not TheInput:IsKeyDown(KEYP1) then
				pt = Vector3( pt.x+.25-(pt.x+.25)%.5, 0, pt.z+.25-(pt.z+.25)%.5)
			end
		end
		if self:IsBuildBuffered(recipe.name) or self:CanBuild(recipe.name) then
			self.inst.components.locomotor:Stop()
			local buffaction = GLOBAL.BufferedAction(self.inst, nil, GLOBAL.ACTIONS.BUILD, nil, pt, recipe.name, 1)
			if onsuccess then
				buffaction:AddSuccessAction(onsuccess)
			end
			self.inst.components.locomotor:PushAction(buffaction, true)
			return true
		end
    end
    return false
end

local function geombuild(inst)
	inst.CanBuildAtPoint = newCanBuildAtPoint
	inst.MakeRecipe = newMakeRecipe
end


----------deployable-----
local function newCanDeploy(self, pt)
	if not TheInput:IsKeyDown(KEYP1) then
		pt = Vector3( pt.x+.25-(pt.x+.25)%.5, 0, pt.z+.25-(pt.z+.25)%.5)
	end
    return not self.test or self.test(self.inst, pt)
end

local function newDeploy(self, pt, deployer)
	if not TheInput:IsKeyDown(KEYP1) then
		pt = Vector3( pt.x+.25-(pt.x+.25)%.5, 0, pt.z+.25-(pt.z+.25)%.5)
	end
    if not self.test or self.test(self.inst, pt, deployer) then
		if self.ondeploy then
	        self.ondeploy(self.inst, pt, deployer)
		end
		return true
	end
end

local function geomdeploy(inst)
	inst.CanDeploy = newCanDeploy
	inst.Deploy = newDeploy
end

GLOBAL.TheInput:AddKeyDownHandler(ToggleButton, function()
	TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/craft_close")
	if not DialogOpen then
		TogglePopup(inst)
	elseif DialogOpen then 
		DialogOpen = false
		TheFrontEnd:PopScreen()
		_G.SetPause(false)
	end
end)

AddComponentPostInit("placer", geomplace)
AddComponentPostInit("builder", geombuild)
AddComponentPostInit("deployable", geomdeploy)