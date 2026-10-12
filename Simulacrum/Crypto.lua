local _, ns = ...

-- ===========================================================================
-- Minimal crypto for the signed DKP ledger, pure Lua 5.1:
--   SHA-256, base64, Montgomery bignum arithmetic, RSA-1024 (PKCS#1-style
--   padding without DigestInfo). Verification is cheap (e = 65537); signing
--   is only done by the guild master and runs in a coroutine across frames.
-- ===========================================================================
local Crypto = {}
ns.Crypto = Crypto

local floor = math.floor
local TWO32 = 4294967296

-- ---------------------------------------------------------------------------
-- 32-bit ops (WoW's `bit` library if present, normalised to unsigned)
-- ---------------------------------------------------------------------------
local band, bxor, bnot, rshift, lshift
if bit and bit.band then
	local b = bit
	band = function(x, y) return b.band(x, y) % TWO32 end
	bxor = function(x, y) return b.bxor(x, y) % TWO32 end
	bnot = function(x) return b.bnot(x) % TWO32 end
	rshift = function(x, n) return b.rshift(x, n) % TWO32 end
	lshift = function(x, n) return b.lshift(x, n) % TWO32 end
else
	-- arithmetic fallback (nibble tables)
	local AND, XOR = {}, {}
	for i = 0, 15 do
		AND[i], XOR[i] = {}, {}
		for j = 0, 15 do
			local a, x, p, ii, jj = 0, 0, 1, i, j
			for _ = 1, 4 do
				local bi, bj = ii % 2, jj % 2
				if bi == 1 and bj == 1 then a = a + p end
				if bi ~= bj then x = x + p end
				ii, jj, p = floor(ii / 2), floor(jj / 2), p * 2
			end
			AND[i][j], XOR[i][j] = a, x
		end
	end
	local function op(t, x, y)
		local r, p = 0, 1
		for _ = 1, 8 do
			r = r + t[x % 16][y % 16] * p
			x, y, p = floor(x / 16), floor(y / 16), p * 16
		end
		return r
	end
	band = function(x, y) return op(AND, x % TWO32, y % TWO32) end
	bxor = function(x, y) return op(XOR, x % TWO32, y % TWO32) end
	bnot = function(x) return TWO32 - 1 - x % TWO32 end
	rshift = function(x, n) return floor((x % TWO32) / 2 ^ n) end
	lshift = function(x, n) return (x * 2 ^ n) % TWO32 end
end
local function ror(x, n) return (rshift(x, n) + lshift(x, 32 - n)) % TWO32 end

-- ---------------------------------------------------------------------------
-- SHA-256 -> 32 raw bytes
-- ---------------------------------------------------------------------------
local K256 = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

function Crypto.SHA256(msg)
	local len = #msg
	msg = msg .. "\128" .. ("\0"):rep((55 - len) % 64)
	local bits = len * 8
	local tail = {}
	for i = 8, 1, -1 do tail[i] = string.char(bits % 256); bits = floor(bits / 256) end
	msg = msg .. table.concat(tail)

	local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
	local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	local w = {}
	for chunk = 1, #msg, 64 do
		for i = 0, 15 do
			local a, b, c, d = msg:byte(chunk + i * 4, chunk + i * 4 + 3)
			w[i] = ((a * 256 + b) * 256 + c) * 256 + d
		end
		for i = 16, 63 do
			local v15, v2 = w[i - 15], w[i - 2]
			local s0 = bxor(bxor(ror(v15, 7), ror(v15, 18)), rshift(v15, 3))
			local s1 = bxor(bxor(ror(v2, 17), ror(v2, 19)), rshift(v2, 10))
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % TWO32
		end
		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
		for i = 0, 63 do
			local S1 = bxor(bxor(ror(e, 6), ror(e, 11)), ror(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local t1 = (h + S1 + ch + K256[i + 1] + w[i]) % TWO32
			local S0 = bxor(bxor(ror(a, 2), ror(a, 13)), ror(a, 22))
			local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
			local t2 = (S0 + maj) % TWO32
			h, g, f, e, d, c, b, a = g, f, e, (d + t1) % TWO32, c, b, a, (t1 + t2) % TWO32
		end
		h0, h1, h2, h3 = (h0 + a) % TWO32, (h1 + b) % TWO32, (h2 + c) % TWO32, (h3 + d) % TWO32
		h4, h5, h6, h7 = (h4 + e) % TWO32, (h5 + f) % TWO32, (h6 + g) % TWO32, (h7 + h) % TWO32
	end
	local out = {}
	for _, v in ipairs({ h0, h1, h2, h3, h4, h5, h6, h7 }) do
		out[#out + 1] = string.char(floor(v / 16777216) % 256, floor(v / 65536) % 256, floor(v / 256) % 256, v % 256)
	end
	return table.concat(out)
end

function Crypto.Hex(s)
	return (s:gsub(".", function(c) return ("%02x"):format(c:byte()) end))
end

-- ---------------------------------------------------------------------------
-- base64 (no padding; alphabet is safe in addon messages and saved vars)
-- ---------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64I = {}
for i = 1, 64 do B64I[B64:sub(i, i)] = i - 1 end

function Crypto.B64Encode(s)
	local out = {}
	for i = 1, #s, 3 do
		local a, b, c = s:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local chars = (b == nil) and 2 or (c == nil) and 3 or 4
		for j = 1, chars do
			local idx = floor(n / 2 ^ (6 * (4 - j))) % 64
			out[#out + 1] = B64:sub(idx + 1, idx + 1)
		end
	end
	return table.concat(out)
end

function Crypto.B64Decode(s)
	local out = {}
	for i = 1, #s, 4 do
		local chunk = s:sub(i, i + 3)
		local n, cnt = 0, #chunk
		for j = 1, 4 do
			local v = B64I[chunk:sub(j, j)]
			if j <= cnt and not v then return nil end
			n = n * 64 + (v or 0)
		end
		local bytes = { floor(n / 65536) % 256, floor(n / 256) % 256, n % 256 }
		for j = 1, cnt - 1 do out[#out + 1] = string.char(bytes[j]) end
	end
	return table.concat(out)
end

-- ---------------------------------------------------------------------------
-- Bignums: little-endian arrays of 24-bit limbs, fixed length k
-- ---------------------------------------------------------------------------
local LB = 16777216 -- 2^24

local function fromBytes(s, k)
	local x = {}
	for i = 1, k do x[i] = 0 end
	local limb, shift = 1, 1
	for i = #s, 1, -1 do
		x[limb] = x[limb] + s:byte(i) * shift
		shift = shift * 256
		if shift == LB then limb, shift = limb + 1, 1 end
	end
	return x
end

local function toBytes(x, nbytes)
	local out, limb, shift = {}, 1, 1
	for i = nbytes, 1, -1 do
		out[i] = string.char(floor((x[limb] or 0) / shift) % 256)
		shift = shift * 256
		if shift == LB then limb, shift = limb + 1, 1 end
	end
	return table.concat(out)
end

local function geq(a, m, k, top)
	if top and top > 0 then return true end
	for i = k, 1, -1 do
		if a[i] ~= m[i] then return a[i] > m[i] end
	end
	return true
end

-- Montgomery product a*b*R^-1 mod m (CIOS). All intermediates stay below 2^53.
local function montmul(a, b, m, mp, k)
	local t = {}
	for i = 1, k + 2 do t[i] = 0 end
	for i = 1, k do
		local ai, C = a[i], 0
		for j = 1, k do
			local s = t[j] + ai * b[j] + C
			C = floor(s / LB)
			t[j] = s - C * LB
		end
		local s = t[k + 1] + C
		C = floor(s / LB)
		t[k + 1] = s - C * LB
		t[k + 2] = C
		local mu = (t[1] * mp) % LB
		s = t[1] + mu * m[1]
		C = floor(s / LB)
		for j = 2, k do
			s = t[j] + mu * m[j] + C
			C = floor(s / LB)
			t[j - 1] = s - C * LB
		end
		s = t[k + 1] + C
		C = floor(s / LB)
		t[k] = s - C * LB
		t[k + 1] = t[k + 2] + C
	end
	local top = t[k + 1]
	t[k + 1], t[k + 2] = nil, nil
	if geq(t, m, k, top) then
		local borrow = 0
		for i = 1, k do
			local v = t[i] - m[i] - borrow
			if v < 0 then v, borrow = v + LB, 1 else borrow = 0 end
			t[i] = v
		end
	end
	return t
end

local function one(k)
	local x = { 1 }
	for i = 2, k do x[i] = 0 end
	return x
end

-- PKCS#1 v1.5-style encoding: 00 01 FF..FF 00 || SHA-256(msg)
local function encode(msg, nbytes)
	local h = Crypto.SHA256(msg)
	return "\0\1" .. ("\255"):rep(nbytes - 3 - #h) .. "\0" .. h
end

-- modexp with exponent as a bit string ("1011..."), optional yield callback
local function modexp(base, bits, key, onStep)
	local k, m, mp = key.k, key.n, key.mp
	local xm = montmul(base, key.r2, m, mp, k)   -- to Montgomery form
	local acc = montmul(one(k), key.r2, m, mp, k) -- R mod m
	for i = 1, #bits do
		acc = montmul(acc, acc, m, mp, k)
		if bits:byte(i) == 49 then acc = montmul(acc, xm, m, mp, k) end
		if onStep then onStep(i) end
	end
	return montmul(acc, one(k), m, mp, k)         -- back to normal form
end

local function hexToBits(hex)
	local map = { ["0"] = "0000", ["1"] = "0001", ["2"] = "0010", ["3"] = "0011", ["4"] = "0100", ["5"] = "0101",
		["6"] = "0110", ["7"] = "0111", ["8"] = "1000", ["9"] = "1001", a = "1010", b = "1011", c = "1100", d = "1101", e = "1110", f = "1111" }
	return (hex:lower():gsub(".", map):gsub("^0+", ""))
end

local E_BITS = "10000000000000001" -- 65537

function Crypto.Verify(msg, sigB64, key)
	key = key or ns.LEDGER_PUBKEY
	if not key or type(sigB64) ~= "string" then return false end
	local sig = Crypto.B64Decode(sigB64)
	if not sig or #sig ~= key.bytes then return false end
	local s = fromBytes(sig, key.k)
	if geq(s, key.n, key.k) then return false end
	local m = modexp(s, E_BITS, key)
	return toBytes(m, key.bytes) == encode(msg, key.bytes)
end

-- Synchronous signing (tests / small batches)
function Crypto.Sign(msg, priv, key)
	key = key or ns.LEDGER_PUBKEY
	priv.bits = priv.bits or hexToBits(priv.d)
	local m = fromBytes(encode(msg, key.bytes), key.k)
	return Crypto.B64Encode(toBytes(modexp(m, priv.bits, key), key.bytes))
end

-- Signing spread across frames so the game does not hitch: callback(sigB64)
local signQueue, signer = {}, nil
function Crypto.SignAsync(msg, priv, callback, key)
	signQueue[#signQueue + 1] = { msg = msg, priv = priv, cb = callback, key = key or ns.LEDGER_PUBKEY }
	if signer then return end
	signer = CreateFrame("Frame")
	local co
	signer:SetScript("OnUpdate", function()
		if not co then
			local job = table.remove(signQueue, 1)
			if not job then signer:SetScript("OnUpdate", nil); signer = nil; return end
			co = coroutine.create(function()
				job.priv.bits = job.priv.bits or hexToBits(job.priv.d)
				local m = fromBytes(encode(job.msg, job.key.bytes), job.key.k)
				local r = modexp(m, job.priv.bits, job.key, function(i) if i % 6 == 0 then coroutine.yield() end end)
				job.cb(Crypto.B64Encode(toBytes(r, job.key.bytes)))
			end)
		end
		local ok, err = coroutine.resume(co)
		if not ok then geterrorhandler()(err); co = nil
		elseif coroutine.status(co) == "dead" then co = nil end
	end)
end
