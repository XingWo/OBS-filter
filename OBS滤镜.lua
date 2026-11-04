--[[
红魔游戏空间 · 游戏滤镜复刻（OBS 滤镜脚本）
=================================================
全部从手机实拍对照图反推出来的：


安装：OBS → 工具 → 脚本 → 加号 → 选本文件
使用：源 → 滤镜 → 加号 → 「红魔游戏滤镜」
--]]

obs = obslua
bit = require('bit')

local S_MODE       = 'mode'
local S_AMOUNT     = 'amount'
local S_BRIGHTNESS = 'brightness'
local S_CONTRAST   = 'contrast'
local S_SATURATION = 'saturation'
local S_VIGNETTE   = 'vignette'
local S_OUTLINE_SIZE  = 'outline_size'
local S_OUTLINE_COLOR = 'outline_color'

------------------------------------------------------------------
-- 实测参数（来源：tools/params_poly.json + tools/crayon_params.json）
-- A: 3x3 通道混合；b: 偏置；poly: 每通道三次多项式 c0+c1*p+c2*p^2+c3*p^3
------------------------------------------------------------------
local IDENT = {
    A = { {1, 0, 0}, {0, 1, 0}, {0, 0, 1} },
    b = { 0, 0, 0 },
    poly = { {0, 1, 0, 0}, {0, 1, 0, 0}, {0, 1, 0, 0} },
}

local FILTERS = {
    {
        id = 'hunt', name = '狩猎', op = 'color',
        A = { {0.39047, -0.69564, -0.71678}, {-0.68574, 0.37521, -0.72453}, {-0.67789, -0.70254, 0.35130} },
        b = {1.03358, 1.03650, 1.03306},
        poly = { {0.01750, 0.46808, 1.21432, -0.70974}, {-0.01163, 0.76962, 0.62485, -0.39261}, {0.00899, 0.59358, 0.96673, -0.58103} },
    },
    {
        id = 'night', name = '夜视', op = 'color',
        A = { {1.00504, -0.06242, -0.01584}, {-0.10038, 1.04195, -0.01349}, {-0.11432, -0.03254, 1.07299} },
        b = {0.00872, 0.00799, 0.00827},
        poly = { {0.03387, 0.50209, 1.64020, -1.20464}, {0.04199, 0.50508, 1.43735, -0.98599}, {0.01982, 0.71427, 0.83986, -0.50306} },
    },
    {
        id = 'eagle', name = '鹰眼', op = 'eagle',
        A = { {0.99552, -0.00098, -0.01339}, {-0.00733, 0.99324, 0.00811}, {-0.00351, -0.00097, 0.98422} },
        b = {0.00271, 0.00335, 0.00269},
        poly = { {0.00187, 0.94252, 0.25623, -0.24367}, {0.00127, 0.97461, 0.10935, -0.10133}, {0.00156, 0.95023, 0.26292, -0.26558} },
        edge_t = 0.14, edge_w = 0.10, edge_gain = 1.0, g_k = 0.40, g_b = 0.08,
    },
    {
        id = 'sharp', name = '超清', op = 'ultra',
        A = { {1.01209, 0.03452, -0.00424}, {-0.02816, 1.09546, -0.02297}, {-0.01375, 0.03746, 1.01364} },
        b = {-0.01782, -0.01939, -0.01809},
        poly = { {0.00308, 0.93908, 0.22618, -0.17747}, {0.00410, 0.94174, 0.19431, -0.14580}, {0.00344, 0.94326, 0.19282, -0.13803} },
        usm_k = 0.32,
    },
    {
        -- 纯净 = 重度去饱和但保留淡彩（实测手机饱和度 12.9%，非全灰度）；
        id = 'pure', name = '纯净', op = 'color',
        A = { {0.33550, 0.32725, 0.33417}, {0.10270, 0.44787, 0.44034}, {0.13684, 0.26885, 0.58352} },
        b = {0.00077, 0.00195, 0.00150},
        poly = { {-0.00189, 1.01582, -0.02500, 0.00276}, {-0.00132, 1.01377, -0.03254, 0.01684}, {-0.00079, 1.00988, -0.02973, 0.02058} },
    },
    {
        id = 'cyber', name = '赛博朋克', op = 'color',
        A = { {0.84528, 0.14568, -0.12922}, {-0.18702, 1.13791, 0.07220}, {0.00526, -0.05151, 1.27824} },
        b = {-0.07961, -0.09526, -0.07278},
        poly = { {0.00343, 0.39011, 3.70865, -3.57405}, {0.01276, 0.54850, 1.96266, -1.55083}, {0.00873, 0.61982, 1.72617, -1.34564} },
    },
    {
        id = 'inst', name = '仪器模拟', op = 'color',
        A = { {0.30859, -0.01529, 0.01994}, {-0.00667, 1.00546, -0.00709}, {-0.00121, -0.00434, 0.32282} },
        b = {-0.00142, 0.00169, -0.00022},
        poly = { {0.00423, 0.71735, 3.55209, -9.64249}, {-0.00025, 0.99751, 0.02579, -0.03166}, {0.00028, 0.94418, 1.06673, -3.55237} },
    },
    {
        id = 'movie', name = '电影模拟', op = 'movie',
        A = { {0.79681, -0.00837, -0.01585}, {-0.04044, 0.78643, -0.02227}, {-0.05231, -0.00721, 0.63080} },
        b = {-0.02584, -0.02410, -0.00482},
        poly = { {0.00869, 0.61886, 2.23197, -2.60415}, {0.00075, 0.87749, 1.10305, -1.67956}, {0.00072, 0.77798, 2.59933, -4.98776} },
        grain = 0.165,
    },
    {
        id = 'sketch', name = '素描模拟', op = 'sketch',
        A = IDENT.A, b = IDENT.b, poly = IDENT.poly,
    },
    {
        id = 'film', name = '胶片模拟', op = 'movie',
        A = { {1.59399, -0.11739, -0.16095}, {0.02416, 1.38224, -0.07887}, {-0.03593, -0.00413, 0.72616} },
        b = {-0.09376, 0.07753, 0.28281},
        poly = { {-0.00909, 0.28276, 3.21700, -2.46552}, {-0.11563, 1.55996, -0.54668, -0.00088}, {-0.21549, 1.93585, -0.92835, -0.04384} },
        grain = 0.058,
    },
        -- 蜡笔模拟：只能说尽力还原了
    {
        id = 'crayon', name = '蜡笔模拟', op = 'crayon',
        A = IDENT.A, b = IDENT.b, poly = IDENT.poly,
        ilo = 0.44, ihi = 0.72, chroma_c0 = 0.02, chroma_c1 = 0.12, chroma_cap = 0.50,
        edge_t_strong = 0.30, edge_w_strong = 0.10,
        edge_t_weak = 0.025, edge_w_weak = 0.05, weak_gain = 0.85,
        weak_ink_gray = 0.84, weak_ink_color = 0.72, weak_cap = 0.35, wash = 0.40,
        dark_keep = 0.008, dark_w = 0.008, paper = 0.97,
    },
    {
        id = 'oil', name = '油画模拟', op = 'oil',
        A = { {0.98891, -0.00903, -0.01057}, {-0.00925, 0.98848, -0.00956}, {-0.00979, -0.00605, 0.98491} },
        b = {0.00626, 0.00598, 0.00592},
        poly = { {-0.00026, 0.97792, 0.13218, -0.14810}, {0.00014, 0.96899, 0.19250, -0.21179}, {-0.00004, 0.97524, 0.17534, -0.19961} },
    },
    -- 描边：与素描模拟同款描边（Sobel + lutEdge），其余保留原图；专属选项：描边大小 + 描边颜色
    {
        id = 'outline', name = '描边', op = 'outline',
        A = IDENT.A, b = IDENT.b, poly = IDENT.poly,
    },
    -- 蜡笔描边：与蜡笔模拟同款描边（形态学带双墨），其余保留原图；专属选项：仅描边大小（墨色跟随画面色相，无颜色选项）
    {
        id = 'crayon_outline', name = '蜡笔描边', op = 'crayon_outline',
        A = IDENT.A, b = IDENT.b, poly = IDENT.poly,
        ilo = 0.44, ihi = 0.72, chroma_c0 = 0.02, chroma_c1 = 0.12, chroma_cap = 0.50,
        edge_t_strong = 0.30, edge_w_strong = 0.10,
        edge_t_weak = 0.025, edge_w_weak = 0.05, weak_gain = 0.85,
        weak_ink_gray = 0.84, weak_ink_color = 0.72, weak_cap = 0.35,
    },
    -- 临时调试档已删除（eagle/movie 偏亮根因已定位：场景残留旧滤镜叠加）
}

-- 固定数值格式，避免 Lua 输出 1e-06 这种 HLSL 不接受的写法
local function n(v)
    local s = string.format('%.6f', v)
    return s
end

------------------------------------------------------------------
-- shader 模板
------------------------------------------------------------------
local TPL_HEAD = [==[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float2 pixel_size;
uniform float  amount;
uniform float  brightness;
uniform float  contrast;
uniform float  saturation;
uniform float  vignette;
uniform float  time_seed;
uniform float  outline_size;     // 描边/蜡笔描边：线宽（像素，1-10），由 UI 实时传入
uniform float outline_color_r;    // 描边：描边颜色 R（0..1），由 UI 实时传入
uniform float outline_color_g;    // 描边：描边颜色 G（0..1）
uniform float outline_color_b;    // 描边：描边颜色 B（0..1）

sampler_state textureSampler {
    Filter    = Linear;
    AddressU  = Clamp;
    AddressV  = Clamp;
};

struct VertDataIn {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

struct VertDataOut {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

VertDataOut VShader(VertDataIn v_in)
{
    VertDataOut o;
    o.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    o.uv  = v_in.uv;
    return o;
}

float3 tap(float2 uv)
{
    return image.Sample(textureSampler, uv).rgb;
}

float lum(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

// 3x3 Sobel，返回 0..1（0.25 是 4*255 归一化）
float gradMag(float2 uv)
{
    float2 d = pixel_size;
    float l00 = lum(tap(uv + float2(-d.x, -d.y)));
    float l10 = lum(tap(uv + float2( 0.0, -d.y)));
    float l20 = lum(tap(uv + float2( d.x, -d.y)));
    float l01 = lum(tap(uv + float2(-d.x,  0.0)));
    float l21 = lum(tap(uv + float2( d.x,  0.0)));
    float l02 = lum(tap(uv + float2(-d.x,  d.y)));
    float l12 = lum(tap(uv + float2( 0.0,  d.y)));
    float l22 = lum(tap(uv + float2( d.x,  d.y)));
    float gx = (l20 + 2.0 * l21 + l22) - (l00 + 2.0 * l01 + l02);
    float gy = (l02 + 2.0 * l12 + l22) - (l00 + 2.0 * l10 + l20);
    return sqrt(gx * gx + gy * gy) * 0.25;
}

float edgeSobel(float2 uv)
{
    return gradMag(uv);
}

// Sobel + 非极大值抑制 -> 1px 细线（比较梯度方向 ±1px 的插值梯度幅度）
float edgeThin(float2 uv)
{
    float2 d = pixel_size;
    float l00 = lum(tap(uv + float2(-d.x, -d.y)));
    float l10 = lum(tap(uv + float2( 0.0, -d.y)));
    float l20 = lum(tap(uv + float2( d.x, -d.y)));
    float l01 = lum(tap(uv + float2(-d.x,  0.0)));
    float l21 = lum(tap(uv + float2( d.x,  0.0)));
    float l02 = lum(tap(uv + float2(-d.x,  d.y)));
    float l12 = lum(tap(uv + float2( 0.0,  d.y)));
    float l22 = lum(tap(uv + float2( d.x,  d.y)));
    float gx = (l20 + 2.0 * l21 + l22) - (l00 + 2.0 * l01 + l02);
    float gy = (l02 + 2.0 * l12 + l22) - (l00 + 2.0 * l10 + l20);
    float e = sqrt(gx * gx + gy * gy) * 0.25;
    float2 g = float2(gx, gy) / (e * 4.0 + 1e-5);
    float e1 = gradMag(uv + g * d);
    float e2 = gradMag(uv - g * d);
    if (e < e1 || e < e2) return 0.0;
    return e;
}

// 3x3 扫描：输出形态学带(dilate-erode)与平均色度（蜡笔描边用）
// 实测：band 对锐利边缘(UI文字)输出 0.7+，对场景渐变边 0.05~0.2
void scan3x3(float2 uv, out float band, out float cmAvg)
{
    float2 d = pixel_size;
    float lumax = -1.0;
    float lumin = 1.0;
    float cmsum = 0.0;
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float3 s = tap(uv + float2(x, y) * d);
            float lg = lum(s);
            lumax = max(lumax, lg);
            lumin = min(lumin, lg);
            float3 ch = s - lg;
            cmsum += max(max(abs(ch.r), abs(ch.g)), abs(ch.b));
        }
    }
    band = lumax - lumin;
    cmAvg = cmsum / 9.0;
}

// 素描边缘强度 → 反相灰度查找表（离线按手机实拍逐像素拟合）。
// 移到共享区：素描模拟与「描边」用同一张表，保证描边与素描同款。
float lutEdge(float x)
{
    float v = 0.065;
    v = lerp(0.031, v, saturate((x - 0.45) / 0.20));
    v = lerp(0.042, v, saturate((x - 0.30) / 0.15));
    v = lerp(0.394, v, saturate((x - 0.20) / 0.10));
    v = lerp(0.545, v, saturate((x - 0.12) / 0.08));
    v = lerp(0.697, v, saturate((x - 0.08) / 0.04));
    v = lerp(0.820, v, saturate((x - 0.04) / 0.04));
    v = lerp(0.912, v, saturate((x - 0.02) / 0.02));
    v = lerp(0.954, v, saturate((x - 0.01) / 0.01));
    v = lerp(1.000, v, saturate( x        / 0.01));
    return v;
}

float3 colorModel(float3 c)
{
    float3 p;
    p.r = @A00@ * c.r + @A01@ * c.g + @A02@ * c.b + @B0@;
    p.g = @A10@ * c.r + @A11@ * c.g + @A12@ * c.b + @B1@;
    p.b = @A20@ * c.r + @A21@ * c.g + @A22@ * c.b + @B2@;
    p = saturate(p);

    float3 o;
    o.r = @P0R@ + p.r * (@P1R@ + p.r * (@P2R@ + p.r * @P3R@));
    o.g = @P0G@ + p.g * (@P1G@ + p.g * (@P2G@ + p.g * @P3G@));
    o.b = @P0B@ + p.b * (@P1B@ + p.b * (@P2B@ + p.b * @P3B@));
    return saturate(o);
}

float hash21(float2 p, float t)
{
    return frac(sin(dot(p, float2(12.9898, 78.233)) + t * 37.719) * 43758.5453);
}

]==]

local TPL_BODY = {
    color = [==[
float3 applyFilter(float3 c, float2 uv)
{
    return colorModel(c);
}
]==],
    ultra = [==[
float3 applyFilter(float3 c, float2 uv)
{
    float2 d = pixel_size;
    float3 s = tap(uv) * 4.0;
    s += (tap(uv + float2(d.x, 0.0)) + tap(uv - float2(d.x, 0.0))
        + tap(uv + float2(0.0, d.y)) + tap(uv - float2(0.0, d.y))) * 2.0;
    s += tap(uv + float2(d.x, d.y));
    s += tap(uv + float2(-d.x, d.y));
    s += tap(uv + float2(d.x, -d.y));
    s += tap(uv - float2(d.x, d.y));
    s /= 16.0;
    return colorModel(saturate(c + (c - s) * @USM@));
}
]==],
    eagle = [==[
float3 applyFilter(float3 c, float2 uv)
{
    float3 base = colorModel(c);
    float e = edgeThin(uv);
    float m = saturate((e - @ET@) / @EW@);
    m = m * m * (3.0 - 2.0 * m) * @EG@;
    float gk = @GK@ + @GB@ * lum(c);
    float3 green = float3(gk, 1.0, gk);
    return lerp(base, green, m);
}
]==],
    oil = [==[
// 油画 = 可分离 7x7 中值（实测手机：文字重度涂抹、场景柔化、平坦区不变）。
// 旧版 5x5 双边滤波因保边特性对文字完全不生效（效果≈无），已弃用。
// bitonic-8 排序网络（v7 为 +inf 哨兵），已用全排列验证取 v[3] 正确。
void CX(inout float3 a, inout float3 b)
{
    float3 mn = min(a, b);
    b = max(a, b);
    a = mn;
}

float3 med7h(float2 uv)
{
    float2 d = pixel_size;
    float3 v0 = tap(uv + float2(-3.0 * d.x, 0.0));
    float3 v1 = tap(uv + float2(-2.0 * d.x, 0.0));
    float3 v2 = tap(uv + float2(-1.0 * d.x, 0.0));
    float3 v3 = tap(uv);
    float3 v4 = tap(uv + float2(1.0 * d.x, 0.0));
    float3 v5 = tap(uv + float2(2.0 * d.x, 0.0));
    float3 v6 = tap(uv + float2(3.0 * d.x, 0.0));
    float3 v7 = float3(1e9, 1e9, 1e9);
    CX(v0, v1); CX(v3, v2); CX(v4, v5); CX(v7, v6);
    CX(v0, v2); CX(v1, v3); CX(v6, v4); CX(v7, v5);
    CX(v0, v1); CX(v2, v3); CX(v5, v4); CX(v7, v6);
    CX(v0, v4); CX(v1, v5); CX(v2, v6); CX(v3, v7);
    CX(v0, v2); CX(v1, v3); CX(v4, v6); CX(v5, v7);
    CX(v0, v1); CX(v2, v3); CX(v4, v5); CX(v6, v7);
    return v3;
}

float3 applyFilter(float3 c, float2 uv)
{
    float2 d = pixel_size;
    float3 w0 = med7h(uv + float2(0.0, -3.0 * d.y));
    float3 w1 = med7h(uv + float2(0.0, -2.0 * d.y));
    float3 w2 = med7h(uv + float2(0.0, -1.0 * d.y));
    float3 w3 = med7h(uv);
    float3 w4 = med7h(uv + float2(0.0, 1.0 * d.y));
    float3 w5 = med7h(uv + float2(0.0, 2.0 * d.y));
    float3 w6 = med7h(uv + float2(0.0, 3.0 * d.y));
    float3 w7 = float3(1e9, 1e9, 1e9);
    CX(w0, w1); CX(w3, w2); CX(w4, w5); CX(w7, w6);
    CX(w0, w2); CX(w1, w3); CX(w6, w4); CX(w7, w5);
    CX(w0, w1); CX(w2, w3); CX(w5, w4); CX(w7, w6);
    CX(w0, w4); CX(w1, w5); CX(w2, w6); CX(w3, w7);
    CX(w0, w2); CX(w1, w3); CX(w4, w6); CX(w5, w7);
    CX(w0, w1); CX(w2, w3); CX(w4, w5); CX(w6, w7);
    return colorModel(w3);
}
]==],
    movie = [==[
// 单色胶粒：4 tap 2x2 平均 -> 1px 自相关 ~0.5、团块 ~1.5px
float grainAt(float2 p, float t)
{
    float s = hash21(p, t);
    s += hash21(p + float2(1.0, 0.0), t);
    s += hash21(p + float2(0.0, 1.0), t);
    s += hash21(p + float2(1.0, 1.0), t);
    return s * 0.25 - 0.5;
}

float3 applyFilter(float3 c, float2 uv)
{
    float3 base = colorModel(c);
    float2 p = floor(uv / pixel_size);
    float t = floor(time_seed * 24.0);
    return saturate(base + grainAt(p, t) * @GRAIN@);
}
]==],
    sketch = [==[
float3 applyFilter(float3 c, float2 uv)
{
    float v = lutEdge(edgeSobel(uv));
    return float3(v, v, v);
}
]==],
    crayon = [==[
float3 applyFilter(float3 c, float2 uv)
{
    float l = lum(c);

    // 3x3 扫描：形态学带 + 平均色度（离线搜索见 tools/crayon_v33.py / params_v31_crayon.json）
    float band, cmAvg;
    scan3x3(uv, band, cmAvg);
    float3 ch = c - l;
    float cm = max(max(abs(ch.r), abs(ch.g)), abs(ch.b)) + 1e-5;
    float3 dir = ch / cm;

    // 墨色：色度低(UI文字) -> 深灰；色度高(场景) -> 亮彩，色相跟随 dir
    // 弱带独立浅彩墨（手机平坦区也带色，见 tools/crayon_v37.py 区间分析）
    float cf = saturate((cmAvg - @C0@) / (@C1@ - @C0@));
    float3 inkS = saturate(lerp(@ILO@, @IHI@, cf) + dir * (cf * @CAP@));
    float3 inkW = saturate(lerp(@WG@, @WC@, cf) + dir * (cf * @CAPW@));

    // 双阈值带：强带 -> 深描边(UI文字/锐边)，弱带 -> 浅彩线(场景渐变边)
    // 顺序：先弱带后强带，保证文字深描边不被弱带洗淡
    float ms = saturate((band - @ETS@) / @EWS@);
    float mw = saturate((band - @ETW@) / @EWW@) * @WK@;
    ms = ms * ms * (3.0 - 2.0 * ms);
    mw = mw * mw * (3.0 - 2.0 * mw);

    float3 col = lerp(float3(@PAPER@, @PAPER@, @PAPER@), inkW, mw);
    col = lerp(col, inkS, ms);

    // 全局色度 wash：只加色度不加亮度（手机平坦区饱和 3.62% 的来源）
    col += ch * @WASH@;

    // 极暗保留：实测原图 l<0.005 全黑保留，l>0.02 全白纸
    float dark = saturate((@DK@ - l) / @DKD@);
    return saturate(lerp(col, c, dark));
}
]==],
    debug = [==[
float3 applyFilter(float3 c, float2 uv)
{
    return c;
}
]==],

    -- 描边：沿用素描模拟同款描边（Sobel 边缘 → lutEdge 同款映射），
    -- 但只把“暗部主线条”作为覆盖层叠加到原图，其余保持原图不变。
    outline = [==[
float3 applyFilter(float3 c, float2 uv)
{
    // 与素描同款：Sobel 边缘强度 → 膨胀到 outline_size 像素 → lutEdge 取暗部为主线条
    float best = edgeSobel(uv);
    for (int s = 0; s < 8; s++)
    {
        float ang = 6.2831853 * (float)s / 8.0;
        float2 dir = float2(cos(ang), sin(ang));
        for (int k = 1; k <= 10; k++)
        {
            float r = (float)k;
            if (r > outline_size + 0.5) break;
            best = max(best, edgeSobel(uv + dir * pixel_size * r));
        }
    }
    float v = lutEdge(best);
    // 同素描：v 越低线越实（e 越大 → v 越小）；取 v<0.5 为主线条
    float cov = saturate(1.0 - smoothstep(0.2, 0.5, v));
    return lerp(c, float3(outline_color_r, outline_color_g, outline_color_b), cov);
}
]==],

    -- 蜡笔描边：沿用蜡笔模拟同款描边（形态学带双墨 inkS/inkW），
    -- 但只把墨线叠加到原图之上，不铺纸白、不加 wash、不极暗保留（保留原图）。仅描边大小可调。
    crayon_outline = [==[
float3 applyFilter(float3 c, float2 uv)
{
    float band, cmAvg; scan3x3(uv, band, cmAvg);
    float l = lum(c);
    float3 ch = c - l;
    float cm = max(max(abs(ch.r), abs(ch.g)), abs(ch.b)) + 1e-5;
    float3 dir = ch / cm;
    float cf = saturate((cmAvg - @C0@) / (@C1@ - @C0@));
    float3 inkS = saturate(lerp(@ILO@, @IHI@, cf) + dir * (cf * @CAP@));
    float3 inkW = saturate(lerp(@WG@, @WC@, cf) + dir * (cf * @CAPW@));

    // 膨胀 band 到 outline_size 像素（取邻域最锐利带）
    float bandMax = band;
    for (int s = 0; s < 6; s++)
    {
        float ang = 6.2831853 * (float)s / 6.0;
        float2 d2 = float2(cos(ang), sin(ang));
        for (int k = 1; k <= 10; k++)
        {
            float r = (float)k;
            if (r > outline_size + 0.5) break;
            float b2, dummy; scan3x3(uv + d2 * pixel_size * r, b2, dummy);
            bandMax = max(bandMax, b2);
        }
    }

    float ms = saturate((bandMax - @ETS@) / @EWS@);
    float mw = saturate((bandMax - @ETW@) / @EWW@) * @WK@;
    ms = ms * ms * (3.0 - 2.0 * ms);
    mw = mw * mw * (3.0 - 2.0 * mw);

    // 与原图一致：从原图起叠墨（先弱带后强带，顺序同蜡笔模拟）
    float3 col = lerp(c, inkW, mw);
    col = lerp(col, inkS, ms);
    return col;
}
]==],
}

local TPL_TAIL = [==[
float4 PShader(VertDataOut v_in) : TARGET
{
    float4 src = image.Sample(textureSampler, v_in.uv);
    float3 c   = src.rgb;

    float3 col = applyFilter(c, v_in.uv);

    col *= brightness;
    col = (col - 0.5) * contrast + 0.5;
    float g = lum(col);
    col = lerp(float3(g, g, g), col, saturation);

    if (vignette > 0.001)
    {
        float vd = distance(v_in.uv, float2(0.5, 0.5)) * 1.41421;
        col *= lerp(1.0, saturate(1.0 - vd * vd), vignette);
    }

    col = saturate(col);
    return float4(lerp(c, col, amount), src.a);
}

technique Draw
{
    pass
    {
        vertex_shader = VShader(v_in);
        pixel_shader  = PShader(v_in);
    }
}
]==]

------------------------------------------------------------------
-- 组装 shader
------------------------------------------------------------------
local function build_shader(f)
    local s = TPL_HEAD
    local A, b, poly = f.A, f.b, f.poly

    local rep = {
        ['@A00@'] = n(A[1][1]), ['@A01@'] = n(A[1][2]), ['@A02@'] = n(A[1][3]),
        ['@A10@'] = n(A[2][1]), ['@A11@'] = n(A[2][2]), ['@A12@'] = n(A[2][3]),
        ['@A20@'] = n(A[3][1]), ['@A21@'] = n(A[3][2]), ['@A22@'] = n(A[3][3]),
        ['@B0@']  = n(b[1]), ['@B1@'] = n(b[2]), ['@B2@'] = n(b[3]),
    }
    for c = 1, 3 do
        local tag = ({ 'R', 'G', 'B' })[c]
        for k = 1, 4 do
            rep['@P' .. (k - 1) .. tag .. '@'] = n(poly[c][k])
        end
    end

    s = s .. TPL_BODY[f.op] .. TPL_TAIL

    rep['@USM@']   = n(f.usm_k or 0.32)
    rep['@ET@']    = n(f.edge_t or 0.24)
    rep['@EW@']    = n(f.edge_w or 0.16)
    rep['@EG@']    = n(f.edge_gain or 0.35)
    rep['@GRAIN@'] = n(f.grain or 0.05)
    rep['@LIFT@']  = n(f.lift or 0.15)
    rep['@GK@']    = n(f.g_k or 0.38)
    rep['@GB@']    = n(f.g_b or 0.05)
    rep['@ILO@']   = n(f.ilo or 0.44)
    rep['@IHI@']   = n(f.ihi or 0.72)
    rep['@C0@']    = n(f.chroma_c0 or 0.02)
    rep['@C1@']    = n(f.chroma_c1 or 0.12)
    rep['@CAP@']   = n(f.chroma_cap or 0.50)
    rep['@ETS@']   = n(f.edge_t_strong or 0.30)
    rep['@EWS@']   = n(f.edge_w_strong or 0.10)
    rep['@ETW@']   = n(f.edge_t_weak or 0.025)
    rep['@EWW@']   = n(f.edge_w_weak or 0.05)
    rep['@WK@']    = n(f.weak_gain or 0.55)
    rep['@WG@']    = n(f.weak_ink_gray or 0.84)
    rep['@WC@']    = n(f.weak_ink_color or 0.72)
    rep['@CAPW@']  = n(f.weak_cap or 0.35)
    rep['@WASH@']  = n(f.wash or 0.40)
    rep['@DK@']    = n(f.dark_keep or 0.008)
    rep['@DKD@']   = n(f.dark_w or 0.008)
    rep['@PAPER@'] = n(f.paper or 1.0)

    for k, v in pairs(rep) do
        s = string.gsub(s, k, v)
    end
    return s
end

------------------------------------------------------------------
-- source
------------------------------------------------------------------
local source_def = {}
source_def.id           = 'redmagic_game_filters_v3'
source_def.type         = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO)

local function set_render_size(f)
    local target = obs.obs_filter_get_target(f.context)
    local w, h
    if target == nil then
        w, h = 0, 0
    else
        w = obs.obs_source_get_base_width(target)
        h = obs.obs_source_get_base_height(target)
    end
    f.width  = w
    f.height = h
    if w <= 0 then w = 1 end
    if h <= 0 then h = 1 end
    f.pixel_size.x = 1.0 / w
    f.pixel_size.y = 1.0 / h
end

local function rebuild_effect(f, mode)
    local filt = FILTERS[mode + 1] or FILTERS[1]
    obs.obs_enter_graphics()
    if f.effect ~= nil then
        obs.gs_effect_destroy(f.effect)
        f.effect = nil
    end
    f.effect = obs.gs_effect_create(build_shader(filt), nil, nil)
    if f.effect ~= nil then
        f.p = {
            pixel_size = obs.gs_effect_get_param_by_name(f.effect, 'pixel_size'),
            amount     = obs.gs_effect_get_param_by_name(f.effect, 'amount'),
            brightness = obs.gs_effect_get_param_by_name(f.effect, 'brightness'),
            contrast   = obs.gs_effect_get_param_by_name(f.effect, 'contrast'),
            saturation = obs.gs_effect_get_param_by_name(f.effect, 'saturation'),
            vignette   = obs.gs_effect_get_param_by_name(f.effect, 'vignette'),
            time_seed  = obs.gs_effect_get_param_by_name(f.effect, 'time_seed'),
            outline_size     = obs.gs_effect_get_param_by_name(f.effect, 'outline_size'),
            outline_color_r  = obs.gs_effect_get_param_by_name(f.effect, 'outline_color_r'),
            outline_color_g  = obs.gs_effect_get_param_by_name(f.effect, 'outline_color_g'),
            outline_color_b  = obs.gs_effect_get_param_by_name(f.effect, 'outline_color_b'),
        }
    end
    obs.obs_leave_graphics()
    return f.effect ~= nil
end

source_def.get_name = function()
    return '滤镜'
end

source_def.create = function(settings, source)
    local f = {}
    f.context    = source
    f.width      = 0
    f.height     = 0
    f.pixel_size = obs.vec2()
    f.mode       = -1
    set_render_size(f)
    rebuild_effect(f, 0)
    if f.effect == nil then
        return nil
    end
    source_def.update(f, settings)
    return f
end

source_def.destroy = function(f)
    if f.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(f.effect)
        obs.obs_leave_graphics()
        f.effect = nil
    end
end

source_def.get_width  = function(f) return f.width end
source_def.get_height = function(f) return f.height end

source_def.update = function(f, settings)
    local m = obs.obs_data_get_int(settings, S_MODE)
    if m ~= f.mode then
        if rebuild_effect(f, m) then
            f.mode = m
        else
            blog(obs.LOG_ERROR, 'shader 编译失败: ' .. ((FILTERS[m + 1] or {}).name or '?'))
            return
        end
    end
    f.amount     = obs.obs_data_get_double(settings, S_AMOUNT)
    f.brightness = obs.obs_data_get_double(settings, S_BRIGHTNESS)
    f.contrast   = obs.obs_data_get_double(settings, S_CONTRAST)
    f.saturation = obs.obs_data_get_double(settings, S_SATURATION)
    f.vignette   = obs.obs_data_get_double(settings, S_VIGNETTE)
    f.outline_size = obs.obs_data_get_double(settings, S_OUTLINE_SIZE)
    -- OBS 颜色属性存的是 0xAABBGGRR（低字节 R / bit8 G / bit16 B / bit24 A），
    -- 与 描边_*.lua 系列一致；切勿按 0xAARRGGBB 拆，否则红蓝互换（选红出蓝）。
    local ocol = obs.obs_data_get_int(settings, S_OUTLINE_COLOR)
    f.outline_color_r = bit.band(ocol, 0xFF) / 255.0
    f.outline_color_g = bit.band(bit.rshift(ocol, 8),  0xFF) / 255.0
    f.outline_color_b = bit.band(bit.rshift(ocol, 16), 0xFF) / 255.0
    set_render_size(f)
end

source_def.video_tick = function(f, seconds)
    set_render_size(f)
end

source_def.video_render = function(f, effect)
    if f.effect == nil or f.width <= 0 or f.height <= 0 then
        return
    end

    obs.obs_source_process_filter_begin(f.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

    obs.gs_effect_set_vec2(f.p.pixel_size, f.pixel_size)
    obs.gs_effect_set_float(f.p.amount,     f.amount)
    obs.gs_effect_set_float(f.p.brightness, f.brightness)
    obs.gs_effect_set_float(f.p.contrast,   f.contrast)
    obs.gs_effect_set_float(f.p.saturation, f.saturation)
    obs.gs_effect_set_float(f.p.vignette,   f.vignette)
    obs.gs_effect_set_float(f.p.time_seed,  os.clock() % 1000.0)

    if f.p.outline_size ~= nil then
        obs.gs_effect_set_float(f.p.outline_size, f.outline_size or 3.0)
    end
    if f.p.outline_color_r ~= nil then
        obs.gs_effect_set_float(f.p.outline_color_r, f.outline_color_r or 0.0)
        obs.gs_effect_set_float(f.p.outline_color_g, f.outline_color_g or 0.0)
        obs.gs_effect_set_float(f.p.outline_color_b, f.outline_color_b or 0.0)
    end

    obs.obs_source_process_filter_end(f.context, f.effect, f.width, f.height)
end

source_def.get_properties = function(f)
    local props = obs.obs_properties_create()

    local list = obs.obs_properties_add_list(props, S_MODE, '滤镜',
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)

    for i, item in ipairs(FILTERS) do
        obs.obs_property_list_add_int(list, item.name, i - 1)
    end

    obs.obs_properties_add_float_slider(props, S_AMOUNT, '强度', 0.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, S_BRIGHTNESS, '亮度', 0.5, 1.5, 0.01)
    obs.obs_properties_add_float_slider(props, S_CONTRAST, '对比度', 0.5, 2.0, 0.01)
    obs.obs_properties_add_float_slider(props, S_SATURATION, '饱和度', 0.0, 2.0, 0.01)
    obs.obs_properties_add_float_slider(props, S_VIGNETTE, '暗角', 0.0, 1.0, 0.01)

    -- 两个描边滤镜的专属选项（大小 1-10px；描边额外有颜色），仅对应档位可见
    local p_size  = obs.obs_properties_add_int_slider(props, S_OUTLINE_SIZE,  '描边大小', 1, 10, 1)
    local p_color = obs.obs_properties_add_color(props, S_OUTLINE_COLOR, '描边颜色')

    local function mode_index_of(id)
        for i, item in ipairs(FILTERS) do
            if item.id == id then return i - 1 end
        end
        return -1
    end
    local MODE_OUTLINE        = mode_index_of('outline')
    local MODE_CRAYON_OUTLINE = mode_index_of('crayon_outline')

    -- 初始可见性：当前档位由 update() 维护在 f.mode（不能把 f 当作 settings）
    local cur = (f and f.mode) or -1
    obs.obs_property_set_visible(p_size,  cur == MODE_OUTLINE or cur == MODE_CRAYON_OUTLINE)
    obs.obs_property_set_visible(p_color, cur == MODE_OUTLINE)

    -- 切换档位时同步显隐专属选项
    obs.obs_property_set_modified_callback(list, function(props2, p, settings2)
        local m = obs.obs_data_get_int(settings2, S_MODE)
        local so = (m == MODE_OUTLINE)
        local sc = (m == MODE_CRAYON_OUTLINE)
        local ps = obs.obs_properties_get(props2, S_OUTLINE_SIZE)
        local pc = obs.obs_properties_get(props2, S_OUTLINE_COLOR)
        if ps then obs.obs_property_set_visible(ps, so or sc) end
        if pc then obs.obs_property_set_visible(pc, so) end
        return true
    end)

    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, S_MODE, 0)
    obs.obs_data_set_default_double(settings, S_AMOUNT, 1.0)
    obs.obs_data_set_default_double(settings, S_BRIGHTNESS, 1.0)
    obs.obs_data_set_default_double(settings, S_CONTRAST, 1.0)
    obs.obs_data_set_default_double(settings, S_SATURATION, 1.0)
    obs.obs_data_set_default_double(settings, S_VIGNETTE, 0.0)
    obs.obs_data_set_default_int(settings, S_OUTLINE_SIZE, 3)
    obs.obs_data_set_default_int(settings, S_OUTLINE_COLOR, 0x000000)
end

obs.obs_register_source(source_def)

function script_description()
    return '仿红魔游戏滤镜同款滤镜'
end
