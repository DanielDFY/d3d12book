//***************************************************************************************
// Default.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//
// Default shader, currently supports lighting.
//***************************************************************************************

// Update to Shader Model 5.1

// Defaults for number of lights.
#ifndef NUM_DIR_LIGHTS
    #define NUM_DIR_LIGHTS 3
#endif

#ifndef NUM_POINT_LIGHTS
    #define NUM_POINT_LIGHTS 0
#endif

#ifndef NUM_SPOT_LIGHTS
    #define NUM_SPOT_LIGHTS 0
#endif

// Include structures and functions for lighting.
#include "LightingUtil.hlsl"

Texture2D    gDiffuseMap : register(t0);

SamplerState gsamPointWrap        : register(s0);
SamplerState gsamPointClamp       : register(s1);
SamplerState gsamLinearWrap       : register(s2);
SamplerState gsamLinearClamp      : register(s3);
SamplerState gsamAnisotropicWrap  : register(s4);
SamplerState gsamAnisotropicClamp : register(s5);

// Constant data that varies per frame.
/*
cbuffer cbPerObject : register(b0)
{
    float4x4 gWorld;
	float4x4 gTexTransform;
};
*/

struct ObjectConstants {
    float4x4 gWorld;
	float4x4 gTexTransform;
};

ConstantBuffer<ObjectConstants> gObjectConstants : register(b0);

// Constant data that varies per pass.
/*
cbuffer cbPass : register(b1)
{
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
*/

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

/*
cbuffer cbMaterial : register(b2)
{
	float4   gDiffuseAlbedo;
    float3   gFresnelR0;
    float    gRoughness;
	float4x4 gMatTransform;
};
*/

struct MaterialConstants {
    float4 gDiffuseAlbedo;
    float3 gFresnelR0;
    float  gRoughness;
	float4x4 gMatTransform;
};

ConstantBuffer<MaterialConstants> gMaterialConstants : register(b2);

// Stencil Reference
struct StencilConstants {
    uint gStencilRef;
};

ConstantBuffer<StencilConstants> gStencilConstants : register(b3);

struct VertexOut
{
	float4 PosH    : SV_POSITION;
	float2 TexC    : TEXCOORD;
};

// The window is composed by two triangle
static const float2 gTexCoords[6] =
{
	float2(0.0f, 1.0f), // left bottom
	float2(0.0f, 0.0f), // lefttop
	float2(1.0f, 0.0f), // right top
    
	float2(0.0f, 1.0f), // left bottom
	float2(1.0f, 0.0f), // right top
	float2(1.0f, 1.0f)  // right bottom
};

VertexOut VS(uint vid : SV_VertexID)
{
	VertexOut vout;

	// convert window coordinates into NDC coordinates to cover the whole window
	vout.TexC = gTexCoords[vid];
	vout.PosH = float4(2.0f * vout.TexC.x - 1.0f, 1.0f - 2.0f * vout.TexC.y, 0.0f, 1.0f);

	return vout;
}

float4 PS(VertexOut pin) : SV_Target
{
    float4 firstLevelColor = float4(0.2f, 0.2f, 0.2f, 1.0f);    // draw 1 time
    float4 secondLevelColor = float4(0.4f, 0.4f, 0.4f, 1.0f);   // draw 2 times
	float4 thirdLevelColor = float4(0.6f, 0.6f, 0.6f, 1.0f);    // draw 3 times
	float4 forthLevelColor = float4(0.8f, 0.8f, 0.8f, 1.0f);    // draw 4 times
	float4 fifthLevelColor = float4(1.0f, 1.0f, 1.0f, 1.0f);    // draw > 4 times

    switch(gStencilConstants.gStencilRef) {
        case 1:
            return firstLevelColor;
        case 2:
            return secondLevelColor;
        case 3:
            return thirdLevelColor;
        case 4:
            return forthLevelColor;
        default:
            return fifthLevelColor;
    }
}


