-- this is the rendering code for the portals, some references from: https://github.com/MattJeanes/world-portals

AddCSLuaFile()

local portals = {}
local renderViewTable = {
	origin = Vector(),
	angles = Angle(),
	drawviewmodel = false,
	zfar = zfar,
}

local function DrawQuadEasier(e, multiplier, offset, rotate)
	local right = e:GetRight() * multiplier.x
	local forward = e:GetForward() * multiplier.y 
	local up = e:GetUp() * multiplier.z 

	local pos = e:GetPos() + e:GetRight() * offset.x + e:GetForward() * offset.y + e:GetUp() * offset.z
	if !rotate then
		render.DrawQuad(
			pos + right - forward + up, 
			pos - right - forward + up, 
			pos - right + forward + up, 
			pos + right + forward + up
		)
	elseif rotate == 1 then
		render.DrawQuad(
			pos + right + forward - up, 
			pos - right + forward - up, 
			pos - right + forward + up, 
			pos + right + forward + up
		)
	else
		render.DrawQuad(
			pos + right - forward + up, 
			pos + right - forward - up, 
			pos + right + forward - up, 
			pos + right + forward + up
		)
	end
end

-- sort the portals by distance since draw functions do not obey the z buffer
timer.Create("seamless_portal_distance_fix", 0.25, 0, function()
	portals = ents.FindByClass("seamless_portal")
	table.sort(portals, function(a, b) 
		return a:GetPos():DistToSqr(EyePos()) < b:GetPos():DistToSqr(EyePos())
	end)
end)

-- update the rendertarget here since we cant do it in postdraw (cuz of infinite recursion)
local drawPlayerInView = false
hook.Add("RenderScene", "seamless_portals_draw", function(eyePos, eyeAngles)
	drawPlayerInView = !SeamlessPortals.drawPlayerInView
	for k, v in ipairs(portals) do
		if !v:IsValid() or !v:ExitPortal():IsValid() then continue end
		-- optimization checks
		if eyePos:DistToSqr(v:GetPos()) > 2500 * 2500 then continue end
		if (eyePos - v:GetPos()):Dot(v:GetUp()) < -10 or eyeAngles:Forward():Dot(eyePos - v:GetPos()) > 50 then continue end

		local exitPortal = v:ExitPortal()
		local editedPos, editedAng = SeamlessPortals.TransformPortal(v, exitPortal, eyePos, Angle(eyeAngles[1], eyeAngles[2], eyeAngles[3]))

		renderViewTable.origin = editedPos
		renderViewTable.angles = editedAng

		-- render the scene
		local oldClip = render.EnableClipping(true)
		render.PushRenderTarget(v.PORTAL_RT)
		render.PushCustomClipPlane(exitPortal:GetUp(), exitPortal:GetUp():Dot(exitPortal:GetPos() + exitPortal:GetUp() * 0.1))
		render.RenderView(renderViewTable)
		render.PopCustomClipPlane()
		render.EnableClipping(oldClip)
		render.PopRenderTarget()

	end
	drawPlayerInView = false
	SeamlessPortals.drawPlayerInView = false
	SeamlessPortals.stupid_halo_fix = false
end)

-- draw the player in renderview
hook.Add("ShouldDrawLocalPlayer", "seamless_portal_drawplayer", function()
	if drawPlayerInView then return true end
end)

-- draw the quad on the portals
local drawMat = Material("models/props_lab/cornerunit_cloud")
hook.Add("PostDrawOpaqueRenderables", "seamless_portals_draw", function(_, sky)
	if sky then return end
	for k, v in ipairs(portals) do
		if !v or !v:IsValid() then continue end
		local backAmt = 3
		local scalex = (v:OBBMaxs().x - v:OBBMins().x) * 0.5 - 1.1
		local scaley = (v:OBBMaxs().y - v:OBBMins().y) * 0.5 - 1.1
		render.SetMaterial(drawMat)


		if drawPlayerInView then 
			DrawQuadEasier(v, Vector(scaley, scalex, backAmt), Vector(1, 1, -backAmt))
			--if !SeamlessPortals.stupid_halo_fix then
			--	DrawQuadEasier(v, Vector(scaley, -scalex, -backAmt), Vector(1, 1, -backAmt))
			--end
			--continue
		end

		-- outer quads
		DrawQuadEasier(v, Vector(scaley, -scalex, -backAmt), Vector(1, 1, -backAmt))
		DrawQuadEasier(v, Vector(scaley, -scalex, backAmt), Vector(1, 1, -backAmt), 1)
		DrawQuadEasier(v, Vector(scaley, scalex, -backAmt), Vector(1, 1, -backAmt), 1)
		DrawQuadEasier(v, Vector(scaley, -scalex, backAmt), Vector(1, 1, -backAmt), 2)
		DrawQuadEasier(v, Vector(-scaley, -scalex, -backAmt), Vector(1, 1, -backAmt), 2)

		-- do cursed stencil stuff
		render.ClearStencil()
		render.SetStencilEnable(true)
		render.SetStencilWriteMask(1)
		render.SetStencilTestMask(1)
		render.SetStencilReferenceValue(1)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.SetStencilPassOperation(STENCIL_REPLACE)
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
	
		-- draw the quad that the 2d texture will be drawn on
		--DrawQuadEasier(v, Vector(scaley, scalex, backAmt), Vector(1, 1, -backAmt))
		DrawQuadEasier(v, Vector(scaley, scalex, -backAmt), Vector(1, 1, -backAmt))
		DrawQuadEasier(v, Vector(scaley, scalex, backAmt), Vector(1, 1, -backAmt), 1)
		DrawQuadEasier(v, Vector(scaley, -scalex, -backAmt), Vector(1, 1, -backAmt), 1)
		DrawQuadEasier(v, Vector(scaley, scalex, backAmt), Vector(1, 1, -backAmt), 2)
		DrawQuadEasier(v, Vector(-scaley, scalex, -backAmt), Vector(1, 1, -backAmt), 2)

		-- draw the actual portal texture
		render.SetMaterial(v.PORTAL_MATERIAL)
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.DrawScreenQuad()

		render.SetStencilEnable(false)
	end
end)
