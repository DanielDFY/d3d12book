//***************************************************************************************
// Tessellation.hlsl by DanielDFY
//***************************************************************************************

// Update to Shader Model 5.1

// Tessellate an icosahedron into a sphere based on distance.

// Include structures and functions for lighting.
#include "LightingUtil.hlsl"

// Constant data that varies per object.

struct ObjectConstants {
    float4x4 gWorld;
    float gRadius;
};

ConstantBuffer<ObjectConstants> gObjectConstants : register(b0);

// Constant data that varies per material.

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

struct VertexIn {
    float3 PosL    : POSITION;
};

struct VertexOut {
    float3 PosL    : POSITION;
};

VertexOut VS(VertexIn vin) {
    VertexOut vout;

    vout.PosL = vin.PosL;

    return vout;
}

struct PatchTess {
    float EdgeTess[3]   : SV_TessFactor;
    float InsideTess : SV_InsideTessFactor;
};

PatchTess ConstantHS(InputPatch<VertexOut, 3> patch, uint patchID : SV_PrimitiveID) {
    PatchTess pt;

    // the sphere is fixed at origin
    float3 centerL = float3(0.0, 0.0, 0.0);
    float3 centerW = mul(float4(centerL, 1.0f), gObjectConstants.gWorld).xyz;

    float d = distance(centerW, gPassConstants.gEyePosW);

    // Tessellate the patch based on distance from the eye such that
    // the tessellation is 0 if d >= d1 and 5 if d <= d0.  The interval
    // [d0, d1] defines the range we tessellate in.

    const float d0 = 20.0f;
    const float d1 = 50.0f;
    float tess = 5.0f * saturate((d1 - d) / (d1 - d0));

    // Uniformly tessellate the patch.

    pt.EdgeTess[0] = tess;
    pt.EdgeTess[1] = tess;
    pt.EdgeTess[2] = tess;

    pt.InsideTess = tess;

    return pt;
}

struct HullOut {
    float3 PosL : POSITION;
};

[domain("tri")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(3)]
[patchconstantfunc("ConstantHS")]
[maxtessfactor(5.0f)]
HullOut HS(InputPatch<VertexOut, 3> p,
    uint i : SV_OutputControlPointID,
    uint patchId : SV_PrimitiveID) {
    HullOut hout;

    hout.PosL = p[i].PosL;

    return hout;
}

struct DomainOut {
    float4 PosH : SV_POSITION;
};

// The domain shader is called for every vertex created by the tessellator.  
// It is like the vertex shader after tessellation.
[domain("tri")]
DomainOut DS(PatchTess patchTess,
    float3 uvw : SV_DomainLocation,
    const OutputPatch<HullOut, 3> tri) {
    DomainOut dout;

    // Barycentric coordinates
    float3 v1 = tri[0].PosL * uvw.x;
	float3 v2 = tri[1].PosL * uvw.y;
	float3 v3 = tri[2].PosL * uvw.z;
    float3 p = normalize(v1 + v2 + v3) * gObjectConstants.gRadius;

    float4 posW = mul(float4(p, 1.0f), gObjectConstants.gWorld);
    dout.PosH = mul(posW, gPassConstants.gViewProj);

    return dout;
}

float4 PS(DomainOut pin) : SV_Target
{
    return float4(1.0f, 1.0f, 1.0f, 1.0f);
}
