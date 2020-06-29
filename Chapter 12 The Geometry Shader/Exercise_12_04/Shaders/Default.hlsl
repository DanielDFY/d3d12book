//***************************************************************************************
// Exercise_12_04 Default.hlsl by DanielDFY
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
struct ObjectConstants {
    float4x4 gWorld;
	float4x4 gTexTransform;
};

ConstantBuffer<ObjectConstants> gObjectConstants : register(b0);

// Constant data that varies per pass.
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

// Constant data that varies per material.
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
    float3 PosW    : POSITION;
    float3 NormalW : NORMAL;
	float2 TexC    : TEXCOORD;
};

struct GeoOut {
    float4 PosH    : SV_POSITION;
    float3 PosW    : POSITION;
    float3 NormalW : NORMAL;
    float2 TexC    : TEXCOORD;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout = (VertexOut)0.0f;
	
    // Transform to world space.
    float4 posW = mul(float4(vin.PosL, 1.0f), gObjectConstants.gWorld);
    vout.PosW = posW.xyz;

    // Assumes nonuniform scaling; otherwise, need to use inverse-transpose of world matrix.
    vout.NormalW = mul(vin.NormalL, (float3x3)gObjectConstants.gWorld);

	// Output vertex attributes for interpolation across triangle.
	float4 texC = mul(float4(vin.TexC, 0.0f, 1.0f), gObjectConstants.gTexTransform);
	vout.TexC = mul(texC, gMaterialConstants.gMatTransform).xy;

    return vout;
}

[maxvertexcount(3)]
void GS(triangle VertexOut gin[3],
    inout TriangleStream<GeoOut> triangleStream) {

    // draw the mesh as normal, passing all the data from vertex shader
    [unroll]
    for (int i = 0; i < 3; ++i) {
        GeoOut geoOut;
        geoOut.PosW = gin[i].PosW;
        geoOut.PosH = mul(float4(geoOut.PosW, 1.0f), gPassConstants.gViewProj);
        geoOut.NormalW = gin[i].NormalW;
        geoOut.TexC = gin[i].TexC;

        triangleStream.Append(geoOut);
    }
    triangleStream.RestartStrip();
}

[maxvertexcount(2)]
void VNGS(triangle VertexOut gin[3],
    inout LineStream<GeoOut> lineStream) {

    // visualize the normal of each vertex
    for (int i = 0; i < 3; ++i) {
        GeoOut geoOut[2];

        // root point
        geoOut[0].PosW = gin[i].PosW;
        // Transform to homogeneous clip space.
        geoOut[0].PosH = mul(float4(geoOut[0].PosW, 1.0f), gPassConstants.gViewProj);
        geoOut[0].NormalW = gin[i].NormalW;
        geoOut[0].TexC = gin[i].TexC;

        // head point
        geoOut[1].PosW = gin[i].PosW + normalize(gin[i].NormalW) * 2.0f;
        // Transform to homogeneous clip space.
        geoOut[1].PosH = mul(float4(geoOut[1].PosW, 1.0f), gPassConstants.gViewProj);
        geoOut[1].NormalW = gin[i].NormalW;
        geoOut[1].TexC = gin[i].TexC;

        lineStream.Append(geoOut[0]);
        lineStream.Append(geoOut[1]);
    }
}

[maxvertexcount(2)]
void FNGS(triangle VertexOut gin[3],
    inout LineStream<GeoOut> lineStream) {

    // visualize the normal of each triangle face

    // calculate the center point of triangle
    float3 pivot = (gin[0].PosW + gin[1].PosW + gin[2].PosW) / 3;

    // calculate texture coordinates of the center point
    float2 texC = (gin[0].TexC + gin[1].TexC + gin[2].TexC) / 3;

    // calculate the normal of triangle
    float3 v1 = gin[1].PosW - gin[0].PosW;
    float3 v2 = gin[2].PosW - gin[0].PosW;
    float3 normal = normalize(cross(v1, v2));

    GeoOut geoOut[2];

    // root point
    geoOut[0].PosW = pivot;
    geoOut[0].PosH = mul(float4(geoOut[0].PosW, 1.0f), gPassConstants.gViewProj);
    geoOut[0].NormalW = normal;
    geoOut[0].TexC = texC;

    // head point
    geoOut[1].PosW = pivot + normal * 1.5f;
    geoOut[1].PosH = mul(float4(geoOut[1].PosW, 1.0f), gPassConstants.gViewProj);
    geoOut[1].NormalW = normal;
    geoOut[1].TexC = texC;

    lineStream.Append(geoOut[0]);
    lineStream.Append(geoOut[1]);
}

float4 PS(GeoOut pin) : SV_Target
{
    float4 diffuseAlbedo = gDiffuseMap.Sample(gsamAnisotropicWrap, pin.TexC) * gMaterialConstants.gDiffuseAlbedo;
	
#ifdef ALPHA_TEST
	// Discard pixel if texture alpha < 0.1.  We do this test as soon 
	// as possible in the shader so that we can potentially exit the
	// shader early, thereby skipping the rest of the shader code.
	clip(diffuseAlbedo.a - 0.1f);
#endif

    // Interpolating normal can unnormalize it, so renormalize it.
    pin.NormalW = normalize(pin.NormalW);

    // Vector from point being lit to eye. 
	float3 toEyeW = gPassConstants.gEyePosW - pin.PosW;
	float distToEye = length(toEyeW);
	toEyeW /= distToEye; // normalize

    // Light terms.
    float4 ambient = gPassConstants.gAmbientLight*diffuseAlbedo;

    const float shininess = 1.0f - gMaterialConstants.gRoughness;
    Material mat = { diffuseAlbedo, gMaterialConstants.gFresnelR0, shininess };
    float3 shadowFactor = 1.0f;
    float4 directLight = ComputeLighting(gPassConstants.gLights, mat, pin.PosW,
        pin.NormalW, toEyeW, shadowFactor);

    float4 litColor = ambient + directLight;

#ifdef FOG
	float fogAmount = saturate((distToEye - gPassConstants.gFogStart) / gPassConstants.gFogRange);
	litColor = lerp(litColor, gPassConstants.gFogColor, fogAmount);
#endif

    // Common convention to take alpha from diffuse albedo.
    litColor.a = diffuseAlbedo.a;

    return litColor;
}


