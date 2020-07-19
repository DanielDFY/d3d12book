//***************************************************************************************
// BezierTessellation.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//
// Demonstrates hardware tessellating a Bezier patch.
//***************************************************************************************

// Update to Shader Model 5.1

#ifndef NUM_DIR_LIGHTS
    #define NUM_DIR_LIGHTS 3
#endif

#ifndef NUM_DIR_LIGHTS
    #define NUM_DIR_LIGHTS 0
#endif

#ifndef NUM_DIR_LIGHTS
    #define NUM_DIR_LIGHTS 0
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

// Constant data that varies per object.
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
    float cbPerPassPad1;
    float2 gRenderTargetSize;
    float2 gInvRenderTargetSize;
    float gNearZ;
    float gFarZ;
    float gTotalTime;
    float gDeltaTime;
    float4 gAmbientLight;

    float4 gFogColor;
    float gFogStart;
    float gFogRange;
    float2 cbPerPassPad2;

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
    float cbPerPassPad1;
    float2 gRenderTargetSize;
    float2 gInvRenderTargetSize;
    float gNearZ;
    float gFarZ;
    float gTotalTime;
    float gDeltaTime;
    float4 gAmbientLight;

    float4 gFogColor;
    float gFogStart;
    float gFogRange;
    float2 cbPerPassPad2;

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

struct VertexIn
{
	float3 PosL    : POSITION;
};

struct VertexOut
{
	float3 PosL    : POSITION;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout;
	
	vout.PosL = vin.PosL;

	return vout;
}
 
struct PatchTess
{
	float EdgeTess[4]   : SV_TessFactor;
	float InsideTess[2] : SV_InsideTessFactor;
};

// Modify: now only use 9 control points

PatchTess ConstantHS(InputPatch<VertexOut, 9> patch, uint patchID : SV_PrimitiveID)
{
	PatchTess pt;
	
	// Uniform tessellation for this demo.

	pt.EdgeTess[0] = 25;
	pt.EdgeTess[1] = 25;
	pt.EdgeTess[2] = 25;
	pt.EdgeTess[3] = 25;
	
	pt.InsideTess[0] = 25;
	pt.InsideTess[1] = 25;
	
	return pt;
}

struct HullOut
{
	float3 PosL : POSITION;
};

// This Hull Shader part is commonly used for a coordinate basis change, 
// for example changing from a quad to a Bezier bi-cubic.
[domain("quad")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(9)]
[patchconstantfunc("ConstantHS")]
[maxtessfactor(64.0f)]
HullOut HS(InputPatch<VertexOut, 9> p, 
           uint i : SV_OutputControlPointID,
           uint patchId : SV_PrimitiveID)
{
	HullOut hout;
	
	hout.PosL = p[i].PosL;
	
	return hout;
}

struct DomainOut
{
    float4 PosH   : SV_POSITION;
    float3 PosW   : POSITION;
    float3 Normal : NORMAL;
    float2 TexC   : TEXCOORD;
};

float3 BernsteinBasis(float t)
{
    float invT = 1.0f - t;

    return float3( invT * invT ,
                   2.0f * t * invT ,
                   t * t );
}

float3 CubicBezierSum(const OutputPatch<HullOut, 9> bezpatch, float3 basisU, float3 basisV)
{
    float3 sum = float3(0.0f, 0.0f, 0.0f);
    sum  = basisV.x * (basisU.x*bezpatch[0].PosL  + basisU.y*bezpatch[1].PosL  + basisU.z*bezpatch[2].PosL );
    sum += basisV.y * (basisU.x*bezpatch[3].PosL  + basisU.y*bezpatch[4].PosL  + basisU.z*bezpatch[5].PosL );
    sum += basisV.z * (basisU.x*bezpatch[6].PosL  + basisU.y*bezpatch[7].PosL  + basisU.z*bezpatch[8].PosL);

    return sum;
}

float3 dBernsteinBasis(float t)
{
    float invT = 1.0f - t;

    return float3( -2.0f * invT,
                   2.0f * (invT - t),
                   2.0f * t );
}

// The domain shader is called for every vertex created by the tessellator.  
// It is like the vertex shader after tessellation.
[domain("quad")]
DomainOut DS(PatchTess patchTess, 
             float2 uv : SV_DomainLocation, 
             const OutputPatch<HullOut, 9> bezPatch)
{
	DomainOut dout;
	
	float3 basisU = BernsteinBasis(uv.x);
	float3 basisV = BernsteinBasis(uv.y);

	float3 p  = CubicBezierSum(bezPatch, basisU, basisV);

    // compute partial derivatives of u and v
    float3 dBasisU = dBernsteinBasis(uv.x);
    float3 dBasisV = dBernsteinBasis(uv.y);

    // compute tangent directions of u and v
    float3 dpdu = CubicBezierSum(bezPatch, dBasisU, basisV);
    float3 dpdv = CubicBezierSum(bezPatch, basisU, dBasisV);

    // compute normal direction
    float3 normal = cross(dpdu, dpdv);
	
    dout.PosW = mul(float4(p, 1.0f), gObjectConstants.gWorld).xyz;
    dout.PosH = mul(float4(dout.PosW, 1.0), gPassConstants.gViewProj);
    dout.Normal = mul(float4(normal, 1.0f), gObjectConstants.gWorld).xyz;

    float4 texC = mul(float4(uv, 0.0, 1.0), gObjectConstants.gTexTransform);
    dout.TexC = mul(texC, gMaterialConstants.gMatTransform).xy;

    return dout;
}

float4 PS(DomainOut pin) : SV_Target
{
    float4 diffuseAlbedo = gDiffuseMap.Sample(gsamAnisotropicWrap, pin.TexC) * gMaterialConstants.gDiffuseAlbedo;

    // Interpolating normal can unnormalize it, so renormalize it.
    pin.Normal = normalize(pin.Normal);

    // Vector from point being lit to eye. 
    float3 toEyeW = normalize(gPassConstants.gEyePosW - pin.PosW);

    // Light terms.
    float4 ambient = gPassConstants.gAmbientLight * diffuseAlbedo;

    const float shininess = 1.0f - gMaterialConstants.gRoughness;
    Material mat = { diffuseAlbedo, gMaterialConstants.gFresnelR0, shininess };
    float3 shadowFactor = 1.0f;
    float4 directLight = ComputeLighting(gPassConstants.gLights, mat, pin.PosW, pin.Normal, toEyeW, shadowFactor);

    float4 litColor = ambient + directLight;

    // Common convention to take alpha from diffuse albedo.
    litColor.a = diffuseAlbedo.a;

    return litColor;
}
