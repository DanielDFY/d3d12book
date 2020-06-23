//***************************************************************************************
// Exercise_12_01 Default.hlsl by DanielDFY
//***************************************************************************************

// Update to Shader Model 5.1

// Defaults for number of lights.
#ifndef NUM_DIR_LIGHTS
    #define NUM_DIR_LIGHTS 0
#endif

#ifndef NUM_POINT_LIGHTS
    #define NUM_POINT_LIGHTS 0
#endif

#ifndef NUM_SPOT_LIGHTS
    #define NUM_SPOT_LIGHTS 0
#endif

// Include structures and functions for lighting.
#include "LightingUtil.hlsl"

// Constant data that varies per object.
struct ObjectConstants {
    float4x4 gWorld;
    float4x4 gTexTransform;
};

ConstantBuffer<ObjectConstants> gObjectConstants : register(b0);

// Constant data that varies per frame.
struct PassConstants {
    float4x4 gView;
    float4x4 gInvView;
    float4x4 gProj;
    float4x4 gInvProj;
    float4x4 gViewProj;
    float4x4 gInvViewProj;
    float3 gEyePosW;
    float cbPerObjectPad1;
    float2 gRenderTargetSize;
    float2 gInvRenderTargetSize;
    float gNearZ;
    float gFarZ;
    float gTotalTime;
    float gDeltaTime;
    float4 gAmbientLight;

    // Allow application to change fog parameters once per frame.
    // For example, we may only use fog for certain times of day.
    float4 gFogColor;
    float gFogStart;
    float gFogRange;
    float2 cbPerObjectPad2;

    // Indices [0, NUM_DIR_LIGHTS) are directional lights;
    // indices [NUM_DIR_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHTS) are point lights;
    // indices [NUM_DIR_LIGHTS+NUM_POINT_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHT+NUM_SPOT_LIGHTS)
    // are spot lights for a maximum of MaxLights per object.
    Light gLights[MaxLights];
};

ConstantBuffer<PassConstants> gPassConstants : register(b1);

struct VertexIn {
	float3 PosL    : POSITION;
    float4 Color   : COLOR;
};

struct VertexOut {
    float3 PosW    : POSITION;
	float4 Color   : COLOR;
};

struct GeoOut {
    float4 PosH    : SV_POSITION;
    float3 PosW    : POSITION;
    float4 Color   : COLOR;
};

VertexOut VS(VertexIn vin) {
    VertexOut vout = (VertexOut)0.0f;

    // Transform to world space.
    float4 posW = mul(float4(vin.PosL, 1.0f), gObjectConstants.gWorld);
    vout.PosW = posW.xyz;

    return vout;
}

[maxvertexcount(4)]
void GS(line VertexOut gin[2], inout LineStream<GeoOut> lineStream) {
    float4 offsetVecter = { 0.0f, 10.0f, 0.0f, 0.0f };
    float4 color = gin[0].Color;

    // Generate quad from line
    float4 v[4];
    v[0] = float4(gin[0].PosW, 1.0f);
    v[1] = float4(gin[1].PosW, 1.0f);
    v[2] = v[1] + offsetVecter;
    v[3] = v[0] + offsetVecter;

    GeoOut geoOut;
    [unroll]
    for (int i = 0; i < 4; ++i) {
        geoOut.PosH = mul(v[i], gPassConstants.gViewProj);
        geoOut.PosW = v[i].xyz;
        geoOut.Color = color;

        lineStream.Append(geoOut);
    }
}

float4 PS(GeoOut pin) : SV_Target
{
    return pin.Color;
}