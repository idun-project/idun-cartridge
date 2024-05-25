-- ease - a modified remix of flux and bezier-easing.
-- https://github.com/poke1024/ease.git

-- the following code is adapted from flux, Copyright (c) 2016 rxi,
-- https://github.com/rxi/flux/.

local ease = { linear = function(p) return p end }

local penner = {
	quad    = "p * p",
	cubic   = "p ^ 3",
	quart   = "p ^ 4",
	quint   = "p ^ 5",
	expo    = "2 ^ (10 * (p - 1))",
	sine    = "-cos(p * (pi * .5)) + 1",
	circ    = "-(sqrt(1 - (p * p)) - 1)",
	back    = "p * p * (2.7 * p - 1.7)",
	elastic = "-(2^(10 * (p - 1)) * sin((p - 1.075) * (pi * 2) / .3))",
	bounce  = "bounce(p)"
}

local bounce = function(t)
	t = 1 - t
	if t < (1 / 2.75) then
  		return 1 - 7.5625 * t * t
	elseif t < (2 / 2.75) then
		t = t - 1.5 / 2.75
		return 1 - (7.5625 * t * t + .75)
	elseif t < (2.5 / 2.75) then
		t = t - 2.25 / 2.75
		return 1 - (7.5625 * t * t + .9375)
	else
		t = t - 2.625 / 2.75
		return 1 - (7.5625 * t * t + .984375)
	end
end

local load = loadstring or load

local symbols = {
	math = math,
	bounce = bounce
}

local compile = function(name, str, expr)
	ease[name] = load([[
		local sin = math.sin; local cos = math.cos; local pi = math.pi; local sqrt = math.sqrt;
		return function(p) ]] .. str:gsub("%$e", expr) .. " end", name, "t", symbols)()
end

for k, v in pairs(penner) do
	compile("in" .. k, "return $e", v)
	compile("out" .. k, [[
		p = 1 - p
		return 1 - ($e)
	]], v)
	compile("inout" .. k, [[
		p = p * 2
		if p < 1 then
		  return .5 * ($e)
		else
		  p = 2 - p
		  return .5 * (1 - ($e)) + .5
		end
	]], v)
end

-- the following code is a lua port of Gaëtan Renaudeau's JavaScript library bezier-easing,
-- https://github.com/gre/bezier-easing (ported from v2.0.3, e0036aa16e36d3647413013fa774d3df37f348f1).

-- These values are established by empiricism with tests (tradeoff: performance VS precision)
local NEWTON_ITERATIONS = 4
local NEWTON_MIN_SLOPE = 0.001
local SUBDIVISION_PRECISION = 0.0000001
local SUBDIVISION_MAX_ITERATIONS = 10

local kSplineTableSize = 11
local kSampleStepSize = 1.0 / (kSplineTableSize - 1.0)

local function A (aA1, aA2) return 1.0 - 3.0 * aA2 + 3.0 * aA1 end
local function B (aA1, aA2) return 3.0 * aA2 - 6.0 * aA1 end
local function C (aA1)      return 3.0 * aA1 end

-- Returns x(t) given t, x1, and x2, or y(t) given t, y1, and y2.
local function calcBezier (aT, aA1, aA2) return ((A(aA1, aA2) * aT + B(aA1, aA2)) * aT + C(aA1)) * aT end

-- Returns dx/dt given t, x1, and x2, or dy/dt given t, y1, and y2.
local function getSlope (aT, aA1, aA2) return 3.0 * A(aA1, aA2) * aT * aT + 2.0 * B(aA1, aA2) * aT + C(aA1) end

local abs = math.abs

local function binarySubdivide (aX, aA, aB, mX1, mX2)
	local currentX, currentT
	for i = 1, SUBDIVISION_MAX_ITERATIONS do
		currentT = aA + (aB - aA) / 2.0
		currentX = calcBezier(currentT, mX1, mX2) - aX
		if currentX > 0.0 then
			aB = currentT
		else
			aA = currentT
		end
		if abs(currentX) <= SUBDIVISION_PRECISION then
			break
		end
	end
	return currentT
end

local function newtonRaphsonIterate (aX, aGuessT, mX1, mX2)
	for i = 1, NEWTON_ITERATIONS do
		local currentSlope = getSlope(aGuessT, mX1, mX2)
		if currentSlope == 0.0 then
			return aGuessT
		end
		local currentX = calcBezier(aGuessT, mX1, mX2) - aX
		aGuessT = aGuessT - currentX / currentSlope
	end
	return aGuessT
end

local newSampleValues
if type(jit) == "table" then -- running under LuaJIT?
	local ffi = require("ffi")
	local spec = "float[" .. tostring(kSplineTableSize + 1) .. "]"
	newSampleValues = function() return ffi.new(spec) end
else
	newSampleValues = function() return {} end
end

ease.cubicbezier = function (mX1, mY1, mX2, mY2)
	if not (0 <= mX1 and mX1 <= 1 and 0 <= mX2 and mX2 <= 1) then
		error('bezier x values must be in [0, 1] range')
	end

	if mX1 == mY1 and mX2 == mY2 then
		return ease.linear
	end

	local sampleValues = newSampleValues()
	for i = 0, kSplineTableSize - 1 do
		sampleValues[i + 1] = calcBezier(i * kSampleStepSize, mX1, mX2)
	end
	local lastSample = kSplineTableSize - 1

	local function getTForX (aX)
		local intervalStart = 0.0
		local currentSample = 1

		while currentSample ~= lastSample and sampleValues[currentSample + 1] <= aX do
			currentSample = currentSample + 1
			intervalStart = intervalStart + kSampleStepSize
		end
		currentSample = currentSample - 1

		-- Interpolate to provide an initial guess for t
		local dist = (aX - sampleValues[currentSample + 1]) / (sampleValues[currentSample + 2] - sampleValues[currentSample + 1])
		local guessForT = intervalStart + dist * kSampleStepSize

		local initialSlope = getSlope(guessForT, mX1, mX2)
		if initialSlope >= NEWTON_MIN_SLOPE then
			return newtonRaphsonIterate(aX, guessForT, mX1, mX2)
		elseif initialSlope == 0.0 then
			return guessForT
		else
			return binarySubdivide(aX, intervalStart, intervalStart + kSampleStepSize, mX1, mX2)
		end
	end

	return function (x)
		-- Because Lua numbers are imprecise, we should guarantee the extremes are right.
		if x == 0 then
			return 0
		elseif x == 1 then
			return 1
		else
			return calcBezier(getTForX(x), mY1, mY2)
		end
	end
end

return ease
