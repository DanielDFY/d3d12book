//***************************************************************************************
// Default.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//
// Default shader, currently supports lighting.
//***************************************************************************************

// Exercise_09_03 Default.hlsl modified by DanielDFY

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

// Modify: now there are two textures
/*
Texture2D    gDiffuseMap : register(t0);
*/
Texture2D    gDiffuseMap : register(t0);
Texture2D    gDiffuseAlphaMap : register(t1);

// Static samplers
/*
SamplerState gsamLinear  : register(s0);
*/
SamplerState gSamPointWrap        : register(s0);
SamplerState gSamPointClamp       : register(s1);
SamplerState gSamLinearWrap       : register(s2);
SamplerState gSamLinearClamp      : register(s3);
SamplerState gSamAnisotropicWrap  : register(s4);
SamplerState gSamAnisotropicClamp : register(s5);

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

// Constant data that varies per frame.
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

    // Indices [0, NUM_DIR_LIGHTS) are directional lights;
    // indices [NUM_DIR_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHTS) are point lights;
    // indices [NUM_DIR_LIGHTS+NUM_POINT_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHT+NUM_SPOT_LIGHTS)
    // are spot lights for a maximum of MaxLights per object.
    Light gLights[MaxLights];
};

ConstantBuffer<PassConstants> gPassConstants : register(b1);

// Constant data that varies per material.
/*
cbuffer cbMaterial : register(b2)
{
	float4 gDiffuseAlbedo;
    float3 gFresnelR0;
    float  gRoughness;
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

struct VertexIn
{
	float3 PosL    : POSITION;
    float3 NormalL : NORMAL;
	float2 TexC    : TEXCOORD;
};

struct VertexOut
{
	float4 PosH    : SV_POSITION;
    float3 PosW    : POSITION;
    float3 NormalW : NORMAL;
	float2 TexC    : TEXCOORD;
    // Modify: add alpha texture coordinates 
    float2 TexAlphaC    : TEXALPHACOORD;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout = (VertexOut)0.0f;
	
    // Transform to world space.
    float4 posW = mul(float4(vin.PosL, 1.0f), gObjectConstants.gWorld);
    vout.PosW = posW.xyz;

    // Assumes nonuniform scaling; otherwise, need to use inverse-transpose of world matrix.
    vout.NormalW = mul(vin.NormalL, (float3x3)gObjectConstants.gWorld);

    // Transform to homogeneous clip space.
    vout.PosH = mul(posW, gPassConstants.gViewProj);

    // Modify: add alpha texture coordinates 
    // Transform texture(alpha) coordinates
    float4 texAlphaC = mul(float4(vin.TexC, 0.0f, 1.0f), gObjectConstants.gTexTransform);
    vout.TexAlphaC = mul(texAlphaC, gMaterialConstants.gMatTransform).xy;

    // Modify: rotate the original texture
    // Rotation as a funtion of time
    float2x2 texRotation = float2x2(
		float2(cos(gPassConstants.gTotalTime), sin(gPassConstants.gTotalTime)),
		float2(-sin(gPassConstants.gTotalTime), cos(gPassConstants.gTotalTime)));

    // Rotate the texture around the center
    vin.TexC -= float2(0.5, 0.5);
	vin.TexC = mul(vin.TexC, texRotation);
	vin.TexC += float2(0.5, 0.5);
	
	// Transform texture coordinates
    float4 texC = mul(float4(vin.TexC, 0.0f, 1.0f), gObjectConstants.gTexTransform);
    vout.TexC = mul(texC, gMaterialConstants.gMatTransform).xy;

    return vout;
}

float4 PS(VertexOut pin) : SV_Target
{
    float4 diffuseAlbedo = gDiffuseMap.Sample(gSamAnisotropicWrap, pin.TexC) *
                            gDiffuseAlphaMap.Sample(gSamAnisotropicWrap, pin.TexAlphaC) *
                            gMaterialConstants.gDiffuseAlbedo;

    // Interpolating normal can unnormalize it, so renormalize it.
    pin.NormalW = normalize(pin.NormalW);

    // Vector from point being lit to eye. 
    float3 toEyeW = normalize(gPassConstants.gEyePosW - pin.PosW);

    // Light terms.
    float4 ambient = gPassConstants.gAmbientLight * diffuseAlbedo;

    const float shininess = 1.0f - gMaterialConstants.gRoughness;
    Material mat = { diffuseAlbedo, gMaterialConstants.gFresnelR0, shininess };
    float3 shadowFactor = 1.0f;
    float4 directLight = ComputeLighting(gPassConstants.gLights, mat, pin.PosW,
        pin.NormalW, toEyeW, shadowFactor);

    float4 litColor = ambient + directLight;

    // Common convention to take alpha from diffuse material.
    litColor.a = diffuseAlbedo.a;

    return litColor;
}


