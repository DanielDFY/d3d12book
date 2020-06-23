//***************************************************************************************
// Exercise_12_03 Default.hlsl by DanielDFY
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

    vout.Color = vin.Color;

    return vout;
}

[maxvertexcount(3)]
void GS(triangle VertexOut gin[3],
    inout TriangleStream<GeoOut> triangleStream) {
    
    float speed = 1.5f;
    float4 color = gin[0].Color;

    // Calculate the normal vector of each triangle
    float3 edge1 = float3(gin[1].PosW - gin[0].PosW);
    float3 edge2 = float3(gin[2].PosW - gin[0].PosW);
    float3 normal = normalize(cross(edge1, edge2));

    GeoOut geoOut;
    [unroll]
    for (int i = 0; i < 3; ++i) {
        // transform the triangle towards the normal vector
        geoOut.PosW = gin[i].PosW + speed * gPassConstants.gTotalTime * normal;
        geoOut.PosH = mul(float4(geoOut.PosW, 1.0), gPassConstants.gViewProj);
        geoOut.Color = color;

        triangleStream.Append(geoOut);
    }
    triangleStream.RestartStrip();
}

float4 PS(GeoOut pin) : SV_Target
{
    return pin.Color;
}