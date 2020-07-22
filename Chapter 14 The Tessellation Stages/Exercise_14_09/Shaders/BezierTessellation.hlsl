//***************************************************************************************
// BezierTessellation.hlsl by DanielDFY
//
// Demonstrates hardware tessellating a Bezier triangle patch.
//***************************************************************************************

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
	float EdgeTess[3]   : SV_TessFactor;
	float InsideTess : SV_InsideTessFactor;
};

PatchTess ConstantHS(InputPatch<VertexOut, 10> patch, uint patchID : SV_PrimitiveID)
{
	PatchTess pt;
	
	// Uniform tessellation for this demo.

	pt.EdgeTess[0] = 25;
	pt.EdgeTess[1] = 25;
	pt.EdgeTess[2] = 25;
	
	pt.InsideTess = 25;
	
	return pt;
}

struct HullOut
{
	float3 PosL : POSITION;
};

// This Hull Shader part is commonly used for a coordinate basis change
[domain("tri")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(10)]
[patchconstantfunc("ConstantHS")]
[maxtessfactor(64.0f)]
HullOut HS(InputPatch<VertexOut, 10> p, 
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

float3 CubicBezierSum(const OutputPatch<HullOut, 10> bezpatch, float basisU, float basisV, float basisW)
{
    float3 sum = float3(0.0f, 0.0f, 0.0f);

    sum = pow(basisV, 3) * bezpatch[0].PosL +
        3 * basisU * pow(basisV, 2) * bezpatch[1].PosL +
        3 * pow(basisV, 2) * basisW * bezpatch[2].PosL;

    sum += 3 * pow(basisU, 2) * basisV * bezpatch[3].PosL +
        6 * basisU * basisV * basisW * bezpatch[4].PosL +
        3 * pow(basisV, 2) * basisW * bezpatch[5].PosL;

    sum += pow(basisU, 3) * bezpatch[6].PosL +
        3 * pow(basisU, 2) * basisW * bezpatch[7].PosL +
        3 * basisU * pow(basisW, 2) * bezpatch[8].PosL +
        pow(basisW, 3) * bezpatch[9].PosL;

    return sum;
}

float3 duCubicBezierSum(const OutputPatch<HullOut, 10> bezpatch, float basisU, float basisV, float basisW)
{
    float3 sum = float3(0.0f, 0.0f, 0.0f);

    sum = 3 * pow(basisV, 2) * bezpatch[1].PosL -
        3 * pow(basisV, 2) * bezpatch[2].PosL;

    sum += 6 * basisU * basisV * bezpatch[3].PosL +
        6 * basisV * basisW * bezpatch[4].PosL - 
        6 * basisU * basisV * bezpatch[4].PosL - 
        6 * basisV * basisW * bezpatch[5].PosL;

    sum += 3 * pow(basisU, 2) * bezpatch[6].PosL +
        6 * basisU * basisW * bezpatch[7].PosL -
        3 * pow(basisU, 2) * bezpatch[7].PosL +
        3 * pow(basisW, 2) * bezpatch[8].PosL -
        6 * basisU * basisW * bezpatch[8].PosL + 
        3 * pow(basisW, 2) * bezpatch[9].PosL;

    return sum;
}

float3 dvCubicBezierSum(const OutputPatch<HullOut, 10> bezpatch, float basisU, float basisV, float basisW) {
    float3 sum = float3(0.0f, 0.0f, 0.0f);

    sum = 3 * pow(basisV, 2) * bezpatch[0].PosL +
        6 * basisU * basisV * bezpatch[1].PosL +
        6 * basisV * basisW * bezpatch[2].PosL -
        3 * pow(basisV, 2) * bezpatch[2].PosL;

    sum += 3 * pow(basisU, 2) * bezpatch[3].PosL +
        6 * basisU * basisW * bezpatch[4].PosL -
        6 * basisU * basisV * bezpatch[4].PosL +
        3 * pow(basisW, 2) * bezpatch[5].PosL -
        6 * basisV * basisW * bezpatch[5].PosL;

    sum += -3 * pow(basisU, 2) * bezpatch[7].PosL -
        6 * basisU * basisW * bezpatch[8].PosL -
        3 * pow(basisW, 2) * bezpatch[9].PosL;

    return sum;
}

// The domain shader is called for every vertex created by the tessellator.  
// It is like the vertex shader after tessellation.
[domain("tri")]
DomainOut DS(PatchTess patchTess, 
             float3 uvw : SV_DomainLocation, 
             const OutputPatch<HullOut, 10> bezPatch)
{
	DomainOut dout;

    float3 p = CubicBezierSum(bezPatch, uvw.x, uvw.y, uvw.z);

    /* bug: the following normal computation might be wrong */

    // compute tangent directions of u and v
    float3 dpdu = duCubicBezierSum(bezPatch, uvw.x, uvw.y, uvw.z);
    float3 dpdv = dvCubicBezierSum(bezPatch, uvw.x, uvw.y, uvw.z);

    // compute normal direction
    float3 normal = cross(dpdu, dpdv);
	
    dout.PosW = mul(float4(p, 1.0f), gObjectConstants.gWorld).xyz;
    dout.PosH = mul(float4(dout.PosW, 1.0), gPassConstants.gViewProj);
    dout.Normal = mul(float4(normal, 1.0f), gObjectConstants.gWorld).xyz;

    float4 texC = mul(float4(uvw, 1.0), gObjectConstants.gTexTransform);
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

    // wrong normal computation in DS, use fixed color to avoid bug
    // return litColor;
    return float4(1.0f, 1.0f, 1.0f, 1.0f);
}
