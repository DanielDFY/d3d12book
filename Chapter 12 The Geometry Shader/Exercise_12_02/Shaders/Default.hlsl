//***************************************************************************************
// Exercise_12_02 Default.hlsl by DanielDFY
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

void subdivide(VertexOut v0, VertexOut v1, VertexOut v2, out VertexOut outVertices[6]) {
    float len = length(v0.PosW);
    float4 color = v0.Color;

    //       v1
    //       *
    //      / \
	//     /   \
	//  m0*-----*m1
    //   / \   / \
	//  /   \ /   \
	// *-----*-----*
    // v0    m2     v2

    float3 m[3];

    // Compute edge midpoints and project them onto unit sphere.
    m[0] = normalize(0.5f * (v0.PosW + v1.PosW)) * len;
    m[1] = normalize(0.5f * (v1.PosW + v2.PosW)) * len;
    m[2] = normalize(0.5f * (v2.PosW + v0.PosW)) * len;

    // Add new geometry.
    outVertices[0].PosW = v0.PosW;
    outVertices[1].PosW = m[0];
    outVertices[2].PosW = m[2];
    outVertices[3].PosW = m[1];
    outVertices[4].PosW = v2.PosW;
    outVertices[5].PosW = v1.PosW;

    [unroll]
    for (int i = 0; i < 6; ++i) {
        outVertices[i].Color = color;
    }
}

void outputSubdivision(VertexOut v[6], inout TriangleStream<GeoOut> triangleStream) {
    GeoOut geoOut[6];

    [unroll]
    for (int i = 0; i < 6; ++i) {
        geoOut[i].PosH = mul(float4(v[i].PosW, 1.0f), gPassConstants.gViewProj);
        geoOut[i].PosW = v[i].PosW;
        geoOut[i].Color = v[i].Color;
    }

    //       5
    //       *
    //      / \
	//     /   \
	//  1 *-----* 3
    //   / \   / \
	//  /   \ /   \
	// *-----*-----*
    // 0     2      4

    // We can draw the subdivision in two strips:
    // Strip 1: bottom three triangles
    // Strip 2: top triangle

    [unroll]
    for (int j = 0; j < 5; ++j) {
        triangleStream.Append(geoOut[j]);
    }

    triangleStream.RestartStrip();

    triangleStream.Append(geoOut[1]);
    triangleStream.Append(geoOut[5]);
    triangleStream.Append(geoOut[3]);

    triangleStream.RestartStrip();
}

[maxvertexcount(40)]
void GS(triangle VertexOut gin[3], inout TriangleStream<GeoOut> triangleStream) {
    float distance = length(gPassConstants.gEyePosW);

    if (distance >= 30.0f) {
        // no subdivision
        float4 v[3];
        v[0] = float4(gin[0].PosW, 1.0f);
        v[1] = float4(gin[1].PosW, 1.0f);
        v[2] = float4(gin[2].PosW, 1.0f);

        float4 color = gin[0].Color;

        GeoOut geoOut[3];
        [unroll]
        for (int i = 0; i < 3; ++i) {
            geoOut[i].PosH = mul(v[i], gPassConstants.gViewProj);
            geoOut[i].PosW = v[i].xyz;
            geoOut[i].Color = color;

            triangleStream.Append(geoOut[i]);
        }
    } else if (distance >= 15.0f) {
        // one subdivision
        VertexOut v[6];
        subdivide(gin[0], gin[1], gin[2], v);
        outputSubdivision(v, triangleStream);
    } else {
        // two subdivisions
        VertexOut v1[6];
        subdivide(gin[0], gin[1], gin[2], v1);

        VertexOut v2[6];
        subdivide(v1[0], v1[1], v1[2], v2);
        outputSubdivision(v2, triangleStream);
        subdivide(v1[1], v1[3], v1[2], v2);
        outputSubdivision(v2, triangleStream);
        subdivide(v1[2], v1[3], v1[4], v2);
        outputSubdivision(v2, triangleStream);
        subdivide(v1[3], v1[1], v1[5], v2);
        outputSubdivision(v2, triangleStream);
    }
    
}

float4 PS(GeoOut pin) : SV_Target
{
    return pin.Color;
}